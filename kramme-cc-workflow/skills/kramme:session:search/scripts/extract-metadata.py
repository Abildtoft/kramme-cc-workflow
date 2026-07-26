#!/usr/bin/env python3
# Adapted from EveryInc compound-engineering-plugin, ce-sessions/scripts/extract-metadata.py.
# Upstream repository: https://github.com/EveryInc/compound-engineering-plugin
# Upstream commit reviewed: 6f9ab03a031c054a8046659926251fb6c149269f
# License: MIT, Copyright (c) 2025 Every.
#
"""Extract session metadata from Claude Code, Codex, and Cursor JSONL files.

Batch mode (preferred — one invocation for all files):
  python3 extract-metadata.py /path/to/dir/*.jsonl
  python3 extract-metadata.py file1.jsonl file2.jsonl file3.jsonl

Single-file mode (stdin):
  head -20 <session.jsonl> | python3 extract-metadata.py

Auto-detects platform from the JSONL structure.
Outputs one JSON object per file, one per line.
Includes a final _meta line with processing stats.
"""
from __future__ import annotations

import itertools
import json
import os
import sys
from datetime import datetime, timezone
from typing import Dict, Iterator, Optional, Sequence

from session_common import (
    JsonObject,
    TranscriptDiagnostics,
    TranscriptShapeError,
    decode_json_object,
    iter_json_objects,
    object_field,
    object_list_field,
    string_field,
)

Metadata = Dict[str, object]

MAX_LINES = 25  # Only need first ~25 lines for metadata
TAIL_BYTES = 16384  # Read last 16KB to find final timestamp past trailing metadata


def try_claude(
    obj: JsonObject,
    diagnostics: TranscriptDiagnostics,
) -> Optional[Metadata]:
    if obj.get("type") != "user" or "gitBranch" not in obj:
        return None
    try:
        return {
            "platform": "claude",
            "branch": string_field(obj, "gitBranch"),
            "ts": string_field(obj, "timestamp"),
            "session": string_field(obj, "sessionId"),
        }
    except TranscriptShapeError:
        diagnostics.record_parse_error()
    return None


def update_codex(
    obj: JsonObject,
    meta: Metadata,
    diagnostics: TranscriptDiagnostics,
) -> tuple[bool, bool]:
    event_type = obj.get("type")
    if event_type == "session_meta":
        try:
            payload = object_field(obj, "payload")
            session_id = string_field(payload, "id")
            if not session_id:
                raise TranscriptShapeError("session_meta payload has no session id")
            timestamp = (
                string_field(payload, "timestamp")
                if "timestamp" in payload
                else string_field(obj, "timestamp")
            )
            candidate: Metadata = {
                "platform": "codex",
                "cwd": string_field(payload, "cwd"),
                "session": session_id,
                "ts": timestamp,
                "source": string_field(payload, "source"),
                "cli_version": string_field(payload, "cli_version"),
            }
        except TranscriptShapeError:
            diagnostics.record_parse_error()
            return False, False
        meta.update(candidate)
        return True, False

    if event_type == "turn_context":
        try:
            payload = object_field(obj, "payload")
            model = string_field(payload, "model")
            context_cwd = string_field(payload, "cwd")
            existing_cwd = string_field(meta, "cwd")
        except TranscriptShapeError:
            diagnostics.record_parse_error()
            return False, False
        meta.update(
            {
                "model": model,
                "cwd": existing_cwd or context_cwd,
            }
        )
        return False, True

    return False, False


def try_cursor(
    obj: JsonObject,
) -> Optional[Metadata]:
    if obj.get("role") in ("user", "assistant") and "type" not in obj:
        return {"platform": "cursor"}
    return None


def extract_from_lines(
    lines: Sequence[str],
) -> tuple[Optional[Metadata], TranscriptDiagnostics]:
    diagnostics = TranscriptDiagnostics()
    claude_result: Optional[Metadata] = None
    codex_meta: Metadata = {}
    found_session_metadata = False
    saw_turn_context = False
    cursor_result: Optional[Metadata] = None

    for obj in iter_json_objects(lines, diagnostics):
        if claude_result is None:
            claude_result = try_claude(obj, diagnostics)
        found_session, saw_context = update_codex(obj, codex_meta, diagnostics)
        found_session_metadata = found_session_metadata or found_session
        saw_turn_context = saw_turn_context or saw_context
        if cursor_result is None:
            cursor_result = try_cursor(obj)

    result: Optional[Metadata]
    if claude_result is not None:
        result = claude_result
    elif found_session_metadata:
        result = codex_meta
    else:
        result = cursor_result

    if result is None and saw_turn_context:
        diagnostics.record_parse_error()
    elif result is None and diagnostics.partial_errors == 0:
        diagnostics.record_parse_error()
    return result, diagnostics


def get_last_timestamp(
    filepath: str,
    size: int,
) -> tuple[Optional[str], TranscriptDiagnostics]:
    """Read the tail of a file to find the last checked timestamp."""
    diagnostics = TranscriptDiagnostics()
    try:
        with open(filepath, "rb") as session_file:
            start = max(0, size - TAIL_BYTES)
            session_file.seek(start)
            tail = session_file.read().decode("utf-8", errors="ignore")
    except (OSError, IOError):
        diagnostics.record_read_error()
        return None, diagnostics

    lines = tail.splitlines()
    if start > 0 and lines:
        lines = lines[1:]
    for line in reversed(lines):
        stripped = line.strip()
        if not stripped:
            continue
        diagnostics.lines += 1
        try:
            obj = decode_json_object(stripped)
            if "timestamp" in obj:
                return string_field(obj, "timestamp"), diagnostics
        except TranscriptShapeError:
            diagnostics.record_parse_error()
    return None, diagnostics


def _iter_user_assistant_text(
    filepath: str,
    diagnostics: TranscriptDiagnostics,
) -> Iterator[str]:
    """Yield only user/assistant text while counting malformed content shapes."""
    try:
        with open(filepath, "r", errors="replace") as session_file:
            for line in session_file:
                stripped = line.strip()
                if not stripped:
                    continue
                diagnostics.lines += 1
                try:
                    obj = decode_json_object(stripped)

                    # Claude Code: type-tagged top-level
                    event_type = obj.get("type")
                    if event_type == "user":
                        message = object_field(obj, "message")
                        content = message.get("content")
                        if isinstance(content, str):
                            yield content
                        elif content is not None:
                            for block in object_list_field(message, "content"):
                                if block.get("type") == "text":
                                    yield string_field(block, "text")
                                # Tool results are intentionally excluded.
                        continue
                    if event_type == "assistant":
                        message = object_field(obj, "message")
                        for block in object_list_field(message, "content"):
                            if block.get("type") == "text":
                                yield string_field(block, "text")
                            # Tool use and thinking blocks are intentionally excluded.
                        continue

                    # Codex: payload-typed events
                    if event_type == "event_msg":
                        payload = object_field(obj, "payload")
                        if payload.get("type") == "user_message":
                            codex_message = string_field(payload, "message")
                            parts = codex_message.split("</system_instruction>")
                            yield parts[-1] if parts else codex_message
                        continue
                    if event_type == "response_item":
                        payload = object_field(obj, "payload")
                        if (
                            payload.get("type") == "message"
                            and payload.get("role") == "assistant"
                        ):
                            for block in object_list_field(payload, "content"):
                                if block.get("type") == "output_text":
                                    yield string_field(block, "text")
                        continue

                    # Cursor: role-tagged with no top-level type
                    if (
                        obj.get("role") in ("user", "assistant")
                        and "type" not in obj
                    ):
                        message = object_field(obj, "message")
                        for block in object_list_field(message, "content"):
                            if block.get("type") == "text":
                                yield string_field(block, "text")
                except TranscriptShapeError:
                    diagnostics.record_parse_error()
    except (OSError, IOError):
        diagnostics.record_read_error()


class KeywordCounter:
    """Count non-overlapping matches without retaining the complete transcript."""

    _MARKERS = ("\0", "\x01", "\x02", "\x03", "\ufffe", "\uffff")

    def __init__(self, keyword: str) -> None:
        self.keyword = keyword
        self.remainder = ""
        self.count = 0

    def feed(self, text: str) -> None:
        combined = self.remainder + text
        marker = next(
            (candidate for candidate in self._MARKERS if candidate not in combined),
            None,
        )
        if marker is None:
            self._feed_without_marker(combined)
            return

        collapsed = combined.replace(self.keyword, marker)
        self.count += collapsed.count(marker)
        unmatched_tail = collapsed[collapsed.rfind(marker) + 1 :]
        self.remainder = (
            unmatched_tail[-len(self.keyword) + 1 :]
            if len(self.keyword) > 1
            else ""
        )

    def _feed_without_marker(self, combined: str) -> None:
        """Fall back when unusually broad text contains every reserved marker."""
        search_from = 0
        while True:
            match_at = combined.find(self.keyword, search_from)
            if match_at < 0:
                break
            self.count += 1
            search_from = match_at + len(self.keyword)

        suffix_start = max(search_from, len(combined) - len(self.keyword) + 1)
        self.remainder = combined[suffix_start:]


def count_keyword_matches(
    filepath: str,
    keywords: Sequence[str],
) -> tuple[dict[str, int], TranscriptDiagnostics]:
    """Count keywords in checked user/assistant text and return diagnostics."""
    counters = {keyword: KeywordCounter(keyword.lower()) for keyword in keywords}
    diagnostics = TranscriptDiagnostics()
    first_chunk = True
    for chunk in _iter_user_assistant_text(filepath, diagnostics):
        if not first_chunk:
            for counter in counters.values():
                counter.feed("\n")
        lowered_chunk = chunk.lower()
        for counter in counters.values():
            counter.feed(lowered_chunk)
        first_chunk = False
    return (
        {keyword: counter.count for keyword, counter in counters.items()},
        diagnostics,
    )


def process_file(
    filepath: str,
) -> tuple[Optional[Metadata], TranscriptDiagnostics]:
    """Extract checked metadata and diagnostics for one file."""
    diagnostics = TranscriptDiagnostics()
    try:
        size = os.path.getsize(filepath)
        with open(filepath, "r", encoding="utf-8", errors="replace") as session_file:
            lines = list(itertools.islice(session_file, MAX_LINES))
    except (OSError, IOError):
        diagnostics.record_read_error()
        return None, diagnostics

    result, header_diagnostics = extract_from_lines(lines)
    diagnostics.add(header_diagnostics)
    if result is None:
        return None, diagnostics

    result["file"] = filepath
    result["size"] = size
    if result["platform"] == "cursor":
        try:
            mtime = os.path.getmtime(filepath)
        except (OSError, IOError):
            diagnostics.record_read_error()
            return None, diagnostics
        result["ts"] = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()
        result["session"] = os.path.basename(os.path.dirname(filepath))
    else:
        last_ts, tail_diagnostics = get_last_timestamp(filepath, size)
        diagnostics.add(tail_diagnostics)
        if last_ts:
            result["last_ts"] = last_ts
    return result, diagnostics


# Parse arguments: files and optional --cwd-filter / --keyword
files: list[str] = []
cwd_filter: Optional[str] = None
keywords: Optional[list[str]] = None
args = sys.argv[1:]
i = 0
while i < len(args):
    if args[i] == "--cwd-filter" and i + 1 < len(args):
        cwd_filter = args[i + 1]
        i += 2
    elif args[i] == "--keyword" and i + 1 < len(args):
        keywords = [keyword for keyword in args[i + 1].split(",") if keyword]
        i += 2
    elif not args[i].startswith("-"):
        files.append(args[i])
        i += 1
    else:
        i += 1

if files:
    # Batch mode: isolate every file so later valid sessions always survive.
    processed = 0
    parse_errors = 0
    read_errors = 0
    filtered = 0
    matched = 0
    for filepath in files:
        if not filepath.endswith(".jsonl"):
            continue
        result, diagnostics = process_file(filepath)
        processed += 1
        should_print = result is not None
        if result is not None:
            result_cwd = result.get("cwd")
            if not isinstance(result_cwd, str):
                result_cwd = None
            if cwd_filter and result_cwd and cwd_filter not in result_cwd:
                filtered += 1
                should_print = False
            elif keywords:
                matches, keyword_diagnostics = count_keyword_matches(
                    filepath,
                    keywords,
                )
                diagnostics.add(keyword_diagnostics)
                result["keyword_matches"] = matches
                match_count = sum(matches.values())
                result["match_count"] = match_count
                if match_count == 0:
                    should_print = False
                else:
                    matched += 1
            if should_print:
                print(json.dumps(result))

        parse_errors += diagnostics.partial_errors
        read_errors += diagnostics.read_errors

    meta: dict[str, object] = {
        "_meta": True,
        "files_processed": processed,
        "parse_errors": parse_errors,
    }
    if read_errors:
        meta["read_errors"] = read_errors
    if filtered:
        meta["filtered_by_cwd"] = filtered
    if keywords:
        meta["files_matched"] = matched
    print(json.dumps(meta))
else:
    # No file arguments: either single-file stdin mode or empty xargs invocation.
    if sys.stdin.isatty():
        lines = []
    else:
        lines = list(itertools.islice(sys.stdin, MAX_LINES))

    if not lines:
        meta = {"_meta": True, "files_processed": 0, "parse_errors": 0}
        if keywords:
            meta["files_matched"] = 0
        print(json.dumps(meta))
    else:
        result, diagnostics = extract_from_lines(lines)
        if result:
            print(json.dumps(result))
        meta = {
            "_meta": True,
            "files_processed": 1,
            "parse_errors": diagnostics.partial_errors,
        }
        if diagnostics.read_errors:
            meta["read_errors"] = diagnostics.read_errors
        print(json.dumps(meta))
