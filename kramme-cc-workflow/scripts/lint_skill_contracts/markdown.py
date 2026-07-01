from __future__ import annotations

import html
import re


def split_markdown_table_row(line: str) -> list[str]:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return []

    cells: list[str] = []
    current: list[str] = []
    escaped = False
    for char in stripped:
        if char == "\\" and not escaped:
            escaped = True
            current.append(char)
            continue
        if char == "|" and not escaped:
            cells.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        escaped = False
    cells.append("".join(current).strip())

    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    return cells


def normalize_markdown_cell(value: str) -> str:
    normalized = re.sub(r"<!--.*?-->", "", value)
    normalized = normalized.replace("<br><br>", " ").replace("<br>", " ")
    normalized = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", normalized)
    normalized = html.unescape(normalized)
    normalized = normalized.replace("`", "")
    normalized = normalized.replace(r"\|", "|")
    normalized = normalized.replace(r"\<", "<").replace(r"\>", ">")
    normalized = normalized.replace(r"\[", "[").replace(r"\]", "]")
    return re.sub(r"\s+", " ", normalized).strip()


def escape_markdown_table_cell(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\n", " ")).strip().replace("|", r"\|")
