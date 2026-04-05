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

is_git_commit_command() {
    local raw_command="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$raw_command" <<'PY'
import os
import re
import shlex
import sys

ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
ENV_OPTIONS_WITH_VALUE = {"-u", "--unset", "-C", "--chdir"}
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}

try:
    tokens = shlex.split(sys.argv[1], posix=True)
except ValueError:
    sys.exit(1)

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
            idx += 2
            continue
        if (
            token.startswith("--unset=")
            or token.startswith("--chdir=")
            or (token.startswith("-u") and token != "-u")
            or (token.startswith("-C") and token != "-C")
        ):
            idx += 1
            continue
        if token.startswith("-"):
            idx += 1
            continue
        break

if idx >= len(tokens) or os.path.basename(tokens[idx]) != "git":
    sys.exit(1)

idx += 1
while idx < len(tokens):
    token = tokens[idx]
    if token == "--":
        idx += 1
        break
    if token in GIT_OPTIONS_WITH_VALUE:
        idx += 2
        continue
    if any(token.startswith(prefix + "=") for prefix in ("--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env")):
        idx += 1
        continue
    if token.startswith("-"):
        idx += 1
        continue
    break

if idx < len(tokens) and tokens[idx] == "commit":
    sys.exit(0)

sys.exit(1)
PY
        return $?
    fi

    echo "$raw_command" | grep -qE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*((/usr/bin/env|env)([[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+|-u([[:space:]]+[^[:space:]]+)?|--unset(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)?|-C([[:space:]]+[^[:space:]]+)?|--chdir(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)?))*[[:space:]]+)?git([[:space:]]+(-C|-c|--[^[:space:]]+)(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)*)*[[:space:]]+commit\b'
}

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
if ! is_git_commit_command "$command"; then
    exit 0
fi

# Check if configured artifact files are staged
configured_artifacts="$(load_artifact_list "$ARTIFACT_LIST_FILE")"
staged_files="$(git diff --cached --name-only 2>/dev/null)"
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
