from __future__ import annotations

import re
from typing import Any

from .strings import is_empty_value, strip_quotes


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
