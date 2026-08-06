#!/usr/bin/env python3
"""Synchronize generated component reference output from component sources.

By default this command checks whether the README component rows and the
compact component catalog match the source metadata in each `SKILL.md`, agent
file, and hook manifest entry. Pass --write to update both in place.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

from json_object import load_json_object


def parse_cli() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Check or sync generated component reference output")
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
        help="Check generated output without writing. This is the default.",
    )
    mode.add_argument(
        "--write",
        action="store_true",
        help="Write generated README rows and the component catalog.",
    )
    return parser.parse_args()


def load_lint_module(script_dir: Path) -> Any:
    script_dir_text = str(script_dir)
    if script_dir_text not in sys.path:
        sys.path.insert(0, script_dir_text)

    import lint_skill_contracts

    return lint_skill_contracts


def load_registry(path: Path) -> dict[str, Any]:
    return load_json_object(path, "registry")


def report_failures(header: str, failures: list[str]) -> None:
    print(header)
    for failure in failures:
        print(f"::error::{failure}")


def read_if_present(path: Path) -> str | None:
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8")


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

    catalog_relative, catalog_rendered, catalog_failures = lint_module.render_component_catalog(root, registry)
    if catalog_failures:
        report_failures("component reference sync failed:", catalog_failures)
        return 1

    catalog_path = None
    catalog_current = None
    if catalog_rendered is not None:
        catalog_path = (root / catalog_relative).resolve()
        catalog_current = read_if_present(catalog_path)

    if args.write:
        updated: list[str] = []
        if current != rendered:
            readme_path.write_text(rendered, encoding="utf-8")
            updated.append(f"{readme_relative} component reference rows")
        if catalog_path is not None and catalog_current != catalog_rendered:
            catalog_path.parent.mkdir(parents=True, exist_ok=True)
            catalog_path.write_text(catalog_rendered, encoding="utf-8")
            updated.append(f"{catalog_relative} component catalog")
        if not updated:
            print("component reference docs are in sync.")
        for target in updated:
            print(f"updated {target}.")
        return 0

    stale: list[str] = []
    if current != rendered:
        stale.append(readme_relative)
    if catalog_path is not None and catalog_current != catalog_rendered:
        stale.append(catalog_relative)
    if stale:
        print("component reference sync check failed:")
        for target in stale:
            print(f"run python3 kramme-cc-workflow/scripts/generate-component-reference.py --write to sync {target}")
        return 1

    print("component reference docs are in sync.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
