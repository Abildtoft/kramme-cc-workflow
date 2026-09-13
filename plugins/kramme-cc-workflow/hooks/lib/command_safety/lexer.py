"""Command-string tokenization shared by every parser mode.

Turns a raw command string into the token segments the policy modes walk:
heredoc bodies stripped (and their substitutions harvested), newlines folded
into separators, ANSI-C quoting expanded, and command substitutions replaced
by `__CMD_SUBST_<n>__` placeholders the modes can resolve later.

Depends on `prefix` because deciding whether a heredoc body is executable
means normalizing the wrappers in front of the command that reads it.
"""

from __future__ import annotations

import re
import shlex
from collections.abc import Iterator
from typing import Optional, cast

from .prefix import normalize_command_prefix
from .syntax import (
    CONTROL_TOKENS,
    NON_KEYWORD_TIME_SENTINEL,
    SHELL_EXECUTABLES,
    PendingHeredoc,
    ShellWord,
    _basename,
    _collect_heredocs,
    _expand_ansi_c_quoted_strings,
    _extract_body_substitutions,
    _shell_invocation_reads_stdin,
    _tokenize_heredoc_prefix,
    _tokens_for_heredoc_command,
    read_backtick_substitution,
    read_dollar_substitution,
)


def _line_has_supported_shell_stdin_heredoc(line: str, heredoc_start: int) -> bool:
    try:
        tokens = _tokens_for_heredoc_command(_tokenize_heredoc_prefix(line[:heredoc_start]))
    except ValueError:
        return False

    normalized = normalize_command_prefix(tokens)
    if normalized.executable is None or _basename(normalized.executable) not in SHELL_EXECUTABLES:
        return False
    return _shell_invocation_reads_stdin(normalized.arguments)


def strip_heredoc_bodies(command: str) -> tuple[str, list[str]]:
    lines = command.splitlines(keepends=True)
    stripped_lines: list[str] = []
    pending_heredocs: list[PendingHeredoc] = []
    extracted: list[str] = []

    for line in lines:
        if pending_heredocs:
            current = pending_heredocs[0]
            # Strip trailing newline for comparison only.
            compare = line[:-1] if line.endswith("\n") else line
            if current["strip_tabs"]:
                # POSIX: <<- strips leading TABs only (never spaces).
                compare = compare.lstrip("\t")
            if compare == current["delimiter"]:
                stripped_lines.append(line)
                pending_heredocs.pop(0)
                continue
            if current["keep_body"]:
                stripped_lines.append(line)
            elif line.endswith("\n"):
                stripped_lines.append("\n")
            else:
                stripped_lines.append("")
            if not current["quoted"] and not current["keep_body"]:
                # Unquoted heredoc bodies still expand $(...) and `...`.
                body_line = line[:-1] if line.endswith("\n") else line
                extracted.extend(_extract_body_substitutions(body_line))
            continue

        stripped_lines.append(line)
        heredocs = _collect_heredocs(line)
        if heredocs:
            for heredoc in heredocs:
                keep_body = _line_has_supported_shell_stdin_heredoc(line, heredoc["start"])
                pending_heredocs.append(cast(PendingHeredoc, {**heredoc, "keep_body": keep_body}))

    return "".join(stripped_lines), extracted


def normalize_newlines(command: str) -> str:
    command, _ = strip_heredoc_bodies(command)
    normalized: list[str] = []
    in_single = False
    in_double = False
    escaped = False
    idx = 0

    while idx < len(command):
        char = command[idx]
        if char in ("\n", "\r") and not in_single and not in_double:
            if escaped:
                if normalized and normalized[-1] == "\\":
                    normalized.pop()
                escaped = False
                idx += 1
                continue
            normalized.append(";")
            escaped = False
            idx += 1
            continue

        if char in ("\n", "\r") and escaped:
            if normalized and normalized[-1] == "\\":
                normalized.pop()
            escaped = False
            idx += 1
            continue

        normalized.append(char)

        if escaped:
            escaped = False
            idx += 1
            continue

        if char == "\\" and not in_single:
            escaped = True
            idx += 1
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            idx += 1
            continue

        if char == '"' and not in_single:
            in_double = not in_double

        idx += 1

    return "".join(normalized)


def _replace_nonkeyword_time_word(raw_word: str) -> str:
    if raw_word == "time" or not any(marker in raw_word for marker in ("'", '"', "\\")):
        return raw_word
    try:
        parsed_word = shlex.split(raw_word, comments=False, posix=True)
    except ValueError:
        return raw_word
    if parsed_word == ["time"]:
        return NON_KEYWORD_TIME_SENTINEL
    return raw_word


def _mark_nonkeyword_time_words(command: str) -> str:
    """Mark shell words that evaluate to `time` but cannot be the keyword."""
    marked: list[str] = []
    chunk_start = 0
    word_start: Optional[int] = None
    quote: Optional[str] = None
    escaped = False
    idx = 0

    while idx < len(command):
        char = command[idx]
        is_boundary = char in " \t\r\n()|&;"

        if word_start is None:
            if is_boundary:
                idx += 1
                continue
            word_start = idx

        if escaped:
            escaped = False
            idx += 1
            continue

        if quote is not None:
            if char == quote:
                quote = None
            elif quote == '"' and char == "\\":
                escaped = True
            idx += 1
            continue

        if char == "\\":
            escaped = True
            idx += 1
            continue

        if char in {"'", '"'}:
            quote = char
            idx += 1
            continue

        if is_boundary:
            raw_word = command[word_start:idx]
            replacement = _replace_nonkeyword_time_word(raw_word)
            if replacement != raw_word:
                marked.extend((command[chunk_start:word_start], replacement))
                chunk_start = idx
            word_start = None
            continue

        idx += 1

    if word_start is not None:
        raw_word = command[word_start:]
        replacement = _replace_nonkeyword_time_word(raw_word)
        if replacement != raw_word:
            marked.extend((command[chunk_start:word_start], replacement))
            chunk_start = len(command)

    marked.append(command[chunk_start:])
    return "".join(marked)


def tokenize(command: str) -> list[str]:
    command = _expand_ansi_c_quoted_strings(normalize_newlines(command))
    command = _mark_nonkeyword_time_words(command)
    lexer = shlex.shlex(command, posix=True, punctuation_chars="()|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return [
        ShellWord("time", shell_keyword_eligible=False) if token == NON_KEYWORD_TIME_SENTINEL else token
        for token in lexer
    ]


def split_segments(tokens: list[str]) -> Iterator[tuple[list[str], Optional[str]]]:
    current: list[str] = []
    for token in tokens:
        if token in CONTROL_TOKENS:
            if current:
                yield current, token
                current = []
            continue
        current.append(token)
    if current:
        yield current, None


def replace_command_substitutions(command: str) -> tuple[str, list[str]]:
    command, heredoc_body_substitutions = strip_heredoc_bodies(command)
    # Start with any substitutions extracted from unquoted heredoc
    # bodies - they're still executed by the shell and need inspection.
    substitutions = list(heredoc_body_substitutions)
    result: list[str] = []
    idx = 0
    in_single = False
    in_double = False
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            result.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\" and not in_single:
            result.append(char)
            escaped = True
            idx += 1
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            result.append(char)
            idx += 1
            continue

        if char == '"' and not in_single:
            in_double = not in_double
            result.append(char)
            idx += 1
            continue

        if not in_single and command.startswith("$" + "(", idx):
            inner, idx = read_dollar_substitution(command, idx)
            substitutions.append(inner)
            result.append(f"__CMD_SUBST_{len(substitutions) - 1}__")
            continue

        if not in_single and char == chr(96):
            inner, idx = read_backtick_substitution(command, idx)
            substitutions.append(inner)
            result.append(f"__CMD_SUBST_{len(substitutions) - 1}__")
            continue

        result.append(char)
        idx += 1

    return "".join(result), substitutions


def extract_placeholder_indexes(tokens: list[str]) -> list[int]:
    indexes: list[int] = []
    seen: set[int] = set()
    for token in tokens:
        for match in re.finditer(r"__CMD_SUBST_(\d+)__", token):
            index = int(match.group(1))
            if index not in seen:
                seen.add(index)
                indexes.append(index)
    return indexes
