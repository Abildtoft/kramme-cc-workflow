#!/usr/bin/env bash
#
# Resolve a PR base ref for workflow skills.
#
# Default output contract: shell-quoted KEY=VALUE lines suitable for:
#   eval "$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" ...)"
# JSON output is available with --format json for structured consumers. The
# shell format is retained temporarily for existing skill snippets until W03B.
#
# Default mode is read-only except for fetching the resolved remote base.
# Recreate-commits passes --backup to enable clean-tree checks, local base
# fast-forwarding, reset-point calculation, and recovery backup creation.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/shell-helpers.sh
source "$SCRIPT_DIR/lib/shell-helpers.sh"

BASE_FLAG=""
BASE_COMMIT_FLAG=""
AFTER_ARG=""
BACKUP_REF_FLAG=""
FETCH_MODE="strict"
BACKUP_MODE=0
FORCE_BACKUP=0
OUTPUT_FORMAT="shell"
RESOLVE_BASE_FETCH_TIMEOUT_SECONDS="${RESOLVE_BASE_FETCH_TIMEOUT_SECONDS:-30}"
RESOLVE_BASE_GH_LOOKUP_TIMEOUT_SECONDS="${RESOLVE_BASE_GH_LOOKUP_TIMEOUT_SECONDS:-10}"
RESOLVE_BASE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"

usage() {
  cat >&2 << 'USAGE'
Usage: resolve-base.sh [--base <branch-or-ref>] [--base-commit <40-hex-oid>] [--strict|--tolerate-fetch-failure] [--backup] [--backup-ref <branch>] [--after <commit>] [--force-backup] [--format shell|json]

Default output is shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE AFTER_COMMIT RESET_POINT ORIGINAL_BRANCH ORIGINAL_TIP BACKUP_REF

JSON output fields:
  base_ref base_branch merge_base after_commit reset_point original_branch original_tip backup_ref
USAGE
}

emit_json() {
  if ! command -v python3 > /dev/null 2>&1; then
    echo "python3 is required for --format json" >&2
    exit 1
  fi

  BASE_REF="$BASE_REF" \
    BASE_BRANCH="$BASE_BRANCH" \
    MERGE_BASE="$MERGE_BASE" \
    AFTER_COMMIT="$AFTER_COMMIT" \
    RESET_POINT="$RESET_POINT" \
    ORIGINAL_BRANCH="$ORIGINAL_BRANCH" \
    ORIGINAL_TIP="$ORIGINAL_TIP" \
    BACKUP_REF="$BACKUP_REF" \
    python3 - << 'PY'
import json
import os
import sys

fields = [
    ("base_ref", "BASE_REF"),
    ("base_branch", "BASE_BRANCH"),
    ("merge_base", "MERGE_BASE"),
    ("after_commit", "AFTER_COMMIT"),
    ("reset_point", "RESET_POINT"),
    ("original_branch", "ORIGINAL_BRANCH"),
    ("original_tip", "ORIGINAL_TIP"),
    ("backup_ref", "BACKUP_REF"),
]

json.dump({key: os.environ.get(env_name, "") for key, env_name in fields}, sys.stdout, separators=(",", ":"))
sys.stdout.write("\n")
PY
}

emit_output() {
  case "$OUTPUT_FORMAT" in
    shell)
      quote_assignment BASE_REF "$BASE_REF"
      quote_assignment BASE_BRANCH "$BASE_BRANCH"
      quote_assignment MERGE_BASE "$MERGE_BASE"
      quote_assignment AFTER_COMMIT "$AFTER_COMMIT"
      quote_assignment RESET_POINT "$RESET_POINT"
      quote_assignment ORIGINAL_BRANCH "$ORIGINAL_BRANCH"
      quote_assignment ORIGINAL_TIP "$ORIGINAL_TIP"
      quote_assignment BACKUP_REF "$BACKUP_REF"
      ;;
    json)
      emit_json
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      require_value "$1" "${2-}"
      BASE_FLAG="$2"
      shift 2
      ;;
    --base-commit)
      require_value "$1" "${2-}"
      BASE_COMMIT_FLAG="$2"
      shift 2
      ;;
    --after)
      require_value "$1" "${2-}"
      AFTER_ARG="$2"
      shift 2
      ;;
    --strict)
      FETCH_MODE="strict"
      shift
      ;;
    --tolerate-fetch-failure)
      FETCH_MODE="tolerate"
      shift
      ;;
    --backup)
      BACKUP_MODE=1
      shift
      ;;
    --backup-ref)
      require_value "$1" "${2-}"
      BACKUP_REF_FLAG="$2"
      shift 2
      ;;
    --force-backup)
      FORCE_BACKUP=1
      shift
      ;;
    --format)
      require_value "$1" "${2-}"
      case "$2" in
        shell | json)
          OUTPUT_FORMAT="$2"
          ;;
        *)
          echo "--format must be 'shell' or 'json'" >&2
          exit 1
          ;;
      esac
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

if [ "$FORCE_BACKUP" -eq 1 ] && [ "$BACKUP_MODE" -ne 1 ]; then
  echo "--force-backup requires --backup" >&2
  exit 1
fi
if [ -n "$BACKUP_REF_FLAG" ] && [ "$BACKUP_MODE" -ne 1 ]; then
  echo "--backup-ref requires --backup" >&2
  exit 1
fi
if [ -n "$BACKUP_REF_FLAG" ]; then
  if [[ ! "$BACKUP_REF_FLAG" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] \
    || ! git check-ref-format --branch "$BACKUP_REF_FLAG" > /dev/null 2>&1; then
    echo "--backup-ref must be a conservative valid branch name" >&2
    exit 1
  fi
fi
if [ -n "$BASE_COMMIT_FLAG" ] && [[ ! "$BASE_COMMIT_FLAG" =~ ^[0-9a-f]{40}$ ]]; then
  echo "--base-commit must be a full 40-character lowercase commit OID" >&2
  exit 1
fi

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null); then
  echo "Not inside a git repository" >&2
  exit 1
fi
REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P)

if [ "$BACKUP_MODE" -eq 1 ]; then
  if [ "$SCRIPT_DIR" = "$REPO_ROOT" ] || [[ "$SCRIPT_DIR" == "$REPO_ROOT"/* ]]; then
    echo "Refusing to run backup mode against the repository that contains this plugin script." >&2
    echo "Run from the user repository with \$CLAUDE_PLUGIN_ROOT/scripts/resolve-base.sh --backup; do not cd into the plugin directory." >&2
    exit 1
  fi

  WORKTREE_STATUS=""
  if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
    echo "Could not inspect the working tree; stop before creating a recovery backup" >&2
    exit 1
  fi
  if [ -n "$WORKTREE_STATUS" ]; then
    echo "Working tree has uncommitted or untracked changes; commit them or use 'git stash --include-untracked' first" >&2
    exit 1
  fi
fi

CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD || true)
if [ "$BACKUP_MODE" -eq 1 ] && [ -z "$CURRENT_BRANCH" ]; then
  echo "HEAD is detached; switch to the feature branch first" >&2
  exit 1
fi
if [ "$BACKUP_MODE" -eq 1 ] \
  && [ -n "$BACKUP_REF_FLAG" ] \
  && [ "$BACKUP_REF_FLAG" = "$CURRENT_BRANCH" ]; then
  echo "--backup-ref must not name the current branch being rewritten" >&2
  exit 1
fi

fetch_remote_branch() {
  local remote="$1"
  local branch="$2"
  local label="$3"
  local remote_ref="refs/remotes/${remote}/${branch}"
  local fetch_status=0
  local fetch_stderr

  fetch_stderr=$(mktemp "${TMPDIR:-/tmp}/resolve-base-fetch-stderr.XXXXXX")
  if run_with_timeout "$RESOLVE_BASE_FETCH_TIMEOUT_SECONDS" env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$RESOLVE_BASE_GIT_SSH_COMMAND" git fetch "$remote" "refs/heads/${branch}:${remote_ref}" 2> "$fetch_stderr"; then
    if ! grep -q '^fatal:' "$fetch_stderr"; then
      cat "$fetch_stderr" >&2
      rm -f "$fetch_stderr"
      return 0
    fi
    fetch_status=1
  else
    fetch_status=$?
  fi
  cat "$fetch_stderr" >&2
  rm -f "$fetch_stderr"

  if [ "$FETCH_MODE" = "tolerate" ] && git rev-parse --verify --quiet "${remote_ref}^{commit}" > /dev/null; then
    if [ "$fetch_status" -eq 124 ] || [ "$fetch_status" -eq 142 ]; then
      echo "Warning: timed out fetching ${remote}/${branch}; using existing ${remote_ref}" >&2
    else
      echo "Warning: failed to fetch ${remote}/${branch}; using existing ${remote_ref}" >&2
    fi
    return 0
  fi

  if [ "$fetch_status" -eq 124 ] || [ "$fetch_status" -eq 142 ]; then
    echo "Timed out fetching ${remote}/${branch}${label:+ for $label} after ${RESOLVE_BASE_FETCH_TIMEOUT_SECONDS}s" >&2
    exit 1
  fi

  echo "Failed to fetch ${remote}/${branch}${label:+ for $label}" >&2
  exit 1
}

remote_exists() {
  git remote get-url "$1" > /dev/null 2>&1
}

BASE_BRANCH=""
BASE_REMOTE="origin"

if [ -n "$BASE_FLAG" ]; then
  case "$BASE_FLAG" in
    refs/remotes/*/*)
      BASE_REMOTE=${BASE_FLAG#refs/remotes/}
      BASE_REMOTE=${BASE_REMOTE%%/*}
      BASE_BRANCH=${BASE_FLAG#refs/remotes/"${BASE_REMOTE}"/}
      ;;
    refs/heads/*)
      BASE_REMOTE="origin"
      BASE_BRANCH=${BASE_FLAG#refs/heads/}
      ;;
    */*)
      CANDIDATE_REMOTE=${BASE_FLAG%%/*}
      if remote_exists "$CANDIDATE_REMOTE"; then
        BASE_REMOTE="$CANDIDATE_REMOTE"
        BASE_BRANCH=${BASE_FLAG#*/}
      else
        BASE_REMOTE="origin"
        BASE_BRANCH=$BASE_FLAG
      fi
      ;;
    *)
      BASE_REMOTE="origin"
      BASE_BRANCH=$BASE_FLAG
      ;;
  esac

  if [ -z "$BASE_BRANCH" ]; then
    echo "Explicit base ref '$BASE_FLAG' did not include a branch name" >&2
    exit 1
  fi
  if ! remote_exists "$BASE_REMOTE"; then
    echo "Explicit base ref '$BASE_FLAG' names unknown remote '$BASE_REMOTE'" >&2
    exit 1
  fi
  if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
    echo "Explicit base branch '$BASE_BRANCH' is not a valid branch name" >&2
    exit 1
  fi

  BASE_REF="refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"
  if [ -z "$BASE_COMMIT_FLAG" ]; then
    fetch_remote_branch "$BASE_REMOTE" "$BASE_BRANCH" "explicit base ref '$BASE_FLAG'"
  fi
else
  if command -v gh > /dev/null 2>&1; then
    BASE_BRANCH=$(run_with_timeout "$RESOLVE_BASE_GH_LOOKUP_TIMEOUT_SECONDS" env GH_PROMPT_DISABLED=1 gh pr view --json baseRefName --jq '.baseRefName' 2> /dev/null || true)
  fi
  if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@' || true)
  fi
  if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@' || true)
  fi
  if [ -z "$BASE_BRANCH" ]; then
    echo "Could not determine base branch; expected PR metadata, origin/HEAD, origin/main, or origin/master" >&2
    exit 1
  fi

  BASE_BRANCH=${BASE_BRANCH#refs/heads/}
  BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
  BASE_BRANCH=${BASE_BRANCH#origin/}
  if [ -z "$BASE_BRANCH" ]; then
    echo "Could not determine base branch" >&2
    exit 1
  fi
  if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
    echo "Base branch '$BASE_BRANCH' is not a valid branch name" >&2
    exit 1
  fi

  BASE_REF="refs/remotes/origin/${BASE_BRANCH}"
  if [ -z "$BASE_COMMIT_FLAG" ]; then
    fetch_remote_branch origin "$BASE_BRANCH" ""
  fi
fi

if [ -n "$BASE_COMMIT_FLAG" ]; then
  if ! git rev-parse --verify --quiet "${BASE_COMMIT_FLAG}^{commit}" > /dev/null; then
    echo "Pinned base commit '$BASE_COMMIT_FLAG' does not resolve locally" >&2
    exit 1
  fi
  BASE_REF="$BASE_COMMIT_FLAG"
fi

if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" > /dev/null; then
  echo "Base ref '$BASE_REF' does not resolve to a commit" >&2
  exit 1
fi
if [ "$BACKUP_MODE" -eq 1 ] && [ -n "$BASE_BRANCH" ] && [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
  echo "Current branch is the base branch '$BASE_BRANCH'; switch to a feature branch first" >&2
  exit 1
fi
if ! git merge-base "$BASE_REF" HEAD > /dev/null; then
  echo "No merge base between '$BASE_REF' and HEAD; histories are unrelated" >&2
  exit 1
fi
MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)

AFTER_COMMIT=""
if [ -n "$AFTER_ARG" ]; then
  if ! AFTER_COMMIT=$(git rev-parse --verify "$AFTER_ARG^{commit}" 2> /dev/null); then
    echo "--after commit '$AFTER_ARG' does not resolve" >&2
    exit 1
  fi
  if ! git merge-base --is-ancestor "$AFTER_COMMIT" HEAD; then
    echo "--after commit '$AFTER_ARG' is not an ancestor of HEAD" >&2
    exit 1
  fi
fi

RESET_POINT=""
ORIGINAL_BRANCH=""
ORIGINAL_TIP=""
BACKUP_REF=""

if [ "$BACKUP_MODE" -eq 1 ]; then
  if [ -z "$BASE_COMMIT_FLAG" ] \
    && [ -n "$BASE_BRANCH" ] \
    && [ "$BASE_REMOTE" = "origin" ] \
    && git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}" \
    && git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
    LOCAL_BASE=$(git rev-parse "refs/heads/${BASE_BRANCH}")
    REMOTE_BASE=$(git rev-parse "refs/remotes/origin/${BASE_BRANCH}")
    if [ "$LOCAL_BASE" != "$REMOTE_BASE" ]; then
      if git merge-base --is-ancestor "$LOCAL_BASE" "$REMOTE_BASE"; then
        git update-ref "refs/heads/${BASE_BRANCH}" "$REMOTE_BASE"
      else
        echo "Local base branch '$BASE_BRANCH' has diverged from origin/$BASE_BRANCH; resolve manually before retrying" >&2
        exit 1
      fi
    fi
  fi

  if [ -n "$AFTER_COMMIT" ]; then
    RESET_POINT="$AFTER_COMMIT"
  else
    RESET_POINT="$MERGE_BASE"
  fi
  ORIGINAL_BRANCH="$CURRENT_BRANCH"
  ORIGINAL_TIP=$(git rev-parse HEAD)
  if [ -n "$BACKUP_REF_FLAG" ]; then
    BACKUP_REF="$BACKUP_REF_FLAG"
  else
    BACKUP_REF="${ORIGINAL_BRANCH}-recreate-backup"
  fi
  "$SCRIPT_DIR/verify-rewrite-state.sh" \
    --expected-branch "$ORIGINAL_BRANCH" \
    --expected-tip "$ORIGINAL_TIP" \
    --reset-point "$RESET_POINT"
  if git show-ref --verify --quiet "refs/heads/$BACKUP_REF"; then
    EXISTING_BACKUP_TIP=$(git rev-parse "refs/heads/$BACKUP_REF")
    if [ "$EXISTING_BACKUP_TIP" = "$ORIGINAL_TIP" ]; then
      :
    elif [ "$FORCE_BACKUP" -ne 1 ]; then
      echo "Backup branch '$BACKUP_REF' already exists at $EXISTING_BACKUP_TIP; refusing to move it." >&2
      echo "Inspect it with: git log --oneline --decorate -n 5 $BACKUP_REF" >&2
      echo "Recover with: git reset --hard $BACKUP_REF" >&2
      echo "After confirming it is safe to replace, rerun with --force-backup." >&2
      exit 1
    else
      git branch -f "$BACKUP_REF" "$ORIGINAL_TIP" > /dev/null
    fi
  else
    git branch "$BACKUP_REF" "$ORIGINAL_TIP" > /dev/null
  fi
fi

emit_output
