"""`commit-contexts` mode: model what a `git commit` in the command would stage.

See README.md#git-command-parser-mode-contracts in the parent directory for
the CLI contract and the commit-context field schema this mode implements.
"""

from __future__ import annotations

import json
import os
import re
from typing import Optional, TypedDict

from .lexer import (
    extract_placeholder_indexes,
    replace_command_substitutions,
    split_segments,
    tokenize,
)
from .prefix import (
    _extract_shell_inline_command,
    _filter_environment_assignments,
    normalize_command_prefix,
)
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
    classify_git_global_option,
)


class CommitContext(TypedDict, total=False):
    git_args: list[str]
    git_env: list[str]
    selection_mode: str
    pathspecs: list[str]
    pathspec_from_file: str
    pathspec_file_nul: bool
    selection_error: str
    parse_error: str


COMMIT_REPLAY_ENV_VARS = {
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_NAMESPACE",
    "GIT_COMMON_DIR",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_LITERAL_PATHSPECS",
    "GIT_GLOB_PATHSPECS",
    "GIT_NOGLOB_PATHSPECS",
    "GIT_ICASE_PATHSPECS",
}
COMMIT_SELECTION_LONG_OPTIONS_WITH_VALUE = {
    "--author",
    "--cleanup",
    "--date",
    "--file",
    "--fixup",
    "--message",
    "--reedit-message",
    "--reuse-message",
    "--squash",
    "--template",
    "--trailer",
}
COMMIT_SELECTION_LONG_OPTIONS_WITH_OPTIONAL_VALUE = {
    "--gpg-sign",
    "--untracked-files",
}
COMMIT_SELECTION_LONG_OPTIONS_WITHOUT_VALUE = {
    "--ahead-behind",
    "--allow-empty",
    "--allow-empty-message",
    "--amend",
    "--branch",
    "--dry-run",
    "--edit",
    "--long",
    "--no-ahead-behind",
    "--no-amend",
    "--no-branch",
    "--no-dry-run",
    "--no-edit",
    "--no-gpg-sign",
    "--no-long",
    "--no-null",
    "--no-porcelain",
    "--no-post-rewrite",
    "--no-quiet",
    "--no-short",
    "--no-signoff",
    "--no-status",
    "--no-verbose",
    "--no-verify",
    "--null",
    "--porcelain",
    "--post-rewrite",
    "--quiet",
    "--reset-author",
    "--short",
    "--signoff",
    "--status",
    "--verbose",
    "--verify",
}
COMMIT_SELECTION_SHORT_OPTIONS_WITH_VALUE = {"C", "F", "c", "m", "t"}
COMMIT_SELECTION_SHORT_OPTIONS_WITH_OPTIONAL_VALUE = {"S", "u"}
COMMIT_SELECTION_ERROR_PREFIX = "Unable to safely inspect git commit content selection:"


def commit_selection_error(detail: str) -> CommitContext:
    return {"selection_error": f"{COMMIT_SELECTION_ERROR_PREFIX} {detail}"}


def parse_commit_selection(args: list[str]) -> CommitContext:
    explicit_modes: list[str] = []
    pathspecs: list[str] = []
    pathspec_from_file: Optional[str] = None
    pathspec_file_nul = False
    after_separator = False
    idx = 0

    while idx < len(args):
        arg = args[idx]
        if after_separator:
            pathspecs.append(arg)
            idx += 1
            continue

        if arg == "--":
            after_separator = True
            idx += 1
            continue

        if arg in {"--patch", "--interactive"}:
            return commit_selection_error(
                "--patch and --interactive cannot be modeled without running an interactive staging session."
            )

        if arg in {"--all", "--include", "--only"}:
            explicit_modes.append(arg[2:])
            idx += 1
            continue

        if arg in {"--no-all", "--no-include", "--no-only"}:
            return commit_selection_error(f"{arg} content-selection negation is unsupported.")

        if arg == "--pathspec-from-file":
            if idx + 1 >= len(args):
                return commit_selection_error("--pathspec-from-file is missing its file.")
            pathspec_from_file = args[idx + 1]
            idx += 2
            continue

        if arg.startswith("--pathspec-from-file="):
            pathspec_from_file = arg.split("=", 1)[1]
            idx += 1
            continue

        if arg == "--pathspec-file-nul":
            pathspec_file_nul = True
            idx += 1
            continue

        if arg in {"--no-pathspec-from-file", "--no-pathspec-file-nul"}:
            return commit_selection_error(f"{arg} content-selection negation is unsupported.")

        if arg in COMMIT_SELECTION_LONG_OPTIONS_WITH_VALUE:
            if idx + 1 >= len(args):
                return commit_selection_error(f"{arg} is missing its value.")
            idx += 2
            continue

        option_name, separator, _ = arg.partition("=")
        if separator and option_name in COMMIT_SELECTION_LONG_OPTIONS_WITH_VALUE:
            idx += 1
            continue

        if (
            arg in COMMIT_SELECTION_LONG_OPTIONS_WITH_OPTIONAL_VALUE
            or separator
            and option_name in COMMIT_SELECTION_LONG_OPTIONS_WITH_OPTIONAL_VALUE
            or arg in COMMIT_SELECTION_LONG_OPTIONS_WITHOUT_VALUE
        ):
            idx += 1
            continue

        if arg.startswith("--"):
            return commit_selection_error(f"unrecognized commit option {arg}.")

        if arg.startswith("-") and arg != "-":
            cluster = arg[1:]
            consume_next = False
            for position, letter in enumerate(cluster):
                if letter == "a":
                    explicit_modes.append("all")
                    continue
                if letter == "i":
                    explicit_modes.append("include")
                    continue
                if letter == "o":
                    explicit_modes.append("only")
                    continue
                if letter == "p":
                    return commit_selection_error(
                        "-p cannot be modeled without running an interactive staging session."
                    )
                if letter in COMMIT_SELECTION_SHORT_OPTIONS_WITH_VALUE:
                    consume_next = position == len(cluster) - 1
                    break
                if letter in COMMIT_SELECTION_SHORT_OPTIONS_WITH_OPTIONAL_VALUE:
                    break
            if consume_next:
                if idx + 1 >= len(args):
                    return commit_selection_error(f"-{cluster[-1]} is missing its value.")
                idx += 2
            else:
                idx += 1
            continue

        pathspecs.append(arg)
        idx += 1

    distinct_modes = set(explicit_modes)
    if len(distinct_modes) > 1:
        return commit_selection_error("conflicting --all, --include, and --only modes are unsupported.")
    if pathspec_from_file is not None and pathspecs:
        return commit_selection_error("--pathspec-from-file cannot be combined with command-line pathspecs.")
    if pathspec_file_nul and pathspec_from_file is None:
        return commit_selection_error("--pathspec-file-nul requires --pathspec-from-file.")
    if pathspec_from_file == "":
        return commit_selection_error("--pathspec-from-file is missing its file.")
    if pathspec_from_file == "-":
        return commit_selection_error("--pathspec-from-file=- depends on consumed hook stdin.")
    if (
        any("__CMD_SUBST_" in pathspec for pathspec in pathspecs)
        or pathspec_from_file is not None
        and "__CMD_SUBST_" in pathspec_from_file
    ):
        return commit_selection_error("command substitution in a pathspec cannot be replayed safely.")

    selection_mode = (
        next(iter(distinct_modes))
        if distinct_modes
        else "only"
        if pathspecs or pathspec_from_file is not None
        else "index"
    )
    if selection_mode == "all" and (pathspecs or pathspec_from_file is not None):
        return commit_selection_error("--all cannot be combined with pathspec selection.")
    if selection_mode == "index":
        return {}

    selection: CommitContext = {
        "selection_mode": selection_mode,
        "pathspecs": pathspecs,
    }
    if pathspec_from_file is not None:
        selection["pathspec_from_file"] = pathspec_from_file
        selection["pathspec_file_nul"] = pathspec_file_nul
    return selection


def unset_replay_env(git_env: list[str], key: str) -> None:
    git_env[:] = [assignment for assignment in git_env if assignment.split("=", 1)[0] != key]


def set_replay_env(git_env: list[str], key: str, value: str) -> None:
    unset_replay_env(git_env, key)
    git_env.append(f"{key}={value}")


def inherited_replay_env_from_process() -> list[str]:
    return [f"{key}={os.environ[key]}" for key in COMMIT_REPLAY_ENV_VARS if key in os.environ]


class ParseError(Exception):
    pass


class CommitSegmentResult(_StructValue):
    __slots__ = ("contexts", "persisted_git_env", "persisted_shell_git_vars")

    def __init__(
        self,
        contexts: list[CommitContext],
        persisted_git_env: list[str],
        persisted_shell_git_vars: list[str],
    ) -> None:
        self.contexts = contexts
        self.persisted_git_env = persisted_git_env
        self.persisted_shell_git_vars = persisted_shell_git_vars


def parse_commit_contexts(
    command: str,
    inherited_git_args: Optional[list[str]] = None,
    inherited_git_env: Optional[list[str]] = None,
    inherited_shell_git_vars: Optional[list[str]] = None,
    depth: int = 0,
) -> list[CommitContext]:
    # Cap recursion so pathological nesting can't hit Python's stack limit
    # and convert a ValueError into an uncaught RecursionError (which would
    # exit the interpreter non-zero and the shell would fail open).
    if depth > 4:
        raise ParseError("command substitution nesting too deep")

    contexts: list[CommitContext] = []
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
    used_placeholder_indexes: set[int] = set()
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
        if separator in ENV_PERSISTING_CONTROL_TOKENS:
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


def lookup_replay_env(assignments: list[str], key: str) -> Optional[str]:
    for assignment in assignments:
        assignment_key, _, assignment_value = assignment.partition("=")
        if assignment_key == key:
            return assignment_value
    return None


def parse_commit_segment(
    tokens: list[str],
    git_args: list[str],
    git_env: list[str],
    shell_git_vars: list[str],
    depth: int = 0,
) -> CommitSegmentResult:
    idx = 0
    git_args = list(git_args)
    inherited_shell_git_env = list(git_env)
    shell_git_env = list(inherited_shell_git_env)
    inherited_shell_git_vars = list(shell_git_vars)
    shell_git_vars = list(inherited_shell_git_vars)
    git_env = list(shell_git_env)
    shell_env_persists = True
    pending_shell_git_vars: list[str] = []

    while idx < len(tokens) and tokens[idx] in SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE:
        if tokens[idx] == "(":
            shell_env_persists = False
        idx += 1

    assignment_start = idx
    while idx < len(tokens) and _is_assignment(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        if key in COMMIT_REPLAY_ENV_VARS:
            set_replay_env(git_env, key, value)
            set_replay_env(pending_shell_git_vars, key, value)
        idx += 1

    segment_has_command = idx < len(tokens)
    normalized = normalize_command_prefix(
        tokens[idx:],
        inherited_environment=git_env,
        inherited_repository_modifiers=git_args,
        shell_keywords_allowed=idx == assignment_start,
    )
    git_env = _filter_environment_assignments(normalized.environment, COMMIT_REPLAY_ENV_VARS)
    git_args = normalized.repository_modifiers
    tokens = [normalized.executable, *normalized.arguments] if normalized.executable is not None else []
    idx = 0

    if idx >= len(tokens):
        if not segment_has_command:
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
        base = _basename_no_unescape(tokens[idx])
        if base == "alias" and normalized.shell_builtins_allowed:
            raise ParseError("shell alias definitions are not supported")

        if base == "export" and normalized.shell_builtins_allowed:
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
                if _is_assignment(token):
                    key, value = token.split("=", 1)
                    if key in COMMIT_REPLAY_ENV_VARS:
                        set_replay_env(shell_git_vars, key, value)
                        set_replay_env(shell_git_env, key, value)
                        set_replay_env(git_env, key, value)
                    idx += 1
                    continue
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", token):
                    exported_value = lookup_replay_env(shell_git_vars, token)
                    if exported_value is not None:
                        set_replay_env(shell_git_env, token, exported_value)
                        set_replay_env(git_env, token, exported_value)
                    idx += 1
                    continue
                if token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "unset" and normalized.shell_builtins_allowed:
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

        if base in SHELL_EXECUTABLES:
            nested_command = _extract_shell_inline_command(tokens[idx + 1 :])
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

    if idx >= len(tokens) or _basename_no_unescape(tokens[idx]) != "git":
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
        classification = classify_git_global_option(token)
        if classification == GIT_GLOBAL_END_OF_OPTIONS:
            idx += 1
            break
        if classification == GIT_GLOBAL_OPTION_WITH_VALUE:
            git_args.append(token)
            if idx + 1 < len(tokens):
                git_args.append(tokens[idx + 1])
            idx += 2
            continue
        if classification == GIT_GLOBAL_OPTION_FLAG:
            git_args.append(token)
            idx += 1
            continue
        if classification == GIT_GLOBAL_OPTION_AMBIGUOUS:
            # We cannot tell whether the next token is this option's value or
            # the subcommand, so refuse rather than let a commit hide behind it.
            raise ParseError(f"ambiguous git global option: {token}")
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
        context: CommitContext = {"git_args": git_args, "git_env": git_env}
        context.update(parse_commit_selection(tokens[idx + 1 :]))
        persisted_shell_git_env = shell_git_env if shell_env_persists else inherited_shell_git_env
        persisted_shell_git_vars = shell_git_vars if shell_env_persists else inherited_shell_git_vars
        return CommitSegmentResult(
            contexts=[context],
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
    """Emit the `commit-contexts` array.

    See README.md#git-command-parser-mode-contracts.
    """
    result: list[CommitContext]
    try:
        result = parse_commit_contexts(command)
    except (ParseError, RecursionError, ValueError):
        # Emit a sentinel the shell caller recognises and blocks on.
        result = [{"parse_error": parse_error_reason}]
    print(json.dumps(result))
    return 0
