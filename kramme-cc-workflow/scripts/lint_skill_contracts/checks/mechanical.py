from __future__ import annotations

import json

from ..frontmatter import frontmatter_type_errors, parse_frontmatter
from ..io import read_text, rel, skill_paths
from ..schema import skill_frontmatter_required_fields
from .types import CheckResult, LintContext

SKILL_CONTRACT_KINDS = {"executable", "evaluation", "guidance", "registry"}


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
            "mechanical: required_frontmatter must come from contract_schema, not synced-contracts.yaml"
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
                result.failures.append(f"mechanical: {relative} is missing frontmatter field {field!r}")
        for field, expected_type in frontmatter_type_errors(text, context.schema):
            result.failures.append(f"mechanical: {relative} frontmatter field {field!r} must be {expected_type}")
        description = frontmatter.get("description")
        if description is not None and len(description) > max_description:
            result.failures.append(
                f"mechanical: {relative} description is {len(description)} chars, exceeds {max_description}"
            )

    agent_result = check_agent_frontmatter_names(context)
    result.failures.extend(agent_result.failures)

    size_result = check_file_line_budgets(context)
    result.failures.extend(size_result.failures)
    result.warnings.extend(size_result.warnings)

    require_skill_contract_coverage = config.get("require_skill_contract_coverage", False)
    if not isinstance(require_skill_contract_coverage, bool):
        result.failures.append("mechanical: require_skill_contract_coverage must be a boolean")
        require_skill_contract_coverage = False
    coverage_result = check_skill_contract_coverage(
        context,
        required=require_skill_contract_coverage,
    )
    result.failures.extend(coverage_result.failures)
    result.warnings.extend(coverage_result.warnings)

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


def check_skill_contract_coverage(context: LintContext, *, required: bool = False) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("skill_contract_coverage")
    if config is None:
        if required:
            result.failures.append("mechanical: skill_contract_coverage is required")
        return result
    if not isinstance(config, dict):
        result.failures.append("mechanical: skill_contract_coverage must be an object")
        return result

    inventory_relative = config.get("inventory")
    mechanical_only = config.get("mechanical_only")
    if not isinstance(inventory_relative, str) or not inventory_relative:
        result.failures.append(
            "mechanical: skill_contract_coverage.inventory must be a non-empty repository-relative path"
        )
        return result
    if not isinstance(mechanical_only, list) or not all(isinstance(path, str) and path for path in mechanical_only):
        result.failures.append("mechanical: skill_contract_coverage.mechanical_only must be an array of skill paths")
        return result

    inventory_path = (context.root / inventory_relative).resolve()
    try:
        inventory_path.relative_to(context.root)
    except ValueError:
        result.failures.append(f"mechanical: skill contract inventory escapes repository root: {inventory_relative}")
        return result

    try:
        inventory = json.loads(read_text(inventory_path))
    except (OSError, json.JSONDecodeError) as error:
        result.failures.append(f"mechanical: cannot load skill contract inventory {inventory_relative}: {error}")
        return result
    if not isinstance(inventory, dict):
        result.failures.append(f"mechanical: skill contract inventory {inventory_relative} must be a JSON object")
        return result

    contracts = inventory.get("skill_contracts")
    if not isinstance(contracts, list):
        result.failures.append(f"mechanical: {inventory_relative}.skill_contracts must be an array")
        return result

    mechanical_config = context.registry.get("mechanical", {})
    pattern = mechanical_config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    discovered = {rel(path, context.root) for path in skill_paths(context.root, pattern)}
    mapped: set[str] = set()
    relationships: set[tuple[str, str]] = set()

    for index, contract in enumerate(contracts):
        label = f"mechanical: skill contract mapping {index + 1}"
        if not isinstance(contract, dict):
            result.failures.append(f"{label} must be an object")
            continue
        suite = contract.get("suite")
        kind = contract.get("kind")
        skills = contract.get("skills")
        if not isinstance(suite, str) or not suite:
            result.failures.append(f"{label} requires a non-empty suite path")
            continue
        if not isinstance(kind, str) or kind not in SKILL_CONTRACT_KINDS:
            result.failures.append(f"{label} kind must be one of {', '.join(sorted(SKILL_CONTRACT_KINDS))}")
            continue
        if not isinstance(skills, list) or not skills or not all(isinstance(path, str) and path for path in skills):
            result.failures.append(f"{label} requires a non-empty array of skill paths")
            continue

        suite_path = (context.root / suite).resolve()
        try:
            suite_path.relative_to(context.root)
        except ValueError:
            result.failures.append(f"{label} suite escapes repository root: {suite}")
        else:
            if not suite_path.is_file():
                result.failures.append(f"{label} suite does not exist: {suite}")

        for skill in skills:
            relationship = (skill, suite)
            if relationship in relationships:
                result.failures.append(f"mechanical: duplicate skill contract mapping: {skill} -> {suite}")
            relationships.add(relationship)
            mapped.add(skill)
            if skill not in discovered:
                result.failures.append(f"{label} skill does not exist: {skill}")

    baseline = set(mechanical_only)
    if len(baseline) != len(mechanical_only):
        result.failures.append("mechanical: skill_contract_coverage.mechanical_only contains duplicate paths")
    for skill in sorted(mapped & baseline):
        result.failures.append(f"mechanical: covered skill is still listed as mechanical-only: {skill}")
    for skill in sorted(baseline - discovered):
        result.failures.append(f"mechanical: mechanical-only skill is not discovered: {skill}; remove or fix the entry")
    for skill in sorted(discovered - mapped - baseline):
        result.failures.append(
            f"mechanical: skill contract coverage is unclassified: {skill}; "
            "map a behavioral suite or add an explicit mechanical-only burndown entry"
        )
    for skill in sorted(baseline & discovered):
        result.warnings.append(
            f"mechanical: skill-contract burndown: {skill} has mechanical checks only; "
            "add a behavioral contract mapping"
        )

    return result


def check_file_line_budgets(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("mechanical", {})
    budgets = config.get("file_line_budgets", [])
    if not isinstance(budgets, list):
        result.failures.append("mechanical: file_line_budgets must be an array")
        return result

    for budget in budgets:
        if not isinstance(budget, dict):
            result.failures.append("mechanical: each file_line_budgets entry must be an object")
            continue
        name = budget.get("name")
        patterns = budget.get("globs")
        warn_lines = budget.get("warn_lines")
        baseline = budget.get("baseline", {})
        excluded = budget.get("excluded", [])
        if (
            not isinstance(name, str)
            or not name
            or not isinstance(patterns, list)
            or not patterns
            or not all(isinstance(pattern, str) and pattern for pattern in patterns)
            or not isinstance(warn_lines, int)
            or isinstance(warn_lines, bool)
            or warn_lines <= 0
            or not isinstance(baseline, dict)
            or not all(
                isinstance(path, str) and path and isinstance(lines, int) and not isinstance(lines, bool) and lines > 0
                for path, lines in baseline.items()
            )
            or not isinstance(excluded, list)
            or not all(isinstance(path, str) and path for path in excluded)
        ):
            result.failures.append(
                "mechanical: file line budget entries require a name, non-empty globs, "
                "a positive warn_lines integer, a path-to-line-count baseline, and path exclusions"
            )
            continue

        excluded_paths = set(excluded)
        discovered = {
            rel(path, context.root): path
            for pattern in patterns
            for path in skill_paths(context.root, pattern)
            if rel(path, context.root) not in excluded_paths
        }
        for relative, path in sorted(discovered.items()):
            line_count = len(read_text(path).splitlines())
            baseline_lines = baseline.get(relative)
            if line_count < warn_lines and baseline_lines is None:
                continue
            if baseline_lines is None:
                result.warnings.append(
                    f"mechanical: {name} size budget: unbaselined {relative} has "
                    f"{line_count} lines (warn at {warn_lines}); shrink it or record the reviewed baseline"
                )
                continue
            if line_count < warn_lines:
                result.warnings.append(
                    f"mechanical: {name} size baseline can be removed: {relative} has "
                    f"{line_count} lines (warn at {warn_lines})"
                )
                continue
            delta = line_count - baseline_lines
            if delta > 0:
                line_noun = "line" if delta == 1 else "lines"
                comparison = f"{delta} {line_noun} above baseline {baseline_lines}"
            elif delta < 0:
                improvement = -delta
                line_noun = "line" if improvement == 1 else "lines"
                comparison = f"{improvement} {line_noun} below baseline {baseline_lines}; lower the baseline"
            else:
                comparison = f"at baseline {baseline_lines}"
            result.warnings.append(
                f"mechanical: {name} size baseline: {relative} has {line_count} lines "
                f"({comparison}; warn at {warn_lines})"
            )

        for relative in sorted(set(baseline) - set(discovered)):
            result.warnings.append(
                f"mechanical: {name} size baseline is not discovered: {relative}; remove or fix the entry"
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
