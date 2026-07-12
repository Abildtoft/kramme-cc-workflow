from __future__ import annotations

from ..frontmatter import frontmatter_type_errors, parse_frontmatter
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
        for field, expected_type in frontmatter_type_errors(text, context.schema):
            result.failures.append(
                f"mechanical: {relative} frontmatter field {field!r} "
                f"must be {expected_type}"
            )
        description = frontmatter.get("description")
        if description is not None and len(description) > max_description:
            result.failures.append(
                f"mechanical: {relative} description is {len(description)} chars, "
                f"exceeds {max_description}"
            )

    agent_result = check_agent_frontmatter_names(context)
    result.failures.extend(agent_result.failures)

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


def check_agent_frontmatter_names(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("mechanical", {})
    pattern = config.get("agent_glob", "kramme-cc-workflow/agents/*.md")

    for path in skill_paths(context.root, pattern):
        relative = rel(path, context.root)
        frontmatter = parse_frontmatter(read_text(path))
        if frontmatter is None:
            result.failures.append(f"mechanical: {relative} is missing YAML frontmatter")
            continue

        expected_name = path.stem
        actual_name = frontmatter.get("name")
        if actual_name is None:
            result.failures.append(f"mechanical: {relative} is missing frontmatter field 'name'")
            continue
        if actual_name != expected_name:
            result.failures.append(
                f"mechanical: {relative} frontmatter name {actual_name!r} "
                f"does not match agent filename {expected_name!r}"
            )
    return result
