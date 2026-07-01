from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable


@dataclass(frozen=True)
class LintContext:
    root: Path
    registry: dict[str, Any]
    schema: dict[str, Any]


@dataclass
class CheckResult:
    failures: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


CheckFunc = Callable[[LintContext], CheckResult]
