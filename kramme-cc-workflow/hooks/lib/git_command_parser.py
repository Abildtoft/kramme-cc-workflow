#!/usr/bin/env python3
"""Shared shell/git parser entry point for safety hooks."""

from __future__ import annotations

import re
import shlex
import sys
import os
import json
from dataclasses import dataclass


CONTROL_TOKENS = {";", ";;", "&&", "||", "|", "|&", "&"}
ASSIGNMENT_WORD = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
SHELL_FUNCTION_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}
SHELL_RESERVED_COMMAND_WORDS = {
    "!",
    "if",
    "then",
    "elif",
    "else",
    "fi",
    "do",
    "done",
    "while",
    "until",
    "for",
    "in",
    "case",
    "esac",
    "{",
    "}",
    "(",
}
SHELL_OPTIONS_WITH_VALUE = {
    "--command",
    "--rcfile",
    "--init-file",
    "--startup-file",
    "-o",
    "-O",
    "+O",
}

NONINTERACTIVE_ENV_PERSISTING_CONTROL_TOKENS = {";", "&&", "||"}
NONINTERACTIVE_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
NONINTERACTIVE_SHELL_KEYWORDS = {
    "!",
    "if",
    "then",
    "elif",
    "else",
    "fi",
    "do",
    "done",
    "while",
    "until",
    "for",
    "in",
    "case",
    "esac",
    "{",
    "}",
    "(",
    ")",
}
NONINTERACTIVE_SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}
NONINTERACTIVE_SHELL_OPTIONS_WITH_VALUE = {
    "--command",
    "--rcfile",
    "--init-file",
    "--startup-file",
    "-o",
    "-O",
    "+O",
}
NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND = "__parse_error__"
NONINTERACTIVE_XARGS_OPTIONS_WITH_VALUE = {
    "-d",
    "-E",
    "-I",
    "-L",
    "-P",
    "-n",
    "-s",
    "--delimiter",
    "--eof",
    "--max-args",
    "--max-chars",
    "--max-procs",
    "--replace",
}
NONINTERACTIVE_SUDO_OPTIONS_WITH_VALUE = {
    "-u",
    "-g",
    "-h",
    "-p",
    "-C",
    "-D",
    "-R",
    "-T",
    "-U",
    "-r",
    "-t",
}
NONINTERACTIVE_GIT_OPTIONS_WITH_VALUE = {
    "-C",
    "-c",
    "--config-env",
    "--exec-path",
    "--git-dir",
    "--namespace",
    "--super-prefix",
    "--work-tree",
}


@dataclass
class NoninteractiveParseResult:
    env: dict
    subcmd: str
    args: list


def _decode_ansi_c_string(value):
    """Decode the escape sequences supported by shell ANSI-C quoting."""
    simple_escapes = {
        "a": "\a",
        "b": "\b",
        "e": "\x1b",
        "E": "\x1b",
        "f": "\f",
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "v": "\v",
        "\\": "\\",
        "'": "'",
        '"': '"',
        "?": "?",
    }
    decoded = []
    idx = 0
    while idx < len(value):
        if value[idx] != "\\":
            decoded.append(value[idx])
            idx += 1
            continue

        if idx + 1 >= len(value):
            decoded.append("\\")
            break

        escape = value[idx + 1]
        if escape in simple_escapes:
            decoded.append(simple_escapes[escape])
            idx += 2
            continue
        if escape in "01234567":
            end = idx + 2
            while end < min(idx + 4, len(value)) and value[end] in "01234567":
                end += 1
            decoded.append(chr(int(value[idx + 1 : end], 8)))
            idx = end
            continue
        if escape in {"x", "u", "U"}:
            max_digits = {"x": 2, "u": 4, "U": 8}[escape]
            start = idx + 2
            end = start
            while (
                end < min(start + max_digits, len(value))
                and value[end] in "0123456789abcdefABCDEF"
            ):
                end += 1
            if end == start:
                decoded.extend(("\\", escape))
                idx += 2
                continue
            try:
                decoded.append(chr(int(value[start:end], 16)))
            except ValueError as exc:
                raise ValueError("Invalid ANSI-C Unicode escape.") from exc
            idx = end
            continue
        if escape == "c" and idx + 2 < len(value):
            decoded.append(chr(ord(value[idx + 2].upper()) & 0x1F))
            idx += 3
            continue
        if escape in {"\n", "\r"}:
            idx += 2
            continue

        decoded.extend(("\\", escape))
        idx += 2

    return "".join(decoded)


def _expand_ansi_c_quoted_strings(command):
    """Replace unquoted $'...' forms with equivalent shlex-safe strings."""
    expanded = []
    idx = 0
    quote = None
    while idx < len(command):
        char = command[idx]

        if quote == "'":
            expanded.append(char)
            if char == "'":
                quote = None
            idx += 1
            continue

        if quote == '"':
            expanded.append(char)
            if char == "\\" and idx + 1 < len(command):
                expanded.append(command[idx + 1])
                idx += 2
                continue
            if char == '"':
                quote = None
            idx += 1
            continue

        if command.startswith("$'", idx):
            value = []
            end = idx + 2
            while end < len(command):
                if command[end] == "\\" and end + 1 < len(command):
                    value.extend((command[end], command[end + 1]))
                    end += 2
                    continue
                if command[end] == "'":
                    break
                value.append(command[end])
                end += 1
            if end >= len(command):
                raise ValueError("Unterminated ANSI-C quoted string.")
            expanded.append(shlex.quote(_decode_ansi_c_string("".join(value))))
            idx = end + 1
            continue

        expanded.append(char)
        if char in {"'", '"'}:
            quote = char
        elif char == "\\" and idx + 1 < len(command):
            expanded.append(command[idx + 1])
            idx += 2
            continue
        idx += 1

    return "".join(expanded)


def read_dollar_substitution(command, start):
    inner = []
    depth = 1
    idx = start + 2
    in_single = False
    in_double = False
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            inner.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\" and not in_single:
            inner.append(char)
            escaped = True
            idx += 1
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            inner.append(char)
            idx += 1
            continue

        if char == '"' and not in_single:
            in_double = not in_double
            inner.append(char)
            idx += 1
            continue

        if not in_single and not in_double and command.startswith("$" + "(", idx):
            nested_inner, idx = read_dollar_substitution(command, idx)
            inner.append("$" + "(" + nested_inner + ")")
            continue

        if not in_single and not in_double and char == ")":
            depth -= 1
            if depth == 0:
                return "".join(inner), idx + 1

        inner.append(char)
        idx += 1

    raise ValueError("Unterminated command substitution.")


def read_backtick_substitution(command, start):
    inner = []
    idx = start + 1
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            inner.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\":
            inner.append(char)
            escaped = True
            idx += 1
            continue

        if char == chr(96):
            return "".join(inner), idx + 1

        inner.append(char)
        idx += 1

    raise ValueError("Unterminated backtick command substitution.")


def _extract_body_substitutions(line):
    # Collect $(...) / `...` contents from an unquoted heredoc body line.
    # Mirrors the bash extract_body_substitutions helper.
    subs = []
    idx = 0
    length = len(line)
    while idx < length:
        ch = line[idx]
        if ch == "$" and idx + 1 < length and line[idx + 1] == "(":
            inner, idx = read_dollar_substitution(line, idx)
            subs.append(inner)
            continue
        if ch == chr(96):
            inner, idx = read_backtick_substitution(line, idx)
            subs.append(inner)
            continue
        idx += 1
    return subs


def _basename(token):
    return os.path.basename(token.lstrip("\\"))


def _is_assignment(token):
    return ASSIGNMENT_WORD.match(token) is not None


def _is_shell_function_name(token):
    return SHELL_FUNCTION_NAME.match(token) is not None


def _skip_empty_function_parens(tokens, idx):
    if idx < len(tokens) and tokens[idx] == "()":
        return idx + 1
    if idx + 1 < len(tokens) and tokens[idx] == "(" and tokens[idx + 1] == ")":
        return idx + 2
    return idx


def _function_body_start(tokens, idx):
    token = tokens[idx]

    if token == "function":
        if idx + 1 >= len(tokens) or not _is_shell_function_name(tokens[idx + 1]):
            return None
        body_idx = _skip_empty_function_parens(tokens, idx + 2)
        if body_idx < len(tokens) and tokens[body_idx] == "{":
            return body_idx
        return None

    if not _is_shell_function_name(token):
        return None

    body_idx = _skip_empty_function_parens(tokens, idx + 1)
    if body_idx == idx + 1:
        return None
    if body_idx < len(tokens) and tokens[body_idx] == "{":
        return body_idx
    return None


def _collect_heredocs(line):
    heredocs = []
    idx = 0
    quote = None
    length = len(line)

    while idx < length:
        char = line[idx]
        next_char = line[idx + 1] if idx + 1 < length else ""

        if quote == "'":
            if char == "'":
                quote = None
            idx += 1
            continue

        if quote == '"':
            if char == '"':
                quote = None
            elif char == "\\" and next_char:
                idx += 2
                continue
            idx += 1
            continue

        if char in {"'", '"'}:
            quote = char
            idx += 1
            continue

        if char == "\\" and next_char:
            idx += 2
            continue

        if char != "<" or next_char != "<":
            idx += 1
            continue

        if idx + 2 < length and line[idx + 2] == "<":
            idx += 3
            continue

        start = idx
        strip_tabs = False
        idx += 2
        if idx < length and line[idx] == "-":
            strip_tabs = True
            idx += 1

        while idx < length and line[idx] in {" ", "\t"}:
            idx += 1

        token = []
        quoted = False
        if idx < length and line[idx] in {"'", '"'}:
            quoted = True
            delimiter_quote = line[idx]
            idx += 1
            while idx < length:
                char = line[idx]
                if char == delimiter_quote:
                    idx += 1
                    break
                token.append(char)
                idx += 1
        else:
            while idx < length:
                char = line[idx]
                if char in {" ", "\t", "\n", "\r", ";", "|", "&", "<", ">"}:
                    break
                if char == "\\" and idx + 1 < length:
                    idx += 1
                    char = line[idx]
                token.append(char)
                idx += 1

        delimiter = "".join(token)
        if delimiter:
            heredocs.append(
                {
                    "delimiter": delimiter,
                    "quoted": quoted,
                    "strip_tabs": strip_tabs,
                    "start": start,
                }
            )

    return heredocs


def _tokenize_heredoc_prefix(line):
    lexer = shlex.shlex(line, posix=True, punctuation_chars="()|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def _tokens_for_heredoc_command(tokens):
    start = 0
    for idx, token in enumerate(tokens):
        if token in CONTROL_TOKENS:
            start = idx + 1

    command_tokens = []
    idx = start
    while idx < len(tokens):
        token = tokens[idx]
        if token in {"<", ">", ">>", "<>", ">|", "<&", ">&"}:
            idx += 2
            continue
        if re.match(r"^\d*(?:<<-?|<<<|<>|>>?|>\||<&|>&)", token):
            idx += 1
            continue
        command_tokens.append(token)
        idx += 1

    return command_tokens


def _shell_has_c_option(word):
    return word.startswith("-") and not word.startswith("--") and "c" in word[1:]


def _shell_invocation_reads_stdin(args):
    idx = 0
    skip_option_operand = False

    while idx < len(args):
        word = args[idx]

        if skip_option_operand:
            skip_option_operand = False
            idx += 1
            continue

        if word in {"-c", "--command"} or word.startswith("--command="):
            return False

        if _shell_has_c_option(word):
            return False

        if word in SHELL_OPTIONS_WITH_VALUE:
            skip_option_operand = True
            idx += 1
            continue

        if any(
            word.startswith(prefix + "=")
            for prefix in ("--rcfile", "--init-file", "--startup-file")
        ):
            idx += 1
            continue

        if word == "--":
            idx += 1
            continue

        if word.startswith("-") or word.startswith("+"):
            idx += 1
            continue

        return False

    return True


def _skip_prefixed_command_options(tokens, idx, command_name):
    if command_name in {"command", "builtin"}:
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                return idx + 1
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    if command_name == "env":
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if _is_assignment(token):
                idx += 1
                continue
            if token == "--":
                return idx + 1
            if token in {"-u", "--unset", "-C", "--chdir"}:
                idx += 2
                continue
            if token.startswith("--unset=") or token.startswith("--chdir="):
                idx += 1
                continue
            if token.startswith("-u") and token != "-u":
                idx += 1
                continue
            if token.startswith("-C") and token != "-C":
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    if command_name == "sudo":
        idx += 1
        sudo_options_with_value = {
            "-u",
            "-g",
            "-h",
            "-p",
            "-C",
            "-D",
            "-R",
            "-T",
            "-U",
            "-r",
            "-t",
        }
        sudo_long_options_with_value = {
            "--user",
            "--group",
            "--host",
            "--prompt",
            "--command-timeout",
            "--close-from",
            "--chdir",
            "--chroot",
            "--login-class",
            "--role",
            "--type",
            "--other-user",
        }
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                return idx + 1
            if token in sudo_options_with_value or token in sudo_long_options_with_value:
                idx += 2
                continue
            if any(
                token.startswith(prefix + "=")
                for prefix in (
                    "--user",
                    "--group",
                    "--host",
                    "--prompt",
                    "--command-timeout",
                    "--close-from",
                    "--chdir",
                    "--chroot",
                    "--login-class",
                    "--role",
                    "--type",
                    "--other-user",
                )
            ):
                idx += 1
                continue
            if token.startswith("-") and not token.startswith("--"):
                value_option_seen = False
                for position, letter in enumerate(token[1:]):
                    if letter in {
                        "u",
                        "g",
                        "h",
                        "p",
                        "C",
                        "D",
                        "R",
                        "T",
                        "U",
                        "r",
                        "t",
                    }:
                        idx += 2 if position == len(token[1:]) - 1 else 1
                        value_option_seen = True
                        break
                if value_option_seen:
                    continue
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    if command_name == "nice":
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                return idx + 1
            if token in {"-n", "--adjustment"}:
                idx += 2
                continue
            if token.startswith("--adjustment="):
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    if command_name == "timeout":
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                idx += 1
                if idx < len(tokens):
                    idx += 1
                break
            if token in {"-s", "--signal", "-k", "--kill-after"}:
                idx += 2
                continue
            if token.startswith("--signal=") or token.startswith("--kill-after="):
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            idx += 1
            break
        return idx

    if command_name == "time":
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                return idx + 1
            if token in {"-o", "-f", "--output", "--format"}:
                idx += 2
                continue
            if token.startswith("--output=") or token.startswith("--format="):
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    if command_name == "nohup":
        idx += 1
        if idx < len(tokens) and tokens[idx] == "--":
            return idx + 1
        return idx

    if command_name == "exec":
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                return idx + 1
            if token == "-a":
                idx += 2
                continue
            if token.startswith("-"):
                idx += 1
                continue
            return idx
        return idx

    return idx


def _line_has_supported_shell_stdin_heredoc(line, heredoc_start):
    try:
        tokens = _tokens_for_heredoc_command(
            _tokenize_heredoc_prefix(line[:heredoc_start])
        )
    except ValueError:
        return False

    idx = 0
    while idx < len(tokens):
        token = tokens[idx]
        base = _basename(token)

        if _is_assignment(token) or token in SHELL_RESERVED_COMMAND_WORDS:
            idx += 1
            continue

        if base in {
            "command",
            "builtin",
            "env",
            "sudo",
            "nice",
            "timeout",
            "time",
            "nohup",
            "exec",
        }:
            next_idx = _skip_prefixed_command_options(tokens, idx, base)
            if next_idx == idx:
                return False
            idx = next_idx
            continue

        if base in SHELL_EXECUTABLES:
            return _shell_invocation_reads_stdin(tokens[idx + 1 :])

        return False

    return False


def strip_heredoc_bodies(command):
    lines = command.splitlines(keepends=True)
    stripped_lines = []
    pending_heredocs = []
    extracted = []

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
                keep_body = _line_has_supported_shell_stdin_heredoc(
                    line, heredoc["start"]
                )
                pending_heredocs.append({**heredoc, "keep_body": keep_body})

    return "".join(stripped_lines), extracted


def normalize_newlines(command):
    command, _ = strip_heredoc_bodies(command)
    normalized = []
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


def tokenize(command):
    command = _expand_ansi_c_quoted_strings(normalize_newlines(command))
    lexer = shlex.shlex(command, posix=True, punctuation_chars="()|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def split_segments(tokens):
    current = []
    for token in tokens:
        if token in CONTROL_TOKENS:
            if current:
                yield current, token
                current = []
            continue
        current.append(token)
    if current:
        yield current, None


def replace_command_substitutions(command):
    command, heredoc_body_substitutions = strip_heredoc_bodies(command)
    # Start with any substitutions extracted from unquoted heredoc
    # bodies - they're still executed by the shell and need inspection.
    substitutions = list(heredoc_body_substitutions)
    result = []
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


def extract_placeholder_indexes(tokens):
    indexes = []
    seen = set()
    for token in tokens:
        for match in re.finditer(r"__CMD_SUBST_(\d+)__", token):
            index = int(match.group(1))
            if index not in seen:
                seen.add(index)
                indexes.append(index)
    return indexes


def _noninteractive_is_assignment(token):
    return NONINTERACTIVE_ASSIGNMENT.match(token) is not None


def _noninteractive_basename(token):
    return os.path.basename(token)


def _noninteractive_is_git_exec(token):
    return _noninteractive_basename(token) == "git"


def _extract_noninteractive_shell_c_command(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in ("-c", "--command"):
            if idx + 1 < len(args):
                return args[idx + 1]
            return None
        if arg.startswith("--command="):
            return arg.split("=", 1)[1]
        if arg in NONINTERACTIVE_SHELL_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in ("--rcfile", "--init-file", "--startup-file")):
            idx += 1
            continue
        if arg == "--":
            return None
        if arg.startswith("-") and not arg.startswith("--"):
            if "c" in arg[1:]:
                if idx + 1 < len(args):
                    return args[idx + 1]
                return None
            idx += 1
            continue
        if arg.startswith("+"):
            idx += 1
            continue
        return None
    return None


def _clear_editor_env(env):
    env.pop("GIT_EDITOR", None)
    env.pop("GIT_SEQUENCE_EDITOR", None)


def _unset_editor_env(env, key):
    if key in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
        env.pop(key, None)


def _apply_exported_editor_env(tokens, inherited_env=None, inherited_shell_vars=None):
    env = dict(inherited_env or {})
    shell_vars = dict(inherited_shell_vars or env)
    idx = 0
    shell_env_persists = True
    pending_shell_vars = {}

    while idx < len(tokens) and tokens[idx] in NONINTERACTIVE_SHELL_KEYWORDS:
        if tokens[idx] == "(":
            shell_env_persists = False
        idx += 1

    while idx < len(tokens) and _noninteractive_is_assignment(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        if key in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
            pending_shell_vars[key] = value
        idx += 1

    if idx >= len(tokens):
        if shell_env_persists:
            shell_vars.update(pending_shell_vars)
        return env, shell_vars

    if not shell_env_persists:
        return env, shell_vars

    command_name = _noninteractive_basename(tokens[idx])
    if command_name == "export":
        shell_vars.update(pending_shell_vars)
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                idx += 1
                break
            if token == "-n":
                if idx + 1 < len(tokens):
                    _unset_editor_env(env, tokens[idx + 1])
                idx += 2
                continue
            if token.startswith("-n") and token != "-n":
                _unset_editor_env(env, token[2:])
                idx += 1
                continue
            if _noninteractive_is_assignment(token):
                key, value = token.split("=", 1)
                if key in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
                    shell_vars[key] = value
                    env[key] = value
                idx += 1
                continue
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", token):
                if token in shell_vars and token in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
                    env[token] = shell_vars[token]
                idx += 1
                continue
            if token.startswith("-"):
                idx += 1
                continue
            break
        return env, shell_vars

    if command_name == "unset":
        unset_targets_variables = True
        idx += 1
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--":
                idx += 1
                break
            if token in {"-f", "-n"}:
                unset_targets_variables = False
                idx += 1
                continue
            if token == "-v":
                unset_targets_variables = True
                idx += 1
                continue
            if token.startswith("-"):
                option_flags = token[1:]
                if "f" in option_flags or "n" in option_flags:
                    unset_targets_variables = False
                elif "v" in option_flags:
                    unset_targets_variables = True
                idx += 1
                continue
            if unset_targets_variables and token in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
                env.pop(token, None)
                shell_vars.pop(token, None)
            idx += 1
        return env, shell_vars

    return env, shell_vars


def parse_env_wrapped_segment(tokens, inherited_env=None):
    env = dict(inherited_env or {})
    idx = 0

    # Support git commands nested in simple shell structures, e.g.:
    # if git commit; then ...
    while idx < len(tokens) and tokens[idx] in NONINTERACTIVE_SHELL_KEYWORDS:
        idx += 1

    while idx < len(tokens) and _noninteractive_is_assignment(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        env[key] = value
        idx += 1

    while idx < len(tokens):
        token = _noninteractive_basename(tokens[idx])
        if token == "env":
            idx += 1
            while idx < len(tokens):
                env_token = tokens[idx]
                if env_token == "--":
                    idx += 1
                    break
                if _noninteractive_is_assignment(env_token):
                    key, value = env_token.split("=", 1)
                    env[key] = value
                    idx += 1
                    continue
                if env_token in ("-i", "--ignore-environment"):
                    _clear_editor_env(env)
                    idx += 1
                    continue
                if env_token in ("-u", "--unset"):
                    if idx + 1 < len(tokens):
                        _unset_editor_env(env, tokens[idx + 1])
                    idx += 2
                    continue
                if env_token.startswith("-u") and env_token != "-u":
                    _unset_editor_env(env, env_token[2:])
                    idx += 1
                    continue
                if env_token.startswith("--unset="):
                    _unset_editor_env(env, env_token.split("=", 1)[1])
                    idx += 1
                    continue
                if env_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token in {"command", "builtin"}:
            idx += 1
            while idx < len(tokens):
                command_token = tokens[idx]
                if command_token == "--":
                    idx += 1
                    break
                if command_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "sudo":
            idx += 1
            while idx < len(tokens):
                sudo_token = tokens[idx]
                if sudo_token == "--":
                    idx += 1
                    break
                if sudo_token in NONINTERACTIVE_SUDO_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if sudo_token in {
                    "--user",
                    "--group",
                    "--host",
                    "--prompt",
                    "--command-timeout",
                    "--close-from",
                    "--chdir",
                    "--chroot",
                    "--login-class",
                    "--role",
                    "--type",
                    "--other-user",
                }:
                    idx += 2
                    continue
                if sudo_token.startswith("--user=") or sudo_token.startswith("--group="):
                    idx += 1
                    continue
                if any(
                    sudo_token.startswith(prefix + "=")
                    for prefix in (
                        "--host",
                        "--prompt",
                        "--command-timeout",
                        "--close-from",
                        "--chdir",
                        "--chroot",
                        "--login-class",
                        "--role",
                        "--type",
                        "--other-user",
                    )
                ):
                    idx += 1
                    continue
                if sudo_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "xargs":
            idx += 1
            while idx < len(tokens):
                xargs_token = tokens[idx]
                if xargs_token == "--":
                    idx += 1
                    break
                if xargs_token in NONINTERACTIVE_XARGS_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if any(
                    xargs_token.startswith(prefix)
                    for prefix in (
                        "--delimiter=",
                        "--eof=",
                        "--max-args=",
                        "--max-chars=",
                        "--max-procs=",
                        "--replace=",
                    )
                ):
                    idx += 1
                    continue
                if xargs_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "find":
            idx += 1
            while idx < len(tokens):
                if tokens[idx] in ("-exec", "-execdir"):
                    idx += 1
                    break
                idx += 1
            continue

        if tokens[idx] in ("-exec", "-execdir"):
            idx += 1
            continue

        break

    while idx < len(tokens) and tokens[idx] in NONINTERACTIVE_SHELL_KEYWORDS:
        idx += 1

    if idx >= len(tokens):
        return None

    exec_token = tokens[idx]
    if _noninteractive_basename(exec_token) == "alias":
        return NoninteractiveParseResult(
            env=env,
            subcmd=NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND,
            args=[],
        )

    if _noninteractive_basename(exec_token) in NONINTERACTIVE_SHELL_EXECUTABLES:
        nested_command = _extract_noninteractive_shell_c_command(tokens[idx + 1 :])
        if nested_command is None:
            return None
        return NoninteractiveParseResult(
            env=env,
            subcmd="__shell_c__",
            args=[nested_command],
        )

    if not _noninteractive_is_git_exec(exec_token):
        return None

    git_argv = tokens[idx + 1 :]
    if not git_argv:
        return None

    git_idx = 0
    while git_idx < len(git_argv):
        token = git_argv[git_idx]
        if token == "--":
            git_idx += 1
            break
        if token in NONINTERACTIVE_GIT_OPTIONS_WITH_VALUE:
            git_idx += 2
            continue
        if any(
            token.startswith(prefix + "=")
            for prefix in (
                "--config-env",
                "--exec-path",
                "--git-dir",
                "--namespace",
                "--super-prefix",
                "--work-tree",
            )
        ):
            git_idx += 1
            continue
        if token.startswith("-C") and token != "-C":
            git_idx += 1
            continue
        if token.startswith("-c") and token != "-c":
            git_idx += 1
            continue
        if token.startswith("-"):
            git_idx += 1
            continue
        break

    if git_idx >= len(git_argv):
        return None

    return NoninteractiveParseResult(
        env=env,
        subcmd=git_argv[git_idx],
        args=git_argv[git_idx + 1 :],
    )


def _parse_noninteractive_git_commands(command, inherited_env=None, inherited_shell_vars=None):
    sanitized_command, raw_substitutions = replace_command_substitutions(command)
    tokens = tokenize(sanitized_command)
    parsed_commands = []
    substitutions = []
    current_env = dict(inherited_env or {})
    current_shell_vars = dict(inherited_shell_vars or current_env)
    used_placeholder_indexes = set()
    for segment, separator in split_segments(tokens):
        segment_env = dict(current_env)
        segment_shell_vars = dict(current_shell_vars)
        for placeholder_index in extract_placeholder_indexes(segment):
            used_placeholder_indexes.add(placeholder_index)
            substitutions.append(
                {
                    "command": raw_substitutions[placeholder_index],
                    "env": dict(segment_env),
                }
            )
        persisted_env, persisted_shell_vars = _apply_exported_editor_env(
            segment,
            inherited_env=segment_env,
            inherited_shell_vars=segment_shell_vars,
        )
        parsed = parse_env_wrapped_segment(segment, inherited_env=persisted_env)
        if parsed is not None:
            parsed_commands.append(parsed)
        if separator in NONINTERACTIVE_ENV_PERSISTING_CONTROL_TOKENS:
            current_env = persisted_env
            current_shell_vars = persisted_shell_vars
        else:
            current_env = segment_env
            current_shell_vars = segment_shell_vars

    for index, substitution in enumerate(raw_substitutions):
        if index in used_placeholder_indexes:
            continue
        substitutions.append(
            {
                "command": substitution,
                "env": dict(inherited_env or {}),
            }
        )
    return parsed_commands, substitutions


def run_noninteractive(command: str) -> int:
    PARSE_ERROR_REASON = (
        "Unable to safely parse command. Refusing potentially interactive git command."
    )

    def has_long_option(args, *names):
        names_set = set(names)
        for arg in args:
            if arg == "--":
                break
            if arg in names_set:
                return True
            if arg.startswith("--"):
                for name in names_set:
                    if arg.startswith(name + "="):
                        return True
        return False


    def fixup_value_is_interactive(value):
        return value.startswith("amend:") or value.startswith("reword:")


    def classify_commit_fixup(args):
        skip_next = False
        expecting_fixup_value = False
        for arg in args:
            if expecting_fixup_value:
                return "interactive" if fixup_value_is_interactive(arg) else "safe"
            if skip_next:
                skip_next = False
                continue
            if arg == "--":
                break
            if arg == "--fixup":
                expecting_fixup_value = True
                continue
            if arg.startswith("--fixup="):
                return "interactive" if fixup_value_is_interactive(arg.split("=", 1)[1]) else "safe"
            if short_option_consumes_next_value(arg, COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE):
                skip_next = True
                continue
            if arg in COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE:
                skip_next = True
        return "none"


    def merge_edit_is_safe(args):
        return has_long_option(args, "--ff-only") and not has_long_option(args, "--no-ff")


    def has_short_option(args, *letters):
        wanted = set(letters)
        for arg in args:
            if arg == "--":
                break
            if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
                continue
            for letter in arg[1:]:
                if letter in wanted:
                    return True
        return False


    COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES = set("mFCctSu")
    COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE = set("mFCct")
    COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE = {
        "--author",
        "--date",
        "--message",
        "--file",
        "--reuse-message",
        "--reedit-message",
        "--fixup",
        "--squash",
        "--cleanup",
        "--trailer",
        "--pathspec-from-file",
    }
    MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES = set("mFsSX")
    MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE = set("mFsX")
    MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE = {
        "--message",
        "--file",
        "--strategy",
        "--strategy-option",
        "--cleanup",
        "--into-name",
    }


    def has_short_option_value_aware(args, wanted, options_with_values):
        for arg in args:
            if arg == "--":
                break
            if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
                continue
            for letter in arg[1:]:
                if letter == wanted:
                    return True
                if letter in options_with_values:
                    break
        return False


    def short_option_consumes_next_value(arg, options_with_values):
        if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
            return False
        letters = arg[1:]
        for idx, letter in enumerate(letters):
            if letter in options_with_values:
                return idx == len(letters) - 1
        return False


    def has_long_option_value_aware(
        args, wanted, short_options_with_values, long_options_with_values
    ):
        skip_next = False
        for arg in args:
            if skip_next:
                skip_next = False
                continue
            if arg == "--":
                break
            if arg == wanted or arg.startswith(wanted + "="):
                return True
            if short_option_consumes_next_value(arg, short_options_with_values):
                skip_next = True
                continue
            if arg in long_options_with_values:
                skip_next = True
        return False


    def has_safe_fixup(args):
        idx = 0
        while idx < len(args):
            arg = args[idx]
            if arg == "--":
                break
            if arg == "--fixup":
                if idx + 1 >= len(args):
                    return False
                return not args[idx + 1].startswith(("amend:", "reword:"))
            if arg.startswith("--fixup="):
                return not arg.split("=", 1)[1].startswith(("amend:", "reword:"))
            idx += 1
        return False


    def commit_requests_editor(args):
        idx = 0
        while idx < len(args):
            arg = args[idx]
            if arg == "--":
                break
            if arg in ("--edit", "--reedit-message") or arg.startswith("--reedit-message="):
                return True
            if arg in ("--message", "--file", "--reuse-message", "--fixup"):
                idx += 2
                continue
            if arg.startswith(("--message=", "--file=", "--reuse-message=", "--fixup=")):
                idx += 1
                continue
            if arg.startswith("-") and arg != "-" and not arg.startswith("--"):
                cluster = arg[1:]
                consume_next = False
                for pos, letter in enumerate(cluster):
                    if letter in ("e", "c"):
                        return True
                    if letter in ("m", "F", "C"):
                        consume_next = pos == len(cluster) - 1
                        break
                idx += 2 if consume_next else 1
                continue
            idx += 1
        return False


    def evaluate(parsed_commands, substitutions, depth=0):
        if depth > 4:
            return PARSE_ERROR_REASON

        for substitution in substitutions:
            try:
                nested_commands, nested_substitutions = _parse_noninteractive_git_commands(
                    substitution["command"],
                    inherited_env=substitution["env"],
                    inherited_shell_vars=substitution["env"],
                )
            except ValueError:
                return PARSE_ERROR_REASON
            reason = evaluate(nested_commands, nested_substitutions, depth=depth + 1)
            if reason is not None:
                return reason

        for parsed in parsed_commands:
            subcmd = parsed.subcmd
            args = parsed.args
            env = parsed.env

            if subcmd == NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND:
                return PARSE_ERROR_REASON

            if subcmd == "__shell_c__":
                try:
                    nested_commands, nested_substitutions = _parse_noninteractive_git_commands(
                        args[0],
                        inherited_env=env,
                        inherited_shell_vars=env,
                    )
                except ValueError:
                    return PARSE_ERROR_REASON
                reason = evaluate(nested_commands, nested_substitutions, depth=depth + 1)
                if reason is not None:
                    return reason
                continue

            if subcmd == "commit":
                if has_short_option_value_aware(args, "e", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES) or has_long_option_value_aware(
                    args,
                    "--edit",
                    COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                    COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE,
                ):
                    return "git commit --edit opens an editor. Remove --edit to keep the commit non-interactive."
                commit_fixup_mode = classify_commit_fixup(args)
                has_no_edit = has_long_option(args, "--no-edit")
                if commit_fixup_mode == "interactive" and not has_no_edit:
                    return "git commit --fixup=amend:<commit> and --fixup=reword:<commit> open an editor unless you also pass --no-edit."
                has_message_source = (
                    not commit_requests_editor(args)
                    and (
                        has_short_option_value_aware(args, "m", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                        or has_short_option_value_aware(args, "F", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                        or has_short_option_value_aware(args, "C", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                        or has_safe_fixup(args)
                        or has_long_option(args, "--message", "--file", "--reuse-message")
                        or commit_fixup_mode == "safe"
                        or has_long_option(args, "--no-edit")
                    )
                )
                if not has_message_source:
                    return "git commit without a message source may open an editor. Use: git commit -m \"your message\" (or --no-edit for amend)"

            elif subcmd == "rebase":
                if has_short_option(args, "i") or has_long_option(args, "--interactive"):
                    if "GIT_SEQUENCE_EDITOR" not in env:
                        return "Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ..."
                if has_long_option(args, "--continue"):
                    if "GIT_EDITOR" not in env:
                        return "git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue"

            elif subcmd == "add":
                if has_short_option(args, "p", "i") or has_long_option(args, "--patch", "--interactive"):
                    return "Interactive git add opens a prompt. Use explicit paths: git add <files>"

            elif subcmd == "merge":
                if (
                    has_short_option_value_aware(args, "e", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    or has_long_option_value_aware(
                        args,
                        "--edit",
                        MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                        MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE,
                    )
                ) and not merge_edit_is_safe(args):
                    return "git merge --edit opens an editor. Remove --edit to keep the merge non-interactive."
                is_explicitly_safe = has_long_option(
                    args,
                    "--abort",
                    "--quit",
                    "--no-edit",
                    "--no-commit",
                    "--squash",
                    "--ff-only",
                    "--ff",
                    "--message",
                    "--file",
                )
                if not is_explicitly_safe:
                    is_explicitly_safe = (
                        has_short_option_value_aware(args, "m", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                        or has_short_option_value_aware(args, "F", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    )
                if not is_explicitly_safe:
                    return "git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>"

            elif subcmd == "cherry-pick":
                is_explicitly_safe = (
                    has_long_option(
                        args,
                        "--continue",
                        "--abort",
                        "--quit",
                        "--skip",
                        "--no-edit",
                        "--no-commit",
                    )
                    or has_short_option(args, "n")
                )
                if not is_explicitly_safe:
                    return "git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>"

        return None


    try:
        parsed_commands, substitutions = _parse_noninteractive_git_commands(command)
    except ValueError:
        print(json.dumps({"block": PARSE_ERROR_REASON}))
        return 0

    reason = evaluate(parsed_commands, substitutions)
    print(json.dumps({"block": reason}))
    return 0


RM_RF_REASON = (
    "rm -rf is blocked. Use `trash` instead (install: brew install trash). "
    "Files go to Trash for recovery."
)
XARGS_RM_RF_REASON = "xargs rm -rf is blocked. Use `trash` instead."
FIND_DELETE_REASON = (
    "find -delete is blocked. Use `trash` instead for recoverable deletion."
)
FIND_EXEC_RM_RF_REASON = "find -exec rm -rf is blocked. Use `trash` instead."
SHRED_REASON = "shred is blocked. Use `trash` instead for recoverable deletion."
UNLINK_REASON = "unlink is blocked. Use `trash` instead for recoverable deletion."


def _extract_shell_c_command(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in ("-c", "--command"):
            idx += 1
            if idx < len(args) and args[idx] == "--" and idx + 1 < len(args):
                return args[idx + 1]
            if idx < len(args):
                return args[idx]
            return None
        if arg.startswith("--command="):
            return arg.split("=", 1)[1]
        if arg in SHELL_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if any(
            arg.startswith(prefix + "=")
            for prefix in ("--rcfile", "--init-file", "--startup-file")
        ):
            idx += 1
            continue
        if arg == "--":
            return None
        if arg.startswith("-") and not arg.startswith("--"):
            if "c" in arg[1:]:
                idx += 1
                if idx < len(args) and args[idx] == "--" and idx + 1 < len(args):
                    return args[idx + 1]
                if idx < len(args):
                    return args[idx]
                return None
            idx += 1
            continue
        if arg.startswith("+"):
            idx += 1
            continue
        return None
    return None


def _has_rf_flags(args):
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


def _has_literal_rm_rf_text(text):
    if re.search(r"(^|[^A-Za-z0-9_])rm([^A-Za-z0-9_]|$)", text) is None:
        return False
    has_recursive = re.search(r"(-[A-Za-z]*[rR]|--recursive)", text) is not None
    has_force = re.search(r"(-[A-Za-z]*f|--force)", text) is not None
    return has_recursive and has_force


def _placeholder_indexes_in_text(text):
    return [
        int(match.group(1))
        for match in re.finditer(r"__CMD_SUBST_(\d+)__", text)
    ]


def _literal_placeholder_reason(text, substitutions):
    for placeholder_index in _placeholder_indexes_in_text(text):
        if placeholder_index < len(substitutions) and _has_literal_rm_rf_text(
            substitutions[placeholder_index]
        ):
            return RM_RF_REASON
    return None


def _join_tokens_as_command(tokens):
    return " ".join(tokens)


def _detect_process_substitutions(tokens, substitutions, depth):
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


def _skip_rm_rf_prefixes(tokens, idx, substitutions, depth):
    while idx < len(tokens):
        token = tokens[idx]
        base = _basename(token)

        if _is_assignment(token):
            idx += 1
            continue

        if base == "env":
            env_idx = idx + 1
            while env_idx < len(tokens):
                env_token = tokens[env_idx]
                if _is_assignment(env_token):
                    env_idx += 1
                    continue
                if env_token == "--":
                    env_idx += 1
                    break
                if env_token in {"-S", "--split-string"}:
                    if env_idx + 1 >= len(tokens):
                        return len(tokens), None
                    try:
                        split_tokens = shlex.split(tokens[env_idx + 1], posix=True)
                    except ValueError:
                        return len(tokens), RM_RF_REASON
                    reason = _detect_rm_rf_segment(
                        split_tokens + tokens[env_idx + 2 :], substitutions, depth + 1
                    )
                    return len(tokens), reason
                if env_token.startswith("--split-string="):
                    try:
                        split_tokens = shlex.split(env_token.split("=", 1)[1], posix=True)
                    except ValueError:
                        return len(tokens), RM_RF_REASON
                    reason = _detect_rm_rf_segment(
                        split_tokens + tokens[env_idx + 1 :], substitutions, depth + 1
                    )
                    return len(tokens), reason
                if env_token in {"-u", "--unset", "-C", "--chdir"}:
                    env_idx += 2
                    continue
                if env_token.startswith("--unset=") or env_token.startswith("--chdir="):
                    env_idx += 1
                    continue
                if env_token.startswith("-u") and env_token != "-u":
                    env_idx += 1
                    continue
                if env_token.startswith("-C") and env_token != "-C":
                    env_idx += 1
                    continue
                if env_token.startswith("-"):
                    env_idx += 1
                    continue
                break
            idx = env_idx
            continue

        if base in {
            "command",
            "builtin",
            "sudo",
            "nice",
            "timeout",
            "time",
            "nohup",
            "exec",
        }:
            next_idx = _skip_prefixed_command_options(tokens, idx, base)
            if next_idx == idx:
                return idx, None
            idx = next_idx
            continue

        return idx, None

    return idx, None


def _detect_xargs(args, substitutions, depth):
    idx = 0
    xargs_options_with_value = {
        "-d",
        "-E",
        "-I",
        "-i",
        "-J",
        "-L",
        "-P",
        "-a",
        "-n",
        "-s",
        "--arg-file",
        "--delimiter",
        "--eof",
        "--max-args",
        "--max-chars",
        "--max-lines",
        "--max-procs",
        "--process-slot-var",
        "--replace",
    }
    xargs_long_attached = (
        "--arg-file=",
        "--delimiter=",
        "--eof=",
        "--max-args=",
        "--max-chars=",
        "--max-lines=",
        "--max-procs=",
        "--process-slot-var=",
        "--replace=",
    )
    xargs_short_attached = (
        "-a",
        "-d",
        "-E",
        "-I",
        "-i",
        "-J",
        "-L",
        "-P",
        "-n",
        "-s",
    )

    while idx < len(args):
        token = args[idx]
        if token == "--":
            idx += 1
            break
        if token in xargs_options_with_value:
            idx += 2
            continue
        if token.startswith(xargs_long_attached):
            idx += 1
            continue
        if any(token.startswith(prefix) and token != prefix for prefix in xargs_short_attached):
            idx += 1
            continue
        if token.startswith("-"):
            idx += 1
            continue
        break

    if idx >= len(args):
        return None

    if _basename(args[idx]) == "rm" and _has_rf_flags(args[idx + 1 :]):
        return XARGS_RM_RF_REASON

    return _detect_command_at(args, idx, substitutions, depth + 1)


def _find_exec_tokens(args, start):
    exec_tokens = []
    idx = start
    while idx < len(args):
        token = args[idx]
        if token in {";", "+", ";;"}:
            break
        exec_tokens.append(token)
        idx += 1
    return exec_tokens


def _detect_find(args, substitutions, depth):
    idx = 0
    while idx < len(args):
        token = args[idx]
        if token == "-delete":
            return FIND_DELETE_REASON
        if token in {"-exec", "-execdir"}:
            exec_tokens = _find_exec_tokens(args, idx + 1)
            if exec_tokens and _basename(exec_tokens[0]) == "rm" and _has_rf_flags(
                exec_tokens[1:]
            ):
                return FIND_EXEC_RM_RF_REASON
            reason = _detect_rm_rf_segment(exec_tokens, substitutions, depth + 1)
            if reason is not None:
                return reason
            idx += len(exec_tokens) + 1
            continue
        idx += 1
    return None


def _detect_command_at(tokens, idx, substitutions, depth):
    idx, prefix_reason = _skip_rm_rf_prefixes(tokens, idx, substitutions, depth)
    if prefix_reason is not None:
        return prefix_reason
    if idx >= len(tokens):
        return None

    token = tokens[idx]
    base = _basename(token)

    if base in SHELL_EXECUTABLES:
        payload = _extract_shell_c_command(tokens[idx + 1 :])
        if payload is None:
            return None
        literal_reason = _literal_placeholder_reason(payload, substitutions)
        if literal_reason is not None:
            return literal_reason
        return _detect_rm_rf_command(payload, depth + 1)

    if base == "eval":
        payload = _join_tokens_as_command(tokens[idx + 1 :])
        literal_reason = _literal_placeholder_reason(payload, substitutions)
        if literal_reason is not None:
            return literal_reason
        if payload:
            return _detect_rm_rf_command(payload, depth + 1)
        return None

    if base == "xargs":
        return _detect_xargs(tokens[idx + 1 :], substitutions, depth)

    if base == "find":
        return _detect_find(tokens[idx + 1 :], substitutions, depth)

    if base == "shred":
        return SHRED_REASON

    if base == "unlink":
        return UNLINK_REASON

    if base == "rm" and _has_rf_flags(tokens[idx + 1 :]):
        return RM_RF_REASON

    return None


def _detect_rm_rf_segment(tokens, substitutions, depth):
    if depth > 5:
        return None

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


def _detect_rm_rf_command(command, depth=0):
    if depth > 5:
        return None

    sanitized_command, substitutions = replace_command_substitutions(command)
    tokens = tokenize(sanitized_command)
    used_placeholder_indexes = set()

    for segment, _separator in split_segments(tokens):
        for placeholder_index in extract_placeholder_indexes(segment):
            used_placeholder_indexes.add(placeholder_index)
            if placeholder_index < len(substitutions):
                reason = _detect_rm_rf_command(
                    substitutions[placeholder_index], depth + 1
                )
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
    try:
        reason = _detect_rm_rf_command(command)
    except (RecursionError, ValueError):
        reason = RM_RF_REASON

    print(json.dumps({"block": reason}))
    return 0


COMMIT_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
COMMIT_ENV_PERSISTING_CONTROL_TOKENS = {";", "&&", "||"}
COMMIT_SHELL_KEYWORDS = {
    "!",
    "if",
    "then",
    "elif",
    "else",
    "fi",
    "do",
    "done",
    "while",
    "until",
    "for",
    "in",
    "case",
    "esac",
    "{",
    "}",
    "(",
    ")",
}
COMMIT_ENV_OPTIONS_WITH_VALUE = {"-u", "--unset", "-C", "--chdir"}
COMMIT_GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}
COMMIT_REPLAY_ENV_VARS = {
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_NAMESPACE",
    "GIT_COMMON_DIR",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
}
COMMIT_SUDO_OPTIONS_WITH_VALUE = {
    "-u",
    "-g",
    "-p",
    "-C",
    "-D",
    "-R",
    "-T",
    "-U",
    "-t",
    "-r",
    "-h",
}
COMMIT_SUDO_LONG_OPTIONS_WITH_VALUE = {
    "--user",
    "--group",
    "--host",
    "--prompt",
    "--command-timeout",
    "--close-from",
    "--chdir",
    "--chroot",
    "--login-class",
    "--role",
    "--type",
    "--other-user",
}
COMMIT_SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}
COMMIT_SHELL_OPTIONS_WITH_VALUE = {"--command", "--rcfile", "--init-file", "--startup-file", "-o", "-O", "+O"}

def parse_shell_inline_command(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in ("-c", "--command"):
            if idx + 1 < len(args):
                return args[idx + 1]
            return None
        if arg.startswith("--command="):
            return arg.split("=", 1)[1]
        if arg in COMMIT_SHELL_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in ("--rcfile", "--init-file", "--startup-file")):
            idx += 1
            continue
        if arg == "--":
            return None
        if arg.startswith("-") and not arg.startswith("--"):
            if "c" in arg[1:]:
                if idx + 1 < len(args):
                    return args[idx + 1]
                return None
            idx += 1
            continue
        if arg.startswith("+"):
            idx += 1
            continue
        return None
    return None


def unset_replay_env(git_env, key):
    git_env[:] = [assignment for assignment in git_env if assignment.split("=", 1)[0] != key]


def set_replay_env(git_env, key, value):
    unset_replay_env(git_env, key)
    git_env.append(f"{key}={value}")


def clear_replay_env(git_env):
    git_env[:] = []


def inherited_replay_env_from_process():
    return [f"{key}={os.environ[key]}" for key in COMMIT_REPLAY_ENV_VARS if key in os.environ]


class ParseError(Exception):
    pass


@dataclass
class CommitSegmentResult:
    contexts: list
    persisted_git_env: list
    persisted_shell_git_vars: list


def parse_commit_contexts(command, inherited_git_args=None, inherited_git_env=None, inherited_shell_git_vars=None, depth=0):
    # Cap recursion so pathological nesting can't hit Python's stack limit
    # and convert a ValueError into an uncaught RecursionError (which would
    # exit the interpreter non-zero and the shell would fail open).
    if depth > 4:
        raise ParseError("command substitution nesting too deep")

    contexts = []
    if inherited_git_env is None:
        inherited_git_env = inherited_replay_env_from_process()
    if inherited_shell_git_vars is None:
        inherited_shell_git_vars = list(inherited_git_env)
    try:
        sanitized_command, substitutions = replace_command_substitutions(command)
        tokens = tokenize(sanitized_command)
    except ValueError as exc:
        raise ParseError(str(exc)) from exc

    current_git_env = list(inherited_git_env or [])
    current_shell_git_vars = list(inherited_shell_git_vars or [])
    used_placeholder_indexes = set()
    for segment, separator in split_segments(tokens):
        segment_input_env = list(current_git_env)
        segment_input_shell_git_vars = list(current_shell_git_vars)
        for placeholder_index in extract_placeholder_indexes(segment):
            used_placeholder_indexes.add(placeholder_index)
            contexts.extend(
                parse_commit_contexts(
                    substitutions[placeholder_index],
                    inherited_git_args=inherited_git_args,
                    inherited_git_env=segment_input_env,
                    inherited_shell_git_vars=segment_input_shell_git_vars,
                    depth=depth + 1,
                )
            )
        segment_result = parse_commit_segment(
            segment,
            list(inherited_git_args or []),
            list(segment_input_env),
            list(segment_input_shell_git_vars),
            depth=depth,
        )
        contexts.extend(segment_result.contexts)
        if separator in COMMIT_ENV_PERSISTING_CONTROL_TOKENS:
            current_git_env = segment_result.persisted_git_env
            current_shell_git_vars = segment_result.persisted_shell_git_vars
        else:
            current_git_env = segment_input_env
            current_shell_git_vars = segment_input_shell_git_vars

    for placeholder_index, substitution in enumerate(substitutions):
        if placeholder_index in used_placeholder_indexes:
            continue
        contexts.extend(
            parse_commit_contexts(
                substitution,
                inherited_git_args=inherited_git_args,
                inherited_git_env=inherited_git_env,
                inherited_shell_git_vars=inherited_shell_git_vars,
                depth=depth + 1,
            )
        )
    return contexts


def lookup_replay_env(assignments, key):
    for assignment in assignments:
        assignment_key, _, assignment_value = assignment.partition("=")
        if assignment_key == key:
            return assignment_value
    return None


def parse_commit_segment(tokens, git_args, git_env, shell_git_vars, depth=0):
    idx = 0
    git_args = list(git_args)
    inherited_shell_git_env = list(git_env)
    shell_git_env = list(inherited_shell_git_env)
    inherited_shell_git_vars = list(shell_git_vars)
    shell_git_vars = list(inherited_shell_git_vars)
    git_env = list(shell_git_env)
    shell_env_persists = True
    pending_shell_git_vars = []

    while idx < len(tokens) and tokens[idx] in COMMIT_SHELL_KEYWORDS:
        if tokens[idx] == "(":
            shell_env_persists = False
        idx += 1

    while idx < len(tokens) and COMMIT_ASSIGNMENT.match(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        if key in COMMIT_REPLAY_ENV_VARS:
            set_replay_env(git_env, key, value)
            set_replay_env(pending_shell_git_vars, key, value)
        idx += 1

    if idx >= len(tokens):
        for assignment in pending_shell_git_vars:
            key, value = assignment.split("=", 1)
            set_replay_env(shell_git_vars, key, value)
        persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
        persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
        return CommitSegmentResult(
            contexts=[],
            persisted_git_env=persisted_shell_git_env,
            persisted_shell_git_vars=persisted_shell_git_vars,
        )

    while idx < len(tokens):
        base = os.path.basename(tokens[idx])
        if base in {"command", "builtin"}:
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if token == "--":
                    idx += 1
                    break
                if token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "alias":
            raise ParseError("shell alias definitions are not supported")

        if base == "sudo":
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if token == "--":
                    idx += 1
                    break
                if token in COMMIT_SUDO_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if token in COMMIT_SUDO_LONG_OPTIONS_WITH_VALUE:
                    if token == "--chdir" and idx + 1 < len(tokens):
                        git_args.extend(["-C", tokens[idx + 1]])
                    idx += 2
                    continue
                if token in {"--askpass", "--background", "--preserve-env", "--remove-timestamp", "--reset-timestamp", "--validate", "--version", "--list", "--non-interactive"}:
                    idx += 1
                    continue
                if any(
                    token.startswith(prefix)
                    for prefix in (
                        "--host=",
                        "--user=",
                        "--group=",
                        "--prompt=",
                        "--command-timeout=",
                        "--close-from=",
                        "--chroot=",
                        "--login-class=",
                        "--role=",
                        "--type=",
                        "--other-user=",
                        "--preserve-env=",
                    )
                ):
                    idx += 1
                    continue
                if token.startswith("--chdir="):
                    git_args.extend(["-C", token.split("=", 1)[1]])
                    idx += 1
                    continue
                if token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "export":
            for assignment in pending_shell_git_vars:
                key, value = assignment.split("=", 1)
                set_replay_env(shell_git_vars, key, value)
            pending_shell_git_vars = []
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if token == "--":
                    idx += 1
                    break
                if token == "-n":
                    if idx + 1 < len(tokens):
                        unset_replay_env(shell_git_env, tokens[idx + 1])
                        unset_replay_env(git_env, tokens[idx + 1])
                    idx += 2
                    continue
                if token.startswith("-n") and token != "-n":
                    unset_replay_env(shell_git_env, token[2:])
                    unset_replay_env(git_env, token[2:])
                    idx += 1
                    continue
                if COMMIT_ASSIGNMENT.match(token):
                    key, value = token.split("=", 1)
                    if key in COMMIT_REPLAY_ENV_VARS:
                        set_replay_env(shell_git_vars, key, value)
                        set_replay_env(shell_git_env, key, value)
                        set_replay_env(git_env, key, value)
                    idx += 1
                    continue
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", token):
                    value = lookup_replay_env(shell_git_vars, token)
                    if value is not None:
                        set_replay_env(shell_git_env, token, value)
                        set_replay_env(git_env, token, value)
                    idx += 1
                    continue
                if token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "unset":
            pending_shell_git_vars = []
            unset_targets_variables = True
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if token == "--":
                    idx += 1
                    break
                if token in {"-f", "-n"}:
                    unset_targets_variables = False
                    idx += 1
                    continue
                if token == "-v":
                    unset_targets_variables = True
                    idx += 1
                    continue
                if token.startswith("-"):
                    option_flags = token[1:]
                    if "f" in option_flags or "n" in option_flags:
                        unset_targets_variables = False
                    elif "v" in option_flags:
                        unset_targets_variables = True
                    idx += 1
                    continue
                if unset_targets_variables:
                    unset_replay_env(shell_git_vars, token)
                    unset_replay_env(shell_git_env, token)
                    unset_replay_env(git_env, token)
                idx += 1
            continue

        if base == "env":
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if COMMIT_ASSIGNMENT.match(token):
                    key, value = token.split("=", 1)
                    if key in COMMIT_REPLAY_ENV_VARS:
                        set_replay_env(git_env, key, value)
                    idx += 1
                    continue
                if token == "--":
                    idx += 1
                    break
                if token in {"-i", "--ignore-environment"}:
                    clear_replay_env(git_env)
                    idx += 1
                    continue
                if token in COMMIT_ENV_OPTIONS_WITH_VALUE:
                    if token in {"-u", "--unset"}:
                        if idx + 1 < len(tokens):
                            unset_replay_env(git_env, tokens[idx + 1])
                        idx += 2
                        continue
                    if token in {"-C", "--chdir"} and idx + 1 < len(tokens):
                        git_args.extend(["-C", tokens[idx + 1]])
                    idx += 2
                    continue
                if token.startswith("--unset="):
                    unset_replay_env(git_env, token.split("=", 1)[1])
                    idx += 1
                    continue
                if token.startswith("-u") and token != "-u":
                    unset_replay_env(git_env, token[2:])
                    idx += 1
                    continue
                if token.startswith("--chdir="):
                    git_args.extend(["-C", token.split("=", 1)[1]])
                    idx += 1
                    continue
                if token.startswith("-C") and token != "-C":
                    git_args.extend(["-C", token[2:]])
                    idx += 1
                    continue
                if token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base in COMMIT_SHELL_EXECUTABLES:
            nested_command = parse_shell_inline_command(tokens[idx + 1 :])
            if nested_command is None:
                persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
                persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
                return CommitSegmentResult(
                    contexts=[],
                    persisted_git_env=persisted_shell_git_env,
                    persisted_shell_git_vars=persisted_shell_git_vars,
                )
            persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
            persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
            return CommitSegmentResult(
                contexts=parse_commit_contexts(
                    nested_command,
                    inherited_git_args=git_args,
                    inherited_git_env=git_env,
                    inherited_shell_git_vars=list(git_env),
                    depth=depth + 1,
                ),
                persisted_git_env=persisted_shell_git_env,
                persisted_shell_git_vars=persisted_shell_git_vars,
            )

        if base == "git":
            break

        persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
        persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
        return CommitSegmentResult(
            contexts=[],
            persisted_git_env=persisted_shell_git_env,
            persisted_shell_git_vars=persisted_shell_git_vars,
        )

    if idx >= len(tokens) or os.path.basename(tokens[idx]) != "git":
        persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
        persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
        return CommitSegmentResult(
            contexts=[],
            persisted_git_env=persisted_shell_git_env,
            persisted_shell_git_vars=persisted_shell_git_vars,
        )

    idx += 1
    while idx < len(tokens):
        token = tokens[idx]
        if token == "--":
            idx += 1
            break
        if token in COMMIT_GIT_OPTIONS_WITH_VALUE:
            git_args.append(token)
            if idx + 1 < len(tokens):
                git_args.append(tokens[idx + 1])
            idx += 2
            continue
        if any(token.startswith(prefix + "=") for prefix in ("--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env")):
            git_args.append(token)
            idx += 1
            continue
        if token.startswith("-"):
            git_args.append(token)
            idx += 1
            continue
        # Command substitution between `git` and its subcommand expands to
        # unknown flags at runtime; keep scanning so a commit context is
        # emitted and the dynamic-repo-selection gate can block on the
        # retained placeholder.
        if token.startswith("__CMD_SUBST_"):
            git_args.append(token)
            idx += 1
            continue
        break

    if idx < len(tokens) and tokens[idx] == "commit":
        persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
        persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
        return CommitSegmentResult(
            contexts=[{"git_args": git_args, "git_env": git_env}],
            persisted_git_env=persisted_shell_git_env,
            persisted_shell_git_vars=persisted_shell_git_vars,
        )

    persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
    persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
    return CommitSegmentResult(
        contexts=[],
        persisted_git_env=persisted_shell_git_env,
        persisted_shell_git_vars=persisted_shell_git_vars,
    )




def run_commit_contexts(command: str, parse_error_reason: str) -> int:
    try:
        result = parse_commit_contexts(command)
    except (ParseError, RecursionError):
        # Emit a sentinel the shell caller recognises and blocks on.
        result = [{"parse_error": parse_error_reason}]
    print(json.dumps(result))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "usage: git_command_parser.py <noninteractive|commit-contexts|rm-rf> "
            "<command> [parse-error-reason]",
            file=sys.stderr,
        )
        return 2

    mode = argv[0]
    command = argv[1]

    if mode == "noninteractive":
        return run_noninteractive(command)

    if mode == "commit-contexts":
        parse_error_reason = argv[2] if len(argv) > 2 else "Unable to safely parse command."
        return run_commit_contexts(command, parse_error_reason)

    if mode == "rm-rf":
        return run_rm_rf(command)

    print(f"unknown parser mode: {mode}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
