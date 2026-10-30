#!/usr/bin/env python3
"""Decide how much of a Pull Request a re-review needs: only what changed since your last review.

  python3 review-delta.py --repo <owner/name> --pr <number> --self <login> \
      --head <commit> --base <commit> --trunk <ref>

Run it inside a checkout of the Pull Request's repository. `--head` is the Pull Request head, `--base` is
the commit this Pull Request's own commits start from (the review's merge base), and `--trunk` is the branch
the stack, or the Pull Request itself, merges into. Prints one JSON document on one line and exits 0
whenever it reaches a decision; exit 2 means an invalid invocation.

Your last review is the newest review you submitted that looked at code: an approval, a change request, a
dismissed review, or a comment review with a summary body. A comment review without a body does not count,
because GitHub records every single comment and thread reply as one.

Scopes:

- `first`: you have not reviewed this Pull Request yet; review all of it.
- `unchanged`: no commit in this layer changed since your last review, either because nothing was pushed or
  because a rebase or restack re-applied every commit with the same patch.
- `delta`: review only the commits after `review_base`.
- `full`: the changes could not be isolated, a reviewed patch was removed or replaced, or the first commit
  changed; review all of it.

After a rebase or restack, commits are matched by `git patch-id --verbatim`, preserving semantic whitespace.
GitHub does not record the base a review saw, so the last-reviewed version of this layer is taken to start
after the newest commit below it
whose patch also existed at your last review. A commit that moved up from below that point counts as
changed; one that was the top of the layer below at your last review counts as reviewed. Every failure
falls back to `full`, never to a smaller scope.

The helper reads your reviews from GitHub and may fetch your last reviewed commit by object ID. It never
writes to GitHub and never changes branches, the index, or the working tree.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Callable, Sequence
from typing import Any

SCHEMA_VERSION = 1
LOCAL_TIMEOUT = 120
NETWORK_TIMEOUT = 60
MAX_COMMITS = 500
OID_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
REPO_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
LOGIN_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?")
CODE_REVIEW_STATES = frozenset({"APPROVED", "CHANGES_REQUESTED", "DISMISSED"})
# Normalize the log output that `git patch-id` hashes, whatever the user's configuration.
PATCH_LOG = (
    "-c",
    "log.showSignature=false",
    "-c",
    "diff.noprefix=false",
    "-c",
    "diff.mnemonicPrefix=false",
    "log",
    "--no-merges",
    "-p",
    "--binary",
    "--no-color",
    "--no-ext-diff",
    "--no-textconv",
    "--format=commit %H",
)

Json = dict[str, Any]


class Fallback(Exception):
    """The changes since the last review cannot be isolated; the message is the reason."""


def environment() -> dict[str, str]:
    return dict(os.environ, GH_PROMPT_DISABLED="1", GIT_TERMINAL_PROMPT="0", GIT_OPTIONAL_LOCKS="0", NO_COLOR="1")


def run(argv: Sequence[str], timeout: int, data: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
    """Run without a shell; a timeout or launch failure becomes exit 124 or 127 with the reason on stderr."""
    try:
        return subprocess.run(list(argv), env=environment(), input=data or b"", capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(list(argv), 124, b"", f"timed out after {timeout}s".encode())
    except OSError as error:
        return subprocess.CompletedProcess(list(argv), 127, b"", str(error).encode())


def tail(data: bytes) -> str:
    return " ".join(data.decode("utf-8", "replace").split())[-300:]


def git(*args: str, data: bytes | None = None) -> str:
    result = run(["git", *args], LOCAL_TIMEOUT, data)
    if result.returncode != 0:
        command = next((arg for arg in args if not arg.startswith("-") and "=" not in arg), "command")
        raise Fallback(f"`git {command}` failed: {tail(result.stderr) or f'exit {result.returncode}'}")
    return result.stdout.decode("utf-8", "replace")


def succeeds(*args: str) -> bool:
    return run(["git", *args], LOCAL_TIMEOUT).returncode == 0


def has_commit(oid: str) -> bool:
    return succeeds("cat-file", "-e", f"{oid}^{{commit}}")


def is_ancestor(ancestor: str, descendant: str) -> bool:
    return succeeds("merge-base", "--is-ancestor", ancestor, descendant)


def merge_base(first: str, second: str) -> str | None:
    result = run(["git", "merge-base", first, second], LOCAL_TIMEOUT)
    oid = result.stdout.decode("utf-8", "replace").strip()
    return oid if result.returncode == 0 and OID_RE.fullmatch(oid) else None


def has_merges(start: str, end: str) -> bool:
    return bool(git("rev-list", "--merges", "--max-count=1", f"{start}..{end}").strip())


def commits(start: str, end: str) -> list[tuple[str, str]]:
    """Commits after `start` up to `end`, oldest first, as (object ID, subject) pairs."""
    pairs = []
    for line in git("log", "--reverse", "--no-merges", "--format=%H%x00%s", f"{start}..{end}").splitlines():
        oid, _, subject = line.partition("\0")
        pairs.append((oid, subject))
    return pairs


def patch_ids(start: str, end: str) -> dict[str, str]:
    """Whitespace-preserving patch IDs after `start` up to `end`; empty commits have none."""
    log = git(*PATCH_LOG, f"{start}..{end}")
    if not log.strip():
        return {}
    ids = {}
    for line in git("patch-id", "--verbatim", data=log.encode("utf-8")).splitlines():
        parts = line.split()
        if len(parts) == 2:
            ids[parts[1]] = parts[0]
    return ids


def gh_items(path: str, what: str) -> list[Any]:
    result = run(["gh", "api", "--paginate", "--slurp", path], NETWORK_TIMEOUT)
    if result.returncode != 0:
        raise Fallback(f"could not read {what}: {tail(result.stderr) or f'gh exited {result.returncode}'}")
    try:
        pages = json.loads(result.stdout or b"null")
    except ValueError as error:
        raise Fallback(f"could not parse {what}: {error}") from error
    if not isinstance(pages, list) or not all(isinstance(page, list) for page in pages):
        raise Fallback(f"could not parse {what}: expected pages of lists")
    return [item for page in pages for item in page]


def last_review(reviews: list[Any], login: str) -> Json | None:
    """The newest submitted review by `login` that looked at code, as the fields the report shows."""
    best: Json | None = None
    for review in reviews:
        if not isinstance(review, dict):
            continue
        user = review.get("user")
        state, commit, submitted = review.get("state"), review.get("commit_id"), review.get("submitted_at")
        body = review.get("body")
        if not isinstance(user, dict) or user.get("login") != login:
            continue
        if not (isinstance(commit, str) and OID_RE.fullmatch(commit) and isinstance(submitted, str)):
            continue
        has_summary = isinstance(body, str) and bool(body.strip())
        if state not in CODE_REVIEW_STATES and not (state == "COMMENTED" and has_summary):
            continue
        if best is None or submitted > best["submitted_at"]:
            best = {"id": review.get("id"), "state": state, "submitted_at": submitted, "commit": commit}
    return best


def decision(scope: str, reason: str, **fields: Any) -> Json:
    payload: Json = {
        "schema_version": SCHEMA_VERSION,
        "scope": scope,
        "reason": reason,
        "last_review": None,
        "review_base": None,
        "commits": [],
        "dropped": [],
        "lower_layers_changed": None,
        "notes": [],
    }
    payload.update(fields)
    return payload


def entries(pairs: list[tuple[str, str]], changed: set[str]) -> list[Json]:
    return [
        {"oid": oid, "subject": subject, "status": "changed" if oid in changed else "unchanged"}
        for oid, subject in pairs
    ]


def appended(old: str, head: str, base: str) -> Json:
    """New commits on top of the last reviewed head, with no history rewritten."""
    if has_merges(old, head):
        raise Fallback("merge commits arrived since your last review")
    new = {oid for oid, _ in commits(old, head)}
    listed = entries(commits(base, head), new)
    if old == base:
        return decision("full", "every commit in this layer is new since your last review", commits=listed)
    reason = f"{len(new)} of {len(listed)} commits in this layer are new since your last review"
    return decision("delta", reason, review_base=old, commits=listed, lower_layers_changed=False)


def rewritten(old: str, head: str, base: str, trunk: str) -> Json:
    """Match this layer's commits to the last reviewed version of it by patch after a rebase or restack."""
    resolved = run(["git", "rev-parse", "--verify", "--quiet", f"{trunk}^{{commit}}"], LOCAL_TIMEOUT)
    trunk_oid = resolved.stdout.decode("utf-8", "replace").strip()
    if resolved.returncode != 0 or not OID_RE.fullmatch(trunk_oid):
        raise Fallback(f"the trunk `{trunk}` does not resolve to a commit")
    new_bottom, old_bottom = merge_base(head, trunk_oid), merge_base(old, trunk_oid)
    if not new_bottom or not old_bottom or not is_ancestor(new_bottom, base):
        raise Fallback("your last reviewed commit and this Pull Request share no history with the trunk")
    if has_merges(new_bottom, head) or has_merges(old_bottom, old):
        raise Fallback("the stack contains merge commits")
    old_series, lower, layer = commits(old_bottom, old), commits(new_bottom, base), commits(base, head)
    if len(old_series) + len(lower) + len(layer) > MAX_COMMITS:
        raise Fallback(f"more than {MAX_COMMITS} commits to compare")
    old_ids, new_ids = patch_ids(old_bottom, old), patch_ids(new_bottom, head)
    position = {oid: index for index, (oid, _) in enumerate(old_series)}
    old_by_patch: dict[str, list[str]] = {}
    for oid, _ in old_series:
        if oid in old_ids:
            old_by_patch.setdefault(old_ids[oid], []).append(oid)

    start = 0
    if lower:
        matches = (old_by_patch.get(new_ids.get(oid, ""), []) for oid, _ in reversed(lower))
        boundary = next((max(found, key=position.__getitem__) for found in matches if found), None)
        if boundary is None:
            raise Fallback(
                "the layers below were rewritten, so where this layer started at your last review is unknown"
            )
        start = position[boundary] + 1
    reviewed = old_series[start:]
    reviewed_patches = {old_ids[oid] for oid, _ in reviewed if oid in old_ids}
    changed = {oid for oid, _ in layer if oid in new_ids and new_ids[oid] not in reviewed_patches}
    layer_patches = {new_ids[oid] for oid, _ in layer if oid in new_ids}
    dropped = [
        {"oid": oid, "subject": subject}
        for oid, subject in reviewed
        if oid in old_ids and old_ids[oid] not in layer_patches
    ]
    lower_changed = any(new_ids.get(oid) not in old_by_patch for oid, _ in lower if oid in new_ids)
    fields: Json = {"commits": entries(layer, changed), "dropped": dropped, "lower_layers_changed": lower_changed}
    if dropped:
        return decision("full", "reviewed patches were removed or replaced, so the whole layer needs review", **fields)
    if not changed:
        return decision("unchanged", "every commit in this layer has the same patch as at your last review", **fields)
    first = next(index for index, (oid, _) in enumerate(layer) if oid in changed)
    if first == 0:
        reason = "the first commit in this layer changed since your last review, so the whole layer needs review"
        return decision("full", reason, **fields)
    reason = f"{len(changed)} of {len(layer)} commits in this layer changed since your last review"
    return decision("delta", reason, review_base=layer[first - 1][0], **fields)


def compare(old: str, head: str, base: str, trunk: str) -> Json:
    if old == head:
        return decision("unchanged", "no commits were pushed since your last review", lower_layers_changed=False)
    if not has_commit(old):
        run(["git", "fetch", "--quiet", "--no-tags", "origin", old], NETWORK_TIMEOUT)
        if not has_commit(old):
            raise Fallback(f"your last reviewed commit {old[:12]} is no longer available")
    if not is_ancestor(base, head):
        raise Fallback("the review base is not an ancestor of the Pull Request head")
    if is_ancestor(old, head) and is_ancestor(base, old):
        return appended(old, head, base)
    return rewritten(old, head, base, trunk)


def resolve(args: argparse.Namespace) -> Json:
    try:
        reviews = gh_items(f"repos/{args.repo}/pulls/{args.pr}/reviews", "your earlier reviews")
    except Fallback as error:
        return decision("full", str(error))
    previous = last_review(reviews, args.self)
    if previous is None:
        return decision("first", "you have not reviewed this Pull Request yet")
    try:
        result = compare(previous["commit"], args.head, args.base, args.trunk)
    except Fallback as error:
        return decision("full", str(error), last_review=previous)
    result["last_review"] = previous
    return result


def oid(value: str) -> str:
    if not OID_RE.fullmatch(value):
        raise argparse.ArgumentTypeError(f"expected a full commit object ID: {value!r}")
    return value


def pattern(expression: re.Pattern[str], label: str) -> Callable[[str], str]:
    def check(value: str) -> str:
        if not expression.fullmatch(value):
            raise argparse.ArgumentTypeError(f"expected {label}: {value!r}")
        return value

    return check


def positive(value: str) -> int:
    if not value.isdigit() or int(value) < 1:
        raise argparse.ArgumentTypeError(f"expected a positive Pull Request number: {value!r}")
    return int(value)


def trunk_ref(value: str) -> str:
    if not value or value.startswith("-") or any(char.isspace() for char in value) or ".." in value:
        raise argparse.ArgumentTypeError(f"expected a branch or remote-tracking ref: {value!r}")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Scope a re-review to what changed since your last review.")
    parser.add_argument("--repo", required=True, type=pattern(REPO_RE, "owner/name"))
    parser.add_argument("--pr", required=True, type=positive)
    parser.add_argument("--self", required=True, type=pattern(LOGIN_RE, "a GitHub login"))
    parser.add_argument("--head", required=True, type=oid)
    parser.add_argument("--base", required=True, type=oid)
    parser.add_argument("--trunk", required=True, type=trunk_ref)
    args = parser.parse_args(argv)
    print(json.dumps(resolve(args), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
