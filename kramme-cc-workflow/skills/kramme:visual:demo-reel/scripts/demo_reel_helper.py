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
        "Artifacts are local-only under .context/demo-reels unless the user explicitly asks to upload later.",
    ]
    print(json.dumps(tools, indent=2, sort_keys=True))


def create_run_dir(args: argparse.Namespace) -> None:
    repo_root = Path(args.repo_root).expanduser().resolve()
    timestamp = args.timestamp or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    root_dir = repo_root / ".context" / "demo-reels"
    run_dir = root_dir / timestamp
    suffix = 1
    while True:
        try:
            run_dir.mkdir(parents=True, exist_ok=False)
            break
        except FileExistsError:
            run_dir = root_dir / f"{timestamp}-{suffix:02d}"
            suffix += 1
    manifest = {
        "tier": None,
        "description": None,
        "artifacts": [],
        "created_at": timestamp,
    }
    (run_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(run_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description="Helpers for local demo evidence capture.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    preflight_parser = subparsers.add_parser("preflight")
    preflight_parser.set_defaults(func=preflight)

    run_dir_parser = subparsers.add_parser("create-run-dir")
    run_dir_parser.add_argument("--repo-root", required=True)
    run_dir_parser.add_argument("--timestamp")
    run_dir_parser.set_defaults(func=create_run_dir)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
