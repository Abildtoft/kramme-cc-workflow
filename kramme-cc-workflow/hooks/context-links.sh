#!/bin/bash
# Context Links Hook - displays active PR/MR and Linear issue links at end of messages
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "context-links" "json"
#
# This Stop hook detects:
# - Linear issue ID from branch name (pattern: {prefix}/{TEAM-ID}-description)
# - Open PR/MR for the current branch (GitHub or GitLab)
#
# Outputs JSON with systemMessage containing plain URLs (markdown not rendered in CLI).

# Optional org-specific configuration. This file is not tracked and can override defaults.
CONTEXT_LINKS_CONFIG_FILE="${CONTEXT_LINKS_CONFIG_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config}"
CONTEXT_LINKS_CONFIG_LINEAR_WORKSPACE_SLUG=""
CONTEXT_LINKS_CONFIG_LINEAR_TEAM_KEYS=""
CONTEXT_LINKS_CONFIG_LINEAR_ISSUE_REGEX=""
CONTEXT_LINKS_CONFIG_GITLAB_REMOTE_REGEX=""

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
            CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=*|CONTEXT_LINKS_LINEAR_TEAM_KEYS=*|CONTEXT_LINKS_LINEAR_ISSUE_REGEX=*|CONTEXT_LINKS_GITLAB_REMOTE_REGEX=*)
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
                    CONTEXT_LINKS_GITLAB_REMOTE_REGEX)
                        CONTEXT_LINKS_CONFIG_GITLAB_REMOTE_REGEX="$value"
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
# 3) Legacy LINEAR_* / GITLAB_REMOTE_REGEX env vars (backward compatibility)
# 4) Defaults
LINEAR_WORKSPACE_SLUG="${CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG:-${CONTEXT_LINKS_CONFIG_LINEAR_WORKSPACE_SLUG:-${LINEAR_WORKSPACE_SLUG:-consensusaps}}}"
LINEAR_TEAM_KEYS="${CONTEXT_LINKS_LINEAR_TEAM_KEYS:-${CONTEXT_LINKS_CONFIG_LINEAR_TEAM_KEYS:-${LINEAR_TEAM_KEYS:-WAN,HEA,MEL,POT,FIR,FEG}}}"
LINEAR_ISSUE_REGEX="${CONTEXT_LINKS_LINEAR_ISSUE_REGEX:-${CONTEXT_LINKS_CONFIG_LINEAR_ISSUE_REGEX:-${LINEAR_ISSUE_REGEX:-}}}"
GITLAB_REMOTE_REGEX="${CONTEXT_LINKS_GITLAB_REMOTE_REGEX:-${CONTEXT_LINKS_CONFIG_GITLAB_REMOTE_REGEX:-${GITLAB_REMOTE_REGEX:-(gitlab\\.com|consensusaps)}}}"

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

# Detect platform and check for open PR/MR
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if echo "$REMOTE_URL" | grep -q "github.com"; then
    # GitHub - check for PR
    PR_JSON=$(gh pr view --json url,number 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$PR_JSON" ]; then
        PR_URL=$(echo "$PR_JSON" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$PR_URL" ]; then
            PR_LINK="GitHub: ${PR_URL}"
        fi
    fi
elif [ -n "$GITLAB_REMOTE_REGEX" ] && echo "$REMOTE_URL" | grep -qE "$GITLAB_REMOTE_REGEX" 2>/dev/null; then
    # GitLab - check for MR
    MR_JSON=$(glab mr view --output json 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$MR_JSON" ]; then
        MR_URL=""
        MR_NUM=""
        if command -v python3 >/dev/null 2>&1; then
            MR_FIELDS=$(printf '%s' "$MR_JSON" | python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

if isinstance(data, list):
    data = data[0] if data else {}

if not isinstance(data, dict):
    sys.exit(1)

web_url = data.get("web_url", "")
iid = data.get("iid", "")
if web_url:
    sys.stdout.write("{}\t{}".format(web_url, iid))
PY
)
            if [ $? -eq 0 ] && [ -n "$MR_FIELDS" ]; then
                IFS=$'\t' read -r MR_URL MR_NUM <<< "$MR_FIELDS"
            fi
        elif command -v python >/dev/null 2>&1; then
            MR_FIELDS=$(printf '%s' "$MR_JSON" | python - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

if isinstance(data, list):
    data = data[0] if data else {}

if not isinstance(data, dict):
    sys.exit(1)

web_url = data.get("web_url", "")
iid = data.get("iid", "")
if web_url:
    sys.stdout.write("{}\t{}".format(web_url, iid))
PY
)
            if [ $? -eq 0 ] && [ -n "$MR_FIELDS" ]; then
                IFS=$'\t' read -r MR_URL MR_NUM <<< "$MR_FIELDS"
            fi
        fi

        if [ -z "$MR_URL" ]; then
            # Match only the MR's web_url (contains /-/merge_requests/), not author/assignee URLs
            MR_URL=$(echo "$MR_JSON" | tr '\n' ' ' | grep -oE '"web_url"[[:space:]]*:[[:space:]]*"[^"]*/-/merge_requests/[0-9]+"' | head -1 | grep -oE 'https://[^"]+')
            MR_NUM=$(echo "$MR_JSON" | tr '\n' ' ' | grep -o '"iid"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/[^0-9]*//g')
        fi

        if [ -n "$MR_URL" ]; then
            PR_LINK="GitLab: ${MR_URL}"
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
