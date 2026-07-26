#!/usr/bin/env python3
# Adapted from EveryInc compound-engineering-plugin, ce-sessions/scripts/extract-errors.py.
# Upstream repository: https://github.com/EveryInc/compound-engineering-plugin
# Upstream commit reviewed: 6f9ab03a031c054a8046659926251fb6c149269f
# License: MIT, Copyright (c) 2025 Every.
#
"""Extract error signals from a Claude Code, Codex, or Cursor JSONL session file.

Usage:
  cat <session.jsonl> | python3 extract-errors.py
  cat <session.jsonl> | python3 extract-errors.py --output PATH

Auto-detects platform from the JSONL structure.
Note: Cursor agent transcripts do not log tool results, so no errors can be extracted.
Finds failed tool calls / commands and outputs them with timestamps.

When --output PATH is given, the extracted error log is written to PATH and
stdout receives only a one-line JSON status (_meta with wrote/bytes/stats).
This lets callers route bulk content to a scratch file without round-tripping
extraction bytes through orchestrator tool results.

Without --output, extracted content goes to stdout and ends with a _meta line.
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Callable

from session_common import (
    AtomicOutput,
    JsonObject,
    Platform,
    TranscriptDiagnostics,
    TranscriptShapeError,
    iter_platform_events,
    object_field,
    object_list_field,
    redact_sensitive,
    string_field,
    string_list_field,
)

EventHandler = Callable[[JsonObject], None]

parser = argparse.ArgumentParser(add_help=True)
parser.add_argument(
    "--output",
    metavar="PATH",
    help="Write extracted errors to PATH instead of stdout. Stdout receives a one-line _meta status.",
)
args = parser.parse_args()

output = AtomicOutput(args.output)

stats: dict[str, int] = {"lines": 0, "parse_errors": 0, "errors_found": 0}


def summarize_error(raw: object) -> str:
    """Extract a short error summary instead of dumping the full payload."""
    text = str(raw).strip()
    # Take the first non-empty line as the error message
    for line in text.split("\n"):
        line = line.strip()
        if line:
            return redact_sensitive(line[:200])
    return redact_sensitive(text[:200])


def handle_claude(obj: JsonObject) -> None:
    if obj.get("type") == "user":
        message = object_field(obj, "message")
        content = message.get("content")
        if isinstance(content, str) or content is None:
            return
        for block in object_list_field(message, "content"):
            if block.get("type") == "tool_result" and block.get("is_error"):
                ts = string_field(obj, "timestamp")[:19]
                summary = summarize_error(block.get("content", ""))
                print(f"[{ts}] [error] {summary}")
                print("---")
                stats["errors_found"] += 1


def handle_codex(obj: JsonObject) -> None:
    if obj.get("type") == "event_msg":
        p = object_field(obj, "payload")
        if p.get("type") == "exec_command_end":
            command_output = string_field(p, "aggregated_output")
            stderr = string_field(p, "stderr")
            command = string_list_field(p, "command")
            cmd_str = command[-1] if command else ""

            exit_match = None
            if "Process exited with code " in command_output:
                try:
                    code_str = command_output.split("Process exited with code ")[1].split(
                        "\n"
                    )[0]
                    exit_code = int(code_str)
                    if exit_code != 0:
                        exit_match = exit_code
                except (IndexError, ValueError):
                    pass

            if exit_match is not None or stderr:
                ts = string_field(obj, "timestamp")[:19]
                error_summary = summarize_error(stderr if stderr else command_output)
                print(f"[{ts}] [error] exit={exit_match} cmd={redact_sensitive(cmd_str[:120])}: {error_summary}")
                print("---")
                stats["errors_found"] += 1


# Cursor transcripts don't log tool results — no errors to extract
def handle_noop(obj: JsonObject) -> None:
    pass

handlers: dict[Platform, EventHandler] = {
    "claude": handle_claude,
    "codex": handle_codex,
    "cursor": handle_noop,
}

diagnostics = TranscriptDiagnostics()
for platform, event in iter_platform_events(sys.stdin, diagnostics):
    try:
        handlers[platform](event)
    except TranscriptShapeError:
        diagnostics.record_parse_error()

stats["lines"] = diagnostics.lines
stats["parse_errors"] = diagnostics.partial_errors
print(json.dumps({"_meta": True, **stats}))

if output.enabled:
    output_status = output.commit()
    print(json.dumps({"_meta": True, **output_status, **stats}))
