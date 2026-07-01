#!/usr/bin/env python3
"""Compatibility CLI for the modular skill contract linter."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType


def _load_impl() -> ModuleType:
    package_name = "_lint_skill_contracts_impl"
    existing = sys.modules.get(package_name)
    if existing is not None:
        return existing

    package_dir = Path(__file__).resolve().parent / "lint_skill_contracts"
    spec = importlib.util.spec_from_file_location(
        package_name,
        package_dir / "__init__.py",
        submodule_search_locations=[str(package_dir)],
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load skill contract linter package from {package_dir}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[package_name] = module
    spec.loader.exec_module(module)
    return module


_IMPL = _load_impl()
__all__ = list(getattr(_IMPL, "__all__", []))
globals().update({name: getattr(_IMPL, name) for name in __all__})
main = getattr(_IMPL, "main")


if __name__ == "__main__":
    raise SystemExit(main())
