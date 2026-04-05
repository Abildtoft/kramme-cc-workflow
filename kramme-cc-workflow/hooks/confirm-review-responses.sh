#!/bin/bash
# Hook: Confirm before committing review artifact files
# Blocks git commit when configured review artifacts are staged, asking for confirmation
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses"

ARTIFACT_LIST_FILE="${CONFIRM_REVIEW_ARTIFACT_LIST_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/confirm-review-artifacts.txt}"

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

    # Basename entries (e.g. REVIEW_OVERVIEW.md) match any folder.
    # Path entries (e.g. siw/LOG.md) match exact/suffix paths.
    [ "$staged_file" = "$artifact" ] && return 0
    case "$staged_file" in
        */"$artifact") return 0 ;;
    esac
    return 1
}

parse_git_commit_context() {
    local raw_command="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$raw_command" <<'PY'
import json
import os
import re
import shlex
import sys

ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
ENV_OPTIONS_WITH_VALUE = {"-u", "--unset", "-C", "--chdir"}
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}

result = {"is_commit": False, "git_args": []}

try:
    tokens = shlex.split(sys.argv[1], posix=True)
except ValueError:
    print(json.dumps(result))
    sys.exit(0)

idx = 0
while idx < len(tokens) and ASSIGNMENT.match(tokens[idx]):
    idx += 1

if idx < len(tokens) and os.path.basename(tokens[idx]) == "env":
    idx += 1
    while idx < len(tokens):
        token = tokens[idx]
        if ASSIGNMENT.match(token):
            idx += 1
            continue
        if token == "--":
            idx += 1
            break
        if token in ENV_OPTIONS_WITH_VALUE:
            if token in {"-C", "--chdir"} and idx + 1 < len(tokens):
                result["git_args"].extend(["-C", tokens[idx + 1]])
            idx += 2
            continue
        if (
            token.startswith("--unset=")
            or (token.startswith("-u") and token != "-u")
        ):
            idx += 1
            continue
        if token.startswith("--chdir="):
            result["git_args"].extend(["-C", token.split("=", 1)[1]])
            idx += 1
            continue
        if token.startswith("-C") and token != "-C":
            result["git_args"].extend(["-C", token[2:]])
            idx += 1
            continue
        if token.startswith("-"):
            idx += 1
            continue
        break

if idx >= len(tokens) or os.path.basename(tokens[idx]) != "git":
    print(json.dumps(result))
    sys.exit(0)

idx += 1
while idx < len(tokens):
    token = tokens[idx]
    if token == "--":
        idx += 1
        break
    if token in GIT_OPTIONS_WITH_VALUE:
        result["git_args"].append(token)
        if idx + 1 < len(tokens):
            result["git_args"].append(tokens[idx + 1])
        idx += 2
        continue
    if any(token.startswith(prefix + "=") for prefix in ("--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env")):
        result["git_args"].append(token)
        idx += 1
        continue
    if token.startswith("-"):
        result["git_args"].append(token)
        idx += 1
        continue
    break

if idx < len(tokens) and tokens[idx] == "commit":
    result["is_commit"] = True

print(json.dumps(result))
PY
        return
    fi

    local token
    local saw_git=false
    local is_commit=false
    local git_args=()
    local git_args_json='[]'

    set -f
    # shellcheck disable=SC2086
    set -- $raw_command
    set +f

    while [ $# -gt 0 ]; do
        token="$1"
        case "$token" in
            [A-Za-z_][A-Za-z0-9_]*=*)
                shift
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
                            shift
                            ;;
                        -u|--unset)
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --unset=*|-u*)
                            shift
                            ;;
                        -C|--chdir)
                            if [ $# -ge 2 ]; then
                                git_args+=("-C" "$2")
                                shift 2
                            else
                                shift
                            fi
                            ;;
                        --chdir=*)
                            git_args+=("-C" "${token#*=}")
                            shift
                            ;;
                        -C*)
                            git_args+=("-C" "${token#-C}")
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
            git|/usr/bin/git)
                saw_git=true
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    if [ "$saw_git" != "true" ]; then
        printf '%s\n' '{"is_commit":false,"git_args":[]}'
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
                    git_args+=("$2")
                    shift 2
                else
                    shift
                fi
                ;;
            --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--config-env=*)
                git_args+=("$token")
                shift
                ;;
            -C*)
                git_args+=("-C" "${token#-C}")
                shift
                ;;
            -c*)
                git_args+=("-c" "${token#-c}")
                shift
                ;;
            -*)
                git_args+=("$token")
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -gt 0 ] && [ "$1" = "commit" ]; then
        is_commit=true
    fi

    if [ ${#git_args[@]} -gt 0 ]; then
        git_args_json="$(printf '%s\n' "${git_args[@]}" | jq -R . | jq -s .)"
    fi

    jq -cn --argjson is_commit "$is_commit" --argjson git_args "$git_args_json" \
        '{is_commit: $is_commit, git_args: $git_args}'
}

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
commit_context="$(parse_git_commit_context "$command")"
if [ "$(echo "$commit_context" | jq -r '.is_commit // false')" != "true" ]; then
    exit 0
fi

git_prefix_args=()
while IFS= read -r git_arg; do
    [ -z "$git_arg" ] && continue
    git_prefix_args+=("$git_arg")
done <<EOF
$(echo "$commit_context" | jq -r '.git_args[]?')
EOF

# Check if configured artifact files are staged
configured_artifacts="$(load_artifact_list "$ARTIFACT_LIST_FILE")"
staged_files="$(git "${git_prefix_args[@]}" diff --cached --name-only 2>/dev/null)"
blocked_files=()

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
