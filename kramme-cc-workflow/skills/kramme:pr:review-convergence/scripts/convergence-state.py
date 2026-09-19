#!/usr/bin/env python3
"""Run-state helper for kramme:pr:review-convergence.

The convergence policy used to describe the review archive walk, the remediation
commit boundary, and the cycle ledger as prose the orchestrator followed by hand.
This script owns those mechanical steps so they cannot be skipped or half-applied.

Subcommands:

  validate-archive --archive-key KEY
      Establish `.context/KEY/reviews/` without following symlinks, prove it is
      strictly below the repository root, and prove Git ignores it.

  ledger init --archive-key KEY --work-id ID --max-cycles N
  ledger record --archive-key KEY --entry JSON
  ledger summary --archive-key KEY
      Maintain the run-scoped cycle ledger under the validated archive and
      summarize cycles, rounds, commits, and per-gate agent launches.

  commit-boundary --archive-key KEY --work-id ID --message MSG
                  [--scope-mode none|exact-files|containment] [--scope-path P ...]
                  -- PATH...
      Classify every dirty path, stage only the named paths, commit, and prove the
      committed tree equals the staged tree that passed focused verification.

Exit codes: 0 success, 1 validation failure, 2 usage error, 3 commit hooks changed
the committed tree (the commit exists; focused verification must rerun).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

ARCHIVE_KEYS = ("pr-review-convergence", "linear-issue-to-pr", "code-plan-to-pr")
LEDGER_NAME = "cycle-ledger.json"
ENTRY_KINDS = ("gate", "round", "cycle", "commit")
ROUND_KINDS = ("full", "delta", "validation-only")
SCOPE_MODES = ("none", "exact-files", "containment")

EXIT_OK = 0
EXIT_VALIDATION = 1
EXIT_USAGE = 2
EXIT_HOOK_CHANGED_TREE = 3


class ValidationError(Exception):
    """A precondition the policy requires did not hold."""


def git(*args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise ValidationError(f"git {' '.join(args)} failed: {result.stderr.strip() or result.returncode}")
    return result


def repository_root() -> Path:
    root = git("rev-parse", "--show-toplevel").stdout.strip()
    if not root:
        raise ValidationError("not inside a Git repository")
    return Path(root).resolve(strict=True)


def require_archive_key(key: str) -> str:
    if key not in ARCHIVE_KEYS:
        raise ValidationError(f"archive key {key!r} is not allowlisted; expected one of {', '.join(ARCHIVE_KEYS)}")
    return key


def _require_real_directory(component: Path, root: Path) -> None:
    if component.is_symlink():
        raise ValidationError(f"{component} is a symlink; the review archive must be built from real directories")
    if not component.is_dir():
        raise ValidationError(f"{component} exists but is not a directory")
    canonical = component.resolve(strict=True)
    if canonical == root or root not in canonical.parents:
        raise ValidationError(f"{component} resolves to {canonical}, which is not strictly below {root}")


def validate_archive(key: str) -> dict[str, str]:
    root = repository_root()
    relative = PurePosixPath(".context") / key / "reviews"
    walked = root
    for part in relative.parts:
        walked = walked / part
        if walked.is_symlink():
            raise ValidationError(f"{walked} is a symlink; refusing to use it as an archive component")
        if not walked.exists():
            try:
                walked.mkdir()
            except OSError as error:
                raise ValidationError(f"could not create {walked}: {error}") from error
        _require_real_directory(walked, root)
    archive = f"{relative.as_posix()}/"
    ignored = git("check-ignore", "-q", "--", archive, cwd=root, check=False)
    if ignored.returncode == 1:
        raise ValidationError(f"{archive} is not ignored by Git; add it to .gitignore before review")
    if ignored.returncode != 0:
        raise ValidationError(f"git check-ignore failed for {archive}: {ignored.stderr.strip()}")
    return {"review_archive": relative.as_posix(), "canonical": str(walked.resolve(strict=True))}


def ledger_path(key: str) -> Path:
    info = validate_archive(key)
    return Path(info["canonical"]) / LEDGER_NAME


def _load_ledger(path: Path) -> dict[str, Any]:
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValidationError(f"{path} is not a regular file")
    if not path.exists():
        raise ValidationError(f"{path} does not exist; run `ledger init` first")
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict) or not isinstance(data.get("entries"), list):
        raise ValidationError(f"{path} is not a convergence ledger")
    return data


def _write_ledger(path: Path, data: dict[str, Any]) -> None:
    temporary = path.with_suffix(".json.tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(temporary, path)


def ledger_init(key: str, work_id: str, max_cycles: int) -> dict[str, Any]:
    if max_cycles < 0:
        raise ValidationError("--max-cycles must be a nonnegative integer")
    path = ledger_path(key)
    if path.is_symlink():
        raise ValidationError(f"{path} is a symlink")
    data: dict[str, Any] = {
        "work_id": work_id,
        "max_cycles": max_cycles,
        "started_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "entries": [],
    }
    _write_ledger(path, data)
    return {"ledger": str(path), "work_id": work_id, "max_cycles": max_cycles}


def _validate_entry(entry: Any) -> dict[str, Any]:
    if not isinstance(entry, dict):
        raise ValidationError("--entry must be a JSON object")
    kind = entry.get("kind")
    if kind not in ENTRY_KINDS:
        raise ValidationError(f"entry kind {kind!r} must be one of {', '.join(ENTRY_KINDS)}")
    if kind == "gate":
        if not isinstance(entry.get("gate"), str) or not entry["gate"]:
            raise ValidationError("gate entries require a non-empty `gate` string")
        launched = entry.get("agents_launched")
        if not isinstance(launched, int) or isinstance(launched, bool) or launched < 0:
            raise ValidationError("gate entries require a nonnegative integer `agents_launched`")
    if kind == "round":
        if entry.get("round_kind") not in ROUND_KINDS:
            raise ValidationError(f"round entries require `round_kind` in {', '.join(ROUND_KINDS)}")
    if kind == "commit":
        for field in ("commit", "tree"):
            if not isinstance(entry.get(field), str) or not entry[field]:
                raise ValidationError(f"commit entries require a non-empty `{field}` string")
    return entry


def ledger_record(key: str, entry_json: str) -> dict[str, Any]:
    try:
        entry = json.loads(entry_json)
    except json.JSONDecodeError as error:
        raise ValidationError(f"--entry is not valid JSON: {error}") from error
    entry = _validate_entry(entry)
    path = ledger_path(key)
    data = _load_ledger(path)
    entry = dict(entry)
    entry["sequence"] = len(data["entries"]) + 1
    entry["recorded_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    if entry["kind"] == "cycle":
        cycles_used = sum(1 for existing in data["entries"] if existing.get("kind") == "cycle") + 1
        if cycles_used > int(data.get("max_cycles", 0)):
            raise ValidationError(
                f"cycle {cycles_used} exceeds the budget of {data.get('max_cycles')}; the bounded stop must fire instead"
            )
        entry["cycle"] = cycles_used
    data["entries"].append(entry)
    _write_ledger(path, data)
    return {"ledger": str(path), "sequence": entry["sequence"], "kind": entry["kind"]}


def ledger_summary(key: str) -> dict[str, Any]:
    path = ledger_path(key)
    data = _load_ledger(path)
    entries = data["entries"]
    rounds: dict[str, int] = {kind: 0 for kind in ROUND_KINDS}
    per_gate: dict[str, int] = {}
    commits: list[dict[str, str]] = []
    for entry in entries:
        kind = entry.get("kind")
        if kind == "round":
            rounds[entry["round_kind"]] += 1
        elif kind == "gate":
            per_gate[entry["gate"]] = per_gate.get(entry["gate"], 0) + int(entry["agents_launched"])
        elif kind == "commit":
            commits.append({"commit": entry["commit"], "tree": entry["tree"]})
    cycles_used = sum(1 for entry in entries if entry.get("kind") == "cycle")
    total_agents = sum(per_gate.values())
    total_rounds = sum(rounds.values())
    round_parts = ", ".join(f"{kind}×{count}" for kind, count in rounds.items() if count)
    gate_parts = ", ".join(f"{gate} {count}" for gate, count in sorted(per_gate.items()))
    line = f"Review cost: {total_agents} agents across {total_rounds} rounds ({round_parts or 'none'})"
    if gate_parts:
        line += f"; per gate: {gate_parts}"
    return {
        "work_id": data.get("work_id"),
        "max_cycles": data.get("max_cycles"),
        "cycles_used": cycles_used,
        "rounds": rounds,
        "agents_launched": per_gate,
        "total_agents": total_agents,
        "commits": commits,
        "review_cost_line": line,
    }


def _normalize_path(raw: str) -> str:
    if not raw or raw.startswith("-") or raw.startswith("/") or "\\" in raw:
        raise ValidationError(f"path {raw!r} must be a relative repository path without a leading `-` or `/`")
    if any(ord(char) < 32 for char in raw):
        raise ValidationError(f"path {raw!r} contains control characters")
    parts = PurePosixPath(raw).parts
    if any(part in ("..", "") for part in parts) or parts[0] == ".":
        raise ValidationError(f"path {raw!r} must not contain `.` or `..` segments")
    return PurePosixPath(*parts).as_posix()


def _check_scope(path: str, mode: str, scope_paths: list[str]) -> None:
    if mode == "none":
        return
    if not scope_paths:
        raise ValidationError(f"--scope-mode {mode} requires at least one --scope-path")
    if mode == "exact-files":
        if path not in scope_paths:
            raise ValidationError(f"{path} is not one of the validated exact scope files")
        return
    for scope in scope_paths:
        if path == scope or path.startswith(scope.rstrip("/") + "/"):
            return
    raise ValidationError(f"{path} is outside every validated scope path")


def _dirty_paths(root: Path) -> list[str]:
    output = git("status", "--porcelain=v1", "-z", "--untracked-files=all", cwd=root).stdout
    records = output.split("\0")
    dirty: list[str] = []
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        status, path = record[:2], record[3:]
        dirty.append(path)
        if status[0] in ("R", "C"):
            # Renames and copies carry the original path in the following record.
            index += 1
    return dirty


def commit_boundary(
    key: str,
    work_id: str,
    message: str,
    paths: list[str],
    scope_mode: str,
    scope_paths: list[str],
) -> tuple[dict[str, Any], int]:
    if not paths:
        raise ValidationError("commit-boundary requires at least one path after `--`")
    if work_id not in message:
        raise ValidationError("the commit message must include the work ID")
    normalized = [_normalize_path(path) for path in paths]
    if len(set(normalized)) != len(normalized):
        raise ValidationError("duplicate paths supplied")
    normalized_scope = [_normalize_path(path) for path in scope_paths]
    for path in normalized:
        _check_scope(path, scope_mode, normalized_scope)
    root = repository_root()
    dirty = _dirty_paths(root)
    extras = sorted(set(dirty) - set(normalized))
    if extras:
        raise ValidationError(
            "dirty paths outside the remediation batch; stop instead of committing them: " + ", ".join(extras)
        )
    missing = sorted(set(normalized) - set(dirty))
    if missing:
        raise ValidationError("named paths have no changes to commit: " + ", ".join(missing))
    git("add", "--", *normalized, cwd=root)
    staged_tree = git("write-tree", cwd=root).stdout.strip()
    git("commit", "-q", "-m", message, cwd=root)
    commit = git("rev-parse", "HEAD", cwd=root).stdout.strip()
    committed_tree = git("rev-parse", "HEAD^{tree}", cwd=root).stdout.strip()
    hook_changed_tree = committed_tree != staged_tree
    remaining = _dirty_paths(root)
    entry = {
        "kind": "commit",
        "work_id": work_id,
        "commit": commit,
        "tree": committed_tree,
        "paths": normalized,
        "hook_changed_tree": hook_changed_tree,
    }
    ledger_record(key, json.dumps(entry))
    result = {
        "commit": commit,
        "tree": committed_tree,
        "staged_tree": staged_tree,
        "paths": normalized,
        "hook_changed_tree": hook_changed_tree,
        "worktree_clean": not remaining,
    }
    if remaining:
        result["dirty_after_commit"] = remaining
        return result, EXIT_VALIDATION
    if hook_changed_tree:
        return result, EXIT_HOOK_CHANGED_TREE
    return result, EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="convergence-state.py", description=__doc__.splitlines()[0])
    subparsers = parser.add_subparsers(dest="command", required=True)

    archive = subparsers.add_parser("validate-archive", help="establish and prove the review archive")
    archive.add_argument("--archive-key", required=True)

    ledger = subparsers.add_parser("ledger", help="maintain the cycle ledger")
    ledger_sub = ledger.add_subparsers(dest="ledger_command", required=True)
    init = ledger_sub.add_parser("init")
    init.add_argument("--archive-key", required=True)
    init.add_argument("--work-id", required=True)
    init.add_argument("--max-cycles", required=True, type=int)
    record = ledger_sub.add_parser("record")
    record.add_argument("--archive-key", required=True)
    record.add_argument("--entry", required=True, help="one JSON object")
    summary = ledger_sub.add_parser("summary")
    summary.add_argument("--archive-key", required=True)

    boundary = subparsers.add_parser("commit-boundary", help="stage and commit one verified remediation batch")
    boundary.add_argument("--archive-key", required=True)
    boundary.add_argument("--work-id", required=True)
    boundary.add_argument("--message", required=True)
    boundary.add_argument("--scope-mode", choices=SCOPE_MODES, default="none")
    boundary.add_argument("--scope-path", action="append", default=[])
    boundary.add_argument("paths", nargs="*", help="paths after `--`")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as error:
        return EXIT_USAGE if error.code else EXIT_OK
    try:
        exit_code = EXIT_OK
        if args.command == "validate-archive":
            payload: dict[str, Any] = validate_archive(require_archive_key(args.archive_key))
        elif args.command == "ledger":
            key = require_archive_key(args.archive_key)
            if args.ledger_command == "init":
                payload = ledger_init(key, args.work_id, args.max_cycles)
            elif args.ledger_command == "record":
                payload = ledger_record(key, args.entry)
            else:
                payload = ledger_summary(key)
        else:
            payload, exit_code = commit_boundary(
                require_archive_key(args.archive_key),
                args.work_id,
                args.message,
                args.paths,
                args.scope_mode,
                args.scope_path,
            )
    except ValidationError as error:
        print(f"convergence-state: {error}", file=sys.stderr)
        return EXIT_VALIDATION
    json.dump(payload, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
