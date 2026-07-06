#!/usr/bin/env python3
"""Synchronize README component reference rows from skill frontmatter.

By default this command checks whether README skill rows match the source
metadata in each `SKILL.md`. Pass --write to update the rows in place.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_cli() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Check or sync README component reference rows"
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
        help="Check README rows without writing. This is the default.",
    )
    mode.add_argument(
        "--write",
        action="store_true",
        help="Write generated README rows.",
    )
    return parser.parse_args()


def load_lint_module(script_dir: Path) -> Any:
    script_dir_text = str(script_dir)
    if script_dir_text not in sys.path:
        sys.path.insert(0, script_dir_text)

    import lint_skill_contracts

    return lint_skill_contracts


def load_registry(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"{path}: registry must be JSON-compatible YAML for stdlib parsing: {exc}"
        ) from exc


def report_failures(header: str, failures: list[str]) -> None:
    print(header)
    for failure in failures:
        print(f"::error::{failure}")


def main() -> int:
    args = parse_cli()
    root = args.repo_root.resolve()
    registry_path = args.registry.resolve()
    registry = load_registry(registry_path)
    lint_module = load_lint_module(Path(__file__).resolve().parent)

    rendered, failures = lint_module.render_readme_component_sync(root, registry)
    if failures:
        report_failures("component reference sync failed:", failures)
        return 1
    if rendered is None:
        report_failures(
            "component reference sync failed:",
            ["component reference sync did not produce rendered content"],
        )
        return 1

    path_failures: list[str] = []
    readme_relative = lint_module.readme_relative_for_component_sync(registry, path_failures)
    if readme_relative is None:
        report_failures(
            "component reference sync failed:",
            path_failures or ["component reference sync did not resolve a README path"],
        )
        return 1
    readme_path = (root / readme_relative).resolve()
    current = readme_path.read_text(encoding="utf-8")

    if args.write:
        if current != rendered:
            readme_path.write_text(rendered, encoding="utf-8")
            print(f"updated {readme_relative} component reference rows.")
        else:
            print("component reference docs are in sync.")
        return 0

    if current != rendered:
        print("component reference sync check failed:")
        print("run scripts/generate-component-reference.py --write to sync README rows")
        return 1

    print("component reference docs are in sync.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
