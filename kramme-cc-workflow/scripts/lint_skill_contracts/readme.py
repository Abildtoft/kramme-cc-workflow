from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .frontmatter import (
    expected_arguments,
    expected_invocation,
    parse_frontmatter,
    parse_frontmatter_bool,
)
from .io import read_text, rel, resolve
from .markdown import (
    escape_markdown_table_cell,
    normalize_markdown_cell,
    split_markdown_table_row,
)
from .schema import load_contract_schema, skill_frontmatter_field_by_loader_property
from .strings import is_empty_value, shorten


@dataclass(frozen=True)
class SkillReference:
    name: str
    display_name: str
    invocation: str
    arguments: str
    description: str


@dataclass(frozen=True)
class AgentReference:
    name: str
    description: str


@dataclass(frozen=True)
class HookReference:
    name: str
    event: str
    description: str


def skill_reference_from_frontmatter(
    name: str,
    frontmatter: dict[str, str],
    schema: dict[str, Any] | None = None,
) -> SkillReference:
    user_invocable_field = skill_frontmatter_field_by_loader_property(
        "userInvocable",
        "user-invocable",
        schema,
    )
    display_name = (
        f"/{name}" if parse_frontmatter_bool(frontmatter, user_invocable_field) else name
    )
    return SkillReference(
        name=name,
        display_name=display_name,
        invocation=expected_invocation(frontmatter, schema),
        arguments=expected_arguments(frontmatter, schema),
        description=frontmatter.get("description", ""),
    )


def render_skill_reference_row(reference: SkillReference) -> str:
    arguments = (
        "—"
        if reference.arguments == "—"
        else f"`{escape_markdown_table_cell(reference.arguments)}`"
    )
    return (
        f"| `{escape_markdown_table_cell(reference.display_name)}` | "
        f"{reference.invocation} | "
        f"{arguments} | "
        f"{escape_markdown_table_cell(reference.description)} |"
    )


def generated_readme_block_bounds(
    readme: str,
    config: dict[str, Any],
    failures: list[str],
    label: str = "readme skill sync",
) -> tuple[int, int] | None:
    lines = readme.splitlines()
    start_marker = config.get("start_marker")
    end_marker = config.get("end_marker")
    if start_marker or end_marker:
        if not isinstance(start_marker, str) or not isinstance(end_marker, str):
            failures.append(f"{label}: start_marker and end_marker must both be strings")
            return None
        try:
            start = next(index for index, line in enumerate(lines) if line.strip() == start_marker)
        except StopIteration:
            failures.append(f"{label}: missing start marker {start_marker!r}")
            return None
        try:
            end = next(
                index
                for index, line in enumerate(lines[start + 1 :], start=start + 1)
                if line.strip() == end_marker
            )
        except StopIteration:
            failures.append(f"{label}: missing end marker {end_marker!r}")
            return None
        if end <= start:
            failures.append(f"{label}: generated block end marker precedes start marker")
            return None
        return start + 1, end

    start_heading = config.get("section_start_heading", "## Skills")
    end_heading = config.get("section_end_heading", "## Agents")
    in_section = False
    start = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == start_heading:
            in_section = True
            start = index + 1
            continue
        if in_section and stripped == end_heading:
            return start, index

    failures.append(
        f"{label}: could not find section from {start_heading!r} to {end_heading!r}"
    )
    return None


def name_from_readme_cell(cell: str, pattern: str) -> str | None:
    match = re.search(pattern, cell)
    if match:
        return match.group("name")
    return None


def skill_name_from_readme_cell(cell: str) -> str | None:
    return name_from_readme_cell(cell, r"`/?(?P<name>kramme:[A-Za-z0-9:_-]+)`")


def agent_name_from_readme_cell(cell: str) -> str | None:
    return name_from_readme_cell(cell, r"`(?P<name>kramme:[A-Za-z0-9:_-]+)`")


def hook_name_from_readme_cell(cell: str) -> str | None:
    return name_from_readme_cell(cell, r"`(?P<name>[A-Za-z0-9_-]+)`")


def readme_component_rows(
    readme: str,
    config: dict[str, Any],
    failures: list[str],
    label: str,
    name_from_cell,
) -> dict[str, tuple[int, list[str]]]:
    bounds = generated_readme_block_bounds(readme, config, failures, label)
    if bounds is None:
        return {}

    start, end = bounds
    rows: dict[str, tuple[int, list[str]]] = {}
    for index, line in enumerate(readme.splitlines()[start:end], start=start + 1):
        cells = split_markdown_table_row(line)
        if not cells:
            continue
        name = name_from_cell(cells[0])
        if name is None:
            continue
        if name in rows:
            previous_line = rows[name][0]
            failures.append(
                f"{label}: README entry {name!r} is documented more than once "
                f"(lines {previous_line} and {index})"
            )
            continue
        rows[name] = (index, cells)
    return rows


def readme_skill_rows(
    readme: str,
    config: dict[str, Any],
    failures: list[str],
) -> dict[str, tuple[int, list[str]]]:
    return readme_component_rows(
        readme,
        config,
        failures,
        "readme skill sync",
        skill_name_from_readme_cell,
    )


def load_skill_references(
    root: Path,
    skills_relative: str,
    failures: list[str],
    schema: dict[str, Any] | None = None,
) -> dict[str, SkillReference]:
    skills_dir = resolve(root, skills_relative)
    if not skills_dir.exists():
        failures.append(f"readme skill sync: registered path is missing: {skills_relative}")
        return {}

    references: dict[str, SkillReference] = {}
    for path in sorted(skills_dir.iterdir()):
        skill_path = path / "SKILL.md"
        if not path.is_dir() or not skill_path.is_file():
            continue
        text = read_text(skill_path)
        frontmatter = parse_frontmatter(text)
        relative = rel(skill_path, root)
        if frontmatter is None:
            failures.append(f"readme skill sync: {relative} is missing YAML frontmatter")
            continue
        name = path.name
        frontmatter_name = frontmatter.get("name")
        if frontmatter_name and frontmatter_name != name:
            failures.append(
                f"readme skill sync: {relative} frontmatter name {frontmatter_name!r} "
                f"does not match skill directory {name!r}"
            )
            continue
        references[name] = skill_reference_from_frontmatter(name, frontmatter, schema)
    return references


def load_agent_references(
    root: Path,
    agents_relative: str,
    failures: list[str],
) -> dict[str, AgentReference]:
    agents_dir = resolve(root, agents_relative)
    if not agents_dir.exists():
        failures.append(f"readme agent sync: registered path is missing: {agents_relative}")
        return {}

    references: dict[str, AgentReference] = {}
    for path in sorted(agents_dir.glob("*.md")):
        text = read_text(path)
        frontmatter = parse_frontmatter(text)
        relative = rel(path, root)
        if frontmatter is None:
            failures.append(f"readme agent sync: {relative} is missing YAML frontmatter")
            continue
        name = path.stem
        frontmatter_name = frontmatter.get("name")
        if frontmatter_name and frontmatter_name != name:
            failures.append(
                f"readme agent sync: {relative} frontmatter name {frontmatter_name!r} "
                f"does not match agent file {name!r}"
            )
            continue
        description = frontmatter.get("description", "")
        if is_empty_value(description):
            failures.append(f"readme agent sync: {relative} is missing frontmatter description")
            continue
        references[name] = AgentReference(name=name, description=description)
    return references


def hook_name_from_command(command: str, command_path_regex: str) -> str | None:
    matches = re.findall(command_path_regex, command)
    if not matches:
        return None
    command_path = Path(matches[0])
    return command_path.name.removesuffix(".sh")


def hook_event_label(event: str, matcher: Any) -> str:
    if isinstance(matcher, str) and not is_empty_value(matcher):
        return f"{event} ({matcher})"
    return event


def load_hook_references(
    root: Path,
    config: dict[str, Any],
    failures: list[str],
) -> dict[str, HookReference]:
    hooks_relative = config.get("hooks_json", "kramme-cc-workflow/hooks/hooks.json")
    hooks_path = resolve(root, hooks_relative)
    if not hooks_path.exists():
        failures.append(f"readme hook sync: registered path is missing: {hooks_relative}")
        return {}

    try:
        data = json.loads(read_text(hooks_path))
    except json.JSONDecodeError as exc:
        failures.append(
            f"readme hook sync: {hooks_relative} is invalid JSON at line {exc.lineno}, "
            f"column {exc.colno}: {exc.msg}"
        )
        return {}

    hooks = data.get("hooks") if isinstance(data, dict) else None
    if not isinstance(hooks, dict):
        failures.append(f"readme hook sync: {hooks_relative} must contain an object field 'hooks'")
        return {}

    command_path_regex = config.get(
        "command_path_regex",
        r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)",
    )
    descriptions = config.get("descriptions", {})
    if not isinstance(descriptions, dict):
        failures.append("readme hook sync: descriptions must be an object keyed by hook name")
        descriptions = {}

    order: list[str] = []
    events_by_name: dict[str, list[str]] = {}

    for event, entries in hooks.items():
        if not isinstance(entries, list):
            continue
        for entry_index, entry in enumerate(entries, start=1):
            if not isinstance(entry, dict):
                continue
            event_label = hook_event_label(event, entry.get("matcher"))
            hook_entries = entry.get("hooks")
            if not isinstance(hook_entries, list):
                continue
            for hook_index, hook_entry in enumerate(hook_entries, start=1):
                if not isinstance(hook_entry, dict):
                    continue
                command = hook_entry.get("command")
                if not isinstance(command, str):
                    continue
                name = hook_name_from_command(command, command_path_regex)
                if name is None:
                    failures.append(
                        f"readme hook sync: {hooks_relative} {event}[{entry_index}]."
                        f"hooks[{hook_index}] command does not reference a plugin hook script"
                    )
                    continue
                if name not in events_by_name:
                    events_by_name[name] = []
                    order.append(name)
                if event_label not in events_by_name[name]:
                    events_by_name[name].append(event_label)

    references: dict[str, HookReference] = {}
    for name in order:
        description = descriptions.get(name)
        if not isinstance(description, str) or is_empty_value(description):
            failures.append(f"readme hook sync: descriptions is missing hook {name!r}")
            continue
        references[name] = HookReference(
            name=name,
            event=", ".join(events_by_name[name]),
            description=description,
        )
    return references


def check_readme_extra_skill_rows(
    readme_relative: str,
    skills_relative: str,
    documented_skills: dict[str, tuple[int, list[str]]],
    references: dict[str, SkillReference],
    allow_readme_only: set[str],
    failures: list[str],
) -> None:
    for name, (line_no, _cells) in documented_skills.items():
        if name in allow_readme_only and name not in references:
            continue
        if name not in references:
            failures.append(
                f"readme skill sync: {readme_relative}:{line_no} documents {name!r}, "
                f"but {skills_relative}/{name}/SKILL.md does not exist"
            )


def check_readme_extra_component_rows(
    label: str,
    readme_relative: str,
    source_relative: str,
    component_type: str,
    documented_rows: dict[str, tuple[int, list[str]]],
    references: dict[str, Any],
    failures: list[str],
) -> None:
    for name, (line_no, _cells) in documented_rows.items():
        if name not in references:
            failures.append(
                f"{label}: {readme_relative}:{line_no} documents {name!r}, "
                f"but {component_type} source is missing from {source_relative}"
            )


def check_simple_readme_component_sync(
    label: str,
    readme_relative: str,
    source_relative: str,
    component_type: str,
    documented_rows: dict[str, tuple[int, list[str]]],
    references: dict[str, Any],
    required_columns: dict[str, int],
    expected_values_for_reference,
    failures: list[str],
) -> None:
    for name in sorted(references):
        if name not in documented_rows:
            failures.append(
                f"{label}: {readme_relative} is missing {component_type} {name!r} "
                f"from {source_relative}"
            )

    check_readme_extra_component_rows(
        label,
        readme_relative,
        source_relative,
        component_type,
        documented_rows,
        references,
        failures,
    )

    max_column = max(required_columns.values())
    for name, (line_no, cells) in documented_rows.items():
        reference = references.get(name)
        if reference is None:
            continue
        if len(cells) <= max_column:
            columns = ", ".join(field.title() for field in required_columns)
            failures.append(
                f"{label}: {readme_relative}:{line_no} row for {name!r} must "
                f"include {columns} columns"
            )
            continue

        expected_values = expected_values_for_reference(reference)
        for field, column in required_columns.items():
            actual = normalize_markdown_cell(cells[column])
            expected = normalize_markdown_cell(expected_values[field])
            if actual != expected:
                failures.append(
                    f"{label}: {readme_relative}:{line_no} {name!r} "
                    f"{field} differs from source metadata; expected "
                    f"{shorten(expected)!r}, got {shorten(actual)!r}"
                )


def check_readme_skill_rows_sync(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any],
    failures: list[str],
) -> None:
    config = registry.get("readme_skill_sync")
    if not config:
        return

    readme_relative = config.get("readme", "README.md")
    skills_relative = config.get("skills_dir", "kramme-cc-workflow/skills")
    readme_path = resolve(root, readme_relative)

    if not readme_path.exists():
        failures.append(f"readme skill sync: registered path is missing: {readme_relative}")
        return

    readme = read_text(readme_path)
    references = load_skill_references(root, skills_relative, failures, schema)
    documented_skills = readme_skill_rows(readme, config, failures)

    for name in sorted(references):
        if name not in documented_skills:
            failures.append(
                f"readme skill sync: {readme_relative} is missing skill {name!r} "
                f"from {skills_relative}"
            )

    allow_readme_only = set(config.get("allow_readme_only_skills", []))
    check_readme_extra_skill_rows(
        readme_relative,
        skills_relative,
        documented_skills,
        references,
        allow_readme_only,
        failures,
    )
    required_columns = {
        "skill": int(config.get("skill_column", 0)),
        "invocation": int(config.get("invocation_column", 1)),
        "arguments": int(config.get("arguments_column", 2)),
        "description": int(config.get("description_column", 3)),
    }
    max_column = max(required_columns.values())

    for name, (line_no, cells) in documented_skills.items():
        if name in allow_readme_only and name not in references:
            continue
        reference = references.get(name)
        if reference is None:
            continue
        if len(cells) <= max_column:
            failures.append(
                f"readme skill sync: {readme_relative}:{line_no} row for {name!r} must "
                "include Skill, Invocation, Arguments, and Description columns"
            )
            continue

        expected_values = {
            "skill": reference.display_name,
            "invocation": reference.invocation,
            "arguments": reference.arguments,
            "description": reference.description,
        }
        for field, column in required_columns.items():
            actual = normalize_markdown_cell(cells[column])
            expected = normalize_markdown_cell(expected_values[field])
            if actual != expected:
                failures.append(
                    f"readme skill sync: {readme_relative}:{line_no} {name!r} "
                    f"{field} differs from SKILL.md frontmatter; expected "
                    f"{shorten(expected)!r}, got {shorten(actual)!r}"
                )


def check_readme_agent_sync(
    root: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> None:
    config = registry.get("readme_agent_sync")
    if not config:
        return

    readme_relative = config.get("readme", "README.md")
    agents_relative = config.get("agents_dir", "kramme-cc-workflow/agents")
    readme_path = resolve(root, readme_relative)

    if not readme_path.exists():
        failures.append(f"readme agent sync: registered path is missing: {readme_relative}")
        return

    readme = read_text(readme_path)
    references = load_agent_references(root, agents_relative, failures)
    documented_agents = readme_component_rows(
        readme,
        config,
        failures,
        "readme agent sync",
        agent_name_from_readme_cell,
    )
    check_simple_readme_component_sync(
        "readme agent sync",
        readme_relative,
        agents_relative,
        "agent",
        documented_agents,
        references,
        {
            "agent": int(config.get("agent_column", 0)),
            "description": int(config.get("description_column", 1)),
        },
        lambda reference: {
            "agent": reference.name,
            "description": reference.description,
        },
        failures,
    )


def check_readme_hook_sync(
    root: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> None:
    config = registry.get("readme_hook_sync")
    if not config:
        return

    readme_relative = config.get("readme", "README.md")
    hooks_relative = config.get("hooks_json", "kramme-cc-workflow/hooks/hooks.json")
    readme_path = resolve(root, readme_relative)

    if not readme_path.exists():
        failures.append(f"readme hook sync: registered path is missing: {readme_relative}")
        return

    readme = read_text(readme_path)
    references = load_hook_references(root, config, failures)
    documented_hooks = readme_component_rows(
        readme,
        config,
        failures,
        "readme hook sync",
        hook_name_from_readme_cell,
    )
    check_simple_readme_component_sync(
        "readme hook sync",
        readme_relative,
        hooks_relative,
        "hook",
        documented_hooks,
        references,
        {
            "hook": int(config.get("hook_column", 0)),
            "event": int(config.get("event_column", 1)),
            "description": int(config.get("description_column", 2)),
        },
        lambda reference: {
            "hook": reference.name,
            "event": reference.event,
            "description": reference.description,
        },
        failures,
    )


def check_readme_skill_sync(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any],
    failures: list[str],
) -> None:
    check_readme_skill_rows_sync(root, registry, schema, failures)
    check_readme_agent_sync(root, registry, failures)
    check_readme_hook_sync(root, registry, failures)


def render_agent_reference_row(reference: AgentReference) -> str:
    return (
        f"| `{escape_markdown_table_cell(reference.name)}` | "
        f"{escape_markdown_table_cell(reference.description)} |"
    )


def render_hook_reference_row(reference: HookReference) -> str:
    return (
        f"| `{escape_markdown_table_cell(reference.name)}` | "
        f"{escape_markdown_table_cell(reference.event)} | "
        f"{escape_markdown_table_cell(reference.description)} |"
    )


def replace_generated_readme_block(
    readme: str,
    config: dict[str, Any],
    failures: list[str],
    label: str,
    lines: list[str],
) -> str | None:
    bounds = generated_readme_block_bounds(readme, config, failures, label)
    if bounds is None:
        return None
    start, end = bounds
    readme_lines = readme.splitlines()
    readme_lines[start:end] = lines
    rendered = "\n".join(readme_lines)
    if readme.endswith("\n"):
        rendered += "\n"
    return rendered


def render_readme_skill_rows_sync(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any],
    readme: str,
    failures: list[str],
) -> str | None:
    config = registry.get("readme_skill_sync")
    if not config:
        return readme

    readme_relative = config.get("readme", "README.md")
    skills_relative = config.get("skills_dir", "kramme-cc-workflow/skills")
    references = load_skill_references(root, skills_relative, failures, schema)
    documented_skills = readme_skill_rows(readme, config, failures)
    allow_readme_only = set(config.get("allow_readme_only_skills", []))
    for name in sorted(references):
        if name not in documented_skills:
            failures.append(
                f"readme skill sync: {readme_relative} is missing skill {name!r} "
                f"from {skills_relative}"
            )
    check_readme_extra_skill_rows(
        readme_relative,
        skills_relative,
        documented_skills,
        references,
        allow_readme_only,
        failures,
    )
    if failures:
        return None

    lines = readme.splitlines()
    trailing_newline = readme.endswith("\n")
    for name, (line_no, _cells) in documented_skills.items():
        reference = references.get(name)
        if reference is None:
            continue
        lines[line_no - 1] = render_skill_reference_row(reference)

    rendered = "\n".join(lines)
    if trailing_newline:
        rendered += "\n"
    return rendered


def render_readme_agent_sync(
    root: Path,
    registry: dict[str, Any],
    readme: str,
    failures: list[str],
) -> str | None:
    config = registry.get("readme_agent_sync")
    if not config:
        return readme

    agents_relative = config.get("agents_dir", "kramme-cc-workflow/agents")
    references = load_agent_references(root, agents_relative, failures)
    if failures:
        return None
    rows = [render_agent_reference_row(reference) for reference in references.values()]
    block_lines = ["| Agent | Description |", "| --- | --- |", *rows]
    return replace_generated_readme_block(
        readme,
        config,
        failures,
        "readme agent sync",
        block_lines,
    )


def render_readme_hook_sync(
    root: Path,
    registry: dict[str, Any],
    readme: str,
    failures: list[str],
) -> str | None:
    config = registry.get("readme_hook_sync")
    if not config:
        return readme

    references = load_hook_references(root, config, failures)
    if failures:
        return None
    rows = [render_hook_reference_row(reference) for reference in references.values()]
    block_lines = ["| Hook | Event | Description |", "| --- | --- | --- |", *rows]
    return replace_generated_readme_block(
        readme,
        config,
        failures,
        "readme hook sync",
        block_lines,
    )


def readme_relative_for_component_sync(
    registry: dict[str, Any],
    failures: list[str],
) -> str | None:
    configs = [
        registry.get("readme_skill_sync"),
        registry.get("readme_agent_sync"),
        registry.get("readme_hook_sync"),
    ]
    readme_values = {
        config.get("readme", "README.md")
        for config in configs
        if isinstance(config, dict)
    }
    if not readme_values:
        failures.append("component reference sync: registry has no README sync config")
        return None
    if len(readme_values) > 1:
        failures.append(
            "component reference sync: README sync configs must target the same README file"
        )
        return None
    return next(iter(readme_values))


def render_readme_component_sync(
    root: Path,
    registry: dict[str, Any],
) -> tuple[str | None, list[str]]:
    failures: list[str] = []
    schema = load_contract_schema(root, registry, failures)
    readme_relative = readme_relative_for_component_sync(registry, failures)
    if readme_relative is None:
        return None, failures

    readme_path = resolve(root, readme_relative)
    if not readme_path.exists():
        return None, [
            f"component reference sync: registered path is missing: {readme_relative}"
        ]

    rendered: str | None = read_text(readme_path)
    rendered = render_readme_skill_rows_sync(root, registry, schema, rendered, failures)
    if rendered is not None:
        rendered = render_readme_agent_sync(root, registry, rendered, failures)
    if rendered is not None:
        rendered = render_readme_hook_sync(root, registry, rendered, failures)
    if failures:
        return None, failures
    return rendered, []


def render_readme_skill_sync(
    root: Path, registry: dict[str, Any]
) -> tuple[str | None, list[str]]:
    return render_readme_component_sync(root, registry)
