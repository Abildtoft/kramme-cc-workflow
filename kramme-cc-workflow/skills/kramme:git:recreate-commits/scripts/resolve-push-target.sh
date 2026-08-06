#!/usr/bin/env bash

set -euo pipefail

ORIGINAL_TIP=""
BASE_BRANCH=""

usage() {
  echo "Usage: resolve-push-target.sh --original-tip <40-hex-oid> --base-branch <branch>" >&2
}

# Synced quote_assignment helper (keep aligned across standalone shell scripts):
quote_assignment() {
  local name="$1"
  local value="${2-}"
  printf '%s=%q\n' "$name" "$value"
}

emit_target() {
  quote_assignment PUSH_SOURCE_BRANCH "${PUSH_SOURCE_BRANCH-}"
  quote_assignment PUSH_REMOTE_URL "${PUSH_REMOTE_URL-}"
  quote_assignment PUSH_REMOTE_REF "${PUSH_REMOTE_REF-}"
  quote_assignment PUSH_LEASE_OID "${PUSH_LEASE_OID-}"
}

emit_empty_target() {
  PUSH_SOURCE_BRANCH=""
  PUSH_REMOTE_URL=""
  PUSH_REMOTE_REF=""
  PUSH_LEASE_OID=""
  emit_target
}

read_branch_config() {
  local key="$1"
  local destination="$2"
  local value=""
  local status=0

  if value=$(git config --get "$key"); then
    status=0
  else
    status=$?
  fi

  case "$status" in
  0)
    if [ -z "$value" ]; then
      echo "Git configuration '$key' is present but empty; repair it before rewriting history." >&2
      exit 1
    fi
    printf -v "$destination" '%s' "$value"
    return 0
    ;;
  1)
    printf -v "$destination" '%s' ""
    return 1
    ;;
  *)
    echo "Could not read Git configuration '$key'; stop before deriving a force-push target." >&2
    exit 1
    ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
  --original-tip)
    if [ $# -lt 2 ] || [ -z "${2-}" ]; then
      echo "--original-tip requires a value" >&2
      exit 1
    fi
    ORIGINAL_TIP="$2"
    shift 2
    ;;
  --base-branch)
    if [ $# -lt 2 ] || [ -z "${2-}" ]; then
      echo "--base-branch requires a value" >&2
      exit 1
    fi
    BASE_BRANCH="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage
    exit 1
    ;;
  esac
done

if [[ ! "$ORIGINAL_TIP" =~ ^[0-9a-f]{40}$ ]] ||
  ! git rev-parse --verify --quiet "${ORIGINAL_TIP}^{commit}" >/dev/null; then
  echo "--original-tip must be a full 40-character commit OID that resolves locally" >&2
  exit 1
fi
if [ -z "$BASE_BRANCH" ] || ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "--base-branch must be a valid branch name" >&2
  exit 1
fi

PUSH_SOURCE_BRANCH=$(git symbolic-ref --quiet --short HEAD) || {
  echo "Cannot resolve a push target from a detached HEAD." >&2
  exit 1
}
if ! git check-ref-format --branch "$PUSH_SOURCE_BRANCH" >/dev/null 2>&1; then
  echo "Current branch '$PUSH_SOURCE_BRANCH' is not a valid branch name." >&2
  exit 1
fi
CURRENT_TIP=$(git rev-parse --verify HEAD)
if [ "$CURRENT_TIP" != "$ORIGINAL_TIP" ]; then
  echo "The current tip changed after backup creation; stop before resolving a force-push target." >&2
  exit 1
fi

UPSTREAM_REMOTE=""
UPSTREAM_REMOTE_PRESENT=0
UPSTREAM_MERGE_REF=""
UPSTREAM_MERGE_REF_PRESENT=0
if read_branch_config "branch.${PUSH_SOURCE_BRANCH}.remote" UPSTREAM_REMOTE; then
  UPSTREAM_REMOTE_PRESENT=1
fi
if read_branch_config "branch.${PUSH_SOURCE_BRANCH}.merge" UPSTREAM_MERGE_REF; then
  UPSTREAM_MERGE_REF_PRESENT=1
fi
if [ "$UPSTREAM_REMOTE_PRESENT" -eq 0 ] && [ "$UPSTREAM_MERGE_REF_PRESENT" -eq 0 ]; then
  emit_empty_target
  exit 0
fi
if [ "$UPSTREAM_REMOTE_PRESENT" -eq 0 ] || [ "$UPSTREAM_MERGE_REF_PRESENT" -eq 0 ]; then
  echo "The upstream configuration for '$PUSH_SOURCE_BRANCH' is incomplete; refusing to derive a force-push target." >&2
  exit 1
fi
if [ "$UPSTREAM_REMOTE" = "." ]; then
  emit_empty_target
  exit 0
fi

case "$UPSTREAM_MERGE_REF" in
refs/heads/*) ;;
*)
  echo "The upstream for '$PUSH_SOURCE_BRANCH' is not a remote branch: '$UPSTREAM_MERGE_REF'." >&2
  exit 1
  ;;
esac
if [ "$UPSTREAM_MERGE_REF" = "refs/heads/${BASE_BRANCH}" ]; then
  echo "The configured upstream for '$PUSH_SOURCE_BRANCH' targets the base branch '$BASE_BRANCH'; refusing to force-push it." >&2
  exit 1
fi
if [ "$UPSTREAM_MERGE_REF" != "refs/heads/${PUSH_SOURCE_BRANCH}" ]; then
  echo "The configured upstream ref '$UPSTREAM_MERGE_REF' does not match the current branch '$PUSH_SOURCE_BRANCH'; set a matching upstream before rewriting history." >&2
  exit 1
fi
if ! git check-ref-format "$UPSTREAM_MERGE_REF" >/dev/null 2>&1; then
  echo "The upstream for '$PUSH_SOURCE_BRANCH' is not a valid branch ref: '$UPSTREAM_MERGE_REF'." >&2
  exit 1
fi

PUSH_REMOTE=$(git for-each-ref --format='%(push:remotename)' "refs/heads/${PUSH_SOURCE_BRANCH}") || {
  echo "Could not resolve the effective push remote for '$PUSH_SOURCE_BRANCH'." >&2
  exit 1
}
PUSH_TRACKING_REF=$(git for-each-ref --format='%(push)' "refs/heads/${PUSH_SOURCE_BRANCH}") || {
  echo "Could not resolve the effective push ref for '$PUSH_SOURCE_BRANCH'." >&2
  exit 1
}
if [ -z "$PUSH_REMOTE" ] || [ -z "$PUSH_TRACKING_REF" ]; then
  echo "The effective push destination for '$PUSH_SOURCE_BRANCH' is not one branch; configure push.default and the push remote explicitly before rewriting history." >&2
  exit 1
fi
PUSH_REMOTE_REF="refs/heads/${PUSH_SOURCE_BRANCH}"
EXPECTED_PUSH_TRACKING_REF="refs/remotes/${PUSH_REMOTE}/${PUSH_SOURCE_BRANCH}"
if [ "$PUSH_TRACKING_REF" != "$EXPECTED_PUSH_TRACKING_REF" ]; then
  echo "The effective push configuration for '$PUSH_SOURCE_BRANCH' remaps it to '$PUSH_TRACKING_REF'; configure a same-named destination before rewriting history." >&2
  exit 1
fi

PUSH_REMOTE_URLS=()
PUSH_REMOTE_URLS_OUTPUT=""
if ! PUSH_REMOTE_URLS_OUTPUT=$(git remote get-url --push --all -- "$PUSH_REMOTE" 2>/dev/null); then
  echo "The effective push destination for '$PUSH_SOURCE_BRANCH' names unknown remote '$PUSH_REMOTE'." >&2
  exit 1
fi
while IFS= read -r push_url; do
  [ -n "$push_url" ] || continue
  PUSH_REMOTE_URLS[${#PUSH_REMOTE_URLS[@]}]="$push_url"
done <<<"$PUSH_REMOTE_URLS_OUTPUT"
if [ "${#PUSH_REMOTE_URLS[@]}" -ne 1 ]; then
  echo "Remote '$PUSH_REMOTE' must resolve to exactly one push URL before an automatic history rewrite." >&2
  exit 1
fi
PUSH_REMOTE_URL="${PUSH_REMOTE_URLS[0]}"

if ! git check-ref-format "$PUSH_REMOTE_REF" >/dev/null 2>&1; then
  echo "The effective push ref for '$PUSH_SOURCE_BRANCH' is invalid: '$PUSH_REMOTE_REF'." >&2
  exit 1
fi

PUSH_LEASE_OID=$(git rev-parse --verify "${PUSH_TRACKING_REF}^{commit}") || {
  echo "The effective push destination '$PUSH_TRACKING_REF' does not resolve locally; fetch it before rewriting history." >&2
  exit 1
}
if ! git merge-base --is-ancestor "$PUSH_LEASE_OID" "$ORIGINAL_TIP"; then
  echo "Push destination '$PUSH_TRACKING_REF' contains commits absent from the local original tip; integrate or coordinate them before rewriting history." >&2
  exit 1
fi

emit_target
