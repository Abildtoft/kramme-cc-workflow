#!/bin/bash
# Hook: Confirm before committing review artifact files
# Blocks git commit when configured review artifacts are staged, asking for confirmation
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses"

ARTIFACT_LIST_FILE="${CONFIRM_REVIEW_ARTIFACT_LIST_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/confirm-review-artifacts.txt}"
COMMAND_SUBSTITUTION_TOKEN="__CMD_SUBST_"
UNSAFE_REPO_SELECTION_REASON="Unable to safely determine the git commit target because repository selection uses command substitution. Use a literal path or commit from within the target repo."
PARSE_ERROR_REASON="Unable to safely parse command. Refusing possible git commit that may stage a review artifact."
REPLAY_GIT_ENV_VARS=(
    GIT_DIR
    GIT_WORK_TREE
    GIT_INDEX_FILE
    GIT_NAMESPACE
    GIT_COMMON_DIR
    GIT_OBJECT_DIRECTORY
    GIT_ALTERNATE_OBJECT_DIRECTORIES
)

load_artifact_list() {
    local list_file="$1"
    local artifact_list=()
    local line

    if [ -f "$list_file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//')
            [ -z "$line" ] && continue
            artifact_list+=("$line")
        done < "$list_file"
    fi

    # Safe fallback when list file is missing/empty.
    if [ ${#artifact_list[@]} -eq 0 ]; then
        artifact_list=("REVIEW_OVERVIEW.md")
    fi

    printf '%s\n' "${artifact_list[@]}"
}

matches_artifact() {
    local staged_file="$1"
    local artifact="$2"

    # Artifact entries are shell-style globs.
    # Basename patterns (e.g. REVIEW_OVERVIEW.md, PR_PLAN_*.md) match any folder.
    # Path patterns (e.g. siw/LOG.md) match exact/suffix paths.
    [[ "$staged_file" == $artifact ]] && return 0
    [[ "$staged_file" == */$artifact ]] && return 0
    return 1
}

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-parse-utils.sh"

token_is_assignment() {
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]
}

is_shell_keyword_token() {
    case "$(strip_wrapping_quotes "$1")" in
        '!'|if|then|elif|else|fi|do|done|while|until|for|in|case|esac|'{'|'}')
            return 0
            ;;
    esac
    return 1
}

should_replay_git_env() {
    case "$1" in
        GIT_DIR|GIT_WORK_TREE|GIT_INDEX_FILE|GIT_NAMESPACE|GIT_COMMON_DIR|GIT_OBJECT_DIRECTORY|GIT_ALTERNATE_OBJECT_DIRECTORIES)
            return 0
            ;;
    esac
    return 1
}

contains_command_substitution_token() {
    case "$1" in
        *"$COMMAND_SUBSTITUTION_TOKEN"*)
            return 0
            ;;
    esac
    return 1
}

context_has_dynamic_repo_selection() {
    # Any prefix arg that still carries a command-substitution placeholder
    # would be expanded by git when we replay it (see also git -c
    # core.fsmonitor=$(...) which achieves RCE). Refuse to replay such
    # args regardless of which flag they sit behind.
    local arg assignment key value
    for arg in "${git_prefix_args[@]}"; do
        if contains_command_substitution_token "$arg"; then
            return 0
        fi
    done

    for assignment in "${git_env_assignments[@]}"; do
        key="${assignment%%=*}"
        value="${assignment#*=}"
        if should_replay_git_env "$key" && contains_command_substitution_token "$value"; then
            return 0
        fi
    done

    return 1
}

append_git_env_assignment() {
    local assignment="$1"
    local key="${assignment%%=*}"
    local value

    should_replay_git_env "$key" || return 0
    value="$(strip_wrapping_quotes "${assignment#*=}")"
    remove_git_env_assignment "$key"
    git_env+=("$key=$value")
}

remove_git_env_assignment() {
    local key="$1"
    local assignment filtered=()

    for assignment in "${git_env[@]}"; do
        if [ "${assignment%%=*}" != "$key" ]; then
            filtered+=("$assignment")
        fi
    done

    git_env=("${filtered[@]}")
}

clear_git_env_assignments() {
    git_env=()
}

collect_current_git_env_assignments() {
    local key

    for key in "${REPLAY_GIT_ENV_VARS[@]}"; do
        if [ "${!key+x}" = x ]; then
            printf '%s=%s\n' "$key" "${!key}"
        fi
    done
}

extract_shell_inline_command() {
    local value

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
            --)
                return 1
                ;;
            -c|--command)
                shift
                [ $# -gt 0 ] || return 1
                printf '%s\n' "$(strip_wrapping_quotes "$1")"
                return 0
                ;;
            --command=*)
                printf '%s\n' "${value#*=}"
                return 0
                ;;
            --rcfile|--init-file|--startup-file|-o|-O|+O)
                shift
                [ $# -gt 0 ] && shift
                ;;
            --rcfile=*|--init-file=*|--startup-file=*)
                shift
                ;;
            --*)
                shift
                ;;
            -*)
                case "${value#-}" in
                    *c*)
                        shift
                        [ $# -gt 0 ] || return 1
                        printf '%s\n' "$(strip_wrapping_quotes "$1")"
                        return 0
                        ;;
                esac
                shift
                ;;
            +*)
                shift
                ;;
            *)
                return 1
                ;;
        esac
    done

    return 1
}

emit_git_commit_context() {
    local git_args_json='[]'
    local git_env_json='[]'

    if [ ${#git_args[@]} -gt 0 ]; then
        git_args_json="$(printf '%s\n' "${git_args[@]}" | jq -R . | jq -s .)"
    fi
    if [ ${#git_env[@]} -gt 0 ]; then
        git_env_json="$(printf '%s\n' "${git_env[@]}" | jq -R . | jq -s .)"
    fi

    jq -cn --argjson git_args "$git_args_json" --argjson git_env "$git_env_json" \
        '{git_args: $git_args, git_env: $git_env}'
}

parse_git_commit_segment_fallback() {
    local prefix_git_args="$1"
    local prefix_git_env="$2"
    shift 2

    local token inline_command
    local saw_git=false
    local git_args=()
    local git_env=()

    while IFS= read -r token; do
        [ -z "$token" ] && continue
        git_args+=("$token")
    done <<EOF
$prefix_git_args
EOF

    while IFS= read -r token; do
        [ -z "$token" ] && continue
        git_env+=("$token")
    done <<EOF
$prefix_git_env
EOF

    while [ $# -gt 0 ] && is_shell_keyword_token "$1"; do
        shift
    done

    while [ $# -gt 0 ] && token_is_assignment "$(strip_wrapping_quotes "$1")"; do
        append_git_env_assignment "$(strip_wrapping_quotes "$1")"
        shift
    done

    while [ $# -gt 0 ]; do
        token="$1"
        case "$(token_basename "$token")" in
            command)
                shift
                while [ $# -gt 0 ]; do
                    case "$(strip_wrapping_quotes "$1")" in
                        --)
                            shift
                            break
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            sudo)
                shift
                while [ $# -gt 0 ]; do
                    token="$(strip_wrapping_quotes "$1")"
                    case "$token" in
                        --)
                            shift
                            break
                            ;;
                        -u|-[ugpCRTtrh])
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --user|--group|--host|--prompt|--command-timeout|--close-from|--role|--type|--other-user)
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --chdir)
                            shift
                            if [ $# -gt 0 ]; then
                                git_args+=("-C" "$(strip_wrapping_quotes "$1")")
                                shift
                            fi
                            ;;
                        --askpass|--background|--preserve-env|--remove-timestamp|--reset-timestamp|--validate|--version|--list|--non-interactive)
                            shift
                            ;;
                        --host=*|--user=*|--group=*|--prompt=*|--command-timeout=*|--close-from=*|--role=*|--type=*|--other-user=*|--preserve-env=*)
                            shift
                            ;;
                        --chdir=*)
                            git_args+=("-C" "$(strip_wrapping_quotes "${token#*=}")")
                            shift
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            env|/usr/bin/env)
                shift
                while [ $# -gt 0 ]; do
                    token="$1"
                    case "$token" in
                        --)
                            shift
                            break
                            ;;
                        [A-Za-z_][A-Za-z0-9_]*=*)
                            append_git_env_assignment "$token"
                            shift
                            ;;
                        -i|--ignore-environment)
                            clear_git_env_assignments
                            shift
                            ;;
                        -u|--unset)
                            shift
                            if [ $# -gt 0 ]; then
                                remove_git_env_assignment "$(strip_wrapping_quotes "$1")"
                                shift
                            fi
                            ;;
                        --unset=*)
                            remove_git_env_assignment "$(strip_wrapping_quotes "${token#*=}")"
                            shift
                            ;;
                        -u*)
                            remove_git_env_assignment "$(strip_wrapping_quotes "${token#-u}")"
                            shift
                            ;;
                        -C|--chdir)
                            if [ $# -ge 2 ]; then
                                git_args+=("-C" "$(strip_wrapping_quotes "$2")")
                                shift 2
                            else
                                shift
                            fi
                            ;;
                        --chdir=*)
                            git_args+=("-C" "$(strip_wrapping_quotes "${token#*=}")")
                            shift
                            ;;
                        -C*)
                            git_args+=("-C" "$(strip_wrapping_quotes "${token#-C}")")
                            shift
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            sh|bash|zsh|dash|ksh)
                shift
                if inline_command="$(extract_shell_inline_command "$@")"; then
                    parse_git_commit_contexts_fallback \
                        "$inline_command" \
                        "$(printf '%s\n' "${git_args[@]}")" \
                        "$(printf '%s\n' "${git_env[@]}")"
                fi
                return
                ;;
            *)
                if [ "$(token_basename "$token")" = "git" ]; then
                    saw_git=true
                    shift
                    break
                fi
                return
                ;;
        esac
    done

    if [ "$saw_git" != "true" ]; then
        return
    fi

    while [ $# -gt 0 ]; do
        token="$1"
        case "$token" in
            --)
                shift
                break
                ;;
            -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--config-env)
                git_args+=("$token")
                if [ $# -ge 2 ]; then
                    git_args+=("$(strip_wrapping_quotes "$2")")
                    shift 2
                else
                    shift
                fi
                ;;
            --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--config-env=*)
                git_args+=("${token%%=*}=$(strip_wrapping_quotes "${token#*=}")")
                shift
                ;;
            -C*)
                git_args+=("-C" "$(strip_wrapping_quotes "${token#-C}")")
                shift
                ;;
            -c*)
                git_args+=("-c" "$(strip_wrapping_quotes "${token#-c}")")
                shift
                ;;
            -*)
                git_args+=("$(strip_wrapping_quotes "$token")")
                shift
                ;;
            __CMD_SUBST_*)
                # A command substitution between `git` and its subcommand
                # will expand at runtime into unknown flags. Keep scanning
                # past it so we still emit a commit context; the dynamic-
                # repo-selection gate (which rejects any arg containing
                # __CMD_SUBST_) will then block the whole segment.
                git_args+=("$token")
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -gt 0 ] && [ "$(strip_wrapping_quotes "$1")" = "commit" ]; then
        emit_git_commit_context
    fi
}

emit_parse_error_context() {
    local reason="${1:-$PARSE_ERROR_REASON}"
    jq -cn --arg reason "$reason" '{parse_error: $reason}'
}

parse_git_commit_contexts_fallback() {
    local raw_command="$1"
    local prefix_git_args="${2:-}"
    local prefix_git_env="${3:-}"
    local tokenized token_json token_type token_value substitution
    local segment=()
    local sanitized_command
    local substitutions=()

    if ! replace_command_substitutions "$raw_command"; then
        emit_parse_error_context
        return
    fi

    sanitized_command="$SANITIZED_COMMAND"
    substitutions=("${COMMAND_SUBSTITUTIONS[@]}")

    for substitution in "${substitutions[@]}"; do
        parse_git_commit_contexts_fallback "$substitution"
    done

    if ! tokenized="$(shell_tokenize "$sanitized_command" true)"; then
        emit_parse_error_context
        return
    fi

    while IFS= read -r token_json; do
        [ -z "$token_json" ] && continue
        token_type="$(printf '%s\n' "$token_json" | jq -r '.type')"
        token_value="$(printf '%s\n' "$token_json" | jq -r '.value')"
        if [ "$token_type" = "control" ]; then
            parse_git_commit_segment_fallback "$prefix_git_args" "$prefix_git_env" "${segment[@]}"
            segment=()
            continue
        fi
        segment+=("$token_value")
    done <<EOF
$tokenized
EOF

    parse_git_commit_segment_fallback "$prefix_git_args" "$prefix_git_env" "${segment[@]}"
}

parse_git_commit_contexts() {
    local raw_command="$1"
    local inherited_git_env

    inherited_git_env="$(collect_current_git_env_assignments)"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$raw_command" "$PARSE_ERROR_REASON" <<'PY'
import json
import os
import re
import shlex
import sys

ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
CONTROL_TOKENS = {";", "&&", "||", "|", "|&", "&"}
SHELL_KEYWORDS = {
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
}
HEREDOC_START = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
ENV_OPTIONS_WITH_VALUE = {"-u", "--unset", "-C", "--chdir"}
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}
REPLAY_ENV_VARS = {
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_NAMESPACE",
    "GIT_COMMON_DIR",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
}
SUDO_OPTIONS_WITH_VALUE = {"-u", "-g", "-p", "-C", "-R", "-T", "-t", "-r", "-h"}
SUDO_LONG_OPTIONS_WITH_VALUE = {
    "--user",
    "--group",
    "--host",
    "--prompt",
    "--command-timeout",
    "--close-from",
    "--chdir",
    "--role",
    "--type",
    "--other-user",
}
SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}
SHELL_OPTIONS_WITH_VALUE = {"--command", "--rcfile", "--init-file", "--startup-file", "-o", "-O", "+O"}


def normalize_newlines(command):
    command, _ = strip_heredoc_bodies(command)
    normalized = []
    in_single = False
    in_double = False
    escaped = False

    for char in command:
        if char in ("\n", "\r") and not in_single and not in_double:
            normalized.append(";")
            escaped = False
            continue

        normalized.append(char)

        if escaped:
            escaped = False
            continue

        if char == "\\" and not in_single:
            escaped = True
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            continue

        if char == '"' and not in_single:
            in_double = not in_double

    return "".join(normalized)


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


def strip_heredoc_bodies(command):
    lines = command.splitlines(keepends=True)
    stripped_lines = []
    delimiter = None
    is_quoted = False
    is_dashed = False
    extracted = []

    for line in lines:
        if delimiter is not None:
            # Strip trailing newline for comparison only.
            compare = line[:-1] if line.endswith("\n") else line
            if is_dashed:
                # POSIX: <<- strips leading TABs only (never spaces).
                compare = compare.lstrip("\t")
            if compare == delimiter:
                stripped_lines.append(line)
                delimiter = None
                is_quoted = False
                is_dashed = False
                continue
            if not is_quoted:
                # Unquoted heredoc bodies still expand $(...) and `...`.
                body_line = line[:-1] if line.endswith("\n") else line
                extracted.extend(_extract_body_substitutions(body_line))
            if line.endswith("\n"):
                stripped_lines.append("\n")
            else:
                stripped_lines.append("")
            continue

        match = HEREDOC_START.search(line)
        if match is not None:
            delimiter = match.group(2)
            is_quoted = match.group(1) != ""
            is_dashed = match.group(0).startswith("<<-")
        stripped_lines.append(line)

    return "".join(stripped_lines), extracted


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
            escaped = False
            inner.append(char)
            idx += 1
            continue

        if char == "\\":
            escaped = True
            inner.append(char)
            idx += 1
            continue

        if char == chr(96):
            return "".join(inner), idx + 1

        inner.append(char)
        idx += 1

    raise ValueError("Unterminated backtick command substitution.")


def replace_command_substitutions(command):
    command, heredoc_body_substitutions = strip_heredoc_bodies(command)
    # Start with any substitutions extracted from unquoted heredoc
    # bodies — they're still executed by the shell and need inspection.
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


def tokenize(command):
    lexer = shlex.shlex(normalize_newlines(command), posix=True, punctuation_chars="|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def split_segments(tokens):
    current = []
    for token in tokens:
        if token in CONTROL_TOKENS:
            if current:
                yield current
                current = []
            continue
        current.append(token)
    if current:
        yield current


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
        if arg in SHELL_OPTIONS_WITH_VALUE:
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
    return [f"{key}={os.environ[key]}" for key in REPLAY_ENV_VARS if key in os.environ]


PARSE_ERROR_REASON = sys.argv[2] if len(sys.argv) > 2 else "Unable to safely parse command."


class ParseError(Exception):
    pass


def parse_commit_contexts(command, inherited_git_args=None, inherited_git_env=None, depth=0):
    # Cap recursion so pathological nesting can't hit Python's stack limit
    # and convert a ValueError into an uncaught RecursionError (which would
    # exit the interpreter non-zero and the shell would fail open).
    if depth > 4:
        raise ParseError("command substitution nesting too deep")

    contexts = []
    if inherited_git_env is None:
        inherited_git_env = inherited_replay_env_from_process()
    try:
        sanitized_command, substitutions = replace_command_substitutions(command)
        tokens = tokenize(sanitized_command)
    except ValueError as exc:
        raise ParseError(str(exc)) from exc

    for substitution in substitutions:
        contexts.extend(parse_commit_contexts(substitution, depth=depth + 1))

    for segment in split_segments(tokens):
        contexts.extend(
            parse_commit_segment(
                segment,
                list(inherited_git_args or []),
                list(inherited_git_env or []),
            )
        )
    return contexts


def parse_commit_segment(tokens, git_args, git_env):
    idx = 0

    while idx < len(tokens) and tokens[idx] in SHELL_KEYWORDS:
        idx += 1

    while idx < len(tokens) and ASSIGNMENT.match(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        if key in REPLAY_ENV_VARS:
            set_replay_env(git_env, key, value)
        idx += 1

    while idx < len(tokens):
        base = os.path.basename(tokens[idx])
        if base == "command":
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

        if base == "sudo":
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if token == "--":
                    idx += 1
                    break
                if token in SUDO_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if token in SUDO_LONG_OPTIONS_WITH_VALUE:
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

        if base == "env":
            idx += 1
            while idx < len(tokens):
                token = tokens[idx]
                if ASSIGNMENT.match(token):
                    key, value = token.split("=", 1)
                    if key in REPLAY_ENV_VARS:
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
                if token in ENV_OPTIONS_WITH_VALUE:
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

        if base in SHELL_EXECUTABLES:
            nested_command = parse_shell_inline_command(tokens[idx + 1 :])
            if nested_command is None:
                return []
            return parse_commit_contexts(nested_command, git_args, git_env)

        if base == "git":
            break

        return []

    if idx >= len(tokens) or os.path.basename(tokens[idx]) != "git":
        return []

    idx += 1
    while idx < len(tokens):
        token = tokens[idx]
        if token == "--":
            idx += 1
            break
        if token in GIT_OPTIONS_WITH_VALUE:
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
        return [{"git_args": git_args, "git_env": git_env}]

    return []


try:
    result = parse_commit_contexts(sys.argv[1])
except (ParseError, RecursionError):
    # Emit a sentinel the shell caller recognises and blocks on.
    result = [{"parse_error": PARSE_ERROR_REASON}]
print(json.dumps(result))
PY
        return
    fi

    local context_lines
    context_lines="$(parse_git_commit_contexts_fallback "$raw_command" "" "$inherited_git_env")"
    if [ -z "$context_lines" ]; then
        printf '%s\n' '[]'
        return
    fi

    printf '%s\n' "$context_lines" | jq -s .
}

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
commit_contexts="$(parse_git_commit_contexts "$command")"
if [ "$(echo "$commit_contexts" | jq 'length')" -eq 0 ]; then
    exit 0
fi

# Check if configured artifact files are staged
configured_artifacts="$(load_artifact_list "$ARTIFACT_LIST_FILE")"
blocked_files=()

while IFS= read -r commit_context_json; do
    [ -z "$commit_context_json" ] && continue

    parse_error_reason="$(printf '%s\n' "$commit_context_json" | jq -r '.parse_error // empty')"
    if [ -n "$parse_error_reason" ]; then
        echo "$parse_error_reason" >&2
        exit 2
    fi

    git_prefix_args=()
    while IFS= read -r git_arg_json; do
        git_prefix_args+=("$(printf '%s\n' "$git_arg_json" | jq -r '.')")
    done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_args[]?')

    git_env_assignments=()
    while IFS= read -r git_env_json; do
        git_env_assignments+=("$(printf '%s\n' "$git_env_json" | jq -r '.')")
    done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_env[]?')

    if context_has_dynamic_repo_selection; then
        echo "$UNSAFE_REPO_SELECTION_REASON" >&2
        exit 2
    fi

    staged_files="$(
        (
            unset "${REPLAY_GIT_ENV_VARS[@]}"
            for assignment in "${git_env_assignments[@]}"; do
                export "$assignment"
            done
            # Leave stderr on the hook's stderr so the user sees git's own
            # diagnostic. We then fail closed based on the exit status.
            git "${git_prefix_args[@]}" diff --cached --name-only
        )
    )"
    diff_exit_status=$?
    if [ "$diff_exit_status" -ne 0 ]; then
        # Can't confirm the artifact is *not* staged — fail closed so
        # bad-env/repo-corruption can't slip a staged artifact through.
        echo "Unable to inspect staged files (git diff --cached exited $diff_exit_status). Refusing possible commit of a review artifact." >&2
        exit 2
    fi

    if [ -n "$staged_files" ]; then
        while IFS= read -r staged_file; do
            [ -z "$staged_file" ] && continue
            while IFS= read -r artifact; do
                [ -z "$artifact" ] && continue
                if matches_artifact "$staged_file" "$artifact"; then
                    blocked_files+=("$staged_file")
                    break
                fi
            done <<< "$configured_artifacts"
        done <<< "$staged_files"
    fi
done < <(echo "$commit_contexts" | jq -c '.[]')

if [ ${#blocked_files[@]} -gt 0 ]; then
    deduped_blocked_files=()
    for blocked_file in "${blocked_files[@]}"; do
        already_seen=false
        for existing_blocked_file in "${deduped_blocked_files[@]}"; do
            if [ "$existing_blocked_file" = "$blocked_file" ]; then
                already_seen=true
                break
            fi
        done
        if [ "$already_seen" != "true" ]; then
            deduped_blocked_files+=("$blocked_file")
        fi
    done
    blocked_files=("${deduped_blocked_files[@]}")

    blocked_file_list=$(IFS=', '; echo "${blocked_files[*]}")
    config_path_display="$ARTIFACT_LIST_FILE"
    if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
        config_path_display="${ARTIFACT_LIST_FILE#${CLAUDE_PLUGIN_ROOT}/}"
    fi

    echo "Review artifact file(s) staged for commit: $blocked_file_list. Please confirm you want to include these files. Configure this list in $config_path_display." >&2
    exit 2
fi

exit 0
