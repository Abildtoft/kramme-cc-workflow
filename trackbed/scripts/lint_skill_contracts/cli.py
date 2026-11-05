from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from json_object import load_json_object

from .checks import run


def add_arguments(parser: argparse.ArgumentParser, defaults: argparse.Namespace) -> argparse.ArgumentParser:
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=defaults.repo_root,
        help="Repository root. Defaults to two directories above this script.",
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=defaults.registry,
        help="Path to synced-contracts.yaml.",
    )
    return parser


def parse_cli() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent.parent
    defaults = argparse.Namespace(
        repo_root=script_dir.parent.parent,
        registry=script_dir / "synced-contracts.yaml",
    )
    parser = argparse.ArgumentParser(description="Lint copied skill contracts")
    return add_arguments(parser, defaults).parse_args()


def load_registry(path: Path) -> dict[str, Any]:
    return load_json_object(path, "registry")


def main() -> int:
    args = parse_cli()
    root = args.repo_root.resolve()
    registry = load_registry(args.registry.resolve())
    failures, warnings = run(root, registry)
    if warnings:
        print("skill contract lint warnings:")
        for warning in warnings:
            print(f"::warning::{warning}")
    if failures:
        print("skill contract lint failed:")
        for failure in failures:
            print(f"::error::{failure}")
        return 1
    print("skill contract lint passed.")
    return 0
