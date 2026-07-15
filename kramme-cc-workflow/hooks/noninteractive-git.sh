#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Block git commands that open interactive editors.
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "noninteractive-git" ""

PYTHON_REQUIRED_REASON="noninteractive-git hook: python3 not found; refusing to run safety hook without the shared git command parser. Install python3 or disable this hook explicitly."
PARSER_ERROR_REASON="Unable to safely parse command metadata. Refusing potentially interactive git command."

if ! source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/safety-hook-parser.sh"; then
  echo "$PARSER_ERROR_REASON" >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi

run_safety_hook_parser "noninteractive-git" "noninteractive" "$PYTHON_REQUIRED_REASON" "$PARSER_ERROR_REASON"

exit 0
