from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .io import rel, resolve

DEFAULT_CONTRACT_SCHEMA_PATH = Path(__file__).resolve().parent.parent / "schemas" / "skill-contracts.json"


def load_contract_schema_file(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_default_contract_schema() -> dict[str, Any]:
    schema, _error = _load_default_contract_schema_with_error()
    return schema


def _load_default_contract_schema_with_error() -> tuple[dict[str, Any], str | None]:
    try:
        schema = load_contract_schema_file(DEFAULT_CONTRACT_SCHEMA_PATH)
    except OSError as exc:
        return {}, f"default contract schema: cannot read {DEFAULT_CONTRACT_SCHEMA_PATH}: {exc}"
    except json.JSONDecodeError as exc:
        return {}, f"default contract schema: {DEFAULT_CONTRACT_SCHEMA_PATH} is invalid JSON: {exc}"
    if not isinstance(schema, dict):
        return {}, f"default contract schema: {DEFAULT_CONTRACT_SCHEMA_PATH} must be a JSON object"
    return schema, None


DEFAULT_CONTRACT_SCHEMA, DEFAULT_CONTRACT_SCHEMA_ERROR = _load_default_contract_schema_with_error()


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
        return _fallback_to_default_schema(path, failures)
    except json.JSONDecodeError as exc:
        failures.append(f"contract schema: {rel(path, root)} is invalid JSON: {exc}")
        return _fallback_to_default_schema(path, failures)
    if not isinstance(schema, dict):
        failures.append(f"contract schema: {rel(path, root)} must be a JSON object")
        return _fallback_to_default_schema(path, failures)
    return schema


def _fallback_to_default_schema(path: Path, failures: list[str]) -> dict[str, Any]:
    if DEFAULT_CONTRACT_SCHEMA_ERROR is not None and path != DEFAULT_CONTRACT_SCHEMA_PATH:
        failures.append(DEFAULT_CONTRACT_SCHEMA_ERROR)
    return DEFAULT_CONTRACT_SCHEMA


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
