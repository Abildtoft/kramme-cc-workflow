#!/usr/bin/env bash
#
# Resolve whether the current branch belongs to a GitHub stack.
#
# Output is shell-quoted KEY=VALUE lines suitable for:
#   eval "$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh")"
#
# A successful result is definitive:
#   STACK_MEMBERSHIP=local  - the gh-stack extension tracks this branch locally
#   STACK_MEMBERSHIP=remote - GitHub associates the branch's PR with a stack,
#                             but the extension does not track it locally
#   STACK_MEMBERSHIP=none   - this is not a GitHub repository, the branch has no
#                             open PR, or its open PR is not stacked
#
# Operational failures are never reported as "none": the script exits non-zero
# so a caller cannot rewrite or push history under an unknown stack state.

set -euo pipefail

quote_assignment() {
  local name="$1"
  local value="${2-}"
  printf '%s=%q\n' "$name" "$value"
}

emit_result() {
  quote_assignment STACK_MEMBERSHIP "$STACK_MEMBERSHIP"
  quote_assignment STACK_CLI_AVAILABLE "$STACK_CLI_AVAILABLE"
  quote_assignment STACK_PR_NUMBER "$STACK_PR_NUMBER"
  quote_assignment STACK_NUMBER "$STACK_NUMBER"
}

CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD) || {
  echo "Cannot resolve stack membership from a detached HEAD." >&2
  exit 1
}

STACK_MEMBERSHIP=""
STACK_CLI_AVAILABLE=0
STACK_PR_NUMBER=""
STACK_NUMBER=""
GH_STACK_MINIMUM_VERSION="0.1.0"

REMOTE_NAMES=$(git remote) || {
  echo "Could not enumerate Git remotes; stack membership is unknown." >&2
  exit 1
}
GITHUB_REMOTE_FOUND=0
while IFS= read -r remote_name; do
  [ -n "$remote_name" ] || continue
  REMOTE_URLS=$(git remote get-url --all -- "$remote_name") || {
    echo "Could not inspect remote '$remote_name'; stack membership is unknown." >&2
    exit 1
  }
  case "$REMOTE_URLS" in
    *github.com:* | *github.com/*)
      GITHUB_REMOTE_FOUND=1
      break
      ;;
  esac
done <<< "$REMOTE_NAMES"
if [ "$GITHUB_REMOTE_FOUND" -eq 0 ]; then
  STACK_MEMBERSHIP="none"
  emit_result
  exit 0
fi

if ! command -v gh > /dev/null 2>&1; then
  echo "Cannot determine GitHub stack membership because gh is unavailable." >&2
  exit 1
fi

if GH_STACK_VERSION_OUTPUT=$(gh stack --version 2>&1); then
  STACK_CLI_AVAILABLE=1
  if [[ "$GH_STACK_VERSION_OUTPUT" =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    GH_STACK_VERSION=${BASH_REMATCH[0]}
    GH_STACK_VERSION_MAJOR=${BASH_REMATCH[1]}
    GH_STACK_VERSION_MINOR=${BASH_REMATCH[2]}
  else
    echo "Could not parse the installed gh-stack version; upgrade to v$GH_STACK_MINIMUM_VERSION or newer with 'gh extension upgrade stack'." >&2
    exit 1
  fi
  if ((GH_STACK_VERSION_MAJOR == 0 && GH_STACK_VERSION_MINOR < 1)); then
    echo "gh-stack v$GH_STACK_VERSION is unsupported; upgrade to v$GH_STACK_MINIMUM_VERSION or newer with 'gh extension upgrade stack'." >&2
    exit 1
  fi

  set +e
  STACK_VIEW_OUTPUT=$(gh stack view --json 2>&1)
  STACK_VIEW_STATUS=$?
  set -e

  case "$STACK_VIEW_STATUS" in
    0)
      STACK_MEMBERSHIP="local"
      emit_result
      exit 0
      ;;
    2) ;;
    *)
      [ -z "$STACK_VIEW_OUTPUT" ] || printf '%s\n' "$STACK_VIEW_OUTPUT" >&2
      echo "gh stack view failed with exit code $STACK_VIEW_STATUS; stack membership is unknown." >&2
      exit "$STACK_VIEW_STATUS"
      ;;
  esac
fi

STACK_PR_NUMBER=$(gh pr list \
  --head "$CURRENT_BRANCH" \
  --state open \
  --limit 1 \
  --json number \
  --jq '.[0].number // empty') || {
  echo "Could not query the open pull request for '$CURRENT_BRANCH'; stack membership is unknown." >&2
  exit 1
}

if [ -z "$STACK_PR_NUMBER" ]; then
  STACK_MEMBERSHIP="none"
  emit_result
  exit 0
fi

REPO_WITH_OWNER=$(gh repo view --json nameWithOwner --jq '.nameWithOwner') || {
  echo "Could not resolve the current GitHub repository; stack membership is unknown." >&2
  exit 1
}
case "$REPO_WITH_OWNER" in
  */*)
    REPO_OWNER=${REPO_WITH_OWNER%%/*}
    REPO_NAME=${REPO_WITH_OWNER#*/}
    ;;
  *)
    echo "GitHub returned an invalid repository name: '$REPO_WITH_OWNER'." >&2
    exit 1
    ;;
esac

STACK_NUMBER=$(gh api graphql \
  -f query='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){stack{number}}}}' \
  -f owner="$REPO_OWNER" \
  -f name="$REPO_NAME" \
  -F number="$STACK_PR_NUMBER" \
  --jq '.data.repository.pullRequest.stack.number // empty') || {
  echo "Could not query GitHub stack metadata for PR #$STACK_PR_NUMBER; stack membership is unknown." >&2
  exit 1
}

if [ -n "$STACK_NUMBER" ]; then
  STACK_MEMBERSHIP="remote"
else
  STACK_MEMBERSHIP="none"
fi
emit_result
