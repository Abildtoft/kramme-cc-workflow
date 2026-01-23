#!/bin/bash
# Hook: Block destructive file deletion commands
# Recommends using 'trash' CLI instead for safer file deletion
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "block-rm-rf"
#
# Blocked patterns:
# - rm -rf (and variants: /bin/rm, sudo rm, command rm, env rm, \rm, xargs rm)
# - find -delete
# - find -exec rm -rf
# - shred
# - unlink
# - Subshell execution: sh -c "rm -rf", bash -c "rm -rf"
#
# Allowed:
# - git rm (tracked by git, recoverable)
# - Quoted strings (echo "rm -rf" is safe)
#
# Note: This is a best-effort defense, not a comprehensive security barrier.

# Read JSON input from stdin
input=$(cat)

# Extract the command from tool_input
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Helper: Check if text contains both recursive (-r/-R/--recursive) and force (-f/--force) flags
has_rf_flags() {
    local cmd="$1"
    local has_r=false
    local has_f=false
    echo "$cmd" | grep -qE '(-[a-zA-Z]*[rR]|--recursive)' && has_r=true
    echo "$cmd" | grep -qE '(-[a-zA-Z]*f|--force)' && has_f=true
    $has_r && $has_f
}

# Helper: Output block message and exit
block() {
    local reason="$1"
    echo "{\"decision\":\"block\",\"reason\":\"$reason\"}"
    exit 0
}

# ============================================================================
# CHECK SUBSHELL EXECUTION (before stripping quotes, since rm is inside quotes)
# sh -c "rm -rf", bash -c "rm -rf", zsh -c "rm -rf"
# ============================================================================
if echo "$command" | grep -qE '(bash|sh|zsh)\s+-c\s+'; then
    # Extract content inside quotes after -c
    # Handles both "..." and '...' quoting styles
    subshell_content=$(echo "$command" | grep -oE "(bash|sh|zsh)\s+-c\s+[\"'][^\"']+[\"']" | sed "s/.*-c\s*[\"']//" | sed "s/[\"']$//")
    if [ -n "$subshell_content" ]; then
        if echo "$subshell_content" | grep -qE '\brm\b' && has_rf_flags "$subshell_content"; then
            block "Subshell rm -rf is blocked. Use \`trash\` instead (install: brew install trash)."
        fi
    fi
fi

# ============================================================================
# STRIP QUOTED STRINGS (to avoid false positives like echo "rm -rf")
# ============================================================================
stripped=$(echo "$command" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g')

# ============================================================================
# ALLOW: git rm (tracked by git, recoverable)
# ============================================================================
if echo "$stripped" | grep -qE '(^|[;&|]\s*)git\s+rm\b'; then
    exit 0
fi

# ============================================================================
# BLOCK: rm -rf (and all variants)
# Catches: rm, /bin/rm, /usr/bin/rm, ./rm, command rm, env rm, \rm, sudo rm
# ============================================================================
rm_prefix='(^|[;&|`]\s*|\$\(\s*)'
rm_variants='(sudo\s+)?(command\s+|env\s+|\\)?(/usr)?(/bin)?/?(\.\/)?rm\b'

if echo "$stripped" | grep -qE "${rm_prefix}${rm_variants}"; then
    if has_rf_flags "$stripped"; then
        block "rm -rf is blocked. Use \`trash\` instead (install: brew install trash). Files go to Trash for recovery."
    fi
fi

# ============================================================================
# BLOCK: xargs rm -rf
# Catches: find . | xargs rm -rf, ls | xargs rm -rf
# ============================================================================
if echo "$stripped" | grep -qE 'xargs\s+.*\brm\b'; then
    if has_rf_flags "$stripped"; then
        block "xargs rm -rf is blocked. Use \`trash\` instead."
    fi
fi

# ============================================================================
# BLOCK: find -delete (always destructive)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}find\b.*-delete"; then
    block "find -delete is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# BLOCK: find -exec rm -rf
# ============================================================================
if echo "$stripped" | grep -qE 'find\b.*-exec\s+.*\brm\b'; then
    if has_rf_flags "$stripped"; then
        block "find -exec rm -rf is blocked. Use \`trash\` instead."
    fi
fi

# ============================================================================
# BLOCK: shred (secure deletion, no recovery possible)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}(sudo\s+)?(/usr)?(/bin)?/?shred\b"; then
    block "shred is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# BLOCK: unlink (file deletion)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}(sudo\s+)?(/usr)?(/bin)?/?unlink\b"; then
    block "unlink is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# ALLOW: Everything else
# ============================================================================
exit 0
