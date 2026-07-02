#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Block git commands that open interactive editors.
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "noninteractive-git" ""

if ! command -v jq > /dev/null 2>&1; then
  echo "noninteractive-git hook: jq not found; refusing to run safety hook without JSON parsing. Install jq or disable this hook explicitly." >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command.
[ -z "$command" ] && exit 0

block() {
  local reason="$1"
  echo "$reason" >&2
  exit 2
}

PYTHON_REQUIRED_REASON="noninteractive-git hook: python3 not found; refusing to run safety hook without the shared git command parser. Install python3 or disable this hook explicitly."
PARSER_ERROR_REASON="Unable to safely parse command metadata. Refusing potentially interactive git command."

if ! command -v python3 > /dev/null 2>&1; then
  block "$PYTHON_REQUIRED_REASON"
fi

if ! decision=$(
  python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git_command_parser.py" noninteractive "$command"
); then
  block "$PARSER_ERROR_REASON"
fi

if ! reason=$(printf '%s\n' "$decision" | jq -r 'if type == "object" then .block // "__ALLOW__" else error("expected parser decision object") end'); then
  block "$PARSER_ERROR_REASON"
fi

if [ "$reason" != "__ALLOW__" ]; then
  block "$reason"
fi

exit 0
