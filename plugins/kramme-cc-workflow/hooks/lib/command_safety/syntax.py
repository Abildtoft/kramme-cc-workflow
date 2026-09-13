"""Shell syntax primitives shared by every parser mode.

Bottom of the package dependency order: nothing here imports another
command_safety module, so the command-prefix normalizer, the tokenizer, and
all three policy modes can depend on it without a cycle.
"""

from __future__ import annotations

import os
import re
import shlex
from typing import Optional, TypedDict


class HeredocSpec(TypedDict):
    delimiter: str
    quoted: bool
    strip_tabs: bool
    start: int


class PendingHeredoc(HeredocSpec):
    keep_body: bool


CONTROL_TOKENS = {";", ";;", "&&", "||", "|", "|&", "&"}
NON_KEYWORD_TIME_SENTINEL = "\0kramme-non-keyword-time\0"
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

# Control tokens after which environment set earlier in the command list is
# still in effect. Shared by the noninteractive and commit-contexts modes.
ENV_PERSISTING_CONTROL_TOKENS = {";", "&&", "||"}
# SHELL_RESERVED_COMMAND_WORDS plus a trailing ")". Used wherever a leading
# token is skipped as a boundary keyword, which a subshell close also is:
# the noninteractive and commit-contexts env/export scans, and the
# command-prefix normalizer's own leading-keyword skip. The bare set is used
# only in _detect_rm_rf_segment, which scans for a command word rather than
# skipping a prefix, so a ")" there is not a boundary to step over.
SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE = SHELL_RESERVED_COMMAND_WORDS | {")"}


class ShellWord(str):
    shell_keyword_eligible: bool

    def __new__(cls, value: str, *, shell_keyword_eligible: bool = True) -> ShellWord:
        word = super().__new__(cls, value)
        word.shell_keyword_eligible = shell_keyword_eligible
        return word


def _decode_ansi_c_string(value: str) -> str:
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
    decoded: list[str] = []
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
            while end < min(start + max_digits, len(value)) and value[end] in "0123456789abcdefABCDEF":
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


def _quote_ansi_c_fragment(value: str) -> str:
    quoted = shlex.quote(value)
    if quoted == value:
        return f"'{value}'"
    return quoted


def _expand_ansi_c_quoted_strings(command: str) -> str:
    """Replace unquoted $'...' forms with equivalent shlex-safe strings."""
    expanded: list[str] = []
    idx = 0
    quote: Optional[str] = None
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
            value: list[str] = []
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
            decoded = _decode_ansi_c_string("".join(value))
            expanded.append(_quote_ansi_c_fragment(decoded))
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


def read_dollar_substitution(command: str, start: int) -> tuple[str, int]:
    inner: list[str] = []
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


def read_backtick_substitution(command: str, start: int) -> tuple[str, int]:
    inner: list[str] = []
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


def _extract_body_substitutions(line: str) -> list[str]:
    # Collect $(...) / `...` contents from an unquoted heredoc body line.
    # Mirrors the bash extract_body_substitutions helper.
    subs: list[str] = []
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


def _basename(token: str) -> str:
    return os.path.basename(token.lstrip("\\"))


def _basename_no_unescape(token: str) -> str:
    """Shared by the noninteractive and commit-contexts modes.

    Unlike _basename(), this does not strip a leading backslash, so a token
    that still carries one after tokenization -- `\\git`, from a command
    string containing `\\\\git` -- is not recognized as `git` here. The
    rm-rf detector uses _basename() instead and does catch the escaped
    form. Keep this delta explicit rather than merging the two helpers.
    """
    return os.path.basename(token)


def _is_assignment(token: str) -> bool:
    return ASSIGNMENT_WORD.match(token) is not None


def _is_shell_function_name(token: str) -> bool:
    return SHELL_FUNCTION_NAME.match(token) is not None


def _skip_empty_function_parens(tokens: list[str], idx: int) -> int:
    if idx < len(tokens) and tokens[idx] == "()":
        return idx + 1
    if idx + 1 < len(tokens) and tokens[idx] == "(" and tokens[idx + 1] == ")":
        return idx + 2
    return idx


def _function_body_start(tokens: list[str], idx: int) -> Optional[int]:
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


def _collect_heredocs(line: str) -> list[HeredocSpec]:
    heredocs: list[HeredocSpec] = []
    idx = 0
    quote: Optional[str] = None
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

        token: list[str] = []
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


def _tokenize_heredoc_prefix(line: str) -> list[str]:
    lexer = shlex.shlex(line, posix=True, punctuation_chars="()|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def _tokens_for_heredoc_command(tokens: list[str]) -> list[str]:
    start = 0
    for idx, token in enumerate(tokens):
        if token in CONTROL_TOKENS:
            start = idx + 1

    command_tokens: list[str] = []
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


def _shell_has_c_option(word: str) -> bool:
    return word.startswith("-") and not word.startswith("--") and "c" in word[1:]


def _shell_invocation_reads_stdin(args: list[str]) -> bool:
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

        if any(word.startswith(prefix + "=") for prefix in ("--rcfile", "--init-file", "--startup-file")):
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
