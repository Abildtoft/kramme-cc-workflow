from __future__ import annotations

from ..frontmatter import parse_frontmatter
from ..io import read_text, rel, skill_paths
from ..schema import skill_frontmatter_required_fields
from .types import CheckResult, LintContext


def check_mechanical(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("mechanical", {})
    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    max_lines = int(config.get("max_skill_lines", 500))
    warn_lines = int(config.get("warn_skill_lines", 0) or 0)
    report_limit = int(config.get("skill_line_report_limit", 20))
    max_description = int(config.get("max_description_chars", 1024))
    if "contract_schema" in context.registry and "required_frontmatter" in config:
        result.failures.append(
            "mechanical: required_frontmatter must come from contract_schema, "
            "not synced-contracts.yaml"
        )
    required_fields = config.get("required_frontmatter")
    if required_fields is None:
        required_fields = skill_frontmatter_required_fields(context.schema)
    line_allowlist = set(config.get("allow_line_count_over", []))
    long_skill_entries: list[tuple[int, str]] = []

    for path in skill_paths(context.root, pattern):
        relative = rel(path, context.root)
        text = read_text(path)
        line_count = len(text.splitlines())
        if warn_lines > 0 and line_count >= warn_lines:
            long_skill_entries.append((line_count, relative))
        if line_count > max_lines and relative not in line_allowlist:
            result.failures.append(
                f"mechanical: {relative} has {line_count} lines, exceeds {max_lines}; "
                "move reference material out of SKILL.md or add a registry burndown entry"
            )

        frontmatter = parse_frontmatter(text)
        if frontmatter is None:
            result.failures.append(f"mechanical: {relative} is missing YAML frontmatter")
            continue
        for field in required_fields:
            if field not in frontmatter:
                result.failures.append(
                    f"mechanical: {relative} is missing frontmatter field {field!r}"
                )
        description = frontmatter.get("description")
        if description is not None and len(description) > max_description:
            result.failures.append(
                f"mechanical: {relative} description is {len(description)} chars, "
                f"exceeds {max_description}"
            )

    if warn_lines <= 0:
        return result

    sorted_long_skills = sorted(long_skill_entries, key=lambda item: (-item[0], item[1]))
    for line_count, relative in sorted_long_skills[:report_limit]:
        if line_count > max_lines:
            status = "over hard budget"
        elif line_count == max_lines:
            status = "at hard budget"
        else:
            status = f"{max_lines - line_count} lines below hard budget"
        result.warnings.append(
            f"mechanical: long-skill burndown: {relative} has {line_count} lines "
            f"({status}; warn at {warn_lines}, fail above {max_lines})"
        )
    return result
