from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .io import read_text, resolve
from .readme import load_agent_references, load_hook_references, load_skill_references
from .schema import load_contract_schema

LABEL = "component catalog"
DEFAULT_CATALOG_PATH = "kramme-cc-workflow/docs/component-catalog.json"
DEFAULT_GENERATOR = "kramme-cc-workflow/scripts/generate-component-reference.py"
DEFAULT_CANONICAL_REFERENCE = "README.md"

# The catalog is navigation metadata generated one way from the same component
# sources the README rows use. It reads its source directories from the README
# sync configs so it can never become a second place to declare components.
REQUIRED_SYNC_CONFIGS = ("readme_skill_sync", "readme_agent_sync", "readme_hook_sync")


def catalog_relative_path(config: dict[str, Any]) -> str:
    path = config.get("path", DEFAULT_CATALOG_PATH)
    return path if isinstance(path, str) and path else DEFAULT_CATALOG_PATH


def missing_sync_configs(registry: dict[str, Any]) -> list[str]:
    return [key for key in REQUIRED_SYNC_CONFIGS if not isinstance(registry.get(key), dict)]


def skill_catalog_entries(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any] | None,
    failures: list[str],
) -> list[dict[str, str]]:
    config = registry["readme_skill_sync"]
    skills_relative = config.get("skills_dir", "kramme-cc-workflow/skills")
    references = load_skill_references(root, skills_relative, failures, schema)
    return [
        {
            "name": name,
            "invocation": references[name].invocation,
            "path": f"{skills_relative}/{name}/SKILL.md",
        }
        for name in sorted(references)
    ]


def agent_catalog_entries(
    root: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> list[dict[str, str]]:
    config = registry["readme_agent_sync"]
    agents_relative = config.get("agents_dir", "kramme-cc-workflow/agents")
    references = load_agent_references(root, agents_relative, failures)
    return [{"name": name, "path": f"{agents_relative}/{name}.md"} for name in sorted(references)]


def hook_catalog_entries(
    root: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> list[dict[str, str]]:
    references = load_hook_references(root, registry["readme_hook_sync"], failures)
    return [
        {
            "name": name,
            "event": references[name].event,
            "path": references[name].path,
        }
        for name in sorted(references)
    ]


def check_catalog_entry_paths(
    root: Path,
    relative: str,
    entries: list[dict[str, str]],
    failures: list[str],
) -> None:
    for entry in entries:
        if not resolve(root, entry["path"]).is_file():
            failures.append(f"{LABEL}: {relative} would document {entry['name']!r} at missing path {entry['path']}")


def component_catalog_document(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any] | None,
    failures: list[str],
) -> dict[str, Any] | None:
    config = registry["component_catalog"]
    relative = catalog_relative_path(config)
    missing = missing_sync_configs(registry)
    if missing:
        failures.append(
            f"{LABEL}: {relative} is generated from README sync metadata; registry is missing {', '.join(missing)}"
        )
        return None

    document = {
        "generated_by": config.get("generated_by", DEFAULT_GENERATOR),
        "canonical_reference": config.get("canonical_reference", DEFAULT_CANONICAL_REFERENCE),
        "skills": skill_catalog_entries(root, registry, schema, failures),
        "agents": agent_catalog_entries(root, registry, failures),
        "hooks": hook_catalog_entries(root, registry, failures),
    }
    if failures:
        return None

    for section in ("skills", "agents", "hooks"):
        check_catalog_entry_paths(root, relative, document[section], failures)
    if failures:
        return None
    return document


def render_component_catalog_text(document: dict[str, Any]) -> str:
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def render_component_catalog(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any] | None = None,
) -> tuple[str | None, str | None, list[str]]:
    """Render the compact catalog as (relative path, text, failures).

    Returns ``(None, None, [])`` when the registry does not configure a catalog.
    """
    config = registry.get("component_catalog")
    if not isinstance(config, dict):
        return None, None, []

    failures: list[str] = []
    if schema is None:
        schema = load_contract_schema(root, registry, failures)
    relative = catalog_relative_path(config)
    document = component_catalog_document(root, registry, schema, failures)
    if document is None:
        return relative, None, failures
    return relative, render_component_catalog_text(document), failures


def check_component_catalog_drift(
    root: Path,
    registry: dict[str, Any],
    schema: dict[str, Any] | None,
    failures: list[str],
) -> None:
    relative, rendered, render_failures = render_component_catalog(root, registry, schema)
    if relative is None:
        return
    if rendered is None:
        # Component source metadata diagnostics belong to the README sync checks,
        # which run in the same pass. Report the blocked catalog once instead of
        # repeating every source failure under a second label.
        source_failures = [failure for failure in render_failures if failure.startswith(LABEL)]
        failures.extend(
            source_failures or [f"{LABEL}: cannot generate {relative} until component source metadata is valid"]
        )
        return

    path = resolve(root, relative)
    if not path.is_file():
        failures.append(f"{LABEL}: registered path is missing: {relative}")
        return
    if read_text(path) != rendered:
        failures.append(
            f"{LABEL}: {relative} is stale; run "
            "python3 kramme-cc-workflow/scripts/generate-component-reference.py --write"
        )
