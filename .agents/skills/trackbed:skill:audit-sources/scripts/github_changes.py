#!/usr/bin/env python3
"""Detect upstream changes to a GitHub-hosted source from commit metadata only.

The helper reads repository, commit, and git-tree metadata through `gh api` and never requests a file body.
It picks a baseline commit (recorded, then pinned, then derived from the review date), lists the commits that
touched the source path on the tracked branch after that baseline, checks whether the path still exists at the
branch head, and prints one bounded JSON object.

Limitation: the commits endpoint filters by committer date (`since`), not by ancestry. A commit merged late with
an older committer date can be missed, and an unrelated commit dated after the baseline can appear. The baseline
commit itself is excluded, and any remaining commit reports the source as changed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date
from typing import Any
from urllib.parse import quote, unquote, urlsplit

GH_TIMEOUT_SECONDS = 60
PAGE_SIZE = 100
DEFAULT_MAX_COMMITS = 20
MAX_TITLE_LENGTH = 120
MAX_MOVE_CANDIDATES = 5
SHA_RE = re.compile(r"[0-9a-f]{40}")
VERSION_TAG_RE = re.compile(r"v?\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
TIMESTAMP_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})")
NAME_RE = re.compile(r"[A-Za-z0-9_.-]+")
FULL_NAME_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")


class UnsupportedUrl(ValueError):
    """The URL is not one of the supported GitHub source forms."""


class SourceError(ValueError):
    """The source could not be checked; the message is the reason."""


@dataclass(frozen=True)
class GitHubSource:
    owner: str
    repo: str
    kind: str
    ref: str | None
    path: str
    pinned: bool

    @property
    def repository(self) -> str:
        return f"{self.owner}/{self.repo}"


def _is_pinned_ref(ref: str) -> bool:
    return SHA_RE.fullmatch(ref.lower()) is not None or VERSION_TAG_RE.fullmatch(ref) is not None


def _repository(owner: str, repo: str) -> tuple[str, str]:
    if repo.endswith(".git"):
        repo = repo[: -len(".git")]
    if not NAME_RE.fullmatch(owner) or not NAME_RE.fullmatch(repo):
        raise UnsupportedUrl("owner or repository name is not a GitHub name")
    return owner, repo


def parse_github_url(url: str) -> GitHubSource:
    """Parse a raw file, tree or blob page, or repository URL; raise UnsupportedUrl for anything else."""
    parts = urlsplit(url)
    if parts.scheme != "https":
        raise UnsupportedUrl("not an HTTPS URL")
    segments = [unquote(segment) for segment in parts.path.split("/") if segment]
    # Decoded segments build API endpoints, so traversal or an encoded slash could reach a file-content endpoint.
    if any(segment in (".", "..") or "/" in segment for segment in segments):
        raise UnsupportedUrl("URL path contains a traversal segment or an encoded slash")

    if parts.netloc == "raw.githubusercontent.com":
        if len(segments) < 4:
            raise UnsupportedUrl("raw URL needs an owner, repository, ref, and path")
        owner, repo = _repository(segments[0], segments[1])
        rest = segments[2:]
        tag_ref = False
        if rest[0] == "refs" and len(rest) >= 4 and rest[1] in ("heads", "tags"):
            tag_ref = rest[1] == "tags"
            rest = rest[2:]
        ref, path = rest[0], "/".join(rest[1:])
        return GitHubSource(owner, repo, "raw", ref, path, tag_ref or _is_pinned_ref(ref))

    if parts.netloc != "github.com" or len(segments) < 2:
        raise UnsupportedUrl("not a raw.githubusercontent.com file or github.com repository URL")
    owner, repo = _repository(segments[0], segments[1])
    if len(segments) == 2:
        return GitHubSource(owner, repo, "repository", None, "", False)
    if segments[2] not in ("tree", "blob") or len(segments) < 4:
        raise UnsupportedUrl("only github.com repository, tree, and blob URLs are supported")
    kind, ref, path = segments[2], segments[3], "/".join(segments[4:])
    if kind == "blob" and not path:
        raise UnsupportedUrl("blob URL needs a file path")
    return GitHubSource(owner, repo, kind, ref, path, _is_pinned_ref(ref))


def run_gh_api(endpoint: str, params: Mapping[str, str]) -> subprocess.CompletedProcess[str]:
    """Run one GET `gh api` call without a shell; a timeout or launch failure becomes exit 124 or 127."""
    argv = ["gh", "api", "-X", "GET", endpoint]
    for key, value in params.items():
        argv.extend(["-f", f"{key}={value}"])
    env = dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1")
    try:
        return subprocess.run(
            argv, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=GH_TIMEOUT_SECONDS
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(argv, 124, "", f"timed out after {GH_TIMEOUT_SECONDS}s")
    except OSError as error:
        return subprocess.CompletedProcess(argv, 127, "", str(error))


def _last_line(text: str) -> str:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " ".join(lines[-1].split())[:200] if lines else "no error output"


def gh_json(endpoint: str, params: Mapping[str, str] | None = None) -> Any:
    result = run_gh_api(endpoint, params or {})
    if result.returncode == 124:
        raise SourceError(f"gh api {endpoint} timed out after {GH_TIMEOUT_SECONDS}s")
    if result.returncode == 127:
        raise SourceError(f"could not run gh: {_last_line(result.stderr)}")
    if result.returncode != 0:
        raise SourceError(f"gh api {endpoint} failed with exit {result.returncode}: {_last_line(result.stderr)}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise SourceError(f"gh api {endpoint} returned malformed JSON") from error


def _object(value: Any, what: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SourceError(f"malformed {what} response")
    return value


def _list(value: Any, what: str) -> list[Any]:
    if not isinstance(value, list):
        raise SourceError(f"malformed {what} response")
    return value


def _string(value: Mapping[str, Any], key: str, what: str) -> str:
    field = value.get(key)
    if not isinstance(field, str):
        raise SourceError(f"malformed {what} response: missing {key}")
    return field


def _commit_identity(value: Any) -> tuple[str, str, str]:
    """Return the SHA, committer timestamp, and message of a commit object."""
    item = _object(value, "commit")
    sha = _string(item, "sha", "commit")
    details = _object(item.get("commit"), "commit")
    committer = _object(details.get("committer"), "commit")
    timestamp = _string(committer, "date", "commit")
    message = details.get("message")
    if not SHA_RE.fullmatch(sha):
        raise SourceError("malformed commit response: invalid SHA")
    if not TIMESTAMP_RE.fullmatch(timestamp):
        raise SourceError("malformed commit response: invalid committer date")
    return sha, timestamp, message if isinstance(message, str) else ""


def _ref_endpoint(full_name: str, ref: str) -> str:
    return f"repos/{full_name}/commits/{quote(ref, safe='/')}"


def _baseline(
    source: GitHubSource, full_name: str, tracked_branch: str, baseline_commit: str | None, last_reviewed_at: str | None
) -> tuple[str, str, str]:
    """Return the baseline SHA, committer timestamp, and source: recorded, then pinned, then derived."""
    if baseline_commit is not None:
        sha, timestamp, _ = _commit_identity(gh_json(_ref_endpoint(full_name, baseline_commit)))
        return sha, timestamp, "recorded"
    if source.pinned and source.ref is not None:
        sha, timestamp, _ = _commit_identity(gh_json(_ref_endpoint(full_name, source.ref)))
        return sha, timestamp, "pinned"
    if last_reviewed_at is None:
        raise SourceError("an unpinned URL needs --baseline-commit or --last-reviewed-at")
    params = {"sha": tracked_branch, "until": f"{last_reviewed_at}T23:59:59Z", "per_page": "1"}
    items = _list(gh_json(f"repos/{full_name}/commits", params), "commit list")
    if not items:
        raise SourceError(f"no commit on {tracked_branch} at or before {last_reviewed_at}")
    sha, timestamp, _ = _commit_identity(items[0])
    return sha, timestamp, "derived"


def _commits_after(
    source: GitHubSource, full_name: str, tracked_branch: str, baseline: str, since: str
) -> tuple[list[dict[str, str]], bool]:
    """Return the commits that touched the path after the baseline, newest first, and whether the page filled."""
    params = {"sha": tracked_branch, "since": since, "per_page": str(PAGE_SIZE)}
    if source.path:
        params["path"] = source.path
    items = _list(gh_json(f"repos/{full_name}/commits", params), "commit list")
    commits: list[dict[str, str]] = []
    for item in items:
        sha, timestamp, message = _commit_identity(item)
        if sha == baseline:
            continue
        title = message.splitlines()[0] if message else ""
        commits.append({"sha": sha[:7], "date": timestamp[:10], "title": title[:MAX_TITLE_LENGTH]})
    return commits, len(items) >= PAGE_SIZE


def _path_status(source: GitHubSource, full_name: str, head_commit: str) -> tuple[str, list[str]]:
    """Return `present`, `missing`, or `unknown` for the path at the head commit, plus move candidates."""
    if not source.path:
        return "present", []
    tree = _object(gh_json(f"repos/{full_name}/git/trees/{head_commit}", {"recursive": "1"}), "tree")
    entries = _list(tree.get("tree"), "tree")
    wanted_type = "tree" if source.kind == "tree" else "blob"
    target_tail = source.path.split("/")[-2:]
    candidates: list[str] = []
    for value in entries:
        entry = _object(value, "tree entry")
        path, entry_type = entry.get("path"), entry.get("type")
        if not isinstance(path, str) or entry_type != wanted_type:
            continue
        if path == source.path:
            return "present", []
        if path.split("/")[-len(target_tail) :] == target_tail and len(candidates) < MAX_MOVE_CANDIDATES:
            candidates.append(path)
    if tree.get("truncated") is True:
        return "unknown", []
    return "missing", candidates


def _head_url(source: GitHubSource, full_name: str, head_commit: str) -> str:
    path = quote(source.path, safe="/")
    if source.kind in ("raw", "blob"):
        return f"https://raw.githubusercontent.com/{full_name}/{head_commit}/{path}"
    suffix = f"/{path}" if path else ""
    return f"https://github.com/{full_name}/tree/{head_commit}{suffix}"


def _validate_arguments(baseline_commit: str | None, last_reviewed_at: str | None, max_commits: int) -> None:
    if baseline_commit is not None and not SHA_RE.fullmatch(baseline_commit):
        raise SourceError("--baseline-commit must be a full 40-character hexadecimal SHA")
    if last_reviewed_at is not None:
        try:
            if not DATE_RE.fullmatch(last_reviewed_at):
                raise ValueError(last_reviewed_at)
            date.fromisoformat(last_reviewed_at)
        except ValueError as error:
            raise SourceError("--last-reviewed-at must be a YYYY-MM-DD date") from error
    if not 1 <= max_commits <= PAGE_SIZE:
        raise SourceError(f"--max-commits must be between 1 and {PAGE_SIZE}")


def detect_changes(
    url: str, source: GitHubSource, *, last_reviewed_at: str | None, baseline_commit: str | None, max_commits: int
) -> dict[str, Any]:
    """Classify a parsed GitHub source as unchanged, changed, moved, or gone from metadata endpoints only."""
    if baseline_commit is not None:
        baseline_commit = baseline_commit.lower()
    _validate_arguments(baseline_commit, last_reviewed_at, max_commits)
    if baseline_commit is None and not source.pinned and last_reviewed_at is None:
        raise SourceError("an unpinned URL needs --baseline-commit or --last-reviewed-at")

    repository = _object(gh_json(f"repos/{source.repository}"), "repository")
    full_name = _string(repository, "full_name", "repository")
    default_branch = _string(repository, "default_branch", "repository")
    if not FULL_NAME_RE.fullmatch(full_name):
        raise SourceError("malformed repository response: invalid full_name")
    renamed_to = full_name if full_name.lower() != source.repository.lower() else None
    tracked_branch = default_branch if source.pinned or source.ref is None else source.ref

    head_commit, _, _ = _commit_identity(gh_json(_ref_endpoint(full_name, tracked_branch)))
    baseline, since, baseline_source = _baseline(source, full_name, tracked_branch, baseline_commit, last_reviewed_at)
    commits, page_filled = _commits_after(source, full_name, tracked_branch, baseline, since)
    path_status, move_candidates = _path_status(source, full_name, head_commit)

    if path_status == "missing":
        status = "moved" if move_candidates else "gone"
    else:
        status = "changed" if commits else "unchanged"

    return {
        "url": url,
        "repository": source.repository,
        "full_name": full_name,
        "renamed_to": renamed_to,
        "path": source.path,
        "ref": source.ref,
        "pinned": source.pinned,
        "tracked_branch": tracked_branch,
        "head_commit": head_commit,
        "head_url": _head_url(source, full_name, head_commit),
        "baseline_commit": baseline,
        "baseline_source": baseline_source,
        "baseline_date": since[:10],
        "path_status": path_status,
        "move_candidates": move_candidates,
        "commit_count": len(commits),
        "commits_truncated": page_filled or len(commits) > max_commits,
        "commits": commits[:max_commits],
        "status": status,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Detect upstream changes to a GitHub-hosted source from metadata.")
    parser.add_argument("--url", required=True, help="raw.githubusercontent.com, tree, blob, or repository URL.")
    parser.add_argument("--last-reviewed-at", help="YYYY-MM-DD; derives the baseline when nothing else does.")
    parser.add_argument("--baseline-commit", help="Full 40-character SHA of the last checked upstream commit.")
    parser.add_argument(
        "--max-commits", type=int, default=DEFAULT_MAX_COMMITS, help=f"Commits to list (1-{PAGE_SIZE})."
    )
    args = parser.parse_args(argv)

    try:
        source = parse_github_url(args.url)
    except UnsupportedUrl as error:
        print(f"github_changes.py: {error}", file=sys.stderr)
        return 2

    try:
        report = detect_changes(
            args.url,
            source,
            last_reviewed_at=args.last_reviewed_at,
            baseline_commit=args.baseline_commit,
            max_commits=args.max_commits,
        )
    except SourceError as error:
        print(f"github_changes.py: {error}", file=sys.stderr)
        return 1

    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
