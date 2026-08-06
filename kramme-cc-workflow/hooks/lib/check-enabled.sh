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

# Shared resolver for hook state/config paths that follow XDG Base Directory
# precedence: an explicit override env var, then the XDG (or platform
# default) directory, then an optional legacy path -- but only when the
# XDG/default file does not already exist.
# Usage: resolve_kramme_path OVERRIDE_VAR XDG_VAR XDG_DEFAULT_SUBDIR FILENAME [LEGACY_PATH]
resolve_kramme_path() {
  local override_var="$1"
  local xdg_var="$2"
  local xdg_default_subdir="$3"
  local filename="$4"
  local legacy_path="${5:-}"
  local override_value
  local xdg_base
  local default_path

  override_value="${!override_var:-}"
  if [ -n "$override_value" ]; then
    printf '%s\n' "$override_value"
    return 0
  fi

  xdg_base="${!xdg_var:-}"
  if [ -z "$xdg_base" ]; then
    xdg_base="${HOME:-}/${xdg_default_subdir}"
  fi
  default_path="${xdg_base}/kramme-cc-workflow/${filename}"

  if [ -z "$legacy_path" ] || [ -f "$default_path" ] || [ ! -f "$legacy_path" ]; then
    printf '%s\n' "$default_path"
    return 0
  fi

  printf '%s\n' "$legacy_path"
}

resolve_hook_state_file() {
  resolve_kramme_path \
    "KRAMME_HOOK_STATE_FILE" \
    "XDG_STATE_HOME" \
    ".local/state" \
    "hook-state.json" \
    "${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json"
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
