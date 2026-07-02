from __future__ import annotations

import re
from pathlib import Path

from ..io import read_text, rel, resolve, skill_paths
from .types import CheckResult, LintContext


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _registered_paths(context: LintContext, result: CheckResult) -> list[Path]:
    config = context.registry.get("base_diff_scope", {})
    paths: dict[str, Path] = {}

    for copy in config.get("paths", []):
        path = resolve(context.root, copy)
        if not path.exists():
            result.failures.append(f"base-diff-scope: registered path is missing: {copy}")
            continue
        if not path.is_file():
            result.failures.append(f"base-diff-scope: registered path is not a file: {copy}")
            continue
        paths[rel(path, context.root)] = path

    for pattern in config.get("scan_globs", []):
        for path in skill_paths(context.root, pattern):
            paths[rel(path, context.root)] = path

    return [paths[key] for key in sorted(paths)]


def check_base_diff_scope(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("base_diff_scope")
    if not config:
        return result

    compiled_patterns: list[tuple[str, re.Pattern[str]]] = []
    for pattern in config.get("forbidden_patterns", []):
        name = pattern["name"]
        regex = pattern["regex"]
        try:
            compiled_patterns.append((name, re.compile(regex, re.MULTILINE)))
        except re.error as exc:
            result.failures.append(
                f"base-diff-scope: forbidden pattern {name!r} is invalid: {exc}"
            )

    for path in _registered_paths(context, result):
        relative = rel(path, context.root)
        text = read_text(path)
        for name, regex in compiled_patterns:
            for match in regex.finditer(text):
                line = _line_number(text, match.start())
                result.failures.append(
                    f"base-diff-scope: {relative}:{line} uses forbidden manual "
                    f"base/diff snippet {name!r}; use scripts/resolve-base.sh or "
                    "scripts/collect-review-diff.sh instead"
                )

    return result
