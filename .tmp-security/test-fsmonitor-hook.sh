#!/bin/bash
set -u
export CLAUDE_PLUGIN_ROOT=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/kramme-cc-workflow

# Create a fresh tmp repo inside the allowed tree
BASE=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/.tmp-security
TMPDIR="$BASE/repo-$$"
mkdir -p "$TMPDIR"
cd "$TMPDIR"
git init -q
echo content > REVIEW_OVERVIEW.md
git add REVIEW_OVERVIEW.md

MARKER="$BASE/PWNED_FSMONITOR_$$"
[ -f "$MARKER" ] && : > "$MARKER"

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
