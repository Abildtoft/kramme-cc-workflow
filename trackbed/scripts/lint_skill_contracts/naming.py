"""Invocable names for shipped components.

Skill and agent frontmatter names carry no prefix; Claude Code puts the plugin name
in front of them, and the Codex converter adds the same prefix, so users and
models invoke every shipped skill and agent as ``trackbed:<name>``.
"""

from __future__ import annotations

PLUGIN_NAMESPACE = "trackbed"


def qualified_name(name: str) -> str:
    """Return the invocable ``trackbed:<name>`` form of a frontmatter name."""
    return f"{PLUGIN_NAMESPACE}:{name}"
