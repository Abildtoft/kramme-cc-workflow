# Adapted from EveryInc compound-engineering-plugin, ce-sessions scripts.
# Upstream repository: https://github.com/EveryInc/compound-engineering-plugin
# Upstream commit reviewed: 6f9ab03a031c054a8046659926251fb6c149269f
# License: MIT, Copyright (c) 2025 Every.
#
"""Shared safety boundary for session-search transcript extractors."""

from __future__ import annotations

import atexit
import json
import os
import re
import sys
import tempfile
from typing import (
    Dict,
    Iterable,
    Iterator,
    List,
    Literal,
    Optional,
    Pattern,
    TextIO,
    Tuple,
    cast,
)

JsonObject = Dict[str, object]
Platform = Literal["claude", "codex", "cursor"]


class TranscriptShapeError(ValueError):
    """A decoded transcript value does not match a supported checked shape."""


class TranscriptDiagnostics:
    """Count failed parse and read attempts across extraction passes."""

    def __init__(self) -> None:
        self.lines = 0
        self.parse_errors = 0
        self.read_errors = 0

    def add(self, other: "TranscriptDiagnostics") -> None:
        self.lines += other.lines
        self.parse_errors += other.parse_errors
        self.read_errors += other.read_errors

    def record_parse_error(self) -> None:
        self.parse_errors += 1

    def record_read_error(self) -> None:
        self.read_errors += 1

    @property
    def partial_errors(self) -> int:
        """All failures that make extraction coverage incomplete."""
        return self.parse_errors + self.read_errors


def decode_json_object(line: str) -> JsonObject:
    """Decode one JSONL line and require a top-level object."""
    try:
        value: object = json.loads(line)
    except (json.JSONDecodeError, ValueError) as error:
        raise TranscriptShapeError("invalid JSON") from error
    if not isinstance(value, dict):
        raise TranscriptShapeError("top-level JSON value is not an object")
    return cast(JsonObject, value)


def iter_json_objects(
    lines: Iterable[str],
    diagnostics: TranscriptDiagnostics,
) -> Iterator[JsonObject]:
    """Yield checked JSON objects while counting malformed non-empty lines."""
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        diagnostics.lines += 1
        try:
            yield decode_json_object(line)
        except TranscriptShapeError:
            diagnostics.record_parse_error()


def detect_platform(obj: JsonObject) -> Optional[Platform]:
    """Detect a supported transcript platform from one checked event object."""
    event_type = obj.get("type")
    if event_type in ("user", "assistant"):
        return "claude"
    if event_type in ("session_meta", "turn_context", "response_item", "event_msg"):
        return "codex"
    if obj.get("role") in ("user", "assistant") and "type" not in obj:
        return "cursor"
    return None


def iter_platform_events(
    lines: Iterable[str],
    diagnostics: TranscriptDiagnostics,
) -> Iterator[Tuple[Platform, JsonObject]]:
    """Decode a transcript and yield events after its platform is detected."""
    platform: Optional[Platform] = None
    for event in iter_json_objects(lines, diagnostics):
        if platform is None:
            platform = detect_platform(event)
            if platform is None:
                continue
        yield platform, event


def object_value(value: object, field: str) -> JsonObject:
    """Require a mapping value."""
    if not isinstance(value, dict):
        raise TranscriptShapeError(f"{field} is not an object")
    return cast(JsonObject, value)


def object_field(obj: JsonObject, key: str) -> JsonObject:
    """Read an optional object field, rejecting a present wrong-shaped value."""
    if key not in obj:
        return {}
    return object_value(obj[key], key)


def object_list_value(value: object, field: str) -> List[JsonObject]:
    """Require a list whose elements are all mappings."""
    if not isinstance(value, list):
        raise TranscriptShapeError(f"{field} is not a list")
    return [object_value(item, f"{field}[]") for item in value]


def object_list_field(obj: JsonObject, key: str) -> List[JsonObject]:
    """Read an optional list-of-objects field."""
    if key not in obj:
        return []
    return object_list_value(obj[key], key)


def string_value(value: object, field: str, default: str = "") -> str:
    """Require a string when a value is present."""
    if value is None:
        return default
    if not isinstance(value, str):
        raise TranscriptShapeError(f"{field} is not a string")
    return value


def string_field(obj: JsonObject, key: str, default: str = "") -> str:
    """Read an optional checked string field."""
    if key not in obj:
        return default
    return string_value(obj[key], key, default)


def string_list_field(obj: JsonObject, key: str) -> List[str]:
    """Read an optional list whose elements are all strings."""
    if key not in obj:
        return []
    value = obj[key]
    if not isinstance(value, list):
        raise TranscriptShapeError(f"{key} is not a list")
    return [string_value(item, f"{key}[]") for item in value]


_SENSITIVE_PATTERNS: List[Pattern[str]] = [
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
        redacted = pattern.sub(
            lambda match: (match.group(1) if match.lastindex else "") + "[REDACTED]",
            redacted,
        )
    return redacted


class AtomicOutput:
    """Redirect stdout to a temporary file and atomically publish on success."""

    def __init__(self, output_path: Optional[str]) -> None:
        self.output_path = output_path or None
        self._original_stdout = sys.stdout
        self._stream: Optional[TextIO] = None
        self._temporary_path: Optional[str] = None
        if self.output_path is not None:
            output_dir = os.path.dirname(os.path.abspath(self.output_path))
            stream = cast(
                TextIO,
                tempfile.NamedTemporaryFile(
                    mode="w",
                    encoding="utf-8",
                    dir=output_dir,
                    prefix=f".{os.path.basename(self.output_path)}.",
                    delete=False,
                ),
            )
            self._stream = stream
            self._temporary_path = stream.name
            sys.stdout = stream
        atexit.register(self.cleanup)

    @property
    def enabled(self) -> bool:
        """Whether extracted output will be published to a destination path."""
        return self.output_path is not None

    def commit(self) -> Dict[str, object]:
        """Publish redirected output and return fields for the status record."""
        if self.output_path is None:
            return {}
        if self._stream is None or self._temporary_path is None:
            raise RuntimeError("atomic output was not initialized")

        self._stream.flush()
        self._stream.close()
        sys.stdout = self._original_stdout
        bytes_written = os.path.getsize(self._temporary_path)
        os.replace(self._temporary_path, self.output_path)
        self._temporary_path = None
        return {
            "wrote": self.output_path,
            "bytes": bytes_written,
        }

    def cleanup(self) -> None:
        """Restore stdout and remove any unpublished temporary output."""
        if self._stream is not None and sys.stdout is self._stream:
            sys.stdout = self._original_stdout
        if self._stream is not None and not self._stream.closed:
            self._stream.close()
        if self._temporary_path is not None:
            try:
                os.unlink(self._temporary_path)
            except FileNotFoundError:
                pass
