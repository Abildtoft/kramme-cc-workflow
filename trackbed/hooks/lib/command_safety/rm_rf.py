"""`rm-rf` mode: block recoverable-deletion bypasses like `rm -rf` and `shred`.

See README.md#git-command-parser-mode-contracts in the parent directory for
the CLI contract this mode implements.
"""

from __future__ import annotations

import json
import re
from typing import Optional

from .lexer import (
    extract_placeholder_indexes,
    replace_command_substitutions,
    split_segments,
    tokenize,
)
from .prefix import normalize_command_prefix
from .syntax import (
    SHELL_EXECUTABLES,
    SHELL_RESERVED_COMMAND_WORDS,
    _basename,
    _function_body_start,
    _is_assignment,
)
from .vocabulary import _skip_xargs_options

RM_RF_REASON = "rm -rf is blocked. Use `trash` instead (install: brew install trash). Files go to Trash for recovery."
XARGS_RM_RF_REASON = "xargs rm -rf is blocked. Use `trash` instead."
FIND_DELETE_REASON = "find -delete is blocked. Use `trash` instead for recoverable deletion."
FIND_EXEC_RM_RF_REASON = "find -exec rm -rf is blocked. Use `trash` instead."
SHRED_REASON = "shred is blocked. Use `trash` instead for recoverable deletion."
UNLINK_REASON = "unlink is blocked. Use `trash` instead for recoverable deletion."
MAX_ANALYSIS_DEPTH = 5


def _has_rf_flags(args: list[str]) -> bool:
    has_recursive = False
    has_force = False

    for arg in args:
        if arg in {"--recursive", "--directories"}:
            has_recursive = True
            continue
        if arg == "--force":
            has_force = True
            continue
        if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
            continue
        option_letters = arg[1:]
        if "r" in option_letters or "R" in option_letters:
            has_recursive = True
        if "f" in option_letters:
            has_force = True

    return has_recursive and has_force


def _has_literal_rm_rf_text(text: str) -> bool:
    if re.search(r"(^|[^A-Za-z0-9_])rm([^A-Za-z0-9_]|$)", text) is None:
        return False
    has_recursive = re.search(r"(-[A-Za-z]*[rR]|--recursive)", text) is not None
    has_force = re.search(r"(-[A-Za-z]*f|--force)", text) is not None
    return has_recursive and has_force


def _placeholder_indexes_in_text(text: str) -> list[int]:
    return [int(match.group(1)) for match in re.finditer(r"__CMD_SUBST_(\d+)__", text)]


def _literal_placeholder_reason(text: str, substitutions: list[str]) -> Optional[str]:
    for placeholder_index in _placeholder_indexes_in_text(text):
        if placeholder_index < len(substitutions) and _has_literal_rm_rf_text(substitutions[placeholder_index]):
            return RM_RF_REASON
    return None


def _join_tokens_as_command(tokens: list[str]) -> str:
    return " ".join(tokens)


def _detect_process_substitutions(tokens: list[str], substitutions: list[str], depth: int) -> Optional[str]:
    idx = 0
    while idx < len(tokens) - 1:
        if tokens[idx] not in {"<", ">"} or tokens[idx + 1] != "(":
            idx += 1
            continue

        nested_depth = 1
        end = idx + 2
        while end < len(tokens):
            if tokens[end] == "(":
                nested_depth += 1
            elif tokens[end] == ")":
                nested_depth -= 1
                if nested_depth == 0:
                    break
            end += 1

        if nested_depth == 0:
            reason = _detect_rm_rf_segment(tokens[idx + 2 : end], substitutions, depth + 1)
            if reason is not None:
                return reason
            idx = end + 1
            continue

        idx += 1

    return None


def _detect_xargs(args: list[str], substitutions: list[str], depth: int) -> Optional[str]:
    idx = _skip_xargs_options(args)

    if idx >= len(args):
        return None

    if _basename(args[idx]) == "rm" and _has_rf_flags(args[idx + 1 :]):
        return XARGS_RM_RF_REASON

    return _detect_command_at(args, idx, substitutions, depth + 1)


def _find_exec_tokens(args: list[str], start: int) -> list[str]:
    exec_tokens: list[str] = []
    idx = start
    while idx < len(args):
        token = args[idx]
        if token in {";", "+", ";;"}:
            break
        exec_tokens.append(token)
        idx += 1
    return exec_tokens


def _detect_find(args: list[str], substitutions: list[str], depth: int) -> Optional[str]:
    idx = 0
    while idx < len(args):
        token = args[idx]
        if token == "-delete":
            return FIND_DELETE_REASON
        if token in {"-exec", "-execdir"}:
            exec_tokens = _find_exec_tokens(args, idx + 1)
            if exec_tokens and _basename(exec_tokens[0]) == "rm" and _has_rf_flags(exec_tokens[1:]):
                return FIND_EXEC_RM_RF_REASON
            reason = _detect_rm_rf_segment(exec_tokens, substitutions, depth + 1)
            if reason is not None:
                return reason
            idx += len(exec_tokens) + 1
            continue
        idx += 1
    return None


def _detect_command_at(tokens: list[str], idx: int, substitutions: list[str], depth: int) -> Optional[str]:
    normalized = normalize_command_prefix(tokens[idx:])
    if normalized.executable is None:
        return None

    token = normalized.executable
    args = normalized.arguments
    base = _basename(token)

    if base in SHELL_EXECUTABLES:
        payload = normalized.nested_shell_command
        if payload is None:
            return None
        literal_reason = _literal_placeholder_reason(payload, substitutions)
        if literal_reason is not None:
            return literal_reason
        return _detect_rm_rf_command(payload, depth + 1)

    if base == "eval":
        payload = _join_tokens_as_command(args)
        literal_reason = _literal_placeholder_reason(payload, substitutions)
        if literal_reason is not None:
            return literal_reason
        if payload:
            return _detect_rm_rf_command(payload, depth + 1)
        return None

    if base == "xargs":
        return _detect_xargs(args, substitutions, depth)

    if base == "find":
        return _detect_find(args, substitutions, depth)

    if base == "shred":
        return SHRED_REASON

    if base == "unlink":
        return UNLINK_REASON

    if base == "rm" and _has_rf_flags(args):
        return RM_RF_REASON

    return None


def _detect_rm_rf_segment(tokens: list[str], substitutions: list[str], depth: int) -> Optional[str]:
    if depth > MAX_ANALYSIS_DEPTH:
        return RM_RF_REASON

    process_reason = _detect_process_substitutions(tokens, substitutions, depth)
    if process_reason is not None:
        return process_reason

    idx = 0
    command_context = True
    while idx < len(tokens):
        token = tokens[idx]

        if token == ")":
            command_context = True
            idx += 1
            continue

        if not command_context:
            idx += 1
            continue

        if token in SHELL_RESERVED_COMMAND_WORDS or _is_assignment(token):
            command_context = True
            idx += 1
            continue

        function_body_idx = _function_body_start(tokens, idx)
        if function_body_idx is not None:
            idx = function_body_idx + 1
            command_context = True
            continue

        reason = _detect_command_at(tokens, idx, substitutions, depth)
        if reason is not None:
            return reason

        command_context = False
        idx += 1

    return None


def _detect_rm_rf_command(command: str, depth: int = 0) -> Optional[str]:
    if depth > MAX_ANALYSIS_DEPTH:
        return RM_RF_REASON

    sanitized_command, substitutions = replace_command_substitutions(command)
    tokens = tokenize(sanitized_command)
    used_placeholder_indexes: set[int] = set()

    for segment, _separator in split_segments(tokens):
        for placeholder_index in extract_placeholder_indexes(segment):
            used_placeholder_indexes.add(placeholder_index)
            if placeholder_index < len(substitutions):
                reason = _detect_rm_rf_command(substitutions[placeholder_index], depth + 1)
                if reason is not None:
                    return reason

        reason = _detect_rm_rf_segment(segment, substitutions, depth)
        if reason is not None:
            return reason

    for placeholder_index, substitution in enumerate(substitutions):
        if placeholder_index in used_placeholder_indexes:
            continue
        reason = _detect_rm_rf_command(substitution, depth + 1)
        if reason is not None:
            return reason

    return None


def run_rm_rf(command: str) -> int:
    """Emit the `rm-rf` mode decision.

    See README.md#git-command-parser-mode-contracts.
    """
    try:
        reason = _detect_rm_rf_command(command)
    except (RecursionError, ValueError):
        reason = RM_RF_REASON

    print(json.dumps({"block": reason}))
    return 0
