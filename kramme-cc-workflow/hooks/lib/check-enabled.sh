#!/bin/bash
# Shared function to check if a hook is enabled
# Usage: source this script, then call: is_hook_enabled "hook-name" || exit 0

is_hook_disabled_without_jq() {
  local hook_name="$1"
  local state_file="$2"
  local content=""
  local line disabled_section entry

  [ ! -f "$state_file" ] && return 1

  while IFS= read -r line || [ -n "$line" ]; do
    content="${content}${line}"
  done < "$state_file"

  content="${content// /}"
  content="${content//$'\t'/}"
  content="${content//$'\r'/}"

  case "$content" in
    *'"disabled":['*']'*)
      disabled_section="${content#*\"disabled\":[}"
      disabled_section="${disabled_section%%]*}"
      ;;
    *)
      return 1
      ;;
  esac

  while [ -n "$disabled_section" ]; do
    entry="${disabled_section%%,*}"
    [ "$entry" = "\"$hook_name\"" ] && return 0
    [ "$entry" = "$disabled_section" ] && break
    disabled_section="${disabled_section#*,}"
  done

  return 1
}

is_hook_enabled() {
  local hook_name="$1"
  local state_file="${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json"

  # If jq is not available, only honor the simple state file shape this
  # plugin writes. Unknown or malformed content still fails open.
  if ! command -v jq &> /dev/null; then
    if is_hook_disabled_without_jq "$hook_name" "$state_file"; then
      return 1
    fi
    return 0
  fi

  # If no state file, all hooks enabled
  [ ! -f "$state_file" ] && return 0

  # Check if hook is in disabled array
  if jq -e ".disabled | index(\"$hook_name\")" "$state_file" > /dev/null 2>&1; then
    return 1 # disabled
  fi
  return 0 # enabled
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
      cat > /dev/null
    fi
    if [ "$mode" = "json" ]; then
      echo '{}'
    fi
    exit 0
  fi
}
