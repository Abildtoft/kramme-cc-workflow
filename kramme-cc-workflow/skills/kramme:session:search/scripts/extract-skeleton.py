#!/usr/bin/env python3
# Adapted from EveryInc compound-engineering-plugin, ce-sessions/scripts/extract-skeleton.py.
# Upstream repository: https://github.com/EveryInc/compound-engineering-plugin
# Upstream commit reviewed: 6f9ab03a031c054a8046659926251fb6c149269f
# License: MIT, Copyright (c) 2025 Every.
#
"""Build a local event outline from a Claude Code, Codex, or Cursor JSONL session file.

Usage:
  cat <session.jsonl> | python3 extract-skeleton.py
  cat <session.jsonl> | python3 extract-skeleton.py --output PATH

Auto-detects platform (Claude Code, Codex, or Cursor) from the JSONL structure.
Extracts:
  - User messages (text only, no tool results)
  - Assistant text (no thinking/reasoning blocks)
  - Collapsed tool call summaries (consecutive same-tool calls grouped)

Consecutive tool calls of the same type are collapsed:
  3+ Read calls -> "[tools] 3x Read (file1, file2, +1 more) -> all ok"
Codex call/result pairs are deduplicated (only the result with status is kept).

When --output PATH is given, the extracted skeleton is written to PATH and
stdout receives only a one-line JSON status (_meta with wrote/bytes/stats).
This lets callers route bulk content to a scratch file without round-tripping
extraction bytes through orchestrator tool results.

Without --output, extracted content goes to stdout and ends with a _meta line.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Callable, TypedDict

from session_common import (
    AtomicOutput,
    JsonObject,
    Platform,
    TranscriptDiagnostics,
    TranscriptShapeError,
    iter_platform_events,
    object_field,
    object_list_field,
    object_list_value,
    redact_sensitive,
    string_field,
    string_list_field,
    string_value,
)

EventHandler = Callable[[JsonObject], None]


class ToolEntry(TypedDict, total=False):
    ts: str
    name: str
    target: str
    status: str
    id: str

parser = argparse.ArgumentParser(add_help=True)
parser.add_argument(
    "--output",
    metavar="PATH",
    help="Write extracted skeleton to PATH instead of stdout. Stdout receives a one-line _meta status.",
)
args = parser.parse_args()

output = AtomicOutput(args.output)

stats: dict[str, int] = {
    "lines": 0,
    "parse_errors": 0,
    "user": 0,
    "assistant": 0,
    "tool": 0,
}

# Claude Code wrapper tags to strip from user message content.
# Strip entirely (tag + content): framework noise and raw command output.
# Strip tags only (keep content): command-message, command-name, command-args, user_query.
_STRIP_BLOCK = re.compile(
    r"<(?:task-notification|local-command-caveat|local-command-stdout|local-command-stderr|system-reminder)[^>]*>.*?</(?:task-notification|local-command-caveat|local-command-stdout|local-command-stderr|system-reminder)>",
    re.DOTALL,
)
_STRIP_TAG = re.compile(
    r"</?(?:command-message|command-name|command-args|user_query)[^>]*>"
)


def clean_text(text: str) -> str:
    """Strip framework wrapper tags from message text (Claude and Cursor)."""
    text = _STRIP_BLOCK.sub("", text)
    text = _STRIP_TAG.sub("", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return redact_sensitive(text)


# Buffer for pending tool entries: [{"ts", "name", "target", "status"}]
pending_tools: list[ToolEntry] = []


def flush_tools() -> None:
    """Print buffered tool entries, collapsing consecutive same-name groups."""
    if not pending_tools:
        return

    # Group consecutive entries by tool name
    groups: list[list[ToolEntry]] = []
    for entry in pending_tools:
        if groups and groups[-1][0]["name"] == entry["name"]:
            groups[-1].append(entry)
        else:
            groups.append([entry])

    for group in groups:
        name = group[0]["name"]
        if len(group) <= 2:
            # Print individually
            for e in group:
                status = f" -> {e['status']}" if e.get("status") else ""
                ts_prefix = f"[{e['ts']}] " if e.get("ts") else ""
                print(f"{ts_prefix}[tool] {name} {e['target']}{status}")
                stats["tool"] += 1
        else:
            # Collapse
            ts = group[0].get("ts", "")
            targets = [e["target"] for e in group if e.get("target")]
            ok = sum(1 for e in group if e.get("status") == "ok")
            err = sum(1 for e in group if e.get("status") and e["status"] != "ok")
            no_status = len(group) - ok - err

            # Show first 2 targets, then "+N more"
            if len(targets) > 2:
                target_str = ", ".join(targets[:2]) + f", +{len(targets) - 2} more"
            elif targets:
                target_str = ", ".join(targets)
            else:
                target_str = ""

            if no_status == len(group):
                status_str = ""
            elif err == 0:
                status_str = " -> all ok"
            else:
                status_str = f" -> {ok} ok, {err} error"

            ts_prefix = f"[{ts}] " if ts else ""
            print(f"{ts_prefix}[tools] {len(group)}x {name} ({target_str}){status_str}")
            stats["tool"] += len(group)

    pending_tools.clear()


def _safe_slice(value: object, n: int) -> str:
    """Slice value if it is a string; otherwise return ''.

    Some Claude Code / MCP tool inputs put structured data (dicts, lists) in
    fields like `query` or `prompt`. `dict[:N]` raises TypeError, so guard
    every slice with an isinstance check.
    """
    return value[:n] if isinstance(value, str) else ""


def summarize_claude_tool(block: JsonObject) -> tuple[str, str]:
    """Extract name and target from a Claude Code tool_use block."""
    name = string_field(block, "name", "unknown")
    inp = object_field(block, "input")
    fp = inp.get("file_path")
    p = inp.get("path")
    target = (
        (fp if isinstance(fp, str) else None)
        or (p if isinstance(p, str) else None)
        or _safe_slice(inp.get("command"), 120)
        or _safe_slice(inp.get("pattern"), 200)
        or _safe_slice(inp.get("query"), 80)
        or _safe_slice(inp.get("prompt"), 80)
        or ""
    )
    if isinstance(target, str) and len(target) > 120:
        target = target[:120]
    return name, redact_sensitive(target)


def handle_claude(obj: JsonObject) -> None:
    msg_type = obj.get("type")
    ts = string_field(obj, "timestamp")[:19]

    if msg_type == "user":
        msg = object_field(obj, "message")
        content = msg.get("content", "")

        if isinstance(content, list):
            blocks = object_list_value(content, "content")
            for block in blocks:
                if block.get("type") == "tool_result":
                    is_error = block.get("is_error", False)
                    status = "error" if is_error else "ok"
                    tool_use_id = block.get("tool_use_id")
                    matched = False
                    if tool_use_id:
                        tool_use_id = string_value(tool_use_id, "tool_use_id")
                        for entry in pending_tools:
                            if entry.get("id") == tool_use_id:
                                entry["status"] = status
                                matched = True
                                break
                    if not matched:
                        # Fallback: assign to earliest pending entry without a status
                        for entry in pending_tools:
                            if not entry.get("status"):
                                entry["status"] = status
                                break

            texts = [
                string_field(block, "text")
                for block in blocks
                if block.get("type") == "text" and len(string_field(block, "text")) > 10
            ]
            content = " ".join(texts)
        elif not isinstance(content, str):
            raise TranscriptShapeError("content is neither text nor a list of objects")

        content = clean_text(content)
        if len(content) > 15:
            flush_tools()
            print(f"[{ts}] [user] {content[:800]}")
            print("---")
            stats["user"] += 1

    elif msg_type == "assistant":
        msg = object_field(obj, "message")
        has_text = False
        for block in object_list_field(msg, "content"):
            if block.get("type") == "text":
                text = clean_text(string_field(block, "text"))
                if len(text) > 20:
                    if not has_text:
                        flush_tools()
                        has_text = True
                    print(f"[{ts}] [assistant] {text[:800]}")
                    print("---")
                    stats["assistant"] += 1
            elif block.get("type") == "tool_use":
                name, target = summarize_claude_tool(block)
                tool_entry: ToolEntry = {
                    "ts": ts,
                    "name": name,
                    "target": target,
                }
                tool_id = block.get("id")
                if tool_id:
                    tool_entry["id"] = string_value(tool_id, "id")
                pending_tools.append(tool_entry)


def handle_codex(obj: JsonObject) -> None:
    msg_type = obj.get("type")
    ts = string_field(obj, "timestamp")[:19]

    if msg_type == "event_msg":
        p = object_field(obj, "payload")
        if p.get("type") == "user_message":
            text = string_field(p, "message")
            if len(text) > 15:
                parts = text.split("</system_instruction>")
                user_text = parts[-1].strip() if parts else text
                user_text = clean_text(user_text)
                if len(user_text) > 15:
                    flush_tools()
                    print(f"[{ts}] [user] {user_text[:800]}")
                    print("---")
                    stats["user"] += 1

        elif p.get("type") == "exec_command_end":
            # This is the deduplicated result — has status info
            command = string_list_field(p, "command")
            cmd_str = command[-1] if command else ""
            command_output = string_field(p, "aggregated_output")

            status = "ok"
            if "Process exited with code " in command_output:
                try:
                    code = int(
                        command_output.split("Process exited with code ")[1].split("\n")[0]
                    )
                    if code != 0:
                        status = f"error(exit {code})"
                except (IndexError, ValueError):
                    pass

            if cmd_str:
                # Shorten common patterns for readability
                short_cmd = redact_sensitive(cmd_str[:120])
                pending_tools.append({"ts": ts, "name": "exec", "target": short_cmd, "status": status})

    elif msg_type == "response_item":
        p = object_field(obj, "payload")
        if p.get("type") == "message" and p.get("role") == "assistant":
            for block in object_list_field(p, "content"):
                block_text = string_field(block, "text")
                if block.get("type") == "output_text" and len(block_text) > 20:
                    text = clean_text(block_text)
                    flush_tools()
                    print(f"[{ts}] [assistant] {text[:800]}")
                    print("---")
                    stats["assistant"] += 1

        # Skip function_call — exec_command_end is the deduplicated version with status


def handle_cursor(obj: JsonObject) -> None:
    """Cursor agent transcripts: role-based, no timestamps, same content structure as Claude."""
    role = obj.get("role")
    message = object_field(obj, "message")
    content = object_list_field(message, "content")

    if role == "user":
        texts: list[str] = []
        for block in content:
            if block.get("type") == "text":
                texts.append(string_field(block, "text"))
        text = clean_text(" ".join(texts))
        if len(text) > 15:
            flush_tools()
            # No timestamps available in Cursor transcripts
            print(f"[user] {text[:800]}")
            print("---")
            stats["user"] += 1

    elif role == "assistant":
        has_text = False
        for block in content:
            if block.get("type") == "text":
                text = clean_text(string_field(block, "text"))
                # Skip [REDACTED] placeholder blocks
                if len(text) > 20 and text.strip() != "[REDACTED]":
                    if not has_text:
                        flush_tools()
                        has_text = True
                    print(f"[assistant] {text[:800]}")
                    print("---")
                    stats["assistant"] += 1
            elif block.get("type") == "tool_use":
                name = string_field(block, "name", "unknown")
                inp = object_field(block, "input")
                p = inp.get("path")
                fp = inp.get("file_path")
                target = (
                    (p if isinstance(p, str) else None)
                    or (fp if isinstance(fp, str) else None)
                    or _safe_slice(inp.get("command"), 120)
                    or _safe_slice(inp.get("pattern"), 200)
                    or _safe_slice(inp.get("glob_pattern"), 200)
                    or _safe_slice(inp.get("target_directory"), 200)
                    or ""
                )
                if isinstance(target, str) and len(target) > 120:
                    target = target[:120]
                # No status info available — Cursor doesn't log tool results
                pending_tools.append(
                    {
                        "ts": "",
                        "name": name,
                        "target": redact_sensitive(target),
                    }
                )


handlers: dict[Platform, EventHandler] = {
    "claude": handle_claude,
    "codex": handle_codex,
    "cursor": handle_cursor,
}

diagnostics = TranscriptDiagnostics()
for platform, event in iter_platform_events(sys.stdin, diagnostics):
    try:
        handlers[platform](event)
    except TranscriptShapeError:
        diagnostics.record_parse_error()

# Flush any remaining buffered tools
flush_tools()

stats["lines"] = diagnostics.lines
stats["parse_errors"] = diagnostics.partial_errors
print(json.dumps({"_meta": True, **stats}))

if output.enabled:
    output_status = output.commit()
    print(json.dumps({"_meta": True, **output_status, **stats}))
