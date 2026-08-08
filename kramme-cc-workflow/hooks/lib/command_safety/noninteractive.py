"""`noninteractive` mode: block git commands that can open an editor or prompt.

See README.md#git-command-parser-mode-contracts in the parent directory for
the CLI contract this mode implements.
"""

from __future__ import annotations

import json
import re
from typing import Optional, TypedDict

from .lexer import (
    extract_placeholder_indexes,
    replace_command_substitutions,
    split_segments,
    tokenize,
)
from .prefix import normalize_command_prefix
from .structs import _StructValue
from .syntax import (
    ENV_PERSISTING_CONTROL_TOKENS,
    SHELL_EXECUTABLES,
    SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE,
    _basename_no_unescape,
    _is_assignment,
)
from .vocabulary import (
    GIT_GLOBAL_END_OF_OPTIONS,
    GIT_GLOBAL_OPTION_AMBIGUOUS,
    GIT_GLOBAL_OPTION_FLAG,
    GIT_GLOBAL_OPTION_WITH_VALUE,
    _skip_xargs_options,
    classify_git_global_option,
)

NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND = "__parse_error__"
NONINTERACTIVE_PARSE_ERROR_REASON = "Unable to safely parse command. Refusing potentially interactive git command."


class NoninteractiveSubstitution(TypedDict):
    command: str
    env: dict[str, str]


class NoninteractiveParseResult(_StructValue):
    __slots__ = ("env", "subcmd", "args")

    def __init__(self, env: dict[str, str], subcmd: str, args: list[str]) -> None:
        self.env = env
        self.subcmd = subcmd
        self.args = args


def _noninteractive_is_git_exec(token: str) -> bool:
    return _basename_no_unescape(token) == "git"


def _unset_editor_env(env: dict[str, str], key: str) -> None:
    if key in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
        env.pop(key, None)


def _apply_exported_editor_env(
    tokens: list[str],
    inherited_env: Optional[dict[str, str]] = None,
    inherited_shell_vars: Optional[dict[str, str]] = None,
) -> tuple[dict[str, str], dict[str, str]]:
    env: dict[str, str] = dict(inherited_env or {})
    shell_vars: dict[str, str] = dict(inherited_shell_vars or env)
    idx = 0
    shell_env_persists = True
    pending_shell_vars: dict[str, str] = {}

    while idx < len(tokens) and tokens[idx] in SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE:
        if tokens[idx] == "(":
            shell_env_persists = False
        idx += 1

    while idx < len(tokens) and _is_assignment(tokens[idx]):
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

    command_name = _basename_no_unescape(tokens[idx])
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
            if _is_assignment(token):
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


def parse_env_wrapped_segment(
    tokens: list[str], inherited_env: Optional[dict[str, str]] = None
) -> Optional[NoninteractiveParseResult]:
    inherited_assignments = [f"{key}={value}" for key, value in (inherited_env or {}).items()]
    normalized = normalize_command_prefix(tokens, inherited_environment=inherited_assignments)

    while normalized.executable is not None:
        command_name = _basename_no_unescape(normalized.executable)
        args = normalized.arguments
        idx = 0

        if command_name == "xargs":
            idx = _skip_xargs_options(args)
        elif command_name == "find":
            while idx < len(args) and args[idx] not in {"-exec", "-execdir"}:
                idx += 1
            if idx < len(args):
                idx += 1
        elif command_name in {"-exec", "-execdir"}:
            pass
        else:
            break

        if idx >= len(args):
            return None
        normalized = normalize_command_prefix(
            args[idx:],
            inherited_environment=normalized.environment,
            inherited_repository_modifiers=normalized.repository_modifiers,
        )

    if normalized.executable is None:
        return None

    env = {assignment.split("=", 1)[0]: assignment.split("=", 1)[1] for assignment in normalized.environment}
    exec_token = normalized.executable
    if _basename_no_unescape(exec_token) == "alias":
        return NoninteractiveParseResult(
            env=env,
            subcmd=NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND,
            args=[],
        )

    if _basename_no_unescape(exec_token) in SHELL_EXECUTABLES:
        nested_command = normalized.nested_shell_command
        if nested_command is None:
            return None
        return NoninteractiveParseResult(
            env=env,
            subcmd="__shell_c__",
            args=[nested_command],
        )

    if not _noninteractive_is_git_exec(exec_token):
        return None

    git_argv = normalized.arguments
    if not git_argv:
        return None

    git_idx = 0
    while git_idx < len(git_argv):
        classification = classify_git_global_option(git_argv[git_idx])
        if classification == GIT_GLOBAL_END_OF_OPTIONS:
            git_idx += 1
            break
        if classification == GIT_GLOBAL_OPTION_WITH_VALUE:
            git_idx += 2
            continue
        if classification == GIT_GLOBAL_OPTION_FLAG:
            git_idx += 1
            continue
        if classification == GIT_GLOBAL_OPTION_AMBIGUOUS:
            # We cannot tell whether the next token is this option's value or
            # the subcommand, so refuse rather than let an interactive command
            # hide behind it.
            return NoninteractiveParseResult(
                env=env,
                subcmd=NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND,
                args=[],
            )
        break

    if git_idx >= len(git_argv):
        return None

    return NoninteractiveParseResult(
        env=env,
        subcmd=git_argv[git_idx],
        args=git_argv[git_idx + 1 :],
    )


def _parse_noninteractive_git_commands(
    command: str,
    inherited_env: Optional[dict[str, str]] = None,
    inherited_shell_vars: Optional[dict[str, str]] = None,
) -> tuple[list[NoninteractiveParseResult], list[NoninteractiveSubstitution]]:
    sanitized_command, raw_substitutions = replace_command_substitutions(command)
    tokens = tokenize(sanitized_command)
    parsed_commands: list[NoninteractiveParseResult] = []
    substitutions: list[NoninteractiveSubstitution] = []
    current_env: dict[str, str] = dict(inherited_env or {})
    current_shell_vars: dict[str, str] = dict(inherited_shell_vars or current_env)
    used_placeholder_indexes: set[int] = set()
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
        if separator in ENV_PERSISTING_CONTROL_TOKENS:
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


def _has_long_option(args: list[str], *names: str) -> bool:
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


def _has_short_option(args: list[str], *letters: str) -> bool:
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


def _has_short_option_value_aware(args: list[str], wanted: str, options_with_values: set[str]) -> bool:
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


def _short_option_consumes_next_value(arg: str, options_with_values: set[str]) -> bool:
    if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
        return False
    letters = arg[1:]
    for idx, letter in enumerate(letters):
        if letter in options_with_values:
            return idx == len(letters) - 1
    return False


def _has_long_option_value_aware(
    args: list[str],
    wanted: str,
    short_options_with_values: set[str],
    long_options_with_values: set[str],
) -> bool:
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
            continue
        if arg == "--":
            break
        if arg == wanted or arg.startswith(wanted + "="):
            return True
        if _short_option_consumes_next_value(arg, short_options_with_values):
            skip_next = True
            continue
        if arg in long_options_with_values:
            skip_next = True
    return False


def _fixup_value_is_interactive(value: str) -> bool:
    return value.startswith("amend:") or value.startswith("reword:")


def _classify_commit_fixup(args: list[str]) -> str:
    skip_next = False
    expecting_fixup_value = False
    for arg in args:
        if expecting_fixup_value:
            return "interactive" if _fixup_value_is_interactive(arg) else "safe"
        if skip_next:
            skip_next = False
            continue
        if arg == "--":
            break
        if arg == "--fixup":
            expecting_fixup_value = True
            continue
        if arg.startswith("--fixup="):
            return "interactive" if _fixup_value_is_interactive(arg.split("=", 1)[1]) else "safe"
        if _short_option_consumes_next_value(arg, COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE):
            skip_next = True
            continue
        if arg in COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE:
            skip_next = True
    return "none"


def _has_safe_fixup(args: list[str]) -> bool:
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


def _commit_requests_editor(args: list[str]) -> bool:
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


def _merge_edit_is_safe(args: list[str]) -> bool:
    return _has_long_option(args, "--ff-only") and not _has_long_option(args, "--no-ff")


def _evaluate_noninteractive_commands(
    parsed_commands: list[NoninteractiveParseResult],
    substitutions: list[NoninteractiveSubstitution],
    depth: int = 0,
) -> Optional[str]:
    if depth > 4:
        return NONINTERACTIVE_PARSE_ERROR_REASON

    for substitution in substitutions:
        try:
            nested_commands, nested_substitutions = _parse_noninteractive_git_commands(
                substitution["command"],
                inherited_env=substitution["env"],
                inherited_shell_vars=substitution["env"],
            )
        except ValueError:
            return NONINTERACTIVE_PARSE_ERROR_REASON
        reason = _evaluate_noninteractive_commands(nested_commands, nested_substitutions, depth=depth + 1)
        if reason is not None:
            return reason

    for parsed in parsed_commands:
        subcmd = parsed.subcmd
        args = parsed.args
        env = parsed.env

        if subcmd == NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND:
            return NONINTERACTIVE_PARSE_ERROR_REASON

        if subcmd == "__shell_c__":
            try:
                nested_commands, nested_substitutions = _parse_noninteractive_git_commands(
                    args[0],
                    inherited_env=env,
                    inherited_shell_vars=env,
                )
            except ValueError:
                return NONINTERACTIVE_PARSE_ERROR_REASON
            reason = _evaluate_noninteractive_commands(nested_commands, nested_substitutions, depth=depth + 1)
            if reason is not None:
                return reason
            continue

        if subcmd == "commit":
            if _has_short_option_value_aware(
                args, "e", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES
            ) or _has_long_option_value_aware(
                args,
                "--edit",
                COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE,
            ):
                return "git commit --edit opens an editor. Remove --edit to keep the commit non-interactive."
            commit_fixup_mode = _classify_commit_fixup(args)
            has_no_edit = _has_long_option(args, "--no-edit")
            if commit_fixup_mode == "interactive" and not has_no_edit:
                return "git commit --fixup=amend:<commit> and --fixup=reword:<commit> open an editor unless you also pass --no-edit."
            has_message_source = not _commit_requests_editor(args) and (
                _has_short_option_value_aware(args, "m", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                or _has_short_option_value_aware(args, "F", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                or _has_short_option_value_aware(args, "C", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                or _has_safe_fixup(args)
                or _has_long_option(args, "--message", "--file", "--reuse-message")
                or commit_fixup_mode == "safe"
                or _has_long_option(args, "--no-edit")
            )
            if not has_message_source:
                return 'git commit without a message source may open an editor. Use: git commit -m "your message" (or --no-edit for amend)'

        elif subcmd == "rebase":
            if _has_short_option(args, "i") or _has_long_option(args, "--interactive"):
                if "GIT_SEQUENCE_EDITOR" not in env:
                    return "Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ..."
            if _has_long_option(args, "--continue"):
                if "GIT_EDITOR" not in env:
                    return "git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue"

        elif subcmd == "add":
            if _has_short_option(args, "p", "i") or _has_long_option(args, "--patch", "--interactive"):
                return "Interactive git add opens a prompt. Use explicit paths: git add <files>"

        elif subcmd == "merge":
            if (
                _has_short_option_value_aware(args, "e", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                or _has_long_option_value_aware(
                    args,
                    "--edit",
                    MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                    MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE,
                )
            ) and not _merge_edit_is_safe(args):
                return "git merge --edit opens an editor. Remove --edit to keep the merge non-interactive."
            is_explicitly_safe = _has_long_option(
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
                is_explicitly_safe = _has_short_option_value_aware(
                    args, "m", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES
                ) or _has_short_option_value_aware(args, "F", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
            if not is_explicitly_safe:
                return "git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>"

        elif subcmd == "cherry-pick":
            is_explicitly_safe = _has_long_option(
                args,
                "--continue",
                "--abort",
                "--quit",
                "--skip",
                "--no-edit",
                "--no-commit",
            ) or _has_short_option(args, "n")
            if not is_explicitly_safe:
                return "git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>"

    return None


def run_noninteractive(command: str) -> int:
    """Emit the `noninteractive` mode decision.

    See README.md#git-command-parser-mode-contracts.
    """
    try:
        parsed_commands, substitutions = _parse_noninteractive_git_commands(command)
    except ValueError:
        print(json.dumps({"block": NONINTERACTIVE_PARSE_ERROR_REASON}))
        return 0

    reason = _evaluate_noninteractive_commands(parsed_commands, substitutions)
    print(json.dumps({"block": reason}))
    return 0
