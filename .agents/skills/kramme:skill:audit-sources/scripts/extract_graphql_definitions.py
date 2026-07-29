#!/usr/bin/env python3
"""Extract selected top-level GraphQL definitions from a schema on stdin."""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Sequence

DEFINITION_RE = re.compile(
    r"^(?:extend\s+)?(?:enum|input|interface|scalar|type|union)\s+"
    r"([_A-Za-z][_0-9A-Za-z]*)\b"
)


def _description_start(lines: list[str], definition_index: int) -> int:
    previous = definition_index - 1
    if previous < 0:
        return definition_index

    stripped = lines[previous].strip()
    if stripped.startswith("#"):
        while previous > 0 and lines[previous - 1].strip().startswith("#"):
            previous -= 1
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


def _definition_end(lines: list[str], definition_index: int) -> int:
    depth = 0
    opened = False
    in_block_string = False

    for line_index in range(definition_index, len(lines)):
        line = lines[line_index]
        in_string = False
        escaped = False
        column = 0

        while column < len(line):
            if line.startswith('"""', column) and not in_string:
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
                opened = True
                depth += 1
            elif character == "}":
                depth -= 1
                if depth < 0:
                    raise ValueError(f"unexpected closing brace in definition on line {definition_index + 1}")
                if opened and depth == 0:
                    return line_index
            column += 1

        if not opened:
            return line_index

    raise ValueError(f"unclosed GraphQL definition on line {definition_index + 1}")


def extract_definitions(source: str, names: Sequence[str]) -> str:
    """Return requested definitions, including adjacent descriptions, in request order."""
    requested = list(dict.fromkeys(names))
    if not requested:
        raise ValueError("at least one GraphQL definition name is required")

    lines = source.splitlines()
    locations: dict[str, int] = {}
    for line_index, line in enumerate(lines):
        match = DEFINITION_RE.match(line)
        if not match:
            continue
        name = match.group(1)
        if name in locations:
            raise ValueError(f"duplicate top-level GraphQL definition: {name}")
        locations[name] = line_index

    missing = [name for name in requested if name not in locations]
    if missing:
        raise ValueError("missing GraphQL definitions: " + ", ".join(missing))

    sections: list[str] = []
    for name in requested:
        definition_index = locations[name]
        start = _description_start(lines, definition_index)
        end = _definition_end(lines, definition_index)
        sections.append("\n".join(lines[start : end + 1]).strip())
    return "\n\n".join(sections) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract named top-level definitions from a GraphQL schema on stdin.")
    parser.add_argument("names", nargs="+", help="Definition names in output order.")
    args = parser.parse_args()

    try:
        output = extract_definitions(sys.stdin.read(), args.names)
    except ValueError as error:
        print(f"extract_graphql_definitions.py: {error}", file=sys.stderr)
        return 1

    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
