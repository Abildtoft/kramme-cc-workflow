#!/bin/bash
# Context Links Hook - displays active PR/MR and Linear issue links at end of messages
#
# This Stop hook detects:
# - Linear issue ID from branch name (pattern: {prefix}/{TEAM-ID}-description)
# - Open PR/MR for the current branch (GitHub or GitLab)
#
# Outputs JSON with systemMessage containing plain URLs (markdown not rendered in CLI).

# Get current branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [ -z "$BRANCH" ]; then
    echo '{}'
    exit 0
fi

# Initialize output parts
LINEAR_LINK=""
PR_LINK=""

# Extract Linear issue ID from branch name
# Pattern: {prefix}/{TEAM-ID}-description where TEAM is WAN|HEA|MEL|POT|FIR|FEG
ISSUE_ID=$(echo "$BRANCH" | grep -oiE '(wan|hea|mel|pot|fir|feg)-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')
if [ -n "$ISSUE_ID" ]; then
    LINEAR_LINK="https://linear.app/consensusaps/issue/${ISSUE_ID}"
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
elif echo "$REMOTE_URL" | grep -qE "(gitlab.com|consensusaps)"; then
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
