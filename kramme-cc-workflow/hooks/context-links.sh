#!/bin/bash
# Context Links Hook - displays active PR and Linear issue links at end of messages
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "context-links" "json"
#
# This Stop hook detects:
# - Linear issue ID from branch name (pattern: {prefix}/{TEAM-ID}-description)
# - Open PR for the current branch (GitHub)
#
# Outputs JSON with systemMessage containing plain URLs (markdown not rendered in CLI).

# Optional org-specific configuration. This file is not tracked and can override defaults.
CONTEXT_LINKS_CONFIG_FILE="${CONTEXT_LINKS_CONFIG_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config}"
CONTEXT_LINKS_CONFIG_LINEAR_WORKSPACE_SLUG=""
CONTEXT_LINKS_CONFIG_LINEAR_TEAM_KEYS=""
CONTEXT_LINKS_CONFIG_LINEAR_ISSUE_REGEX=""

load_context_links_config() {
    local config_file="$1"
    local line=""
    local key=""
    local value=""

    [ -f "$config_file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        [ -z "$line" ] && continue
        [ "${line#\#}" != "$line" ] && continue
        line="${line#export }"

        case "$line" in
            CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=*|CONTEXT_LINKS_LINEAR_TEAM_KEYS=*|CONTEXT_LINKS_LINEAR_ISSUE_REGEX=*)
                key="${line%%=*}"
                value="${line#*=}"
                value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
                case "$value" in
                    \"*\")
                        value="${value#\"}"
                        value="${value%\"}"
                        ;;
                    \'*\')
                        value="${value#\'}"
                        value="${value%\'}"
                        ;;
                esac
                case "$key" in
                    CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG)
                        CONTEXT_LINKS_CONFIG_LINEAR_WORKSPACE_SLUG="$value"
                        ;;
                    CONTEXT_LINKS_LINEAR_TEAM_KEYS)
                        CONTEXT_LINKS_CONFIG_LINEAR_TEAM_KEYS="$value"
                        ;;
                    CONTEXT_LINKS_LINEAR_ISSUE_REGEX)
                        CONTEXT_LINKS_CONFIG_LINEAR_ISSUE_REGEX="$value"
                        ;;
                esac
                ;;
        esac
    done < "$config_file"
}

load_context_links_config "$CONTEXT_LINKS_CONFIG_FILE"

# Configuration precedence (highest -> lowest):
# 1) CONTEXT_LINKS_* env vars
# 2) Same vars from hooks/context-links.config
# 3) Legacy LINEAR_* env vars (backward compatibility)
# 4) Defaults
LINEAR_WORKSPACE_SLUG="${CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG:-${CONTEXT_LINKS_CONFIG_LINEAR_WORKSPACE_SLUG:-${LINEAR_WORKSPACE_SLUG:-consensusaps}}}"
LINEAR_TEAM_KEYS="${CONTEXT_LINKS_LINEAR_TEAM_KEYS:-${CONTEXT_LINKS_CONFIG_LINEAR_TEAM_KEYS:-${LINEAR_TEAM_KEYS:-WAN,HEA,MEL,POT,FIR,FEG}}}"
LINEAR_ISSUE_REGEX="${CONTEXT_LINKS_LINEAR_ISSUE_REGEX:-${CONTEXT_LINKS_CONFIG_LINEAR_ISSUE_REGEX:-${LINEAR_ISSUE_REGEX:-}}}"

# Get current branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [ -z "$BRANCH" ]; then
    echo '{}'
    exit 0
fi

# Initialize output parts
LINEAR_LINK=""
PR_LINK=""

# Build issue regex from configured team keys when an explicit regex is not provided.
LINEAR_TEAM_KEYS_REGEX=""
while IFS= read -r TEAM_KEY; do
    TEAM_KEY=$(printf '%s' "$TEAM_KEY" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$TEAM_KEY" ] && continue
    TEAM_KEY=$(printf '%s' "$TEAM_KEY" | sed -E 's/[][(){}.^$*+?|\\-]/\\&/g' | tr '[:upper:]' '[:lower:]')
    if [ -z "$LINEAR_TEAM_KEYS_REGEX" ]; then
        LINEAR_TEAM_KEYS_REGEX="$TEAM_KEY"
    else
        LINEAR_TEAM_KEYS_REGEX="${LINEAR_TEAM_KEYS_REGEX}|${TEAM_KEY}"
    fi
done <<< "$(printf '%s' "$LINEAR_TEAM_KEYS" | tr ', ' '\n\n')"
if [ -z "$LINEAR_ISSUE_REGEX" ] && [ -n "$LINEAR_TEAM_KEYS_REGEX" ]; then
    LINEAR_ISSUE_REGEX="(${LINEAR_TEAM_KEYS_REGEX})-[0-9]+"
fi

# Extract Linear issue ID from branch name
# Pattern controlled by LINEAR_ISSUE_REGEX (or derived from LINEAR_TEAM_KEYS)
ISSUE_ID=""
if [ -n "$LINEAR_ISSUE_REGEX" ]; then
    ISSUE_ID=$(echo "$BRANCH" | grep -oiE "$LINEAR_ISSUE_REGEX" 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
fi
if [ -n "$ISSUE_ID" ] && [ -n "$LINEAR_WORKSPACE_SLUG" ]; then
    LINEAR_LINK="https://linear.app/${LINEAR_WORKSPACE_SLUG}/issue/${ISSUE_ID}"
fi

# Check for open PR
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if echo "$REMOTE_URL" | grep -q "github.com"; then
    PR_JSON=$(gh pr view --json url,number 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$PR_JSON" ]; then
        PR_URL=$(echo "$PR_JSON" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$PR_URL" ]; then
            PR_LINK="GitHub: ${PR_URL}"
        fi
    fi
fi

# Build output message
if [ -n "$LINEAR_LINK" ] || [ -n "$PR_LINK" ]; then
    PARTS=""
    [ -n "$LINEAR_LINK" ] && PARTS="Linear: $LINEAR_LINK"
    if [ -n "$PR_LINK" ]; then
        [ -n "$PARTS" ] && PARTS="$PARTS | "
        PARTS="${PARTS}${PR_LINK}"
    fi
    echo "{\"systemMessage\": \"$PARTS\"}"
else
    echo '{}'
fi
exit 0
