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

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit\b'; then
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
