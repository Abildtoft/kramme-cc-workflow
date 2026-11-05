from __future__ import annotations

from ..catalog import check_component_catalog_drift
from .types import CheckResult, LintContext


def check_component_catalog(context: LintContext) -> CheckResult:
    result = CheckResult()
    check_component_catalog_drift(
        context.root,
        context.registry,
        context.schema,
        result.failures,
    )
    return result
