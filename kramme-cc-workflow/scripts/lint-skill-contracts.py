#!/usr/bin/env python3
"""Lint copied skill contracts declared in synced-contracts.yaml.

The registry is JSON-compatible YAML so this script can run with only the
Python standard library on developer machines and GitHub-hosted runners.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


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


def rel(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def resolve(root: Path, path: str) -> Path:
    return (root / path).resolve()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


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
    failures: list[str],
    warnings: list[str],
) -> None:
    config = registry.get("mechanical", {})
    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    max_lines = int(config.get("max_skill_lines", 500))
    warn_lines = int(config.get("warn_skill_lines", 0) or 0)
    report_limit = int(config.get("skill_line_report_limit", 20))
    max_description = int(config.get("max_description_chars", 1024))
    required_fields = config.get(
        "required_frontmatter",
        ["name", "description", "disable-model-invocation", "user-invocable"],
    )
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


def check_readme_skill_sync(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    config = registry.get("readme_skill_sync")
    if not config:
        return

    readme_relative = config.get("readme", "README.md")
    skills_relative = config.get("skills_dir", "kramme-cc-workflow/skills")
    readme_path = resolve(root, readme_relative)
    skills_dir = resolve(root, skills_relative)

    if not readme_path.exists():
        failures.append(f"readme skill sync: registered path is missing: {readme_relative}")
        return
    if not skills_dir.exists():
        failures.append(f"readme skill sync: registered path is missing: {skills_relative}")
        return

    readme = read_text(readme_path)
    skill_names = sorted(
        path.name
        for path in skills_dir.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )
    skills = set(skill_names)
    documented_regex = re.compile(
        config.get("documented_skill_regex", r"^\|\s*`/(?P<name>kramme:[A-Za-z0-9:_-]+)`\s*\|")
    )
    background_regex = re.compile(
        config.get("background_skill_regex", r"^\|\s*`(?P<name>kramme:[A-Za-z0-9:_-]+)`\s*\|")
    )
    background_heading = config.get("background_section_heading", "### Background Skills")
    in_background_section = False
    documented_skills: dict[str, int] = {}
    for line_no, line in enumerate(readme.splitlines(), start=1):
        stripped = line.strip()
        if stripped == background_heading:
            in_background_section = True
            continue
        if in_background_section and re.match(r"^#{1,3}\s+\S", stripped):
            in_background_section = False

        match = documented_regex.search(line)
        if not match and in_background_section:
            match = background_regex.search(line)
        if not match:
            continue
        name = match.group("name") if "name" in match.groupdict() else match.group(1)
        documented_skills.setdefault(name, line_no)

    for name in skill_names:
        if name not in documented_skills:
            failures.append(
                f"readme skill sync: {readme_relative} is missing skill {name!r} "
                f"from {skills_relative}"
            )

    allow_readme_only = set(config.get("allow_readme_only_skills", []))
    for name, line_no in documented_skills.items():
        if name in skills or name in allow_readme_only:
            continue
        failures.append(
            f"readme skill sync: {readme_relative}:{line_no} documents {name!r}, "
            f"but {skills_relative}/{name}/SKILL.md does not exist"
        )


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


def check_marker_manifests(root: Path, registry: dict[str, Any], failures: list[str]) -> None:
    config = registry.get("marker_implies_manifest")
    if not config:
        return

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    markers = config.get("markers", [])
    manifest_rel = config.get("manifest", "references/sources.yaml")
    required_fields = config.get("required_fields", [])
    one_of_fields = config.get("one_of_fields", [])
    allow_empty = allow_empty_field_keys(config, failures)

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
                if is_empty_value(value) and (manifest_relative, entry_id, field) not in allow_empty:
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
    check_text_contracts(root, registry, failures)
    check_ordered_heading_contracts(root, registry, failures)
    check_file_identity(root, registry, failures)
    check_required_file_contracts(root, registry, failures)
    check_marker_manifests(root, registry, failures)
    check_epilogue_order(root, registry, failures)
    check_hooks_json(root, registry, failures)
    check_readme_skill_sync(root, registry, failures)
    check_mechanical(root, registry, failures, warnings)
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
