#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Record skill usage statistics from prompt and skill-tool events.
#
# This hook is intentionally silent. It writes local JSONL records and returns
# an empty JSON response so usage tracking does not add noise to conversations.

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "skill-usage-stats" "json"

usage_diagnostic_file() {
  if [ -n "${KRAMME_SKILL_USAGE_DIAGNOSTIC_FILE:-}" ]; then
    printf '%s\n' "$KRAMME_SKILL_USAGE_DIAGNOSTIC_FILE"
    return 0
  fi

  local state_home="${XDG_STATE_HOME:-}"
  if [ -z "$state_home" ]; then
    [ -n "${HOME:-}" ] || return 1
    state_home="$HOME/.local/state"
  fi

  printf '%s\n' "$state_home/kramme-cc-workflow/skill-usage-diagnostics.log"
}

usage_diagnostic_max_lines() {
  local max="${KRAMME_SKILL_USAGE_DIAGNOSTIC_MAX_LINES:-20}"
  case "$max" in
    ''|*[!0-9]*) printf '20\n' ;;
    *)
      if [ "$max" -lt 1 ]; then
        printf '20\n'
      else
        printf '%s\n' "$max"
      fi
      ;;
  esac
}

record_usage_diagnostic() {
  local reason="$1"
  local file
  local dir
  local max_lines
  local tmp_file
  local timestamp

  file="$(usage_diagnostic_file)" || return 0
  [ -n "$file" ] || return 0

  dir="$(dirname -- "$file")"
  mkdir -p "$dir" 2> /dev/null || return 0

  timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || printf 'unknown-time')"
  printf '%s skill-usage-stats: %s\n' "$timestamp" "$reason" >> "$file" 2> /dev/null || return 0

  max_lines="$(usage_diagnostic_max_lines)"
  tmp_file="${file}.$$"
  if tail -n "$max_lines" "$file" > "$tmp_file" 2> /dev/null; then
    cat "$tmp_file" > "$file" 2> /dev/null || true
  fi
  rm -f "$tmp_file" 2> /dev/null || true
}

input=$(cat)

if [ -z "$input" ]; then
  echo '{}'
  exit 0
fi

if ! command -v node > /dev/null 2>&1; then
  record_usage_diagnostic "node unavailable"
  echo '{}'
  exit 0
fi

recorder="${CLAUDE_PLUGIN_ROOT}/scripts/skill-usage.js"
if [ ! -f "$recorder" ]; then
  recorder="${CLAUDE_PLUGIN_ROOT}/hooks/skill-usage.js"
fi

output=$(printf '%s' "$input" | node "$recorder" record 2> /dev/null)
status=$?

if [ "$status" -ne 0 ] || [ -z "$output" ]; then
  if [ "$status" -ne 0 ]; then
    record_usage_diagnostic "record failed status=$status"
  else
    record_usage_diagnostic "record produced empty output"
  fi
  echo '{}'
  exit 0
fi

echo "$output"
