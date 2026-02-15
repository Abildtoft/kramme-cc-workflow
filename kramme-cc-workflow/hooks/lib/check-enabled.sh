#!/bin/bash
# Shared function to check if a hook is enabled
# Usage: source this script, then call: is_hook_enabled "hook-name" || exit 0

is_hook_enabled() {
    local hook_name="$1"
    local state_file="${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json"

    # If jq not available, assume enabled (fail open)
    if ! command -v jq &>/dev/null; then
        return 0
    fi

    # If no state file, all hooks enabled
    [ ! -f "$state_file" ] && return 0

    # Check if hook is in disabled array
    if jq -e ".disabled | index(\"$hook_name\")" "$state_file" >/dev/null 2>&1; then
        return 1  # disabled
    fi
    return 0  # enabled
}

# Exit early for disabled hooks, draining stdin to avoid broken pipes.
# Usage: exit_if_hook_disabled "hook-name" ["json"]
# - Use mode "json" for PostToolUse/Stop hooks that must emit an empty JSON object when disabled.
exit_if_hook_disabled() {
    local hook_name="$1"
    local mode="$2"

    if ! is_hook_enabled "$hook_name"; then
        # Drain stdin to avoid SIGPIPE in the caller if input is being piped.
        if [ ! -t 0 ]; then
            cat >/dev/null
        fi
        if [ "$mode" = "json" ]; then
            echo '{}'
        fi
        exit 0
    fi
}
