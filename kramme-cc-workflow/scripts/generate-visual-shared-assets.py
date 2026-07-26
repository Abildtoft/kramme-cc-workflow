#!/usr/bin/env python3
"""Compatibility entry point for visual shared-asset synchronization."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType


def load_synced_files_generator() -> ModuleType:
    script_path = Path(__file__).resolve().with_name("generate-synced-files.py")
    spec = importlib.util.spec_from_file_location("generate_synced_files", script_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load synced-file generator: {script_path}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    generator = load_synced_files_generator()
    output = generator.OutputStyle(
        description="Check or sync visual shared assets from canonical identity groups",
        success_subject="visual shared assets",
        failure_subject="visual shared asset sync",
        synced_label="visual shared asset file(s)",
        command="scripts/generate-visual-shared-assets.py",
        no_groups_message="no visual file identity groups found in registry",
    )
    return int(generator.run_cli(group_prefix="visual-", output=output))


if __name__ == "__main__":
    raise SystemExit(main())
