#!/bin/bash
# Shared function to check if a hook is enabled
# Usage: source this script, then call: is_hook_enabled "hook-name" || exit 0

is_hook_disabled_without_jq() {
  local hook_name="$1"
  local state_file="$2"
  local content=""
  local line disabled_section entry found=false
  local prefix='{"disabled":['
  local suffix=']}'

  [ ! -f "$state_file" ] && return 1

  while IFS= read -r line || [ -n "$line" ]; do
    content="${content}${line}"
  done < "$state_file"

  content="${content// /}"
  content="${content//$'\t'/}"
  content="${content//$'\r'/}"

  case "$content" in
    "$prefix"*"$suffix")
      disabled_section="${content#"$prefix"}"
      disabled_section="${disabled_section%"$suffix"}"
      ;;
    *)
      return 1
      ;;
  esac

  while [ -n "$disabled_section" ]; do
    entry="${disabled_section%%,*}"
    [ -z "$entry" ] && return 1
    [[ "$entry" =~ ^\"[A-Za-z0-9:_-]+\"$ ]] || return 1
    [ "$entry" = "\"$hook_name\"" ] && found=true
    [ "$entry" = "$disabled_section" ] && break
    disabled_section="${disabled_section#*,}"
    [ -z "$disabled_section" ] && return 1
  done

  [ "$found" = "true" ]
}

default_hook_state_file() {
  local state_home="${XDG_STATE_HOME:-}"

  if [ -z "$state_home" ]; then
    state_home="${HOME:-}/.local/state"
  fi

  printf '%s\n' "${state_home}/kramme-cc-workflow/hook-state.json"
}

resolve_hook_state_file() {
  local default_state_file
  local legacy_state_file

  if [ -n "${KRAMME_HOOK_STATE_FILE:-}" ]; then
    printf '%s\n' "$KRAMME_HOOK_STATE_FILE"
    return 0
  fi

  default_state_file="$(default_hook_state_file)"
  legacy_state_file="${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json"

  if [ -f "$default_state_file" ] || [ ! -f "$legacy_state_file" ]; then
    printf '%s\n' "$default_state_file"
    return 0
  fi

  printf '%s\n' "$legacy_state_file"
}

is_hook_enabled() {
  local hook_name="$1"
  local state_file

  state_file="$(resolve_hook_state_file)"

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
