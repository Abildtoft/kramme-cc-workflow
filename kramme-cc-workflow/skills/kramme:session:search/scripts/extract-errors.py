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
import atexit
import itertools
import os
import sys
import json
import re
import tempfile
from typing import Callable, Dict, Iterator, Literal, Optional, Pattern, cast

JsonObject = Dict[str, object]
Platform = Literal["claude", "codex", "cursor"]
EventHandler = Callable[[JsonObject], None]

parser = argparse.ArgumentParser(add_help=True)
parser.add_argument(
    "--output",
    metavar="PATH",
    help="Write extracted errors to PATH instead of stdout. Stdout receives a one-line _meta status.",
)
args = parser.parse_args()

_original_stdout = sys.stdout
_temporary_output_path: Optional[str] = None
if args.output:
    output_dir = os.path.dirname(os.path.abspath(args.output))
    temporary_output = tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=output_dir,
        prefix=f".{os.path.basename(args.output)}.",
        delete=False,
    )
    _temporary_output_path = temporary_output.name
    sys.stdout = temporary_output


def cleanup_temporary_output() -> None:
    if _temporary_output_path:
        try:
            os.unlink(_temporary_output_path)
        except FileNotFoundError:
            pass


atexit.register(cleanup_temporary_output)

stats: dict[str, int] = {"lines": 0, "parse_errors": 0, "errors_found": 0}

_SENSITIVE_PATTERNS: list[Pattern[str]] = [
    re.compile(r"(?i)\b(authorization\s*:\s*bearer\s+)[A-Za-z0-9._~+/=-]{12,}"),
    re.compile(r"(?i)\b((?:api[_-]?key|token|secret|password|passwd|pwd)\s*[:=]\s*)[^\s'\"`;&|]{8,}"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
]


def redact_sensitive(text: object) -> str:
    """Redact common credential shapes before writing extract files."""
    if not isinstance(text, str):
        return ""

    redacted = text
    for pattern in _SENSITIVE_PATTERNS:
        redacted = pattern.sub(lambda m: (m.group(1) if m.lastindex else "") + "[REDACTED]", redacted)
    return redacted


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
        message = cast(JsonObject, obj.get("message", {}))
        content = message.get("content", [])
        if isinstance(content, list):
            for block in cast(list[JsonObject], content):
                if block.get("type") == "tool_result" and block.get("is_error"):
                    ts = cast(str, obj.get("timestamp", ""))[:19]
                    summary = summarize_error(block.get("content", ""))
                    print(f"[{ts}] [error] {summary}")
                    print("---")
                    stats["errors_found"] += 1


def handle_codex(obj: JsonObject) -> None:
    if obj.get("type") == "event_msg":
        p = cast(JsonObject, obj.get("payload", {}))
        if p.get("type") == "exec_command_end":
            output = cast(str, p.get("aggregated_output", ""))
            stderr = cast(str, p.get("stderr", ""))
            command = cast(list[str], p.get("command", []))
            cmd_str = command[-1] if command else ""

            exit_match = None
            if "Process exited with code " in output:
                try:
                    code_str = output.split("Process exited with code ")[1].split("\n")[0]
                    exit_code = int(code_str)
                    if exit_code != 0:
                        exit_match = exit_code
                except (IndexError, ValueError):
                    pass

            if exit_match is not None or stderr:
                ts = cast(str, obj.get("timestamp", ""))[:19]
                error_summary = summarize_error(stderr if stderr else output)
                print(f"[{ts}] [error] exit={exit_match} cmd={redact_sensitive(cmd_str[:120])}: {error_summary}")
                print("---")
                stats["errors_found"] += 1


# Auto-detect from a bounded prefix, replay that prefix once, then stream the
# remaining events without retaining the transcript.
def nonempty_input_lines() -> Iterator[str]:
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if line:
            stats["lines"] += 1
            yield line


detected: Optional[Platform] = None
prefix: list[str] = []
lines = nonempty_input_lines()
for line in itertools.islice(lines, 10):
    prefix.append(line)
    if not detected:
        try:
            obj = cast(JsonObject, json.loads(line))
            if obj.get("type") in ("user", "assistant"):
                detected = "claude"
            elif obj.get("type") in ("session_meta", "turn_context", "response_item", "event_msg"):
                detected = "codex"
            elif obj.get("role") in ("user", "assistant") and "type" not in obj:
                detected = "cursor"
        except (json.JSONDecodeError, KeyError):
            pass
    if detected:
        break

# Cursor transcripts don't log tool results — no errors to extract
def handle_noop(obj: JsonObject) -> None:
    pass

handlers: dict[Platform, EventHandler] = {
    "claude": handle_claude,
    "codex": handle_codex,
    "cursor": handle_noop,
}
handler = handlers[detected] if detected is not None else handle_noop

for line in itertools.chain(prefix, lines):
    try:
        handler(cast(JsonObject, json.loads(line)))
    except (json.JSONDecodeError, KeyError):
        stats["parse_errors"] += 1

print(json.dumps({"_meta": True, **stats}))

if args.output:
    sys.stdout.flush()
    sys.stdout.close()
    sys.stdout = _original_stdout
    os.replace(cast(str, _temporary_output_path), args.output)
    _temporary_output_path = None
    bytes_written = os.path.getsize(args.output)
    print(json.dumps({"_meta": True, "wrote": args.output, "bytes": bytes_written, **stats}))
