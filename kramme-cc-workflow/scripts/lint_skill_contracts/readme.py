from __future__ import annotations

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
from .strings import shorten


@dataclass(frozen=True)
class SkillReference:
    name: str
    display_name: str
    invocation: str
    arguments: str
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
) -> tuple[int, int] | None:
    lines = readme.splitlines()
    start_marker = config.get("start_marker")
    end_marker = config.get("end_marker")
    if start_marker or end_marker:
        if not isinstance(start_marker, str) or not isinstance(end_marker, str):
            failures.append("readme skill sync: start_marker and end_marker must both be strings")
            return None
        try:
            start = next(index for index, line in enumerate(lines) if line.strip() == start_marker)
        except StopIteration:
            failures.append(f"readme skill sync: missing start marker {start_marker!r}")
            return None
        try:
            end = next(
                index
                for index, line in enumerate(lines[start + 1 :], start=start + 1)
                if line.strip() == end_marker
            )
        except StopIteration:
            failures.append(f"readme skill sync: missing end marker {end_marker!r}")
            return None
        if end <= start:
            failures.append("readme skill sync: generated block end marker precedes start marker")
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
        f"readme skill sync: could not find section from {start_heading!r} to {end_heading!r}"
    )
    return None


def skill_name_from_readme_cell(cell: str) -> str | None:
    match = re.search(r"`/?(?P<name>kramme:[A-Za-z0-9:_-]+)`", cell)
    if match:
        return match.group("name")
    return None


def readme_skill_rows(
    readme: str,
    config: dict[str, Any],
    failures: list[str],
) -> dict[str, tuple[int, list[str]]]:
    bounds = generated_readme_block_bounds(readme, config, failures)
    if bounds is None:
        return {}

    start, end = bounds
    rows: dict[str, tuple[int, list[str]]] = {}
    for index, line in enumerate(readme.splitlines()[start:end], start=start + 1):
        cells = split_markdown_table_row(line)
        if not cells:
            continue
        name = skill_name_from_readme_cell(cells[0])
        if name is None:
            continue
        if name in rows:
            previous_line = rows[name][0]
            failures.append(
                f"readme skill sync: README skill {name!r} is documented more than once "
                f"(lines {previous_line} and {index})"
            )
            continue
        rows[name] = (index, cells)
    return rows


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


def check_readme_skill_sync(
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


def render_readme_skill_sync(root: Path, registry: dict[str, Any]) -> tuple[str | None, list[str]]:
    failures: list[str] = []
    schema = load_contract_schema(root, registry, failures)
    config = registry.get("readme_skill_sync")
    if not config:
        return None, ["readme skill sync: registry has no readme_skill_sync config"]

    readme_relative = config.get("readme", "README.md")
    skills_relative = config.get("skills_dir", "kramme-cc-workflow/skills")
    readme_path = resolve(root, readme_relative)
    if not readme_path.exists():
        return None, [f"readme skill sync: registered path is missing: {readme_relative}"]

    readme = read_text(readme_path)
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
        return None, failures

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
    return rendered, []
