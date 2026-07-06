from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


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
