from __future__ import annotations

import re
from typing import Any

from .schema import schema_skill_frontmatter_fields
from .strings import is_empty_value, strip_quotes

_YAML_BOOLEAN_VALUES = {"true", "false"}
_YAML_NULL_VALUES = {"", "null", "~"}
_YAML_NUMBER_PATTERN = re.compile(r"^-?[0-9]+(?:\.[0-9]+)?$")
_YAML_FLOW_NUMBER_PATTERN = re.compile(
    r"^[+-]?(?:[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?"
    r"|\.[0-9]+(?:[eE][+-]?[0-9]+)?|0o[0-7]+|0x[0-9a-fA-F]+"
    r"|\.(?:inf|Inf|INF|nan|NaN|NAN))$"
)
_YAML_BLOCK_SCALAR_PATTERN = re.compile(
    r"^[|>](?:[+-][1-9]?|[1-9][+-]?)?(?:\s+#.*)?$"
)
_YAML_DOUBLE_QUOTE_ESCAPES = {
    "0": "\0",
    "a": "\a",
    "b": "\b",
    "t": "\t",
    "n": "\n",
    "v": "\v",
    "f": "\f",
    "r": "\r",
    "e": "\x1b",
    " ": " ",
    '"': '"',
    "/": "/",
    "\\": "\\",
    "N": "\u0085",
    "_": "\u00a0",
    "L": "\u2028",
    "P": "\u2029",
}
_YAML_HEX_ESCAPE_LENGTHS = {"x": 2, "u": 4, "U": 8}


def parse_frontmatter(text: str) -> dict[str, str] | None:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return None
    end = None
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            end = index
            break
    if end is None:
        return None

    frontmatter: dict[str, str] = {}
    for line in lines[1:end]:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            frontmatter[match.group(1)] = strip_quotes(match.group(2))
    return frontmatter


def parse_frontmatter_bool(frontmatter: dict[str, str], field: str) -> bool:
    return strip_quotes(frontmatter.get(field, "")).lower() == "true"


def frontmatter_type_errors(
    text: str,
    schema: dict[str, Any] | None = None,
) -> list[tuple[str, str]]:
    """Return schema type errors without changing the linter's string parser."""
    values = _raw_frontmatter_values(text)
    errors: list[tuple[str, str]] = []
    for field, contract in schema_skill_frontmatter_fields(schema).items():
        if field not in values or not isinstance(contract, dict):
            continue
        expected_type = contract.get("type")
        value = values[field]
        if expected_type == "string" and not _is_non_empty_yaml_string(value):
            errors.append((field, "a non-empty string"))
        elif expected_type == "boolean" and not _is_yaml_boolean(value):
            errors.append((field, "a boolean ('true' or 'false')"))
        elif expected_type == "string_array" and not _is_non_empty_string_array(value):
            errors.append((field, "a non-empty array of non-empty strings"))
    return errors


def _raw_frontmatter_values(text: str) -> dict[str, str | list[str]]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}

    values: dict[str, str | list[str]] = {}
    index = 1
    while index < end:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", lines[index])
        if not match:
            index += 1
            continue
        field, raw_value = match.groups()
        if _YAML_BLOCK_SCALAR_PATTERN.fullmatch(raw_value.strip()):
            scalar_lines: list[str] = []
            scalar_index = index + 1
            while scalar_index < end:
                line = lines[scalar_index]
                if line and not line[0].isspace():
                    break
                if line.strip():
                    scalar_lines.append(line.strip())
                scalar_index += 1
            values[field] = "\n".join(scalar_lines)
            index = scalar_index
            continue
        if raw_value:
            values[field] = raw_value.strip()
            index += 1
            continue

        items: list[str] = []
        item_index = index + 1
        while item_index < end:
            item_line = lines[item_index]
            if not item_line.strip() or item_line.lstrip().startswith("#"):
                item_index += 1
                continue
            item_match = re.match(r"^\s+-\s*(.*)$", item_line)
            if not item_match:
                break
            item = item_match.group(1).strip()
            item_indent = len(item_line) - len(item_line.lstrip())
            if _YAML_BLOCK_SCALAR_PATTERN.fullmatch(item):
                scalar_lines: list[str] = []
                scalar_index = item_index + 1
                while scalar_index < end:
                    scalar_line = lines[scalar_index]
                    if (
                        scalar_line.strip()
                        and _leading_whitespace(scalar_line) <= item_indent
                    ):
                        break
                    if scalar_line.strip():
                        scalar_lines.append(scalar_line.strip())
                    scalar_index += 1
                items.append("\n".join(scalar_lines))
                item_index = scalar_index
                continue
            if re.match(r"^[^\[\]{},]+:(?:\s|$)", item) and _has_indented_child(
                lines, item_index + 1, end, item_indent
            ):
                items.append("{")
            else:
                items.append(item)
            item_index += 1
        if items:
            values[field] = items
        else:
            values[field] = _continued_plain_scalar(lines, index + 1, end)
        index = item_index
    return values


def _leading_whitespace(line: str) -> int:
    return len(line) - len(line.lstrip())


def _has_indented_child(
    lines: list[str], start: int, end: int, parent_indent: int
) -> bool:
    for index in range(start, end):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        return _leading_whitespace(line) > parent_indent
    return False


def _continued_plain_scalar(lines: list[str], start: int, end: int) -> str:
    scalar_lines: list[str] = []
    index = start
    while index < end:
        line = lines[index]
        if line and not line[0].isspace():
            break
        if line.strip() and not line.lstrip().startswith("#"):
            normalized = line.strip()
            if re.match(r"^[^\[\]{},]+:(?:\s|$)", normalized):
                return ""
            scalar_lines.append(normalized)
        index += 1
    return "\n".join(scalar_lines)


def _is_yaml_boolean(value: str | list[str]) -> bool:
    if isinstance(value, list):
        return False
    decoded = _decode_yaml_quoted_string(value.strip())
    normalized = (
        (decoded if decoded is not None else strip_quotes(value)).strip().lower()
    )
    return normalized in _YAML_BOOLEAN_VALUES


def _is_non_empty_yaml_string(value: str | list[str]) -> bool:
    return _is_non_empty_yaml_scalar_string(value, case_insensitive=False)


def _is_non_empty_yaml_scalar_string(
    value: str | list[str],
    *,
    case_insensitive: bool,
) -> bool:
    if isinstance(value, list):
        return False
    normalized = value.strip()
    decoded = _decode_yaml_quoted_string(normalized)
    if decoded is not None:
        return bool(decoded.strip())
    keyword = normalized.lower() if case_insensitive else normalized
    if keyword in _YAML_NULL_VALUES or keyword in _YAML_BOOLEAN_VALUES:
        return False
    if _YAML_NUMBER_PATTERN.fullmatch(normalized):
        return False
    return bool(normalized)


def _is_non_empty_string_array(value: str | list[str]) -> bool:
    items = value if isinstance(value, list) else _parse_inline_array(value)
    if isinstance(value, list):
        return bool(items) and all(
            _is_non_empty_yaml_block_string(item) for item in items
        )
    return bool(items) and all(_is_non_empty_yaml_flow_string(item) for item in items)


def _is_non_empty_yaml_block_string(value: str) -> bool:
    if value.strip().startswith(("[", "{")):
        return False
    return _is_non_empty_yaml_scalar_string(value, case_insensitive=False)


def _is_non_empty_yaml_flow_string(value: str) -> bool:
    normalized = value.strip()
    decoded = _decode_yaml_quoted_string(normalized)
    if decoded is not None:
        return bool(decoded.strip())
    if normalized.startswith(("[", "{")):
        return False
    if re.match(r"^[^\[\]{},]+:(?:\s|$)", normalized):
        return False
    if _YAML_FLOW_NUMBER_PATTERN.fullmatch(normalized):
        return False
    return _is_non_empty_yaml_scalar_string(normalized, case_insensitive=True)


def _parse_inline_array(value: str) -> list[str]:
    normalized = value.strip()
    if not (normalized.startswith("[") and normalized.endswith("]")):
        return []
    inner = normalized[1:-1].strip()
    if not inner:
        return []

    items: list[str] = []
    current: list[str] = []
    quote: str | None = None
    index = 0
    while index < len(inner):
        character = inner[index]
        if quote == '"' and character == "\\" and index + 1 < len(inner):
            current.extend((character, inner[index + 1]))
            index += 2
            continue
        if quote == "'" and character == "'" and index + 1 < len(inner):
            if inner[index + 1] == "'":
                current.extend((character, character))
                index += 2
                continue
        if character in {'"', "'"}:
            if quote is None:
                quote = character
            elif quote == character:
                quote = None
            current.append(character)
        elif character == "," and quote is None:
            items.append("".join(current).strip())
            current = []
        else:
            current.append(character)
        index += 1
    if quote is not None:
        return []
    items.append("".join(current).strip())
    return items


def _decode_yaml_quoted_string(value: str) -> str | None:
    if len(value) < 2 or value[0] != value[-1] or value[0] not in {'"', "'"}:
        return None
    inner = value[1:-1]
    if value[0] == "'":
        return inner.replace("''", "'")

    decoded: list[str] = []
    index = 0
    while index < len(inner):
        character = inner[index]
        if character != "\\":
            decoded.append(character)
            index += 1
            continue
        if index + 1 >= len(inner):
            return None
        escape = inner[index + 1]
        if escape in _YAML_DOUBLE_QUOTE_ESCAPES:
            decoded.append(_YAML_DOUBLE_QUOTE_ESCAPES[escape])
            index += 2
            continue
        digits = _YAML_HEX_ESCAPE_LENGTHS.get(escape)
        if digits is None or index + 2 + digits > len(inner):
            return None
        raw_codepoint = inner[index + 2 : index + 2 + digits]
        if not re.fullmatch(r"[0-9a-fA-F]+", raw_codepoint):
            return None
        try:
            decoded.append(chr(int(raw_codepoint, 16)))
        except ValueError:
            return None
        index += 2 + digits
    return "".join(decoded)


def expected_invocation(
    frontmatter: dict[str, str],
    schema: dict[str, Any] | None = None,
) -> str:
    from .schema import skill_frontmatter_field_by_loader_property

    user_invocable_field = skill_frontmatter_field_by_loader_property(
        "userInvocable",
        "user-invocable",
        schema,
    )
    disable_model_invocation_field = skill_frontmatter_field_by_loader_property(
        "disableModelInvocation",
        "disable-model-invocation",
        schema,
    )
    user_invocable = parse_frontmatter_bool(frontmatter, user_invocable_field)
    model_invocation_enabled = not parse_frontmatter_bool(
        frontmatter,
        disable_model_invocation_field,
    )
    if user_invocable and model_invocation_enabled:
        return "User, Auto"
    if user_invocable:
        return "User"
    if model_invocation_enabled:
        return "Background"
    return "Hidden"


def expected_arguments(
    frontmatter: dict[str, str],
    schema: dict[str, Any] | None = None,
) -> str:
    from .schema import skill_frontmatter_field_by_loader_property

    user_invocable_field = skill_frontmatter_field_by_loader_property(
        "userInvocable",
        "user-invocable",
        schema,
    )
    argument_hint_field = skill_frontmatter_field_by_loader_property(
        "argumentHint",
        "argument-hint",
        schema,
    )
    if not parse_frontmatter_bool(frontmatter, user_invocable_field):
        return "—"
    argument_hint = frontmatter.get(argument_hint_field)
    if is_empty_value(argument_hint):
        return "—"
    return strip_quotes(str(argument_hint))
