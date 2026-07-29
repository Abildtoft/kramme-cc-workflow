#!/usr/bin/env python3
"""Extract selected named GraphQL type-system definitions from a schema."""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from urllib.parse import urlsplit
from urllib.request import urlopen

DEFINITION_RE = re.compile(
    r"^\s*(?:(?P<extension>extend)\s+)?"
    r"(?P<kind>enum|input|interface|scalar|type|union)\s+"
    r"(?P<name>[_A-Za-z][_0-9A-Za-z]*)\b"
)
OTHER_DEFINITION_RE = re.compile(
    r"^\s*(?:"
    r"(?:extend\s+)?schema\b"
    r"|directive\s+@[_A-Za-z][_0-9A-Za-z]*\b"
    r")"
)
SINGLE_LINE_DESCRIPTION_RE = re.compile(r'^"(?:\\.|[^"\\])*"(?:\s*#.*)?$')
BRACED_DEFINITION_KINDS = {"enum", "input", "interface", "type"}
FETCH_TIMEOUT_SECONDS = 30


@dataclass(frozen=True)
class DefinitionLocation:
    line_index: int
    kind: str
    name: str
    is_extension: bool


def _is_escaped(text: str, column: int) -> bool:
    backslashes = 0
    previous = column - 1
    while previous >= 0 and text[previous] == "\\":
        backslashes += 1
        previous -= 1
    return backslashes % 2 == 1


def _scan_braces(line: str, in_block_string: bool) -> tuple[int, int, bool]:
    opens = 0
    closes = 0
    in_string = False
    escaped = False
    column = 0

    while column < len(line):
        if line.startswith('"""', column) and not in_string and not _is_escaped(line, column):
            in_block_string = not in_block_string
            column += 3
            continue

        character = line[column]
        if in_block_string:
            column += 1
            continue
        if not in_string and character == "#":
            break
        if character == '"' and not escaped:
            in_string = not in_string
            column += 1
            continue
        if in_string:
            escaped = character == "\\" and not escaped
            if character != "\\":
                escaped = False
            column += 1
            continue

        if character == "{":
            opens += 1
        elif character == "}":
            closes += 1
        column += 1

    return opens, closes, in_block_string


def _find_definitions(
    lines: list[str],
) -> tuple[list[DefinitionLocation], dict[int, int | None]]:
    definitions: list[DefinitionLocation] = []
    boundary_indexes: list[int] = []
    depth = 0
    in_block_string = False

    for line_index, line in enumerate(lines):
        if depth == 0 and not in_block_string:
            match = DEFINITION_RE.match(line)
            if match:
                boundary_indexes.append(line_index)
                definitions.append(
                    DefinitionLocation(
                        line_index=line_index,
                        kind=match.group("kind"),
                        name=match.group("name"),
                        is_extension=match.group("extension") is not None,
                    )
                )
            elif OTHER_DEFINITION_RE.match(line):
                boundary_indexes.append(line_index)

        opens, closes, in_block_string = _scan_braces(line, in_block_string)
        depth += opens - closes
        if depth < 0:
            raise ValueError(f"unexpected closing brace on line {line_index + 1}")

    if depth != 0:
        raise ValueError("unclosed GraphQL definition")
    if in_block_string:
        raise ValueError("unclosed GraphQL block string")
    next_boundary_indexes = {
        boundary_index: (boundary_indexes[index + 1] if index + 1 < len(boundary_indexes) else None)
        for index, boundary_index in enumerate(boundary_indexes)
    }
    return definitions, next_boundary_indexes


def _description_start(lines: list[str], definition_index: int) -> int:
    previous = definition_index - 1
    if previous < 0:
        return definition_index

    stripped = lines[previous].strip()
    if stripped.startswith("#"):
        while previous > 0 and lines[previous - 1].strip().startswith("#"):
            previous -= 1
        return previous

    if SINGLE_LINE_DESCRIPTION_RE.fullmatch(stripped):
        return previous

    if not stripped.endswith('"""'):
        return definition_index
    if stripped.count('"""') >= 2:
        return previous

    previous -= 1
    while previous >= 0:
        if '"""' in lines[previous]:
            return previous
        previous -= 1
    return definition_index


def _definition_end(
    lines: list[str],
    definition: DefinitionLocation,
    next_definition_index: int | None,
) -> int:
    if definition.kind not in BRACED_DEFINITION_KINDS:
        if next_definition_index is None:
            end = len(lines) - 1
        else:
            end = _description_start(lines, next_definition_index) - 1
        while end > definition.line_index and not lines[end].strip():
            end -= 1
        return end

    depth = 0
    opened = False
    in_block_string = False
    limit = next_definition_index if next_definition_index is not None else len(lines)

    for line_index in range(definition.line_index, limit):
        line = lines[line_index]
        opens, closes, in_block_string = _scan_braces(line, in_block_string)
        if opens:
            opened = True
        depth += opens - closes
        if depth < 0:
            raise ValueError(f"unexpected closing brace in definition on line {definition.line_index + 1}")
        if opened and depth == 0:
            return line_index

    raise ValueError(f"unclosed GraphQL definition on line {definition.line_index + 1}")


def extract_definitions(source: str, names: Sequence[str]) -> str:
    """Return requested definitions, including adjacent descriptions, in request order."""
    requested = list(dict.fromkeys(names))
    if not requested:
        raise ValueError("at least one GraphQL definition name is required")

    lines = source.splitlines()
    definitions, next_boundary_indexes = _find_definitions(lines)
    requested_set = set(requested)
    locations: dict[str, list[tuple[DefinitionLocation, int | None]]] = {name: [] for name in requested}
    base_definitions: set[str] = set()

    for definition in definitions:
        if definition.name not in requested_set:
            continue
        if not definition.is_extension:
            if definition.name in base_definitions:
                raise ValueError(f"duplicate top-level GraphQL definition: {definition.name}")
            base_definitions.add(definition.name)
        next_definition_index = next_boundary_indexes[definition.line_index]
        locations[definition.name].append((definition, next_definition_index))

    missing = [name for name in requested if not locations[name]]
    if missing:
        raise ValueError("missing GraphQL definitions: " + ", ".join(missing))

    sections: list[str] = []
    for name in requested:
        for definition, next_definition_index in locations[name]:
            start = _description_start(lines, definition.line_index)
            end = _definition_end(lines, definition, next_definition_index)
            sections.append("\n".join(lines[start : end + 1]).strip())
    return "\n\n".join(sections) + "\n"


def read_source(url: str | None) -> str:
    """Read a schema from stdin or fetch it locally without exposing it to model context."""
    if url is None:
        return sys.stdin.read()

    parsed_url = urlsplit(url)
    if parsed_url.scheme != "https" or not parsed_url.netloc:
        raise ValueError("GraphQL schema URL must use HTTPS")

    try:
        with urlopen(url, timeout=FETCH_TIMEOUT_SECONDS) as response:
            return bytes(response.read()).decode("utf-8")
    except (OSError, UnicodeError, ValueError) as error:
        raise ValueError(f"could not read GraphQL schema from {url}: {error}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract named GraphQL type-system definitions from a schema.")
    parser.add_argument(
        "--url",
        help="Fetch the schema locally from this URL instead of reading stdin.",
    )
    parser.add_argument("names", nargs="+", help="Definition names in output order.")
    args = parser.parse_args()

    try:
        output = extract_definitions(read_source(args.url), args.names)
    except ValueError as error:
        print(f"extract_graphql_definitions.py: {error}", file=sys.stderr)
        return 1

    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
