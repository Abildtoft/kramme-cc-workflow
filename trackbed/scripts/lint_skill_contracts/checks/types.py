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


@dataclass(frozen=True)
class TextContractInventory:
    glob: str
    marker: str


@dataclass(frozen=True)
class TextContract:
    label: str
    extract_regex: str
    paths: tuple[str, ...]
    normalizer: str | None
    inventory: TextContractInventory | None


CheckFunc = Callable[[LintContext], CheckResult]
