#!/bin/bash
# Hook: Confirm before committing review artifact files
# Blocks git commit when configured review artifacts are staged, asking for confirmation
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses"

ARTIFACT_LIST_FILE="${CONFIRM_REVIEW_ARTIFACT_LIST_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/confirm-review-artifacts.txt}"
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

append_git_env_assignment() {
    local assignment="$1"
    local key="${assignment%%=*}"
    local value

    should_replay_git_env "$key" || return 0
    remove_git_env_assignment "$key"
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
            *)
                break
                ;;
        esac
    done

    if [ $# -gt 0 ] && [ "$(strip_wrapping_quotes "$1")" = "commit" ]; then
        emit_git_commit_context
    fi
}

parse_git_commit_contexts_fallback() {
    local raw_command="$1"
    local prefix_git_args="${2:-}"
    local prefix_git_env="${3:-}"
    local tokenized token_json token_type token_value
    local segment=()

    if ! tokenized="$(shell_tokenize "$raw_command" true)"; then
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
        python3 - "$raw_command" <<'PY'
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


def parse_commit_contexts(command, inherited_git_args=None, inherited_git_env=None):
    contexts = []
    if inherited_git_env is None:
        inherited_git_env = inherited_replay_env_from_process()
    try:
        tokens = tokenize(command)
    except ValueError:
        return contexts

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
        break

    if idx < len(tokens) and tokens[idx] == "commit":
        return [{"git_args": git_args, "git_env": git_env}]

    return []


print(json.dumps(parse_commit_contexts(sys.argv[1])))
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

    git_prefix_args=()
    while IFS= read -r git_arg_json; do
        git_prefix_args+=("$(printf '%s\n' "$git_arg_json" | jq -r '.')")
    done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_args[]?')

    git_env_assignments=()
    while IFS= read -r git_env_json; do
        git_env_assignments+=("$(printf '%s\n' "$git_env_json" | jq -r '.')")
    done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_env[]?')

    staged_files="$(
        (
            unset "${REPLAY_GIT_ENV_VARS[@]}"
            for assignment in "${git_env_assignments[@]}"; do
                export "$assignment"
            done
            git "${git_prefix_args[@]}" diff --cached --name-only 2>/dev/null
        )
    )"

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
    blocked_file_list=$(IFS=', '; echo "${blocked_files[*]}")
    config_path_display="$ARTIFACT_LIST_FILE"
    if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
        config_path_display="${ARTIFACT_LIST_FILE#${CLAUDE_PLUGIN_ROOT}/}"
    fi

    echo "Review artifact file(s) staged for commit: $blocked_file_list. Please confirm you want to include these files. Configure this list in $config_path_display." >&2
    exit 2
fi

exit 0
