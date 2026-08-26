#!/usr/bin/env python3
"""Extract explicit skill-use evidence from a local agent session.

The extractor emits only validated skill names and aggregate diagnostics. It
never emits transcript text, tool payloads, commands, paths, or reasoning.
Claude Code, Codex, and Cursor JSONL shapes are auto-detected through the
shared session-search parser.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Iterable, Iterator, Optional, Set, cast

from session_common import (
    AtomicOutput,
    JsonObject,
    Platform,
    TranscriptDiagnostics,
    TranscriptShapeError,
    iter_platform_events,
    object_field,
    object_list_field,
    string_field,
)


parser = argparse.ArgumentParser(add_help=True)
parser.add_argument(
    "--output",
    metavar="PATH",
    help="Write evidence JSON to PATH instead of stdout. Stdout receives a one-line status.",
)
parser.add_argument(
    "--known-skill",
    action="append",
    default=[],
    metavar="NAME",
    help="Allow one trusted installed skill name. Repeat for every known skill.",
)
args = parser.parse_args()

output = AtomicOutput(args.output)

SKILL_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}")
SKILL_PATH = re.compile(r"(?:^|[/\\])skills[/\\]([A-Za-z0-9][A-Za-z0-9._:-]{0,127})[/\\]SKILL\.md\b")
SLASH_SKILL = re.compile(r"(?:^|\s)/([A-Za-z0-9][A-Za-z0-9._:-]{0,127})(?=$|[\s,.;!?])")
DIRECT_SKILL_TOOLS = {"skill", "read_skill"}
PATH_READ_TOOLS = {"open", "read", "read_file", "read_skill", "skill", "view"}
SHELL_READ_TOOLS = {"bash", "exec_command", "local_shell_call", "shell"}
SHELL_READ_COMMAND = re.compile(
    r"(?:^|[;&|]\s*)(?:rtk\s+)?(?:bat|cat|grep|head|less|rg|sed|tail)\b",
    re.IGNORECASE,
)
INJECTED_BLOCK = re.compile(
    r"<(?:local-command-caveat|local-command-stderr|local-command-stdout|"
    r"system-reminder|system_instruction|task-notification)[^>]*>.*?"
    r"</(?:local-command-caveat|local-command-stderr|local-command-stdout|"
    r"system-reminder|system_instruction|task-notification)>",
    re.DOTALL | re.IGNORECASE,
)


def iter_strings(value: object, depth: int = 0) -> Iterator[str]:
    """Yield strings from a bounded tool-input structure."""
    if depth > 6:
        return
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for nested in value.values():
            yield from iter_strings(nested, depth + 1)
    elif isinstance(value, list):
        for nested in value:
            yield from iter_strings(nested, depth + 1)


def valid_skill_name(value: object) -> Optional[str]:
    if not isinstance(value, str):
        return None
    candidate = value.strip()
    return candidate if SKILL_NAME.fullmatch(candidate) else None


known_skills: Set[str] = set()
for raw_name in args.known_skill:
    known_name = valid_skill_name(raw_name)
    if known_name is None:
        parser.error("--known-skill must be a valid skill name")
    known_skills.add(known_name)


def names_from_paths(value: object) -> Set[str]:
    names: Set[str] = set()
    for text in iter_strings(value):
        names.update(match.group(1) for match in SKILL_PATH.finditer(text))
    return names


def checked_tool_input(tool_input: object) -> JsonObject:
    """Decode one tool input and reject malformed nested payloads."""
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except (json.JSONDecodeError, ValueError) as error:
            raise TranscriptShapeError("tool input is invalid JSON") from error
    if not isinstance(tool_input, dict):
        raise TranscriptShapeError("tool input is not an object")
    return cast(JsonObject, tool_input)


def shell_reads_skill_path(tool_input: JsonObject) -> bool:
    for key in ("cmd", "command"):
        command = tool_input.get(key)
        if isinstance(command, str) and SHELL_READ_COMMAND.search(command):
            return True
        if isinstance(command, list):
            for part in command:
                if isinstance(part, str) and SHELL_READ_COMMAND.search(part):
                    return True
    return False


def names_from_tool(tool_name: str, raw_tool_input: object) -> Set[str]:
    """Return candidate names without retaining the source tool input."""
    tool_input = checked_tool_input(raw_tool_input)
    normalized_tool = tool_name.lower()
    names: Set[str] = set()

    if normalized_tool in PATH_READ_TOOLS or (
        normalized_tool in SHELL_READ_TOOLS and shell_reads_skill_path(tool_input)
    ):
        names.update(names_from_paths(tool_input))

    if normalized_tool not in DIRECT_SKILL_TOOLS:
        return names

    for key in ("skill", "name", "bundled_skill_id"):
        candidate = valid_skill_name(tool_input.get(key))
        if candidate:
            names.add(candidate)
    return names


def text_content(value: object, field: str) -> Iterable[str]:
    """Yield checked user-authored text blocks, excluding tool results."""
    if isinstance(value, str):
        return (value,)
    if not isinstance(value, list):
        raise TranscriptShapeError(f"{field} is neither text nor a list")

    texts = []
    for block in value:
        if not isinstance(block, dict):
            raise TranscriptShapeError(f"{field}[] is not an object")
        if block.get("type") in ("input_text", "text"):
            texts.append(string_field(cast(JsonObject, block), "text"))
    return texts


def user_texts(event: JsonObject, platform: Platform) -> Iterable[str]:
    """Return only checked user-message text for the detected platform."""
    if platform == "claude":
        if event.get("type") != "user":
            return ()
        return text_content(object_field(event, "message").get("content", ""), "content")

    if platform == "cursor":
        if event.get("role") != "user":
            return ()
        return text_content(object_field(event, "message").get("content", ""), "content")

    if event.get("type") == "event_msg":
        payload = object_field(event, "payload")
        if payload.get("type") == "user_message":
            return (string_field(payload, "message"),)
        return ()

    if event.get("type") == "response_item":
        payload = object_field(event, "payload")
        if payload.get("type") == "message" and payload.get("role") == "user":
            return text_content(payload.get("content", []), "content")
    return ()


def names_from_user_text(text: str) -> Set[str]:
    """Extract explicit slash commands after removing injected wrapper blocks."""
    checked_text = INJECTED_BLOCK.sub("", text)
    return {match.group(1) for match in SLASH_SKILL.finditer(checked_text)}


def claude_or_cursor_tools(
    event: JsonObject,
    platform: Platform,
) -> Iterable[tuple[str, object]]:
    if platform == "claude":
        if event.get("type") != "assistant":
            return ()
        message = object_field(event, "message")
    else:
        if event.get("role") != "assistant":
            return ()
        message = object_field(event, "message")

    tools = []
    for block in object_list_field(message, "content"):
        if block.get("type") == "tool_use":
            tools.append((string_field(block, "name", "unknown"), block.get("input", {})))
    return tools


def codex_tools(event: JsonObject) -> Iterable[tuple[str, object]]:
    if event.get("type") != "response_item":
        return ()
    payload = object_field(event, "payload")
    if payload.get("type") not in ("function_call", "custom_tool_call", "local_shell_call"):
        return ()
    tool_input = payload.get("arguments", payload.get("input", {}))
    return ((string_field(payload, "name", str(payload.get("type"))), tool_input),)


diagnostics = TranscriptDiagnostics()
platforms: Set[str] = set()
skills: Set[str] = set()
skill_events = 0
unknown_skill_events = 0

for platform, event in iter_platform_events(sys.stdin, diagnostics):
    platforms.add(platform)
    try:
        prompt_names: Set[str] = set()
        for text in user_texts(event, platform):
            prompt_names.update(names_from_user_text(text))
        if prompt_names:
            accepted = prompt_names & known_skills
            skills.update(accepted)
            if accepted:
                skill_events += 1
            if prompt_names - known_skills:
                unknown_skill_events += 1

        tools = codex_tools(event) if platform == "codex" else claude_or_cursor_tools(event, platform)
        for tool_name, tool_input in tools:
            detected = names_from_tool(tool_name, tool_input)
            if detected:
                accepted = detected & known_skills
                skills.update(accepted)
                if accepted:
                    skill_events += 1
                if detected - known_skills:
                    unknown_skill_events += 1
    except TranscriptShapeError:
        diagnostics.record_parse_error()

result = {
    "_meta": True,
    "platforms": sorted(platforms),
    "skills": sorted(skills),
    "skill_events": skill_events,
    "unknown_skill_events": unknown_skill_events,
    "lines": diagnostics.lines,
    "parse_errors": diagnostics.partial_errors,
}
print(json.dumps(result))

if output.enabled:
    output_status = output.commit()
    print(json.dumps({"_meta": True, **output_status, **result}))
