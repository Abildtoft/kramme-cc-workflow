from __future__ import annotations

import re

from ..io import read_text, rel, skill_paths
from .types import CheckResult, LintContext


def canonical_epilogue_heading(line: str) -> str | None:
    match = re.match(r"^#{2,3}\s+(.+?)\s*$", line)
    if not match:
        return None
    title = match.group(1).strip()
    if title == "Common Rationalizations":
        return title
    if title.startswith("Red Flags"):
        return "Red Flags"
    if title == "Verification":
        return title
    return None


def check_epilogue_order(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("epilogue_order")
    if not config:
        return result

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    trigger = re.compile(
        config.get("trigger_heading_regex", r"^#{2,3}\s+Common Rationalizations\b"),
        re.MULTILINE,
    )
    required = config.get("required_headings", ["Common Rationalizations", "Red Flags", "Verification"])
    allowlist = set(config.get("allowlist", []))

    for path in skill_paths(context.root, pattern):
        relative = rel(path, context.root)
        if relative in allowlist:
            continue
        text = read_text(path)
        if not trigger.search(text):
            continue
        positions: dict[str, int] = {}
        for index, line in enumerate(text.splitlines(), start=1):
            canonical = canonical_epilogue_heading(line)
            if canonical and canonical not in positions:
                positions[canonical] = index

        missing = [heading for heading in required if heading not in positions]
        if missing:
            result.failures.append(
                f"epilogue order: {relative} is missing canonical section(s): {', '.join(missing)}"
            )
            continue
        order = [positions[heading] for heading in required]
        if order != sorted(order):
            result.failures.append(
                f"epilogue order: {relative} must order sections as "
                + " -> ".join(required)
                + f"; found line order {order}"
            )
    return result
