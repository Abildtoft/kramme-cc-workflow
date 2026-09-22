#!/usr/bin/env python3
"""Small local helpers for kramme:visual:demo-reel.

Inspired by EveryInc compound-engineering-plugin
plugins/compound-engineering/skills/ce-demo-reel/scripts/capture-demo.py,
reviewed at commit b6250490bec4c0488d68ad66d72bd99f6edb95fd.
This is a local implementation; no upstream code was copied.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


def preflight(_: argparse.Namespace) -> None:
    tools = {
        "agent_browser": None,
        "vhs": command_available("vhs"),
        "silicon": command_available("silicon"),
        "ffmpeg": command_available("ffmpeg"),
        "ffprobe": command_available("ffprobe"),
        "screencapture": command_available("screencapture"),
    }
    tools["notes"] = [
        "agent_browser is agent-managed; set it after inspecting available browser automation tools.",
        "Artifacts stay local under .context/demo-reels; a publishing workflow may consume them separately.",
    ]
    print(json.dumps(tools, indent=2, sort_keys=True))


def ensure_direct_child_directory(parent: Path, name: str) -> Path:
    child = parent / name
    if child.is_symlink():
        raise ValueError(f"{child} must not be a symlink")
    if child.exists():
        if not child.is_dir():
            raise ValueError(f"{child} must be a directory")
    else:
        child.mkdir()
    if child.is_symlink() or child.resolve(strict=True).parent != parent:
        raise ValueError(f"{child} must remain a direct child of {parent}")
    return child


def create_run_dir(args: argparse.Namespace) -> None:
    repo_root = Path(args.repo_root).expanduser().resolve(strict=True)
    if not repo_root.is_dir():
        raise ValueError("repo root must be a directory")
    timestamp = args.timestamp or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    context_dir = ensure_direct_child_directory(repo_root, ".context")
    root_dir = ensure_direct_child_directory(context_dir, "demo-reels")
    run_dir = root_dir / timestamp
    suffix = 1
    while True:
        try:
            run_dir.mkdir(exist_ok=False)
            break
        except FileExistsError:
            run_dir = root_dir / f"{timestamp}-{suffix:02d}"
            suffix += 1
    manifest = {
        "schema_version": 1,
        "tier": None,
        "description": None,
        "artifacts": [],
        "created_at": timestamp,
    }
    (run_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(run_dir)


def main() -> int:
    parser = argparse.ArgumentParser(description="Helpers for local demo evidence capture.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    preflight_parser = subparsers.add_parser("preflight")
    preflight_parser.set_defaults(func=preflight)

    run_dir_parser = subparsers.add_parser("create-run-dir")
    run_dir_parser.add_argument("--repo-root", required=True)
    run_dir_parser.add_argument("--timestamp")
    run_dir_parser.set_defaults(func=create_run_dir)

    args = parser.parse_args()
    try:
        args.func(args)
    except (OSError, ValueError) as exc:
        print(f"demo reel helper failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
