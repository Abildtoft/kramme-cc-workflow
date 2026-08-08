"""Command-prefix normalization shared by every parser mode.

`normalize_command_prefix` walks the execution wrappers that can sit in front
of the real executable (`env`, `sudo`, `nice`, `timeout`, `time`, `nohup`,
`exec`, `command`/`builtin`) and reports what actually runs, with the
environment and repository selectors those wrappers contributed. It applies no
hook policy: each mode decides what to do with the result.

Each wrapper owns one handler in `_WRAPPER_HANDLERS`, keyed by the wrapper's
basename. A handler advances `_WrapperScan.idx` past its own options and
records whatever the wrapper changed about the environment, the repository
selectors, or whether shell builtins and reserved words still apply. Adding a
wrapper means adding a handler and a table entry; nothing else in the walk
changes.
"""

from __future__ import annotations

import shlex
from collections.abc import Callable
from typing import Optional

from .structs import _StructValue
from .syntax import (
    SHELL_EXECUTABLES,
    SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE,
    SHELL_OPTIONS_WITH_VALUE,
    _basename,
    _is_assignment,
    _shell_has_c_option,
)

# Bound recursive env -S reparsing and argv rebuilding so safety hooks stay responsive.
MAX_ENV_SPLIT_STRING_EXPANSIONS = 64
MAX_ENV_SPLIT_STRING_EXPANSION_WORK = 100_000


class NormalizedCommandPrefix(_StructValue):
    __slots__ = (
        "executable",
        "arguments",
        "environment",
        "repository_modifiers",
        "nested_shell_command",
        "shell_builtins_allowed",
    )

    def __init__(
        self,
        executable: Optional[str],
        arguments: list[str],
        environment: list[str],
        repository_modifiers: list[str],
        nested_shell_command: Optional[str],
        shell_builtins_allowed: bool,
    ) -> None:
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.repository_modifiers = repository_modifiers
        self.nested_shell_command = nested_shell_command
        self.shell_builtins_allowed = shell_builtins_allowed


def _set_environment_assignment(environment: dict[str, str], assignment: str) -> None:
    key = assignment.split("=", 1)[0]
    environment.pop(key, None)
    environment[key] = assignment


def _unset_environment_assignment(environment: dict[str, str], key: str) -> None:
    environment.pop(key, None)


def _index_environment_assignments(
    assignments: list[str],
) -> dict[str, str]:
    environment: dict[str, str] = {}
    for assignment in assignments:
        _set_environment_assignment(environment, assignment)
    return environment


def _filter_environment_assignments(environment: list[str], allowed_keys: set[str]) -> list[str]:
    return [assignment for assignment in environment if assignment.split("=", 1)[0] in allowed_keys]


def _consume_environment_assignments(tokens: list[str], idx: int, environment: dict[str, str]) -> int:
    while idx < len(tokens) and _is_assignment(tokens[idx]):
        _set_environment_assignment(environment, tokens[idx])
        idx += 1
    return idx


def _extract_shell_inline_command(args: list[str]) -> Optional[str]:
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in {"-c", "--command"}:
            idx += 1
            if idx < len(args) and args[idx] == "--":
                idx += 1
            return args[idx] if idx < len(args) else None
        if arg.startswith("--command="):
            return arg.split("=", 1)[1]
        if arg in SHELL_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in ("--rcfile", "--init-file", "--startup-file")):
            idx += 1
            continue
        if arg == "--":
            return None
        if _shell_has_c_option(arg):
            idx += 1
            if idx < len(args) and args[idx] == "--":
                idx += 1
            return args[idx] if idx < len(args) else None
        if arg.startswith("-") or arg.startswith("+"):
            idx += 1
            continue
        return None
    return None


class _WrapperScan:
    """Mutable position and accumulated effects of the wrapper walk."""

    __slots__ = (
        "tokens",
        "idx",
        "environment",
        "repository_modifiers",
        "shell_builtins_allowed",
        "shell_keywords_allowed",
        "split_string_expansions",
        "split_string_expansion_work",
    )

    def __init__(
        self,
        tokens: list[str],
        environment: dict[str, str],
        repository_modifiers: list[str],
        shell_keywords_allowed: bool,
    ) -> None:
        self.tokens = tokens
        self.idx = 0
        self.environment = environment
        self.repository_modifiers = repository_modifiers
        # External wrappers resolve their payload as an executable, so shell
        # builtins and reserved words stop applying once one has been consumed.
        self.shell_builtins_allowed = True
        self.shell_keywords_allowed = shell_keywords_allowed
        self.split_string_expansions = 0
        self.split_string_expansion_work = 0


def _handle_command_builtin(scan: _WrapperScan) -> None:
    """`command` / `builtin`: skip their own options, keep the environment."""
    scan.shell_keywords_allowed = False
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            break
        if token.startswith("-"):
            scan.idx += 1
            continue
        break


def _handle_env(scan: _WrapperScan) -> None:
    """`env`: apply assignments, unsets, `-C` chdir, and `-S` re-splitting."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    options_allowed = True
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if _is_assignment(token):
            _set_environment_assignment(scan.environment, token)
            scan.idx += 1
            continue
        if options_allowed and token == "--":
            options_allowed = False
            scan.idx += 1
            continue
        if not options_allowed:
            break
        if token in {"-i", "--ignore-environment"}:
            scan.environment.clear()
            scan.idx += 1
            continue
        if token in {"-u", "--unset"}:
            if scan.idx + 1 >= len(scan.tokens):
                scan.idx = len(scan.tokens)
                break
            _unset_environment_assignment(scan.environment, scan.tokens[scan.idx + 1])
            scan.idx += 2
            continue
        if token.startswith("--unset="):
            _unset_environment_assignment(scan.environment, token.split("=", 1)[1])
            scan.idx += 1
            continue
        if token.startswith("-u") and token != "-u":
            _unset_environment_assignment(scan.environment, token[2:])
            scan.idx += 1
            continue
        if token in {"-C", "--chdir"}:
            if scan.idx + 1 >= len(scan.tokens):
                scan.idx = len(scan.tokens)
                break
            scan.repository_modifiers.extend(["-C", scan.tokens[scan.idx + 1]])
            scan.idx += 2
            continue
        if token.startswith("--chdir="):
            scan.repository_modifiers.extend(["-C", token.split("=", 1)[1]])
            scan.idx += 1
            continue
        if token.startswith("-C") and token != "-C":
            scan.repository_modifiers.extend(["-C", token[2:]])
            scan.idx += 1
            continue
        split_string_value: Optional[str] = None
        split_string_width = 0
        if token in {"-S", "--split-string"}:
            if scan.idx + 1 >= len(scan.tokens):
                scan.idx = len(scan.tokens)
                break
            split_string_value = scan.tokens[scan.idx + 1]
            split_string_width = 2
        elif token.startswith("--split-string="):
            split_string_value = token.split("=", 1)[1]
            split_string_width = 1
        if split_string_value is not None:
            scan.split_string_expansions += 1
            scan.split_string_expansion_work += len(split_string_value)
            if (
                scan.split_string_expansions > MAX_ENV_SPLIT_STRING_EXPANSIONS
                or scan.split_string_expansion_work > MAX_ENV_SPLIT_STRING_EXPANSION_WORK
            ):
                raise ValueError("env split-string expansion limit exceeded")
            split_tokens = shlex.split(split_string_value, posix=True)
            scan.tokens = scan.tokens[: scan.idx] + split_tokens + scan.tokens[scan.idx + split_string_width :]
            continue
        if token.startswith("-"):
            scan.idx += 1
            continue
        break


_SUDO_SHORT_OPTIONS_WITH_VALUE = {
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
_SUDO_LONG_OPTIONS_WITH_VALUE = {
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
# Derived, not restated, for the same reason as the letters below. `--chdir` is
# excluded on purpose: _handle_sudo tests this set before its `--chdir=` branch,
# so including it would make the attached-value skip swallow `--chdir=DIR` and
# drop the repository selector that option contributes.
_SUDO_LONG_OPTIONS_WITH_ATTACHED_VALUE = _SUDO_LONG_OPTIONS_WITH_VALUE - {"--chdir"}
# Derived, not restated: _handle_sudo reads the dashed set for standalone
# options and these letters for bundled ones, so a hand-maintained copy would
# let the two paths disagree about where the command starts.
_SUDO_SHORT_OPTION_LETTERS_WITH_VALUE = {option[1:] for option in _SUDO_SHORT_OPTIONS_WITH_VALUE}


def _handle_sudo(scan: _WrapperScan) -> None:
    """`sudo`: skip its options, keep `--chdir`, then take trailing assignments."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            break
        if token in _SUDO_SHORT_OPTIONS_WITH_VALUE or token in _SUDO_LONG_OPTIONS_WITH_VALUE:
            if scan.idx + 1 >= len(scan.tokens):
                scan.idx = len(scan.tokens)
                break
            if token == "--chdir":
                scan.repository_modifiers.extend(["-C", scan.tokens[scan.idx + 1]])
            scan.idx += 2
            continue
        if any(token.startswith(prefix + "=") for prefix in _SUDO_LONG_OPTIONS_WITH_ATTACHED_VALUE):
            scan.idx += 1
            continue
        if token.startswith("--chdir="):
            scan.repository_modifiers.extend(["-C", token.split("=", 1)[1]])
            scan.idx += 1
            continue
        if token.startswith("-") and not token.startswith("--"):
            value_option_seen = False
            option_letters = token[1:]
            for position, letter in enumerate(option_letters):
                if letter in _SUDO_SHORT_OPTION_LETTERS_WITH_VALUE:
                    if position == len(option_letters) - 1:
                        scan.idx += 2
                    else:
                        scan.idx += 1
                    value_option_seen = True
                    break
            if value_option_seen:
                continue
            scan.idx += 1
            continue
        if token.startswith("-"):
            scan.idx += 1
            continue
        break
    scan.idx = _consume_environment_assignments(scan.tokens, scan.idx, scan.environment)


def _handle_nice(scan: _WrapperScan) -> None:
    """`nice`: skip the adjustment option and any other flags."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            break
        if token in {"-n", "--adjustment"}:
            scan.idx += 2
            continue
        if token.startswith("--adjustment=") or token.startswith("-"):
            scan.idx += 1
            continue
        break


def _handle_timeout(scan: _WrapperScan) -> None:
    """`timeout`: skip its options plus the mandatory duration operand."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            if scan.idx < len(scan.tokens):
                scan.idx += 1
            break
        if token in {"-s", "--signal", "-k", "--kill-after"}:
            scan.idx += 2
            continue
        if token.startswith("--signal=") or token.startswith("--kill-after=") or token.startswith("-"):
            scan.idx += 1
            continue
        scan.idx += 1
        break


def _handle_time(scan: _WrapperScan) -> None:
    """`time`: keyword or external, depending on the word and its options."""
    # Bare `time` is a shell keyword. Path-qualified or externally
    # selected variants, and GNU-only options, use executable semantics.
    time_is_shell_keyword = (
        scan.shell_keywords_allowed
        and scan.tokens[scan.idx] == "time"
        and getattr(scan.tokens[scan.idx], "shell_keyword_eligible", True)
    )
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            break
        if token in {"-o", "-f", "--output", "--format"}:
            time_is_shell_keyword = False
            scan.idx += 2
            continue
        if token.startswith("--output=") or token.startswith("--format=") or token.startswith("-"):
            if token != "-p":
                time_is_shell_keyword = False
            scan.idx += 1
            continue
        break
    if not time_is_shell_keyword:
        scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = time_is_shell_keyword
    if time_is_shell_keyword:
        assignment_start = scan.idx
        scan.idx = _consume_environment_assignments(scan.tokens, scan.idx, scan.environment)
        if scan.idx != assignment_start:
            scan.shell_keywords_allowed = False


def _handle_nohup(scan: _WrapperScan) -> None:
    """`nohup`: no options of its own beyond an optional `--`."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    if scan.idx < len(scan.tokens) and scan.tokens[scan.idx] == "--":
        scan.idx += 1


def _handle_exec(scan: _WrapperScan) -> None:
    """`exec`: `-c` clears the environment and `-a` consumes an argv[0] name."""
    scan.shell_builtins_allowed = False
    scan.shell_keywords_allowed = False
    scan.idx += 1
    while scan.idx < len(scan.tokens):
        token = scan.tokens[scan.idx]
        if token == "--":
            scan.idx += 1
            break
        if token.startswith("-"):
            option_letters = token[1:]
            consume_argv0_name = False
            for position, letter in enumerate(option_letters):
                if letter == "c":
                    scan.environment.clear()
                    continue
                if letter == "l":
                    continue
                if letter == "a":
                    consume_argv0_name = position == len(option_letters) - 1
                break
            scan.idx += 1
            if consume_argv0_name:
                scan.idx += 1
            continue
        break


_WRAPPER_HANDLERS: dict[str, Callable[[_WrapperScan], None]] = {
    "builtin": _handle_command_builtin,
    "command": _handle_command_builtin,
    "env": _handle_env,
    "exec": _handle_exec,
    "nice": _handle_nice,
    "nohup": _handle_nohup,
    "sudo": _handle_sudo,
    "time": _handle_time,
    "timeout": _handle_timeout,
}


def normalize_command_prefix(
    tokens: list[str],
    inherited_environment: Optional[list[str]] = None,
    inherited_repository_modifiers: Optional[list[str]] = None,
    shell_keywords_allowed: bool = True,
) -> NormalizedCommandPrefix:
    """Normalize wrappers before the executable without applying hook policy."""
    scan = _WrapperScan(
        tokens=list(tokens),
        environment=_index_environment_assignments(inherited_environment or []),
        repository_modifiers=list(inherited_repository_modifiers or []),
        shell_keywords_allowed=shell_keywords_allowed,
    )

    while (
        scan.shell_keywords_allowed
        and scan.idx < len(scan.tokens)
        and scan.tokens[scan.idx] in SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE
    ):
        scan.idx += 1

    assignment_start = scan.idx
    scan.idx = _consume_environment_assignments(scan.tokens, scan.idx, scan.environment)
    if scan.idx != assignment_start:
        scan.shell_keywords_allowed = False

    while scan.idx < len(scan.tokens):
        handler = _WRAPPER_HANDLERS.get(_basename(scan.tokens[scan.idx]))
        if handler is None:
            break
        handler(scan)

    executable = scan.tokens[scan.idx] if scan.idx < len(scan.tokens) else None
    arguments = scan.tokens[scan.idx + 1 :] if executable is not None else []
    nested_shell_command = None
    if executable is not None and _basename(executable) in SHELL_EXECUTABLES:
        nested_shell_command = _extract_shell_inline_command(arguments)

    return NormalizedCommandPrefix(
        executable=executable,
        arguments=arguments,
        environment=list(scan.environment.values()),
        repository_modifiers=scan.repository_modifiers,
        nested_shell_command=nested_shell_command,
        shell_builtins_allowed=scan.shell_builtins_allowed,
    )
