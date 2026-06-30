#!/usr/bin/env python3
"""Lint copied skill contracts declared in synced-contracts.yaml.

The registry is JSON-compatible YAML so this script can run with only the
Python standard library on developer machines and GitHub-hosted runners.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_CONTRACT_SCHEMA_PATH = (
    Path(__file__).resolve().parent / "schemas" / "skill-contracts.json"
)


@dataclass(frozen=True)
class SkillReference:
    name: str
    display_name: str
    invocation: str
    arguments: str
    description: str


def add_arguments(parser: argparse.ArgumentParser, defaults: argparse.Namespace) -> argparse.ArgumentParser:
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=defaults.repo_root,
        help="Repository root. Defaults to two directories above this script.",
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=defaults.registry,
        help="Path to synced-contracts.yaml.",
    )
    return parser


def parse_cli() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    defaults = argparse.Namespace(
        repo_root=script_dir.parent.parent,
        registry=script_dir / "synced-contracts.yaml",
    )
    parser = argparse.ArgumentParser(description="Lint copied skill contracts")
    return add_arguments(parser, defaults).parse_args()


def load_registry(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"{path}: registry must be JSON-compatible YAML for stdlib parsing: {exc}"
        ) from exc


def load_contract_schema_file(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_default_contract_schema() -> dict[str, Any]:
    try:
        return load_contract_schema_file(DEFAULT_CONTRACT_SCHEMA_PATH)
    except (OSError, json.JSONDecodeError):
        return {}


DEFAULT_CONTRACT_SCHEMA = load_default_contract_schema()


def contract_schema_path(root: Path, registry: dict[str, Any]) -> Path:
    raw_path = registry.get("contract_schema")
    if isinstance(raw_path, str) and raw_path.strip():
        return resolve(root, raw_path)
    return DEFAULT_CONTRACT_SCHEMA_PATH


def load_contract_schema(
    root: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> dict[str, Any]:
    path = contract_schema_path(root, registry)
    try:
        schema = load_contract_schema_file(path)
    except OSError as exc:
        failures.append(f"contract schema: cannot read {rel(path, root)}: {exc}")
        return DEFAULT_CONTRACT_SCHEMA
    except json.JSONDecodeError as exc:
        failures.append(f"contract schema: {rel(path, root)} is invalid JSON: {exc}")
        return DEFAULT_CONTRACT_SCHEMA
    if not isinstance(schema, dict):
        failures.append(f"contract schema: {rel(path, root)} must be a JSON object")
        return DEFAULT_CONTRACT_SCHEMA
    return schema


def schema_skill_frontmatter_fields(
    schema: dict[str, Any] | None = None,
) -> dict[str, Any]:
    contracts = schema or DEFAULT_CONTRACT_SCHEMA
    frontmatter = contracts.get("skill_frontmatter", {})
    fields = frontmatter.get("fields", {}) if isinstance(frontmatter, dict) else {}
    return fields if isinstance(fields, dict) else {}


def skill_frontmatter_fields_by_type(
    type_name: str,
    schema: dict[str, Any] | None = None,
) -> list[str]:
    return [
        field
        for field, contract in schema_skill_frontmatter_fields(schema).items()
        if isinstance(contract, dict) and contract.get("type") == type_name
    ]


def skill_frontmatter_required_fields(schema: dict[str, Any] | None = None) -> list[str]:
    return [
        field
        for field, contract in schema_skill_frontmatter_fields(schema).items()
        if isinstance(contract, dict) and contract.get("required") is True
    ]


def skill_frontmatter_field_by_loader_property(
    loader_property: str,
    fallback: str,
    schema: dict[str, Any] | None = None,
) -> str:
    for field, contract in schema_skill_frontmatter_fields(schema).items():
        if isinstance(contract, dict) and contract.get("loader_property") == loader_property:
            return field
    return fallback


def schema_source_manifest(schema: dict[str, Any] | None = None) -> dict[str, Any]:
    contracts = schema or DEFAULT_CONTRACT_SCHEMA
    manifest = contracts.get("source_manifest", {})
    return manifest if isinstance(manifest, dict) else {}


def source_manifest_required_fields(schema: dict[str, Any] | None = None) -> list[str]:
    fields = schema_source_manifest(schema).get("required_fields", [])
    return [str(field) for field in fields] if isinstance(fields, list) else []


def source_manifest_one_of_fields(schema: dict[str, Any] | None = None) -> list[str]:
    fields = schema_source_manifest(schema).get("one_of_fields", [])
    return [str(field) for field in fields] if isinstance(fields, list) else []


def rel(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def resolve(root: Path, path: str) -> Path:
    return (root / path).resolve()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def shorten(value: str, limit: int = 180) -> str:
    if len(value) <= limit:
        return value
    return value[: limit - 3] + "..."


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def is_empty_value(value: str | None) -> bool:
    if value is None:
        return True
    return strip_quotes(value).strip() == ""


def normalize_value(value: str, normalizer: str | None) -> str:
    value = value.replace("`", "").strip()
    if normalizer == "linewise":
        return "\n".join(line.strip() for line in value.splitlines())
    if normalizer == "status_vocabulary":
        parts = [part.strip().upper() for part in re.split(r"\s*(?:\||,)\s*", value)]
        return " | ".join(part for part in parts if part)
    return re.sub(r"\s+", " ", value)


def split_markdown_table_row(line: str) -> list[str]:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return []

    cells: list[str] = []
    current: list[str] = []
    escaped = False
    for char in stripped:
        if char == "\\" and not escaped:
            escaped = True
            current.append(char)
            continue
        if char == "|" and not escaped:
            cells.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        escaped = False
    cells.append("".join(current).strip())

    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    return cells


def normalize_markdown_cell(value: str) -> str:
    normalized = re.sub(r"<!--.*?-->", "", value)
    normalized = normalized.replace("<br><br>", " ").replace("<br>", " ")
    normalized = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", normalized)
    normalized = html.unescape(normalized)
    normalized = normalized.replace("`", "")
    normalized = normalized.replace(r"\|", "|")
    normalized = normalized.replace(r"\<", "<").replace(r"\>", ">")
    normalized = normalized.replace(r"\[", "[").replace(r"\]", "]")
    return re.sub(r"\s+", " ", normalized).strip()


def escape_markdown_table_cell(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\n", " ")).strip().replace("|", r"\|")


def parse_frontmatter_bool(frontmatter: dict[str, str], field: str) -> bool:
    return strip_quotes(frontmatter.get(field, "")).lower() == "true"


def expected_invocation(
    frontmatter: dict[str, str],
    schema: dict[str, Any] | None = None,
) -> str:
    user_invocable_field = skill_frontmatter_field_by_loader_property(
        "userInvocable",
        "user-invocable",
        schema,
    )
    disable_model_invocation_field = skill_frontmatter_field_by_loader_property(
        "disableModelInvocation",
        "disable-model-invocation",
        schema,
    )
    user_invocable = parse_frontmatter_bool(frontmatter, user_invocable_field)
    model_invocation_enabled = not parse_frontmatter_bool(
        frontmatter,
        disable_model_invocation_field,
    )
    if user_invocable and model_invocation_enabled:
        return "User, Auto"
    if user_invocable:
        return "User"
    if model_invocation_enabled:
        return "Background"
    return "Hidden"


def expected_arguments(
    frontmatter: dict[str, str],
    schema: dict[str, Any] | None = None,
) -> str:
    user_invocable_field = skill_frontmatter_field_by_loader_property(
        "userInvocable",
        "user-invocable",
        schema,
    )
    argument_hint_field = skill_frontmatter_field_by_loader_property(
        "argumentHint",
        "argument-hint",
        schema,
    )
    if not parse_frontmatter_bool(frontmatter, user_invocable_field):
        return "—"
    argument_hint = frontmatter.get(argument_hint_field)
    if is_empty_value(argument_hint):
        return "—"
    return strip_quotes(str(argument_hint))


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


def extract_contract_value(
    text: str,
    regex: str,
    normalizer: str | None,
) -> tuple[str, int] | None:
    source = text.replace("`", "")
    match = re.search(regex, source, flags=re.MULTILINE)
    if not match:
        return None
    value = match.group(1) if match.lastindex else match.group(0)
    line = source.count("\n", 0, match.start()) + 1
    return normalize_value(value, normalizer), line


def check_text_contracts(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    for group in registry.get("text_contracts", []):
        name = group["name"]
        regex = group["extract_regex"]
        normalizer = group.get("normalizer")
        reference: tuple[str, str, int] | None = None
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                failures.append(f"{name}: registered path is missing: {copy}")
                continue
            extracted = extract_contract_value(read_text(path), regex, normalizer)
            if extracted is None:
                failures.append(f"{name}: no registered contract match in {copy}")
                continue
            value, line = extracted
            if reference is None:
                reference = (value, copy, line)
                continue
            ref_value, ref_path, ref_line = reference
            if value != ref_value:
                failures.append(
                    f"{name}: {copy}:{line} differs from {ref_path}:{ref_line}; "
                    f"expected {ref_value!r}, got {value!r}"
                )


def heading_lines(text: str) -> list[tuple[int, str]]:
    matches = []
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if re.match(r"^#{1,6}\s+\S", stripped):
            matches.append((number, stripped))
    return matches


def check_ordered_heading_contracts(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    for group in registry.get("ordered_heading_contracts", []):
        name = group["name"]
        expected = group["headings"]
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                failures.append(f"{name}: registered path is missing: {copy}")
                continue
            headings = heading_lines(read_text(path))
            last_index = -1
            for heading in expected:
                found = next(
                    (
                        (index, line_no)
                        for index, (line_no, actual) in enumerate(headings)
                        if index > last_index and actual == heading
                    ),
                    None,
                )
                if found is None:
                    failures.append(f"{name}: missing or out-of-order heading {heading!r} in {copy}")
                    break
                last_index = found[0]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_file_identity(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    for group in registry.get("file_identity_groups", []):
        name = group["name"]
        reference: tuple[str, str] | None = None
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                failures.append(f"{name}: registered path is missing: {copy}")
                continue
            current_hash = sha256(path)
            if reference is None:
                reference = (current_hash, copy)
                continue
            ref_hash, ref_path = reference
            if current_hash != ref_hash:
                failures.append(
                    f"{name}: {copy} hash {current_hash} differs from {ref_path} hash {ref_hash}; "
                    "sync all registered copies"
                )


def check_required_file_contracts(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    for contract in registry.get("required_file_contracts", []):
        name = contract["name"]
        copy = contract["path"]
        path = resolve(root, copy)
        if not path.exists():
            failures.append(f"{name}: registered path is missing: {copy}")
            continue

        text = read_text(path)
        frontmatter_contract = contract.get("frontmatter", {})
        if frontmatter_contract:
            frontmatter = parse_frontmatter(text)
            if frontmatter is None:
                failures.append(f"{name}: {copy} is missing YAML frontmatter")
            else:
                for field, expected in frontmatter_contract.items():
                    actual = frontmatter.get(field)
                    expected_text = strip_quotes(str(expected))
                    if actual != expected_text:
                        failures.append(
                            f"{name}: {copy} frontmatter field {field!r} expected "
                            f"{expected_text!r}, got {actual!r}"
                        )

        for required_text in contract.get("contains", []):
            if required_text not in text:
                failures.append(f"{name}: {copy} is missing required text {required_text!r}")


def parse_frontmatter(text: str) -> dict[str, str] | None:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return None
    end = None
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            end = index
            break
    if end is None:
        return None

    frontmatter: dict[str, str] = {}
    for line in lines[1:end]:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            frontmatter[match.group(1)] = strip_quotes(match.group(2))
    return frontmatter


def skill_paths(root: Path, pattern: str) -> list[Path]:
    return sorted(path for path in root.glob(pattern) if path.is_file())


def check_mechanical(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any],
    failures: list[str],
    warnings: list[str],
) -> None:
    config = registry.get("mechanical", {})
    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    max_lines = int(config.get("max_skill_lines", 500))
    warn_lines = int(config.get("warn_skill_lines", 0) or 0)
    report_limit = int(config.get("skill_line_report_limit", 20))
    max_description = int(config.get("max_description_chars", 1024))
    if "contract_schema" in registry and "required_frontmatter" in config:
        failures.append(
            "mechanical: required_frontmatter must come from contract_schema, "
            "not synced-contracts.yaml"
        )
    required_fields = config.get("required_frontmatter")
    if required_fields is None:
        required_fields = skill_frontmatter_required_fields(schema)
    line_allowlist = set(config.get("allow_line_count_over", []))
    long_skill_entries: list[tuple[int, str]] = []

    for path in skill_paths(root, pattern):
        relative = rel(path, root)
        text = read_text(path)
        line_count = len(text.splitlines())
        if warn_lines > 0 and line_count >= warn_lines:
            long_skill_entries.append((line_count, relative))
        if line_count > max_lines and relative not in line_allowlist:
            failures.append(
                f"mechanical: {relative} has {line_count} lines, exceeds {max_lines}; "
                "move reference material out of SKILL.md or add a registry burndown entry"
            )

        frontmatter = parse_frontmatter(text)
        if frontmatter is None:
            failures.append(f"mechanical: {relative} is missing YAML frontmatter")
            continue
        for field in required_fields:
            if field not in frontmatter:
                failures.append(f"mechanical: {relative} is missing frontmatter field {field!r}")
        description = frontmatter.get("description")
        if description is not None and len(description) > max_description:
            failures.append(
                f"mechanical: {relative} description is {len(description)} chars, "
                f"exceeds {max_description}"
            )

    if warn_lines <= 0:
        return

    sorted_long_skills = sorted(long_skill_entries, key=lambda item: (-item[0], item[1]))
    for line_count, relative in sorted_long_skills[:report_limit]:
        if line_count > max_lines:
            status = "over hard budget"
        elif line_count == max_lines:
            status = "at hard budget"
        else:
            status = f"{max_lines - line_count} lines below hard budget"
        warnings.append(
            f"mechanical: long-skill burndown: {relative} has {line_count} lines "
            f"({status}; warn at {warn_lines}, fail above {max_lines})"
        )


def check_hooks_json(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    config = registry.get("hooks_json")
    if not config:
        return

    relative_path = config.get("path", "kramme-cc-workflow/hooks/hooks.json")
    path = resolve(root, relative_path)
    if not path.exists():
        failures.append(f"hooks json: registered path is missing: {relative_path}")
        return

    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        failures.append(
            f"hooks json: {relative_path} is invalid JSON at line {exc.lineno}, "
            f"column {exc.colno}: {exc.msg}"
        )
        return

    if not isinstance(data, dict):
        failures.append(f"hooks json: {relative_path} must contain a JSON object")
        return

    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        failures.append(f"hooks json: {relative_path} must contain an object field 'hooks'")
        return

    allowed_events = set(
        config.get(
            "allowed_events",
            ["PreToolUse", "PostToolUse", "UserPromptSubmit", "SessionStart", "Stop"],
        )
    )
    matcher_required_events = set(config.get("matcher_required_events", ["PreToolUse", "PostToolUse"]))
    allowed_hook_types = set(config.get("allowed_hook_types", ["command"]))
    plugin_root = config.get("plugin_root", "kramme-cc-workflow")
    command_path_regex = config.get(
        "command_path_regex",
        r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)",
    )

    for event, entries in hooks.items():
        if event not in allowed_events:
            failures.append(f"hooks json: {relative_path} has unknown event {event!r}")
        if not isinstance(entries, list):
            failures.append(f"hooks json: {relative_path} event {event!r} must be a list")
            continue

        for entry_index, entry in enumerate(entries, start=1):
            entry_label = f"{relative_path} {event}[{entry_index}]"
            if not isinstance(entry, dict):
                failures.append(f"hooks json: {entry_label} must be an object")
                continue

            matcher = entry.get("matcher")
            if event in matcher_required_events and not isinstance(matcher, str):
                failures.append(f"hooks json: {entry_label} must define a string matcher")
            elif event in matcher_required_events and is_empty_value(matcher):
                failures.append(f"hooks json: {entry_label} must define a non-empty matcher")
            elif "matcher" in entry and (not isinstance(matcher, str) or is_empty_value(matcher)):
                failures.append(f"hooks json: {entry_label} matcher must be a non-empty string when present")

            hook_entries = entry.get("hooks")
            if not isinstance(hook_entries, list) or not hook_entries:
                failures.append(f"hooks json: {entry_label} must define a non-empty hooks list")
                continue

            for hook_index, hook_entry in enumerate(hook_entries, start=1):
                hook_label = f"{entry_label}.hooks[{hook_index}]"
                if not isinstance(hook_entry, dict):
                    failures.append(f"hooks json: {hook_label} must be an object")
                    continue

                hook_type = hook_entry.get("type")
                if not isinstance(hook_type, str) or hook_type not in allowed_hook_types:
                    failures.append(
                        f"hooks json: {hook_label} has unsupported type {hook_type!r}; "
                        f"expected one of {sorted(allowed_hook_types)!r}"
                    )

                command = hook_entry.get("command")
                if not isinstance(command, str) or is_empty_value(command):
                    failures.append(f"hooks json: {hook_label} must define a non-empty command")
                    continue

                for plugin_relative in re.findall(command_path_regex, command):
                    command_path = resolve(root, f"{plugin_root}/{plugin_relative}")
                    if not command_path.exists():
                        failures.append(
                            f"hooks json: {hook_label} command references missing path "
                            f"{plugin_root}/{plugin_relative}"
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


def parse_sources_manifest(path: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None

    def set_field(entry: dict[str, Any], key: str, raw_value: str, line_no: int) -> None:
        entry[key] = strip_quotes(raw_value.strip())
        entry.setdefault("_lines", {})[key] = line_no

    for line_no, line in enumerate(read_text(path).splitlines(), start=1):
        item_match = re.match(r"^\s*-\s+([A-Za-z0-9_]+):\s*(.*)$", line)
        if item_match:
            if current is not None:
                entries.append(current)
            current = {}
            set_field(current, item_match.group(1), item_match.group(2), line_no)
            continue

        if current is None:
            continue
        field_match = re.match(r"^\s+([A-Za-z0-9_]+):\s*(.*)$", line)
        if field_match:
            set_field(current, field_match.group(1), field_match.group(2), line_no)

    if current is not None:
        entries.append(current)
    return entries


def marker_present(text: str, markers: list[str]) -> bool:
    return any(marker in text for marker in markers)


def allow_empty_field_keys(config: dict[str, Any], failures: list[str]) -> set[tuple[str, str, str]]:
    allow_empty: set[tuple[str, str, str]] = set()
    raw_entries = config.get("allow_empty_fields", [])
    if not isinstance(raw_entries, list):
        failures.append("marker manifest: allow_empty_fields must be a list")
        return allow_empty

    required_keys = ("path", "entry_id", "field", "reason")
    for index, item in enumerate(raw_entries, start=1):
        label = f"marker manifest: allow_empty_fields[{index}]"
        if not isinstance(item, dict):
            failures.append(f"{label} must be an object")
            continue

        normalized: dict[str, str] = {}
        for key in required_keys:
            value = item.get(key)
            if not isinstance(value, str) or is_empty_value(value):
                failures.append(f"{label} must define non-empty {key!r}")
                continue
            normalized[key] = strip_quotes(value).strip()

        if all(key in normalized for key in required_keys):
            allow_empty.add((normalized["path"], normalized["entry_id"], normalized["field"]))

    return allow_empty


def check_marker_manifests(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any],
    failures: list[str],
) -> None:
    config = registry.get("marker_implies_manifest")
    if not config:
        return

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    markers = config.get("markers", [])
    manifest_rel = config.get("manifest", "references/sources.yaml")
    if "contract_schema" in registry:
        for key in ("required_fields", "one_of_fields"):
            if key in config:
                failures.append(
                    f"marker manifest: {key} must come from contract_schema, "
                    "not synced-contracts.yaml"
                )
    required_fields = config.get("required_fields")
    if required_fields is None:
        required_fields = source_manifest_required_fields(schema)
    one_of_fields = config.get("one_of_fields")
    if one_of_fields is None:
        one_of_fields = source_manifest_one_of_fields(schema)
    allow_empty = allow_empty_field_keys(config, failures)
    used_allow_empty: set[tuple[str, str, str]] = set()

    for path in skill_paths(root, pattern):
        text = read_text(path)
        if not marker_present(text, markers):
            continue
        relative = rel(path, root)
        manifest_path = path.parent / manifest_rel
        manifest_relative = rel(manifest_path, root)
        if not manifest_path.exists():
            failures.append(
                f"marker manifest: {relative} contains a port marker but lacks {manifest_relative}"
            )
            continue
        entries = parse_sources_manifest(manifest_path)
        if not entries:
            failures.append(f"marker manifest: {manifest_relative} has no source entries")
            continue
        for index, entry in enumerate(entries, start=1):
            entry_id = entry.get("id", f"entry-{index}")
            for field in required_fields:
                value = entry.get(field)
                if field not in entry:
                    failures.append(
                        f"marker manifest: {manifest_relative} entry {entry_id!r} is missing {field!r}"
                    )
                    continue
                if is_empty_value(value):
                    allow_key = (manifest_relative, entry_id, field)
                    if allow_key in allow_empty:
                        used_allow_empty.add(allow_key)
                    else:
                        line = entry.get("_lines", {}).get(field, "?")
                        failures.append(
                            f"marker manifest: {manifest_relative}:{line} entry {entry_id!r} "
                            f"has empty {field!r}"
                        )
            if one_of_fields and not any(not is_empty_value(entry.get(field)) for field in one_of_fields):
                failures.append(
                    f"marker manifest: {manifest_relative} entry {entry_id!r} must define one of "
                    + ", ".join(repr(field) for field in one_of_fields)
                )

    for manifest_relative, entry_id, field in sorted(allow_empty - used_allow_empty):
        failures.append(
            f"marker manifest: allow_empty_fields entry for {manifest_relative} entry {entry_id!r} "
            f"field {field!r} does not match an empty required field"
        )


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


def check_epilogue_order(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    config = registry.get("epilogue_order")
    if not config:
        return

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    trigger = re.compile(config.get("trigger_heading_regex", r"^#{2,3}\s+Common Rationalizations\b"), re.MULTILINE)
    required = config.get("required_headings", ["Common Rationalizations", "Red Flags", "Verification"])
    allowlist = set(config.get("allowlist", []))

    for path in skill_paths(root, pattern):
        relative = rel(path, root)
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
            failures.append(
                f"epilogue order: {relative} is missing canonical section(s): {', '.join(missing)}"
            )
            continue
        order = [positions[heading] for heading in required]
        if order != sorted(order):
            failures.append(
                f"epilogue order: {relative} must order sections as "
                + " -> ".join(required)
                + f"; found line order {order}"
            )


def run(root: Path, registry: dict[str, Any]) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    schema = load_contract_schema(root, registry, failures)
    check_text_contracts(root, registry, failures)
    check_ordered_heading_contracts(root, registry, failures)
    check_file_identity(root, registry, failures)
    check_required_file_contracts(root, registry, failures)
    check_marker_manifests(root, registry, schema, failures)
    check_epilogue_order(root, registry, failures)
    check_hooks_json(root, registry, failures)
    check_readme_skill_sync(root, registry, schema, failures)
    check_mechanical(root, registry, schema, failures, warnings)
    return failures, warnings


def main() -> int:
    args = parse_cli()
    root = args.repo_root.resolve()
    registry = load_registry(args.registry.resolve())
    failures, warnings = run(root, registry)
    if warnings:
        print("skill contract lint warnings:")
        for warning in warnings:
            print(f"::warning::{warning}")
    if failures:
        print("skill contract lint failed:")
        for failure in failures:
            print(f"::error::{failure}")
        return 1
    print("skill contract lint passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
