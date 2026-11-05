from __future__ import annotations

import re


def shorten(value: str, limit: int = 180) -> str:
    if len(value) <= limit:
        return value
    return value[: limit - 3] + "..."


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def is_empty_value(value: str | None) -> bool:
    if value is None:
        return True
    return strip_quotes(value).strip() == ""


def normalize_value(value: str, normalizer: str | None) -> str:
    value = value.replace("`", "").strip()
    if normalizer == "linewise":
        return "\n".join(line.strip() for line in value.splitlines())
    if normalizer == "status_vocabulary":
        parts = [part.strip().upper() for part in re.split(r"\s*(?:\||,)\s*", value)]
        return " | ".join(part for part in parts if part)
    return re.sub(r"\s+", " ", value)
