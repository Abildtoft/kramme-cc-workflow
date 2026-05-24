#!/bin/bash
# Hook: Record skill usage statistics from prompt and skill-tool events.
#
# This hook is intentionally silent. It writes local JSONL records and returns
# an empty JSON response so usage tracking does not add noise to conversations.

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "skill-usage-stats" "json"

input=$(cat)

if [ -z "$input" ]; then
  echo '{}'
  exit 0
fi

if ! command -v node > /dev/null 2>&1; then
  echo '{}'
  exit 0
fi

output=$(printf '%s' "$input" | node "${CLAUDE_PLUGIN_ROOT}/scripts/skill-usage.js" record 2> /dev/null)
status=$?

if [ "$status" -ne 0 ] || [ -z "$output" ]; then
  echo '{}'
  exit 0
fi

echo "$output"
