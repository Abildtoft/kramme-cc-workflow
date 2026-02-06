#!/bin/bash
# Hook: Confirm before committing review artifact files
# Blocks git commit when REVIEW_OVERVIEW.md is staged, asking for confirmation
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses"

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit\b'; then
    exit 0
fi

# Check if review overview file is staged
if git diff --cached --name-only 2>/dev/null | grep -qE '(^|/)REVIEW_OVERVIEW\.md$'; then
    echo "Review artifact file (REVIEW_OVERVIEW.md) is staged for commit. Please confirm you want to include this file in the commit." >&2
    exit 2
fi

exit 0
