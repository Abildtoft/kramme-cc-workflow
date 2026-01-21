#!/bin/bash
# Hook: Confirm before committing REVIEW_RESPONSES.md
# Blocks git commit when REVIEW_RESPONSES.md is staged, asking for confirmation

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit\b'; then
    exit 0
fi

# Check if REVIEW_RESPONSES.md is staged
if git diff --cached --name-only 2>/dev/null | grep -qE '(^|/)REVIEW_RESPONSES\.md$'; then
    echo '{"decision":"block","reason":"REVIEW_RESPONSES.md is staged for commit. Please confirm you want to include this file in the commit."}'
    exit 0
fi

exit 0
