#!/usr/bin/env python3
"""Deterministic preflight checks for kramme:linear:issue-to-pr.

The skill keeps Linear lookups, the Linear state gate, and judgment calls. This helper owns the mechanical checks:

  args -- '<raw arguments>'                  Parse the skill arguments; create a private state file (`state_file`).
  capture --state-file PATH                  Record the entry branch, HEAD, status entries, and in-progress Git
                                             operations, then apply the fresh (clean tree) or continue gate.
  check-branch --state-file PATH --branch B  Validate the Linear branch name, require no Pull Request and no
                                             `origin` ref for it, and in continue mode prove the resume state.
  cleanup --state-file PATH                  Remove this helper's state file once the preflight no longer needs it.

Each call prints one JSON document with `schema_version`, `command`, `status`, `reason`, and `message`. Exit codes:
0 `ok`; 1 `blocked` (a gate refused; `reason` names it); 2 `error` (invalid helper invocation or state file).
A Git or GitHub CLI failure is always a blocker, never evidence of absence.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING, Any, Dict, NoReturn, Sequence, Tuple

if TYPE_CHECKING:
    Proc = subprocess.CompletedProcess[bytes]
JsonDict = Dict[str, Any]
Codes = Tuple[int, ...]

SCHEMA_VERSION = 1
STATE_TOOL = "kramme:linear:issue-to-pr/preflight"
SUPPORTED_FLAGS = ["--continue", "--strict", "--cycles <1-5>", "--ship"]
BOOLEAN_FLAGS = {"--continue": "continue_mode", "--strict": "strict_review", "--ship": "ship_mode"}
DEFAULT_CYCLES = 2
ISSUE_ID_RE = re.compile(r"[A-Za-z0-9]+-[0-9]+")
CYCLES_RE = re.compile(r"[1-5]")
BRANCH_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*")
SAFE_STATE_PATH_RE = re.compile(r"/[A-Za-z0-9._/-]+")
ASCII_WHITESPACE_RE = re.compile(r"[ \t\n\r\f\v]+")
UNMERGED_CODES = frozenset({"DD", "AU", "UD", "UA", "DU", "AA", "UU"})
REF_OPERATIONS = (("MERGE_HEAD", "merge"), ("CHERRY_PICK_HEAD", "cherry-pick"), ("REVERT_HEAD", "revert"))
FILE_OPERATIONS = (
    ("rebase-apply/applying", "am"),
    ("rebase-apply", "rebase"),
    ("rebase-merge", "rebase"),
    ("sequencer", "sequencer"),
    ("BISECT_START", "bisect"),
)
SNAPSHOT_KEYS = ("branch", "head", "status_entries", "git_operations")
# kramme:linear:issue-implement recomputes the resume handoff with these exact, config-independent commands.
STATUS_ARGS = ("status", "--porcelain=v1", "-z", "--untracked-files=normal", "--no-renames")
COMMITTED_DIFF_ARGS = ("diff", "--name-only", "-z", "--no-renames")
ORIGIN_PREFIX = "refs/remotes/origin/"
PR_FIELDS = ("number", "url", "state", "headRefName", "headRefOid")
PR_STATES = frozenset({"OPEN", "CLOSED", "MERGED"})
NETWORK_TIMEOUT = 300
EXIT_CODES = {"ok": 0, "blocked": 1, "error": 2}


class Stop(Exception):
    """A gate refused (`blocked`) or the helper was invoked incorrectly (`error`)."""

    def __init__(self, reason: str, message: str, details: JsonDict | None = None, status: str = "blocked") -> None:
        super().__init__(message)
        self.reason = reason
        self.message = message
        self.details = details or {}
        self.status = status


def usage_error(reason: str, message: str) -> Stop:
    return Stop(reason, message, status="error")


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise usage_error("usage", message)


def parse_arguments(raw: str) -> JsonDict:
    tokens = [token for token in ASCII_WHITESPACE_RE.split(raw) if token]
    parsed: JsonDict = {name: False for name in BOOLEAN_FLAGS.values()}
    parsed.update(cycles=DEFAULT_CYCLES, cycles_explicit=False)
    seen: set[str] = set()
    positionals: list[str] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        index += 1
        if not token.startswith("-"):
            positionals.append(token)
            continue
        if token not in BOOLEAN_FLAGS and token != "--cycles":
            raise Stop("unknown_flag", f"Unknown flag {token!r}.", {"flag": token})
        if token in seen:
            raise Stop("duplicate_flag", f"{token} was supplied more than once.", {"flag": token})
        seen.add(token)
        if token == "--cycles":
            value = tokens[index] if index < len(tokens) else ""
            if not CYCLES_RE.fullmatch(value):
                raise Stop("cycles_value_invalid", "--cycles takes one ASCII digit from 1 to 5.", {"value": value})
            index += 1
            parsed.update(cycles=int(value), cycles_explicit=True)
        else:
            parsed[BOOLEAN_FLAGS[token]] = True
    if not positionals:
        raise Stop("issue_id_missing", "Exactly one {TEAM}-{number} issue identifier is required.")
    if len(positionals) > 1:
        raise Stop("extra_positional", "Only one issue identifier is allowed.", {"positionals": positionals})
    if not ISSUE_ID_RE.fullmatch(positionals[0]):
        raise Stop("issue_id_invalid", "The issue identifier must match {TEAM}-{number}.", {"value": positionals[0]})
    parsed["issue_id"] = positionals[0].upper()
    return parsed


def run(argv: Sequence[str], root: Path | None, reason: str, timeout: int) -> Proc:
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", GH_PROMPT_DISABLED="1")
    try:
        return subprocess.run(list(argv), cwd=root, env=env, input=b"", capture_output=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as error:
        raise Stop(reason, f"`{' '.join(argv[:3])}` could not run: {error}", {"command": list(argv)}) from error


def failure(reason: str, argv: Sequence[str], result: Proc, message: str = "") -> Stop:
    stderr = result.stderr.decode("utf-8", errors="replace").strip()
    summary = message or f"`{' '.join(argv[:3])}` failed with exit {result.returncode}."
    return Stop(reason, summary, {"command": list(argv), "exit_code": result.returncode, "stderr": stderr[-600:]})


def git(root: Path | None, *args: str, reason: str = "git_failed", ok: Codes = (0,), timeout: int = 60) -> Proc:
    argv = ["git", *args]
    result = run(argv, root, reason, timeout)
    if result.returncode not in ok:
        raise failure(reason, argv, result)
    return result


def decode(data: bytes, reason: str = "git_failed") -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise Stop(reason, "Command output is not valid UTF-8.") from error


def repository_root() -> Path:
    root = decode(git(None, "rev-parse", "--show-toplevel").stdout).rstrip("\n")
    if not root:
        raise Stop("git_failed", "The current directory is not inside a Git worktree.")
    return Path(root)


def object_id_pattern(root: Path) -> re.Pattern[str]:
    object_format = decode(git(root, "rev-parse", "--show-object-format").stdout).strip()
    length = {"sha1": 40, "sha256": 64}.get(object_format)
    if length is None:
        raise Stop("git_failed", f"Unsupported Git object format {object_format!r}.")
    return re.compile(f"[0-9a-f]{{{length}}}")


def parse_status(raw: bytes) -> list[dict[str, str]]:
    if not raw:
        return []
    if not raw.endswith(b"\0"):
        raise Stop("git_failed", "git status returned an unterminated record.")
    records = raw[:-1].split(b"\0")
    entries: list[dict[str, str]] = []
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if len(record) < 4 or record[2:3] != b" ":
            raise Stop("git_failed", "git status returned a malformed record.")
        entry = {"xy": decode(record[:2]), "path": decode(record[3:])}
        if entry["xy"][0] in "RC":
            if index >= len(records):
                raise Stop("git_failed", "git status returned a rename without its source path.")
            entry["orig_path"] = decode(records[index])
            index += 1
        entries.append(entry)
    return entries


def status_paths(entries: list[dict[str, str]]) -> list[str]:
    return sorted({entry[key] for entry in entries for key in ("path", "orig_path") if key in entry})


def unmerged_paths(entries: list[dict[str, str]]) -> list[str]:
    return sorted(entry["path"] for entry in entries if entry["xy"] in UNMERGED_CODES)


def git_operations(root: Path) -> list[str]:
    found: set[str] = set()
    for ref, operation in REF_OPERATIONS:
        if git(root, "rev-parse", "--quiet", "--verify", ref, ok=(0, 1)).returncode == 0:
            found.add(operation)
    markers = [marker for marker, _ in FILE_OPERATIONS]
    query = [part for marker in markers for part in ("--git-path", marker)]
    locations = decode(git(root, "rev-parse", *query).stdout).splitlines()
    if len(locations) != len(markers):
        raise Stop("git_failed", "git rev-parse --git-path returned an unexpected number of paths.")
    present = {marker for marker, location in zip(markers, locations) if os.path.lexists(root / location)}
    if "rebase-apply/applying" in present:
        present.discard("rebase-apply")
    found.update(operation for marker, operation in FILE_OPERATIONS if marker in present)
    return sorted(found)


def snapshot(root: Path, object_id: re.Pattern[str]) -> JsonDict:
    branch = decode(git(root, "branch", "--show-current").stdout).rstrip("\n")
    head_result = git(root, "rev-parse", "--quiet", "--verify", "HEAD^{commit}", ok=(0, 1))
    head = decode(head_result.stdout).strip()
    if head_result.returncode != 0 or not object_id.fullmatch(head):
        raise Stop("git_failed", "HEAD does not resolve to a commit.")
    status = git(root, *STATUS_ARGS).stdout
    entries = parse_status(status)
    return {"branch": branch or None, "head": head, "status_entries": entries, "git_operations": git_operations(root)}


def valid_args(args: Any) -> bool:
    return (
        isinstance(args, dict)
        and isinstance(args.get("issue_id"), str)
        and ISSUE_ID_RE.fullmatch(args["issue_id"]) is not None
        and all(isinstance(args.get(key), bool) for key in (*BOOLEAN_FLAGS.values(), "cycles_explicit"))
        and type(args.get("cycles")) is int
        and 1 <= args["cycles"] <= 5
    )


def write_state(path: str, state: JsonDict) -> None:
    try:
        handle, temporary = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".kramme-issue-to-pr-", suffix=".tmp")
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(state, stream, indent=2, sort_keys=True)
        os.replace(temporary, path)
    except OSError as error:
        raise usage_error("state_write_failed", f"Could not write the state file {path!r}: {error}") from error


def create_state(args_state: JsonDict) -> str:
    try:
        handle, path = tempfile.mkstemp(prefix="kramme-issue-to-pr-", suffix=".json")
    except OSError as error:
        raise usage_error("state_write_failed", f"Could not create a state file: {error}") from error
    os.close(handle)
    if not SAFE_STATE_PATH_RE.fullmatch(path):
        os.unlink(path)
        raise usage_error("state_write_failed", "The state path has characters outside [A-Za-z0-9._/-]; set TMPDIR.")
    write_state(path, {"schema_version": SCHEMA_VERSION, "tool": STATE_TOOL, "args": args_state})
    return path


def load_state(path: str) -> JsonDict:
    try:
        info = os.lstat(path)
        owner_ok = not hasattr(os, "geteuid") or info.st_uid == os.geteuid()
        if not os.path.isabs(path) or not stat.S_ISREG(info.st_mode) or not owner_ok:
            raise ValueError("not an absolute path to a regular file owned by the current user")
        with open(path, encoding="utf-8") as stream:
            state = json.load(stream)
        if not (
            isinstance(state, dict)
            and state.get("schema_version") == SCHEMA_VERSION
            and state.get("tool") == STATE_TOOL
            and valid_args(state.get("args"))
        ):
            raise ValueError("unexpected state document")
    except (OSError, ValueError) as error:
        raise usage_error("state_invalid", f"State file {path!r} is unusable ({error}); rerun `args`.") from error
    return state


def command_args(raw: str) -> JsonDict:
    parsed = parse_arguments(raw)
    return {"message": "Arguments parsed.", "state_file": create_state(parsed), **parsed}


def command_capture(options: argparse.Namespace) -> JsonDict:
    state = load_state(options.state_file)
    continue_mode = state["args"]["continue_mode"]
    state.pop("capture", None)
    try:
        root = repository_root()
        current = snapshot(root, object_id_pattern(root))
        entries = current["status_entries"]
        result = {
            "continue_mode": continue_mode,
            "entry_branch": current["branch"],
            "head": current["head"],
            "status_paths": status_paths(entries),
            "git_operations": current["git_operations"],
            "unmerged_paths": unmerged_paths(entries),
        }
        if current["git_operations"]:
            raise Stop("git_operation_in_progress", "Finish or abort the in-progress Git operation first.", result)
        if not continue_mode and entries:
            raise Stop("dirty_worktree", "A fresh run requires an empty git status; commit or stash first.", result)
        if continue_mode and current["branch"] is None:
            raise Stop("detached_head", "--continue requires a named current branch.", result)
        if continue_mode and result["unmerged_paths"]:
            raise Stop("unmerged_paths", "--continue refuses unmerged paths.", result)
        state["capture"] = {"repo_root": str(root), **current}
    except Stop:
        with contextlib.suppress(Stop):  # Persist the cleared capture but keep the gate's own reason.
            write_state(options.state_file, state)
        raise
    write_state(options.state_file, state)
    return {"message": "Entry state captured.", "status_entries": entries, **result}


def validate_branch_name(root: Path, branch: str) -> None:
    if not BRANCH_RE.fullmatch(branch):
        raise Stop("branch_name_invalid", "branchName is outside [A-Za-z0-9][A-Za-z0-9._/-]*.", {"branch": branch})
    git(root, "check-ref-format", "--branch", branch, reason="branch_ref_format_invalid")


def require_no_pull_request(root: Path, branch: str) -> None:
    argv = ["gh", "pr", "list", "--head", branch, "--state", "all", "--limit", "100", "--json", ",".join(PR_FIELDS)]
    result = run(argv, root, "gh_failed", NETWORK_TIMEOUT)
    if result.returncode != 0:
        raise failure("gh_failed", argv, result, "gh pr list failed; a CLI error is not evidence of absence.")
    try:
        listed = json.loads(result.stdout.decode("utf-8"))
    except ValueError as error:
        raise Stop("gh_output_malformed", "gh pr list did not return JSON.") from error
    well_formed = isinstance(listed, list) and all(
        isinstance(item, dict)
        and isinstance(item.get("state"), str)
        and item["state"] in PR_STATES
        and item.get("headRefName") == branch
        for item in listed
    )
    if not well_formed:
        raise Stop("gh_output_malformed", "gh pr list returned an unexpected shape.", {"output": str(listed)[:600]})
    pulls = [{field: item.get(field) for field in PR_FIELDS} for item in listed]
    if any(pull["state"] == "OPEN" for pull in pulls):
        raise Stop("pull_request_open", f"An open Pull Request already uses {branch}.", {"pull_requests": pulls})
    if pulls:
        raise Stop("pull_request_closed", f"A closed or merged Pull Request used {branch}.", {"pull_requests": pulls})


def remote_ref_object(output: bytes, ref: str, object_id: re.Pattern[str]) -> str | None:
    """Return None for the zero-line absent result or the object ID of the one exact ref line."""
    if not output:
        return None
    text = output.decode("utf-8", errors="replace")
    fields = text[:-1].split("\t") if text.endswith("\n") and text.count("\n") == 1 else []
    if len(fields) == 2 and object_id.fullmatch(fields[0]) and fields[1] == ref:
        return fields[0]
    raise Stop("ls_remote_malformed", "git ls-remote returned malformed or ambiguous output.", {"output": text[:600]})


def require_absent_remote_branch(root: Path, branch: str, object_id: re.Pattern[str]) -> None:
    ref = f"refs/heads/{branch}"
    output = git(root, "ls-remote", "--heads", "origin", ref, reason="ls_remote_failed", timeout=NETWORK_TIMEOUT)
    existing = remote_ref_object(output.stdout, ref, object_id)
    if existing is not None:
        raise Stop("remote_branch_exists", f"origin already has {ref}.", {"ref": ref, "object_id": existing})


def resolve_base(root: Path) -> str:
    symbolic = git(root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD", reason="base_unresolved", ok=(0, 1))
    if symbolic.returncode == 0:
        target = decode(symbolic.stdout, "base_unresolved").strip()
        if not target.startswith(ORIGIN_PREFIX) or target == ORIGIN_PREFIX:
            raise Stop("base_unresolved", f"refs/remotes/origin/HEAD points to {target!r}, not an origin branch.")
        base = target[len(ORIGIN_PREFIX) :]
        git(root, "check-ref-format", "--branch", base, reason="base_unresolved")
        return base
    for candidate in ("main", "master"):
        verified = git(root, "rev-parse", "--quiet", "--verify", f"{ORIGIN_PREFIX}{candidate}^{{commit}}", ok=(0, 1))
        if verified.returncode == 0:
            return candidate
    raise Stop("base_unresolved", "refs/remotes/origin/HEAD is unset and neither origin/main nor origin/master exists.")


def prove_continuation(root: Path, captured: JsonDict, object_id: re.Pattern[str]) -> JsonDict:
    base = resolve_base(root)
    remote_ref = f"{ORIGIN_PREFIX}{base}"
    refspec = f"+refs/heads/{base}:{remote_ref}"
    git(root, "fetch", "--quiet", "origin", refspec, reason="base_fetch_failed", timeout=NETWORK_TIMEOUT)
    git(root, "rev-parse", "--quiet", "--verify", f"{remote_ref}^{{commit}}", reason="base_fetch_failed")
    current = snapshot(root, object_id)
    changed = [key for key in SNAPSHOT_KEYS if current[key] != captured[key]]
    if changed:
        raise Stop("worktree_changed", "The entry state changed after capture.", {"changed": changed})
    output = decode(git(root, "merge-base", "HEAD", remote_ref, reason="merge_base_unresolved").stdout)
    if not (output.endswith("\n") and object_id.fullmatch(output[:-1])):
        raise Stop("merge_base_unresolved", "git merge-base did not return exactly one full object ID.")
    base_commit = output[:-1]
    if git(root, "merge-base", "--is-ancestor", base_commit, "HEAD", ok=(0, 1)).returncode != 0:
        raise Stop("merge_base_not_ancestor", "The merge base is not an ancestor of HEAD.", {"commit": base_commit})
    diff = git(root, *COMMITTED_DIFF_ARGS, "--no-ext-diff", base_commit, "HEAD").stdout
    committed = sorted({decode(path) for path in diff.split(b"\0") if path})
    dirty = status_paths(captured["status_entries"])
    if not committed and not dirty:
        raise Stop("no_local_changes", f"No committed or dirty path differs from origin/{base}.")
    return {
        "base_branch": base,
        "continue_base_commit": base_commit,
        "entry_head": captured["head"],
        "committed_paths": committed,
        "dirty_paths": dirty,
    }


def command_check_branch(options: argparse.Namespace) -> JsonDict:
    state = load_state(options.state_file)
    captured = state.get("capture")
    if not isinstance(captured, dict) or any(key not in captured for key in ("repo_root", *SNAPSHOT_KEYS)):
        raise usage_error("state_incomplete", "Run a successful `capture` with this state file first.")
    continue_mode = state["args"]["continue_mode"]
    root = repository_root()
    if str(root) != captured["repo_root"]:
        raise Stop("repository_changed", "The worktree differs from the captured one.", {"current": str(root)})
    branch = options.branch
    validate_branch_name(root, branch)
    if continue_mode and captured["branch"] != branch:
        details = {"entry_branch": captured["branch"], "issue_branch": branch}
        raise Stop("continue_branch_mismatch", "--continue requires the entry branch to be the issue branch.", details)
    object_id = object_id_pattern(root)
    require_no_pull_request(root, branch)
    require_absent_remote_branch(root, branch, object_id)
    result: JsonDict = {
        "message": "The issue branch is valid and unpublished.",
        "issue_branch": branch,
        "continue_mode": continue_mode,
        "pull_requests": [],
        "remote_branch": "absent",
    }
    if continue_mode:
        result.update(prove_continuation(root, captured, object_id))
    return result


def command_cleanup(options: argparse.Namespace) -> JsonDict:
    load_state(options.state_file)  # Only ever delete this helper's own state document.
    try:
        os.unlink(options.state_file)
    except OSError as error:
        raise usage_error("state_cleanup_failed", f"Could not remove {options.state_file!r}: {error}") from error
    return {"message": "State file removed."}


def build_parser() -> argparse.ArgumentParser:
    parser = JsonArgumentParser(prog="preflight.py", description="Preflight checks for kramme:linear:issue-to-pr.")
    commands = parser.add_subparsers(dest="command", required=True, parser_class=JsonArgumentParser)
    commands.add_parser("args", help="parse the raw argument string given after --")
    capture = commands.add_parser("capture", help="record and gate the entry worktree state")
    capture.add_argument("--state-file", required=True)
    capture.set_defaults(handler=command_capture)
    check = commands.add_parser("check-branch", help="prove the Linear branch is valid and unpublished")
    check.add_argument("--state-file", required=True)
    check.add_argument("--branch", required=True)
    check.set_defaults(handler=command_check_branch)
    cleanup = commands.add_parser("cleanup", help="remove this helper's state file")
    cleanup.add_argument("--state-file", required=True)
    cleanup.set_defaults(handler=command_cleanup)
    return parser


def emit(command: str | None, status: str, body: JsonDict) -> int:
    payload: JsonDict = {"schema_version": SCHEMA_VERSION, "command": command, "status": status, "reason": None}
    payload.update(body)
    sys.stdout.write(json.dumps(payload, sort_keys=True) + "\n")
    return EXIT_CODES[status]


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    command = arguments[0] if arguments else None
    try:
        if command == "args":
            raw = arguments[2:] if arguments[1:2] == ["--"] else arguments[1:]
            body = command_args(" ".join(raw))
        else:
            options = build_parser().parse_args(arguments)
            body = options.handler(options)
    except Stop as stop:
        body = {"reason": stop.reason, "message": stop.message, "details": stop.details}
        if command == "args" and stop.status == "blocked":
            body["supported_flags"] = SUPPORTED_FLAGS
        return emit(command, stop.status, body)
    except Exception as error:  # Fail closed with one JSON document instead of a traceback.
        body = {"reason": "internal_error", "message": f"Unexpected helper failure: {error!r}", "details": {}}
        return emit(command, "error", body)
    return emit(command, "ok", body)


if __name__ == "__main__":
    sys.exit(main())
