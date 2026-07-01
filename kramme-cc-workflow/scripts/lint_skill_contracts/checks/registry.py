from __future__ import annotations

from collections.abc import Iterable

from ..schema import load_contract_schema
from .basic import (
    check_file_identity,
    check_ordered_heading_contracts,
    check_required_file_contracts,
    check_text_contracts,
)
from .epilogue import check_epilogue_order
from .hooks_json import check_hooks_json
from .marker_manifest import check_marker_manifests
from .mechanical import check_mechanical
from .readme_sync import check_readme_skill_sync
from .types import CheckFunc, CheckResult, LintContext


CHECKS: tuple[tuple[str, CheckFunc], ...] = (
    ("text_contracts", check_text_contracts),
    ("ordered_heading_contracts", check_ordered_heading_contracts),
    ("file_identity", check_file_identity),
    ("required_file_contracts", check_required_file_contracts),
    ("marker_manifests", check_marker_manifests),
    ("epilogue_order", check_epilogue_order),
    ("hooks_json", check_hooks_json),
    ("readme_skill_sync", check_readme_skill_sync),
    ("mechanical", check_mechanical),
)


def run_checks(
    context: LintContext,
    checks: Iterable[tuple[str, CheckFunc]] = CHECKS,
) -> CheckResult:
    result = CheckResult()
    for _name, check in checks:
        check_result = check(context)
        result.failures.extend(check_result.failures)
        result.warnings.extend(check_result.warnings)
    return result


def run(root, registry) -> tuple[list[str], list[str]]:
    schema_failures: list[str] = []
    schema = load_contract_schema(root, registry, schema_failures)
    context = LintContext(root=root, registry=registry, schema=schema)
    result = run_checks(context)
    return schema_failures + result.failures, result.warnings
