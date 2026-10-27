#!/usr/bin/env python3
"""Read-only preflight for kramme:pr:create Steps 1-4.5.

  python3 pr-create-preflight.py [--base <branch>] [--feature-branch <name>] [--linear-issue <ID>] [--auto]

Prints one JSON document with `schema_version`, `status`, `reason`, `message`, and `facts`. Exit codes:
0 `ok`; 1 `blocked` (`reason` names the gate); 2 `error` (invalid invocation or internal failure);
3 `feature_branch_required` (the entry is detached or on the base and no `--feature-branch` was given) or
`remote_classification_required` (origin has the branch at another commit, or at the exact tip with dirty
`--auto` work; every other check passed).

The helper never creates branches, commits, or stashes, never pushes or changes configuration, and never
prints the origin URL. Its only write is the base fetch that `scripts/resolve-base.sh` performs. Git and
GitHub CLI failures are blockers, never evidence of absence.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any, Dict, NoReturn, Sequence, Tuple

if TYPE_CHECKING:
    Proc = subprocess.CompletedProcess[bytes]
JsonDict = Dict[str, Any]
Codes = Tuple[int, ...]

SCHEMA_VERSION = 1
SKILL_SCRIPTS = Path(__file__).resolve().parent
PLUGIN_SCRIPTS = SKILL_SCRIPTS.parents[2] / "scripts"
RESOLVE_BASE = PLUGIN_SCRIPTS / "resolve-base.sh"
RESOLVE_STACK = PLUGIN_SCRIPTS / "resolve-stack-membership.sh"
VALIDATE_BRANCH = SKILL_SCRIPTS / "validate-branch-name.sh"
VERIFY_CLEAN = SKILL_SCRIPTS / "verify-clean-worktree.sh"
REQUIRED_SCRIPTS = (RESOLVE_BASE, RESOLVE_STACK, VALIDATE_BRANCH, VERIFY_CLEAN)

REF_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*")
OID_RE = re.compile(r"[0-9a-f]{40}")
HOST_RE = re.compile(r"[A-Za-z0-9.-]+(:[0-9]+)?")
LINEAR_OVERRIDE_RE = re.compile(r"[A-Za-z0-9]+-[0-9]+")
LINEAR_BRANCH_RE = re.compile(r"[A-Z]{2,5}-[0-9]+", re.IGNORECASE)
GIT_OPERATIONS = (
    ("rebase-merge", "rebase"),
    ("rebase-apply", "rebase"),
    ("MERGE_HEAD", "merge"),
    ("CHERRY_PICK_HEAD", "cherry-pick"),
    ("REVERT_HEAD", "revert"),
)
PR_FIELDS = "number,url,state,headRefName"
COMMIT_LIMIT = 100
INCLUDE_COMMIT_SUBJECT = "Include uncommitted changes for PR creation"
PLACEHOLDER_WORDS = frozenset({"wip", "temp", "tmp", "fixup", "misc"})
AUTOSQUASH_RE = re.compile(r"(fixup|squash|amend)! ")
AI_TRAILER_RE = re.compile(
    r"^co-authored-by:.*\b(claude|anthropic|openai|chatgpt|gpt-?[0-9]*|codex|copilot|gemini|cursor)\b",
    re.IGNORECASE | re.MULTILINE,
)
AI_BANNER_RE = re.compile(
    r"generated (with|by) .*\b(claude|anthropic|openai|chatgpt|codex|copilot|gemini|cursor|ai)\b|\U0001f916",
    re.IGNORECASE,
)
LOCAL_TIMEOUT = 60
NETWORK_TIMEOUT = 120
EXIT_CODES = {"ok": 0, "blocked": 1, "error": 2, "feature_branch_required": 3, "remote_classification_required": 3}


class Stop(Exception):
    """End the run with a non-`ok` status."""

    def __init__(self, status: str, reason: str, message: str, details: JsonDict | None = None) -> None:
        super().__init__(message)
        self.status = status
        self.reason = reason
        self.message = message
        self.details = details or {}


def blocked(reason: str, message: str, details: JsonDict | None = None) -> Stop:
    return Stop("blocked", reason, message, details)


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise Stop("error", "usage", message)


def environment() -> dict[str, str]:
    ssh = os.environ.get("GIT_SSH_COMMAND") or os.environ.get("GIT_SSH") or "ssh"
    return dict(
        os.environ,
        GH_PROMPT_DISABLED="1",
        GIT_TERMINAL_PROMPT="0",
        GCM_INTERACTIVE="Never",
        GIT_SSH_COMMAND=f"{ssh} -oBatchMode=yes",
        GIT_OPTIONAL_LOCKS="0",
    )


def run(argv: Sequence[str], root: Path | None, reason: str, timeout: int = LOCAL_TIMEOUT) -> Proc:
    try:
        return subprocess.run(list(argv), cwd=root, env=environment(), input=b"", capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise blocked(reason, f"`{' '.join(argv[:3])}` timed out after {timeout}s.") from error
    except OSError as error:
        raise blocked(reason, f"`{' '.join(argv[:3])}` could not run: {error}") from error


def stderr_tail(result: Proc) -> str:
    return result.stderr.decode("utf-8", errors="replace").strip()[-600:]


def git(
    root: Path | None, *args: str, reason: str = "git_failed", ok: Codes = (0,), timeout: int = LOCAL_TIMEOUT
) -> Proc:
    result = run(["git", *args], root, reason, timeout)
    if result.returncode not in ok:
        message = f"`git {' '.join(args[:2])}` failed with exit {result.returncode}."
        raise blocked(reason, message, {"exit_code": result.returncode, "stderr": stderr_tail(result)})
    return result


def text(result: Proc) -> str:
    try:
        return result.stdout.decode("utf-8")
    except UnicodeDecodeError as error:
        raise blocked("git_failed", "Command output is not valid UTF-8.") from error


def gh_host(origin_url: str) -> str:
    """Derive the GitHub host exactly as pre-validation-checks.md 1.1 does."""
    host = "github.com"
    for prefix in ("https://", "http://", "ssh://git@"):
        if origin_url.startswith(prefix):
            host = origin_url[len(prefix) :].split("/", 1)[0]
            break
    else:
        if origin_url.startswith("git@") and ":" in origin_url:
            host = origin_url[len("git@") :].split(":", 1)[0]
    return host.rsplit("@", 1)[-1]


def require_ref_shape(value: str, reason: str, label: str) -> None:
    if not REF_RE.fullmatch(value):
        raise blocked(reason, f"{label} is outside [A-Za-z0-9][A-Za-z0-9._/-]*.", {"value": value})


def validate_branch(root: Path, value: str, reason: str, label: str) -> None:
    require_ref_shape(value, reason, label)
    result = run([str(VALIDATE_BRANCH), value], root, reason)
    if result.returncode != 0:
        raise blocked(reason, f"{label} is not a valid branch name.", {"value": value, "stderr": stderr_tail(result)})


def step_1(facts: JsonDict) -> Path:
    if shutil.which("gh") is None:
        raise blocked("gh_missing", "MISSING REQUIREMENT: gh CLI not installed. Install from https://cli.github.com.")
    inside = run(["git", "rev-parse", "--is-inside-work-tree"], None, "not_a_repository")
    if inside.returncode != 0 or inside.stdout.strip() != b"true":
        raise blocked("not_a_repository", "Not inside a git repository.")
    root = Path(text(git(None, "rev-parse", "--show-toplevel")).rstrip("\n"))
    origin = run(["git", "remote", "get-url", "origin"], root, "origin_missing")
    if origin.returncode != 0:
        raise blocked("origin_missing", "No remote 'origin' configured.")
    host = gh_host(text(origin).strip())
    if not HOST_RE.fullmatch(host):
        raise blocked("origin_host_unrecognized", "Could not derive a GitHub host from the origin URL.")
    facts["gh_host"] = host
    auth = run(["gh", "auth", "status", "--active", "--hostname", host], root, "gh_unauthenticated", NETWORK_TIMEOUT)
    if auth.returncode != 0:
        message = (
            f"MISSING REQUIREMENT: gh CLI not authenticated for {host}. Run `gh auth login --hostname {host}` first."
        )
        raise blocked("gh_unauthenticated", message)
    unmerged = sorted({line.split("\t", 1)[-1] for line in text(git(root, "ls-files", "-u")).splitlines()})
    if unmerged:
        raise blocked("merge_conflict", "Merge conflict detected.", {"conflicted_paths": unmerged})
    query = [part for marker, _ in GIT_OPERATIONS for part in ("--git-path", marker)]
    locations = text(git(root, "rev-parse", *query)).splitlines()
    if len(locations) != len(GIT_OPERATIONS):
        raise blocked("git_failed", "git rev-parse --git-path returned an unexpected number of paths.")
    in_progress = sorted({op for (_, op), path in zip(GIT_OPERATIONS, locations) if os.path.lexists(root / path)})
    if in_progress:
        raise blocked("operation_in_progress", "A Git operation is in progress.", {"operations": in_progress})
    return root


def step_2(root: Path, base_override: str | None, facts: JsonDict) -> None:
    entry_branch = text(git(root, "branch", "--show-current")).strip() or None
    entry_commit = text(git(root, "rev-parse", "--verify", "HEAD^{commit}", reason="head_unresolved")).strip()
    if not OID_RE.fullmatch(entry_commit):
        raise blocked("head_unresolved", "HEAD is not a full 40-character commit ID.")
    facts.update(entry_branch=entry_branch, entry_commit=entry_commit)
    if entry_branch is not None:
        validate_branch(root, entry_branch, "entry_branch_invalid", "The current branch name")
    argv = [str(RESOLVE_BASE), "--format", "json"]
    if base_override is not None:
        require_ref_shape(base_override, "base_override_invalid", "--base")
        argv += ["--base", base_override]
    result = run(argv, root, "base_unresolved", NETWORK_TIMEOUT)
    if result.returncode != 0:
        raise blocked("base_unresolved", "Base resolution failed.", {"stderr": stderr_tail(result)})
    try:
        resolved = json.loads(text(result))
        source_ref, base_branch = resolved["base_ref"], resolved["base_branch"]
    except (ValueError, KeyError, TypeError) as error:
        raise blocked("base_unresolved", "resolve-base.sh returned malformed JSON.") from error
    if not isinstance(source_ref, str) or not isinstance(base_branch, str):
        raise blocked("base_unresolved", "resolve-base.sh returned malformed JSON.")
    require_ref_shape(source_ref, "base_unresolved", "The resolved base ref")
    if not source_ref.startswith("refs/remotes/"):
        raise blocked("base_unresolved", "The resolved base ref is not under refs/remotes/.", {"value": source_ref})
    validate_branch(root, base_branch, "base_unresolved", "The resolved base branch")
    pinned = text(git(root, "rev-parse", "--verify", f"{source_ref}^{{commit}}", reason="base_unresolved")).strip()
    if not OID_RE.fullmatch(pinned):
        raise blocked("base_unresolved", "The base ref did not resolve to a full commit ID.")
    facts.update(base_source_ref=source_ref, base_ref=pinned, base_branch=base_branch)


def step_4_local(root: Path, facts: JsonDict) -> None:
    status = text(git(root, "status", "--porcelain", "--untracked-files=all"))
    ahead = int(text(git(root, "rev-list", "--count", f"{facts['base_ref']}..HEAD")).strip())
    facts.update(worktree_status=status.rstrip("\n"), ahead_count=ahead)
    if not status and ahead == 0:
        raise blocked("no_changes", f"No changes detected compared to {facts['base_branch']}.")


def protected_branches(root: Path) -> list[str]:
    names = {"main", "master"}
    configured = git(root, "config", "--local", "--get", "kramme.baseBranch", ok=(0, 1))
    origin_head = git(root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", ok=(0, 1))
    names.add(text(configured).strip())
    names.add(text(origin_head).strip().removeprefix("origin/") if origin_head.returncode == 0 else "")
    names.add(os.environ.get("CONDUCTOR_DEFAULT_BRANCH", ""))
    return sorted(name for name in names if name)


def changed_paths(root: Path, base_ref: str) -> list[str]:
    paths: set[str] = set()
    for args in (("diff", "--name-only", "-z", f"{base_ref}...HEAD"), ("diff", "--name-only", "-z", "HEAD")):
        paths.update(part for part in text(git(root, *args)).split("\0") if part)
    untracked = text(git(root, "ls-files", "-z", "--others", "--exclude-standard"))
    paths.update(part for part in untracked.split("\0") if part)
    return sorted(paths)


def step_3(root: Path, options: argparse.Namespace, facts: JsonDict) -> str:
    entry: str | None = facts["entry_branch"]
    base_branch: str = facts["base_branch"]
    protected = protected_branches(root)
    facts["protected_branches"] = protected
    linear = options.linear_issue.upper() if options.linear_issue else None
    facts["linear_issue_id"] = linear
    if entry is not None and entry != base_branch and entry in protected:
        details = {"entry_branch": entry, "base_branch": base_branch}
        raise blocked("protected_branch_conflict", f"{entry} is a protected branch and differs from the base.", details)
    if entry is not None and entry != base_branch:
        if options.feature_branch is not None and options.feature_branch != entry:
            details = {"entry_branch": entry, "feature_branch": options.feature_branch}
            raise blocked(
                "feature_branch_mismatch", "--feature-branch differs from the current feature branch.", details
            )
        feature = entry
    elif options.feature_branch is None:
        facts["changed_paths"] = changed_paths(root, facts["base_ref"])
        raise Stop("feature_branch_required", "feature_branch_required", "Name a feature branch, then rerun.")
    else:
        feature = str(options.feature_branch)
        validate_branch(root, feature, "feature_branch_invalid", "--feature-branch")
        if feature == base_branch or feature in protected:
            raise blocked("feature_branch_protected", f"{feature} is the base or a protected branch.")
    facts["feature_branch"] = feature
    if linear is None:
        match = LINEAR_BRANCH_RE.search(feature)
        facts["linear_issue_id"] = match.group(0).upper() if match else None
    local = git(root, "show-ref", "--verify", "--quiet", f"refs/heads/{feature}", ok=(0, 1))
    if local.returncode == 0 and feature != entry:
        raise blocked("local_branch_exists", f"A different local branch named {feature} exists; switch to it first.")
    ref = f"refs/heads/{feature}"
    listing = git(root, "ls-remote", "--heads", "origin", ref, reason="ls_remote_failed", timeout=NETWORK_TIMEOUT)
    observed = remote_ref_object(text(listing), ref)
    facts["observed_origin_oid"] = observed
    if observed is not None and feature != entry:
        raise blocked("remote_branch_not_current", f"origin already has {ref}, which is not the current branch.")
    if observed is None:
        facts["branch_action"] = "use-current" if feature == entry else "create-from-entry-head"
    elif observed == facts["entry_commit"]:
        facts["branch_action"] = "reuse-existing-exact-tip"
    else:
        facts["branch_action"] = None
    return feature


def remote_ref_object(output: str, ref: str) -> str | None:
    """Accept only empty output or one `<oid>\\t<ref>` line."""
    if not output:
        return None
    fields = output[:-1].split("\t") if output.endswith("\n") and output.count("\n") == 1 else []
    if len(fields) == 2 and OID_RE.fullmatch(fields[0]) and fields[1] == ref:
        return fields[0]
    raise blocked("ls_remote_malformed", "git ls-remote returned malformed or ambiguous output.")


def step_3_5(root: Path, feature: str) -> None:
    argv = ["gh", "pr", "list", "--head", feature, "--state", "open", "--limit", "100", "--json", PR_FIELDS]
    result = run(argv, root, "gh_pr_list_failed", NETWORK_TIMEOUT)
    if result.returncode != 0:
        details = {"stderr": stderr_tail(result)}
        raise blocked("gh_pr_list_failed", "gh pr list failed; a CLI error is not evidence of absence.", details)
    try:
        listed = json.loads(text(result))
    except ValueError as error:
        raise blocked("gh_pr_list_failed", "gh pr list did not return JSON.") from error
    if not isinstance(listed, list) or not all(isinstance(item, dict) for item in listed):
        raise blocked("gh_pr_list_failed", "gh pr list returned an unexpected shape.")
    if listed:
        urls = [item.get("url") for item in listed]
        raise blocked("pull_request_open", f"An open Pull Request already uses {feature}.", {"urls": urls})


def step_4_4(root: Path, options: argparse.Namespace, facts: JsonDict) -> str | None:
    """Return the remote mode, or None when the agent must classify the existing remote."""
    action = facts["branch_action"]
    if action in ("use-current", "create-from-entry-head"):
        return "fresh"
    if action is None:
        return None
    current = text(git(root, "branch", "--show-current")).strip()
    head = text(git(root, "rev-parse", "HEAD")).strip()
    if current != facts["feature_branch"] or head != facts["entry_commit"]:
        raise blocked("entry_state_changed", "The current branch or HEAD changed during preflight.")
    if facts["worktree_status"]:
        if not options.auto:
            raise blocked("dirty_existing_remote", "Dirty work on an existing remote branch requires --auto.")
        return None
    clean = run([str(VERIFY_CLEAN)], root, "worktree_not_clean")
    if clean.returncode != 0:
        raise blocked("worktree_not_clean", "The clean-worktree proof failed.", {"stderr": stderr_tail(clean)})
    return "recovery"


def step_4_5(root: Path, facts: JsonDict) -> None:
    if facts["branch_action"] == "create-from-entry-head":
        # The branch does not exist yet; recreate-commits and Step 8 resolve it after Step 5 creates it.
        facts["stack_membership"] = "none"
        return
    result = run([str(RESOLVE_STACK)], root, "stack_unresolved", NETWORK_TIMEOUT)
    if result.returncode != 0:
        message = "Stack membership could not be determined; stop before preparing the Pull Request."
        raise blocked("stack_unresolved", message, {"stderr": stderr_tail(result)})
    assignments = dict(line.split("=", 1) for line in text(result).splitlines() if "=" in line)
    membership = shlex.split(assignments.get("STACK_MEMBERSHIP", ""))
    facts["stack_membership"] = membership[0] if len(membership) == 1 else None
    if facts["stack_membership"] != "none":
        message = "kramme:pr:create does not publish stacked branches; use kramme:pr:stack instead."
        raise blocked("stacked_branch", message, {"stack_membership": facts["stack_membership"]})


def commit_flags(parents: list[str], message: str) -> list[str]:
    subject = message.split("\n", 1)[0].strip()
    first_word = subject.split(" ", 1)[0].rstrip(":").lower() if subject else ""
    flags = []
    if len(parents) > 1:
        flags.append("merge")
    if AUTOSQUASH_RE.match(subject):
        flags.append("autosquash")
    if not subject or first_word in PLACEHOLDER_WORDS or subject == INCLUDE_COMMIT_SUBJECT:
        flags.append("placeholder")
    if AI_TRAILER_RE.search(message) or AI_BANNER_RE.search(message):
        flags.append("ai-attribution")
    return flags


def unpublished_commits(root: Path, base_ref: str) -> list[JsonDict]:
    output = text(git(root, "log", "-z", f"--max-count={COMMIT_LIMIT}", "--format=%H%n%P%n%B", f"{base_ref}..HEAD"))
    commits = []
    for record in output.split("\0"):
        if not record:
            continue
        oid, parent_line, message = (record.split("\n", 2) + ["", ""])[:3]
        parents = parent_line.split()
        subject = message.split("\n", 1)[0].strip()
        commits.append({"oid": oid, "subject": subject, "parents": parents, "flags": commit_flags(parents, message)})
    return list(reversed(commits))


def preflight(options: argparse.Namespace, facts: JsonDict) -> str:
    missing = [path.name for path in REQUIRED_SCRIPTS if not os.access(path, os.X_OK)]
    if missing:
        raise Stop("error", "plugin_scripts_missing", "Required plugin scripts are missing.", {"missing": missing})
    if options.linear_issue is not None and not LINEAR_OVERRIDE_RE.fullmatch(options.linear_issue):
        raise Stop("error", "usage", "--linear-issue must match [A-Za-z0-9]+-[0-9]+.")
    root = step_1(facts)
    step_2(root, options.base, facts)
    step_4_local(root, facts)
    feature = step_3(root, options, facts)
    step_3_5(root, feature)
    mode = step_4_4(root, options, facts)
    facts["remote_mode"] = mode
    step_4_5(root, facts)
    if mode is None:
        raise Stop(
            "remote_classification_required",
            "remote_classification_required",
            "origin has the branch; classify it with the frozen-endpoint procedure.",
        )
    if mode == "fresh":
        facts["unpublished_commits"] = unpublished_commits(root, facts["base_ref"])
    return "Preflight passed."


def build_parser() -> argparse.ArgumentParser:
    parser = JsonArgumentParser(prog="pr-create-preflight.py", description="Read-only preflight for kramme:pr:create.")
    parser.add_argument("--base")
    parser.add_argument("--feature-branch")
    parser.add_argument("--linear-issue")
    parser.add_argument("--auto", action="store_true")
    return parser


def emit(status: str, reason: str | None, message: str, facts: JsonDict, details: JsonDict | None = None) -> int:
    payload: JsonDict = {
        "schema_version": SCHEMA_VERSION,
        "status": status,
        "reason": reason,
        "message": message,
        "facts": facts,
    }
    if details:
        payload["details"] = details
    sys.stdout.write(json.dumps(payload, sort_keys=True) + "\n")
    return EXIT_CODES[status]


def main(argv: Sequence[str] | None = None) -> int:
    facts: JsonDict = {}
    try:
        options = build_parser().parse_args(list(sys.argv[1:] if argv is None else argv))
        message = preflight(options, facts)
    except Stop as stop:
        return emit(stop.status, stop.reason, stop.message, facts, stop.details)
    except Exception as error:  # Fail closed with one JSON document instead of a traceback.
        return emit("error", "internal_error", f"Unexpected helper failure: {error!r}", facts)
    return emit("ok", None, message, facts)


if __name__ == "__main__":
    sys.exit(main())
