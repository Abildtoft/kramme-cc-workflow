#!/bin/bash
# kramme hook bundle bootstrap start
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _claude_hook_source="${BASH_SOURCE:-$0}"
  _claude_hook_dir="$(CDPATH= cd -- "$(dirname -- "$_claude_hook_source")" && pwd)"
  CLAUDE_PLUGIN_ROOT="$(CDPATH= cd -- "$_claude_hook_dir/.." && pwd)"
fi
export CLAUDE_PLUGIN_ROOT
unset _claude_hook_source _claude_hook_dir
# kramme hook bundle bootstrap end
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Block destructive file deletion commands
# Recommends using 'trash' CLI instead for safer file deletion
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "block-rm-rf" ""

PYTHON_REQUIRED_REASON="block-rm-rf hook: python3 not found; refusing to run safety hook without the shared command parser. Install python3 or disable this hook explicitly."
PARSER_ERROR_REASON="Unable to safely parse command metadata. Refusing potentially destructive deletion command."

if ! source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/safety-hook-parser.sh"; then
  echo "$PARSER_ERROR_REASON" >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi

run_safety_hook_parser "block-rm-rf" "rm-rf" "$PYTHON_REQUIRED_REASON" "$PARSER_ERROR_REASON"

exit 0
