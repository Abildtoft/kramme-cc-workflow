#!/bin/bash
# Hook: Block git commands that open interactive editors
# Forces non-interactive alternatives for rebase, commit, merge, and add
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "noninteractive-git"

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Helper to output block decision
block() {
    local reason="$1"
    echo "{\"decision\":\"block\",\"reason\":\"$reason\"}"
    exit 0
}

# Strip quoted strings to avoid false positives (e.g., echo "git commit")
# This replaces content in single/double quotes with empty strings
stripped_command=$(echo "$command" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# --- git commit without -m flag ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+commit\b'; then
    if ! echo "$stripped_command" | grep -qE '[[:space:]]+-m[[:space:]]|[[:space:]]+--message\b|[[:space:]]+-C[[:space:]]|[[:space:]]+--reuse-message|[[:space:]]+-F[[:space:]]|[[:space:]]+--file\b'; then
        block "git commit without -m will open an editor. Use: git commit -m \\\"your message\\\""
    fi
fi

# --- git rebase -i without GIT_SEQUENCE_EDITOR ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+rebase[[:space:]]+.*(-i\b|--interactive\b)'; then
    if ! echo "$command" | grep -qE 'GIT_SEQUENCE_EDITOR='; then
        block "Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ..."
    fi
fi

# --- git add -p/-i (interactive mode) ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+add[[:space:]]+.*(-p\b|-i\b|--patch\b|--interactive\b)'; then
    block "Interactive git add opens a prompt. Use explicit paths: git add <files>"
fi

# --- git merge without --no-edit (can open editor for merge commit) ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+merge\b'; then
    # Only block if not using --no-edit, --no-commit, or squash/ff modes
    # Use -- to prevent grep from treating --no-edit as an option
    if ! echo "$stripped_command" | grep -qE -- '--no-edit|--no-commit|--squash|--ff-only|--ff[[:space:]]|--ff$'; then
        block "git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>"
    fi
fi

# --- git rebase --continue (may open editor for conflict resolution) ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+rebase[[:space:]]+--continue\b'; then
    if ! echo "$command" | grep -qE 'GIT_EDITOR='; then
        block "git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue"
    fi
fi

# --- git cherry-pick (may open editor) ---
if echo "$stripped_command" | grep -qE '\bgit[[:space:]]+cherry-pick\b'; then
    # Use -- to prevent grep from treating --no-edit as an option
    if ! echo "$stripped_command" | grep -qE -- '--no-edit|--no-commit|[[:space:]]-n[[:space:]]|[[:space:]]-n$'; then
        block "git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>"
    fi
fi

exit 0
