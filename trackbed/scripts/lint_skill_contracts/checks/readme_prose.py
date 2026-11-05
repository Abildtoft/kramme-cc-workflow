from __future__ import annotations

import re
from typing import Any

from ..io import read_text, resolve
from ..markdown import normalize_markdown_cell
from .types import CheckResult, LintContext

LABEL = "readme prose"
FENCE_PATTERN = re.compile(r"^\s*(```|~~~)")
LIST_ITEM_PATTERN = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
BLOCKQUOTE_PATTERN = re.compile(r"^\s*>\s?")


def readme_prose_blocks(text: str) -> list[tuple[int, str]]:
    """Return ``(line number, text)`` for each README paragraph and list item.

    Headings, tables, fenced code, HTML blocks, and HTML comments are not prose.
    Generated component tables are therefore never measured.
    """
    blocks: list[tuple[int, str]] = []
    current: list[str] = []
    start_line = 0
    in_fence = False
    in_comment = False

    def flush() -> None:
        if current:
            blocks.append((start_line, " ".join(part.strip() for part in current)))
            current.clear()

    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if in_fence:
            in_fence = not FENCE_PATTERN.match(line)
            continue
        if in_comment:
            in_comment = "-->" not in stripped
            continue
        if FENCE_PATTERN.match(line):
            flush()
            in_fence = True
            continue
        if stripped.startswith("<!--"):
            flush()
            in_comment = "-->" not in stripped
            continue
        if not stripped or stripped.startswith(("#", "|", "<")):
            flush()
            continue
        line = BLOCKQUOTE_PATTERN.sub("", line, count=1)
        if LIST_ITEM_PATTERN.match(line):
            flush()
            line = LIST_ITEM_PATTERN.sub("", line, count=1)
        if not current:
            start_line = number
        current.append(line)
    flush()
    return blocks


def positive_int(value: Any) -> int | None:
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    return None


def check_readme_prose(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("readme_prose")
    if config is None:
        return result
    if not isinstance(config, dict):
        result.failures.append(f"{LABEL}: readme_prose must be an object")
        return result

    readme_relative = config.get("readme", "README.md")
    warn_chars = positive_int(config.get("warn_paragraph_chars"))
    report_limit = positive_int(config.get("report_limit", 20))
    if not isinstance(readme_relative, str) or not readme_relative:
        result.failures.append(f"{LABEL}: readme must be a non-empty path")
        return result
    if warn_chars is None:
        result.failures.append(f"{LABEL}: warn_paragraph_chars must be a positive integer")
        return result
    if report_limit is None:
        result.failures.append(f"{LABEL}: report_limit must be a positive integer")
        return result

    readme_path = resolve(context.root, readme_relative)
    if not readme_path.is_file():
        result.failures.append(f"{LABEL}: registered path is missing: {readme_relative}")
        return result

    long_blocks: list[tuple[int, int]] = []
    for line, block in readme_prose_blocks(read_text(readme_path)):
        length = len(normalize_markdown_cell(block))
        if length >= warn_chars:
            long_blocks.append((length, line))
    for length, line in sorted(long_blocks, key=lambda item: (-item[0], item[1]))[:report_limit]:
        result.warnings.append(
            f"{LABEL}: long-paragraph burndown: {readme_relative}:{line} is {length} chars "
            f"(warn at {warn_chars}); split it, use a list or table, or move the detail to a linked docs page"
        )
    return result
