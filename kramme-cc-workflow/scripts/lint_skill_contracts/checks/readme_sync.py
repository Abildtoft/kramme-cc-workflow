from __future__ import annotations

from ..readme import check_readme_skill_sync as append_readme_skill_sync_failures
from .types import CheckResult, LintContext


def check_readme_skill_sync(context: LintContext) -> CheckResult:
    result = CheckResult()
    append_readme_skill_sync_failures(
        context.root,
        context.registry,
        context.schema,
        result.failures,
    )
    return result
