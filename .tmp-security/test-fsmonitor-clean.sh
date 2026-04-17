#!/bin/bash
set -u
export CLAUDE_PLUGIN_ROOT=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/kramme-cc-workflow

BASE=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/.tmp-security
TMPDIR="$BASE/clean-repo-$$"
mkdir -p "$TMPDIR"
cd "$TMPDIR"
git init -q
echo content > innocuous.txt
git add innocuous.txt

MARKER="$BASE/PWNED_CLEAN_$$"

CMD='git -c "core.fsmonitor=touch '"$MARKER"'; false" commit -m test'
echo "--- Command ---"
echo "$CMD"
echo
JSON=$(jq -n --arg cmd "$CMD" '{tool_input:{command:$cmd}}')
echo "--- Hook output ---"
echo "$JSON" | bash "$CLAUDE_PLUGIN_ROOT/hooks/confirm-review-responses.sh"
status=$?
echo
echo "--- Hook exit: $status ---"
echo "--- Marker file ---"
ls -la "$MARKER" 2>&1 || echo "No marker created"
