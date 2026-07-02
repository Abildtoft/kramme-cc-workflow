from __future__ import annotations

from typing import Any

from ..io import read_text, rel, resolve
from .types import CheckResult, LintContext


def normalize_path(path: str) -> str:
    normalized = path.replace("\\", "/").strip()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


def path_segments(path: str) -> list[str]:
    return [segment for segment in normalize_path(path).split("/") if segment]


def has_segment(path: str, candidates: list[str]) -> bool:
    candidate_set = {candidate.lower() for candidate in candidates}
    return any(segment.lower() in candidate_set for segment in path_segments(path))


def has_suffix(path: str, suffixes: list[str]) -> bool:
    lowered = normalize_path(path).lower()
    return any(lowered.endswith(suffix.lower()) for suffix in suffixes)


def has_basename_prefix(path: str, prefixes: list[str]) -> bool:
    basename = normalize_path(path).rsplit("/", maxsplit=1)[-1].lower()
    return any(basename.startswith(prefix.lower()) for prefix in prefixes)


def is_ui_relevant_path(path: str, matcher: dict[str, Any]) -> bool:
    if has_suffix(path, string_list(matcher, "extensions")):
        return True
    if has_basename_prefix(path, string_list(matcher, "basename_prefixes")):
        return True
    if has_segment(path, string_list(matcher, "directory_segments")):
        return True

    asset_dirs = string_list(matcher, "asset_directory_segments")
    asset_extensions = string_list(matcher, "asset_extensions")
    return bool(
        asset_dirs
        and asset_extensions
        and has_segment(path, asset_dirs)
        and has_suffix(path, asset_extensions)
    )


def string_list(config: dict[str, Any], key: str) -> list[str]:
    value = config.get(key, [])
    return [item for item in value if isinstance(item, str)] if isinstance(value, list) else []


def strip_code_span(value: str) -> str:
    stripped = value.strip()
    if stripped.startswith("`") and stripped.endswith("`") and len(stripped) >= 2:
        return stripped[1:-1]
    return stripped


def normalize_fixture_expected(value: str) -> bool | None:
    normalized = strip_code_span(value).lower()
    if normalized in {"ui", "ui-relevant", "true", "yes"}:
        return True
    if normalized in {"non-ui", "not ui", "false", "no"}:
        return False
    return None


def parse_fixture_matrix(text: str) -> dict[str, bool]:
    fixtures: dict[str, bool] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [strip_code_span(cell) for cell in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        path = cells[0].strip()
        if path.lower() == "path" or set(path) <= {"-", " "}:
            continue
        expected = normalize_fixture_expected(cells[1])
        if expected is not None:
            fixtures[path] = expected
    return fixtures


def normalized_text(text: str) -> str:
    return text.replace("`", "")


def required_string_list(
    contract: dict[str, Any],
    key: str,
    label: str,
    result: CheckResult,
) -> list[str]:
    value = contract.get(key, [])
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        result.failures.append(f"{label}: {key} must be a string list")
        return []
    return value


def check_registered_paths(
    context: LintContext,
    label: str,
    contract_id: str,
    paths: list[str],
    required_terms: list[str],
    result: CheckResult,
) -> None:
    for copy in paths:
        path = resolve(context.root, copy)
        if not path.exists():
            result.failures.append(f"{label}: registered path is missing: {copy}")
            continue
        text = normalized_text(read_text(path))
        if contract_id not in text:
            result.failures.append(f"{label}: {copy} is missing contract id {contract_id!r}")
        for term in required_terms:
            if term not in text:
                result.failures.append(f"{label}: {copy} is missing UI relevance term {term!r}")


def check_fixture_matrix(
    context: LintContext,
    label: str,
    canonical_path: str,
    matcher: dict[str, Any],
    fixtures: list[dict[str, Any]],
    result: CheckResult,
) -> None:
    path = resolve(context.root, canonical_path)
    if not path.exists():
        result.failures.append(f"{label}: canonical path is missing: {canonical_path}")
        return

    matrix = parse_fixture_matrix(read_text(path))
    for index, fixture in enumerate(fixtures, start=1):
        fixture_path = fixture.get("path")
        expected = fixture.get("ui_relevant")
        if not isinstance(fixture_path, str) or not isinstance(expected, bool):
            result.failures.append(
                f"{label}: fixtures[{index}] must define path and boolean ui_relevant"
            )
            continue

        actual = is_ui_relevant_path(fixture_path, matcher)
        if actual != expected:
            result.failures.append(
                f"{label}: matcher returns {actual!r} for fixture {fixture_path!r}; "
                f"expected {expected!r}"
            )

        documented = matrix.get(fixture_path)
        if documented is None:
            result.failures.append(
                f"{label}: {rel(path, context.root)} is missing fixture row {fixture_path!r}"
            )
        elif documented != expected:
            result.failures.append(
                f"{label}: {rel(path, context.root)} fixture {fixture_path!r} "
                f"documents {documented!r}; expected {expected!r}"
            )


def check_ui_relevance_contracts(context: LintContext) -> CheckResult:
    result = CheckResult()
    contracts = context.registry.get("ui_relevance_contracts", [])
    if not contracts:
        return result
    if not isinstance(contracts, list):
        result.failures.append("ui relevance contracts: ui_relevance_contracts must be a list")
        return result

    for index, contract in enumerate(contracts, start=1):
        label = f"ui relevance contract {index}"
        if not isinstance(contract, dict):
            result.failures.append(f"{label}: entry must be an object")
            continue

        name = contract.get("name")
        if isinstance(name, str) and name:
            label = name

        contract_id = contract.get("contract_id")
        canonical_path = contract.get("canonical_path")
        matcher = contract.get("matcher", {})
        fixtures = contract.get("fixtures", [])
        if not isinstance(contract_id, str) or not contract_id:
            result.failures.append(f"{label}: contract_id must be a non-empty string")
            continue
        if not isinstance(canonical_path, str) or not canonical_path:
            result.failures.append(f"{label}: canonical_path must be a non-empty string")
            continue
        if not isinstance(matcher, dict):
            result.failures.append(f"{label}: matcher must be an object")
            matcher = {}
        if not isinstance(fixtures, list):
            result.failures.append(f"{label}: fixtures must be a list")
            fixtures = []

        paths = required_string_list(contract, "paths", label, result)
        required_terms = required_string_list(contract, "required_terms", label, result)
        all_paths = [canonical_path, *paths]
        check_registered_paths(context, label, contract_id, all_paths, required_terms, result)
        check_fixture_matrix(context, label, canonical_path, matcher, fixtures, result)

    return result
