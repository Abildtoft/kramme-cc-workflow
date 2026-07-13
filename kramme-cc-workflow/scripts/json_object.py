from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"{path}: {label} must be JSON-compatible YAML for stdlib parsing: {exc}"
        ) from exc

    if not isinstance(value, dict):
        raise SystemExit(
            f"{path}: {label} must be a JSON object; received {json_value_kind(value)}."
        )
    return value


def json_value_kind(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, list):
        return "array"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    return type(value).__name__
