from __future__ import annotations

import re

from ..io import read_text, rel, skill_paths
from .types import CheckResult, LintContext

DEFAULT_FORBIDDEN_HEADING_REGEXES = (
    r"^#{2,3}\s+Common Rationalizations\b",
    r"^#{2,3}\s+Red Flags\b",
)
DEFAULT_DECISION = "docs/decisions/2026-09-07-skill-epilogue-verification-only.md"


def check_epilogue_forbidden(context: LintContext) -> CheckResult:
    """Fail when a skill body carries a retired epilogue section.

    Skills fold gates into the step where they apply and keep at most a
    trimmed ``## Verification`` section; ``Common Rationalizations`` and
    ``Red Flags`` headings are forbidden in shipped ``SKILL.md`` files.
    """
    result = CheckResult()
    config = context.registry.get("epilogue_forbidden")
    if not config:
        return result

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    forbidden = [
        re.compile(regex, re.IGNORECASE)
        for regex in config.get("forbidden_heading_regexes", DEFAULT_FORBIDDEN_HEADING_REGEXES)
    ]
    allowlist = set(config.get("allowlist", []))
    decision = config.get("decision", DEFAULT_DECISION)

    for path in skill_paths(context.root, pattern):
        relative = rel(path, context.root)
        if relative in allowlist:
            continue
        for index, line in enumerate(read_text(path).splitlines(), start=1):
            if any(regex.search(line) for regex in forbidden):
                result.failures.append(
                    f"epilogue forbidden: {relative}:{index} has section heading `{line.strip()}`; "
                    "fold its rules into the step where they apply and keep only a trimmed "
                    f"Verification section (see {decision})"
                )
    return result
