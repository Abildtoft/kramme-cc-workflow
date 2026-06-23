#!/usr/bin/env python3
"""Synchronize visual shared assets declared as file identity groups.

The first path in each visual file identity group is the canonical source.
By default this command only checks whether copies are in sync. Pass
--write to copy canonical bytes into the remaining registered paths.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class SyncAction:
    group: str
    source: str
    target: str
    reason: str


def parse_cli() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Check or sync visual shared assets from canonical identity groups"
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=script_dir.parent.parent,
        help="Repository root. Defaults to two directories above this script.",
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=script_dir / "synced-contracts.yaml",
        help="Path to synced-contracts.yaml.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="Check copies without writing. This is the default.",
    )
    mode.add_argument(
        "--write",
        action="store_true",
        help="Write canonical content to out-of-sync copies.",
    )
    return parser.parse_args()


def load_registry(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"{path}: registry must be JSON-compatible YAML for stdlib parsing: {exc}"
        ) from exc


def resolve(root: Path, path: str) -> Path:
    return (root / path).resolve()


def is_visual_group(group: dict[str, Any]) -> bool:
    name = group.get("name")
    paths = group.get("paths", [])
    return (
        isinstance(name, str)
        and name.startswith("visual-")
        and isinstance(paths, list)
        and len(paths) >= 2
    )


def visual_file_identity_groups(registry: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        group
        for group in registry.get("file_identity_groups", [])
        if isinstance(group, dict) and is_visual_group(group)
    ]


def planned_actions(
    root: Path,
    groups: list[dict[str, Any]],
) -> tuple[list[SyncAction], list[str]]:
    actions: list[SyncAction] = []
    failures: list[str] = []

    for group in groups:
        name = group["name"]
        paths = group["paths"]
        source_rel = paths[0]
        source_path = resolve(root, source_rel)
        if not source_path.exists():
            failures.append(f"{name}: canonical path is missing: {source_rel}")
            continue

        source_bytes = source_path.read_bytes()
        for target_rel in paths[1:]:
            target_path = resolve(root, target_rel)
            if not target_path.exists():
                actions.append(
                    SyncAction(
                        group=name,
                        source=source_rel,
                        target=target_rel,
                        reason="missing",
                    )
                )
                continue
            if target_path.read_bytes() != source_bytes:
                actions.append(
                    SyncAction(
                        group=name,
                        source=source_rel,
                        target=target_rel,
                        reason="differs",
                    )
                )

    return actions, failures


def write_actions(root: Path, actions: list[SyncAction]) -> None:
    source_cache: dict[str, bytes] = {}
    for action in actions:
        source_bytes = source_cache.get(action.source)
        if source_bytes is None:
            source_bytes = resolve(root, action.source).read_bytes()
            source_cache[action.source] = source_bytes
        target_path = resolve(root, action.target)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_bytes(source_bytes)


def report_actions(actions: list[SyncAction]) -> None:
    for action in actions:
        print(
            f"{action.group}: {action.target} {action.reason} from canonical "
            f"{action.source}"
        )


def main() -> int:
    args = parse_cli()
    root = args.repo_root.resolve()
    registry = load_registry(args.registry.resolve())
    groups = visual_file_identity_groups(registry)
    if not groups:
        print("visual shared asset sync failed:")
        print("::error::no visual file identity groups found in registry")
        return 1

    actions, failures = planned_actions(root, groups)
    if failures:
        print("visual shared asset sync failed:")
        for failure in failures:
            print(f"::error::{failure}")
        return 1

    if args.write:
        write_actions(root, actions)
        if actions:
            report_actions(actions)
            print(f"synced {len(actions)} visual shared asset file(s).")
        else:
            print("visual shared assets are in sync.")
        return 0

    if actions:
        print("visual shared asset sync check failed:")
        report_actions(actions)
        print("run scripts/generate-visual-shared-assets.py --write to sync copies")
        return 1

    print("visual shared assets are in sync.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
