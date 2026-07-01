from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from ..io import read_text, rel, skill_paths
from ..schema import source_manifest_one_of_fields, source_manifest_required_fields
from ..strings import is_empty_value, strip_quotes
from .types import CheckResult, LintContext


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


def check_marker_manifests(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("marker_implies_manifest")
    if not config:
        return result

    pattern = config.get("skill_glob", "kramme-cc-workflow/skills/*/SKILL.md")
    markers = config.get("markers", [])
    manifest_rel = config.get("manifest", "references/sources.yaml")
    if "contract_schema" in context.registry:
        for key in ("required_fields", "one_of_fields"):
            if key in config:
                result.failures.append(
                    f"marker manifest: {key} must come from contract_schema, "
                    "not synced-contracts.yaml"
                )
    required_fields = config.get("required_fields")
    if required_fields is None:
        required_fields = source_manifest_required_fields(context.schema)
    one_of_fields = config.get("one_of_fields")
    if one_of_fields is None:
        one_of_fields = source_manifest_one_of_fields(context.schema)
    allow_empty = allow_empty_field_keys(config, result.failures)
    used_allow_empty: set[tuple[str, str, str]] = set()

    for path in skill_paths(context.root, pattern):
        text = read_text(path)
        if not marker_present(text, markers):
            continue
        relative = rel(path, context.root)
        manifest_path = path.parent / manifest_rel
        manifest_relative = rel(manifest_path, context.root)
        if not manifest_path.exists():
            result.failures.append(
                f"marker manifest: {relative} contains a port marker but lacks {manifest_relative}"
            )
            continue
        entries = parse_sources_manifest(manifest_path)
        if not entries:
            result.failures.append(f"marker manifest: {manifest_relative} has no source entries")
            continue
        for index, entry in enumerate(entries, start=1):
            entry_id = entry.get("id", f"entry-{index}")
            for field in required_fields:
                value = entry.get(field)
                if field not in entry:
                    result.failures.append(
                        f"marker manifest: {manifest_relative} entry {entry_id!r} is missing {field!r}"
                    )
                    continue
                if is_empty_value(value):
                    allow_key = (manifest_relative, entry_id, field)
                    if allow_key in allow_empty:
                        used_allow_empty.add(allow_key)
                    else:
                        line = entry.get("_lines", {}).get(field, "?")
                        result.failures.append(
                            f"marker manifest: {manifest_relative}:{line} entry {entry_id!r} "
                            f"has empty {field!r}"
                        )
            if one_of_fields and not any(not is_empty_value(entry.get(field)) for field in one_of_fields):
                result.failures.append(
                    f"marker manifest: {manifest_relative} entry {entry_id!r} must define one of "
                    + ", ".join(repr(field) for field in one_of_fields)
                )

    for manifest_relative, entry_id, field in sorted(allow_empty - used_allow_empty):
        result.failures.append(
            f"marker manifest: allow_empty_fields entry for {manifest_relative} entry {entry_id!r} "
            f"field {field!r} does not match an empty required field"
        )
    return result
