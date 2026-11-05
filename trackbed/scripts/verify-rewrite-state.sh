#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/shell-helpers.sh
source "$SCRIPT_DIR/lib/shell-helpers.sh"

EXPECTED_BRANCH=""
EXPECTED_TIP=""
RESET_POINT=""

usage() {
  echo "Usage: verify-rewrite-state.sh --expected-branch <branch> --expected-tip <40-hex-oid> --reset-point <40-hex-oid>" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --expected-branch)
      require_value "$1" "${2-}"
      EXPECTED_BRANCH="$2"
      shift 2
      ;;
    --expected-tip)
      require_value "$1" "${2-}"
      EXPECTED_TIP="$2"
      shift 2
      ;;
    --reset-point)
      require_value "$1" "${2-}"
      RESET_POINT="$2"
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

if [ -z "$EXPECTED_BRANCH" ] || [ -z "$EXPECTED_TIP" ] || [ -z "$RESET_POINT" ]; then
  usage
  exit 1
fi
if ! git check-ref-format --branch "$EXPECTED_BRANCH" > /dev/null 2>&1; then
  echo "--expected-branch must be a valid branch name" >&2
  exit 1
fi
if [[ ! "$EXPECTED_TIP" =~ ^[0-9a-f]{40}$ ]] \
  || ! git rev-parse --verify --quiet "${EXPECTED_TIP}^{commit}" > /dev/null; then
  echo "--expected-tip must be a full 40-character commit OID that resolves locally" >&2
  exit 1
fi
if [[ ! "$RESET_POINT" =~ ^[0-9a-f]{40}$ ]] \
  || ! git rev-parse --verify --quiet "${RESET_POINT}^{commit}" > /dev/null; then
  echo "--reset-point must be a full 40-character commit OID that resolves locally" >&2
  exit 1
fi

CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD) || {
  echo "HEAD became detached after rewrite validation; stop before resetting." >&2
  exit 1
}
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "The current branch changed from '$EXPECTED_BRANCH' to '$CURRENT_BRANCH'; stop before resetting." >&2
  exit 1
fi

CURRENT_TIP=$(git rev-parse --verify HEAD)
if [ "$CURRENT_TIP" != "$EXPECTED_TIP" ]; then
  echo "The current tip no longer matches the captured original tip; stop before resetting and preserve the new commits." >&2
  exit 1
fi

WORKTREE_STATUS=""
if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
  echo "Could not inspect the working tree; stop before resetting." >&2
  exit 1
fi
if [ -n "$WORKTREE_STATUS" ]; then
  echo "Working tree has uncommitted or untracked changes; commit them or use 'git stash --include-untracked' first" >&2
  exit 1
fi

IGNORED_PATHS_FILE=""
TRACKED_FLAGS_FILE=""
ASSUME_UNCHANGED_PATHS_FILE=""
TEMP_INDEX=""
cleanup() {
  [ -z "$IGNORED_PATHS_FILE" ] || rm -f "$IGNORED_PATHS_FILE"
  [ -z "$TRACKED_FLAGS_FILE" ] || rm -f "$TRACKED_FLAGS_FILE"
  [ -z "$ASSUME_UNCHANGED_PATHS_FILE" ] || rm -f "$ASSUME_UNCHANGED_PATHS_FILE"
  [ -z "$TEMP_INDEX" ] || rm -f "$TEMP_INDEX"
}
trap cleanup EXIT

TRACKED_FLAGS_FILE=$(mktemp "${TMPDIR:-/tmp}/rewrite-tracked-flags.XXXXXX") || {
  echo "Could not create temporary tracked-path inventory; stop before resetting." >&2
  exit 1
}
ASSUME_UNCHANGED_PATHS_FILE=$(mktemp "${TMPDIR:-/tmp}/rewrite-assume-unchanged-paths.XXXXXX") || {
  echo "Could not create temporary assume-unchanged inventory; stop before resetting." >&2
  exit 1
}
if ! git ls-files -v -z > "$TRACKED_FLAGS_FILE"; then
  echo "Could not inspect tracked path flags; stop before resetting." >&2
  exit 1
fi
while IFS= read -r -d '' tracked_entry; do
  if [ "${tracked_entry:0:1}" = "h" ]; then
    printf '%s\0' "${tracked_entry:2}" >> "$ASSUME_UNCHANGED_PATHS_FILE"
  fi
done < "$TRACKED_FLAGS_FILE"

if [ -s "$ASSUME_UNCHANGED_PATHS_FILE" ]; then
  INDEX_PATH=$(git rev-parse --git-path index) || {
    echo "Could not locate the Git index; stop before resetting." >&2
    exit 1
  }
  case "$INDEX_PATH" in
    /*) ;;
    *) INDEX_PATH="$PWD/$INDEX_PATH" ;;
  esac
  TEMP_INDEX=$(mktemp "$(dirname "$INDEX_PATH")/rewrite-check-index.XXXXXX") || {
    echo "Could not create a temporary Git index; stop before resetting." >&2
    exit 1
  }
  if ! cp -- "$INDEX_PATH" "$TEMP_INDEX"; then
    echo "Could not copy the Git index for assume-unchanged validation; stop before resetting." >&2
    exit 1
  fi
  if ! GIT_INDEX_FILE="$TEMP_INDEX" git update-index --no-assume-unchanged -z --stdin < "$ASSUME_UNCHANGED_PATHS_FILE"; then
    echo "Could not validate assume-unchanged paths; stop before resetting." >&2
    exit 1
  fi

  set +e
  GIT_INDEX_FILE="$TEMP_INDEX" git diff --quiet --no-ext-diff --ignore-submodules=none --
  HIDDEN_DIFF_STATUS=$?
  set -e
  case "$HIDDEN_DIFF_STATUS" in
    0) ;;
    1)
      echo "Assume-unchanged tracked content differs from the index; preserve or restore it before resetting." >&2
      exit 1
      ;;
    *)
      echo "Could not compare assume-unchanged paths with the index; stop before resetting." >&2
      exit 1
      ;;
  esac
fi

IGNORED_PATHS_FILE=$(mktemp "${TMPDIR:-/tmp}/rewrite-ignored-paths.XXXXXX") || {
  echo "Could not create temporary ignored-path inventory; stop before resetting." >&2
  exit 1
}

if ! git ls-files --others --ignored --exclude-standard --directory -z > "$IGNORED_PATHS_FILE"; then
  echo "Could not inspect ignored paths; stop before resetting." >&2
  exit 1
fi

while IFS= read -r -d '' ignored_path; do
  ignored_path=${ignored_path%/}
  [ -n "$ignored_path" ] || continue

  RESET_ENTRY_TYPE=""
  if ! RESET_ENTRY_TYPE=$(git ls-tree --format='%(objecttype)' "$RESET_POINT" -- "$ignored_path"); then
    echo "Could not inspect reset point path '$ignored_path'; stop before resetting." >&2
    exit 1
  fi
  if [ -n "$RESET_ENTRY_TYPE" ]; then
    echo "Ignored path '$ignored_path' overlaps content restored by the reset; move it or stash it with 'git stash --all' first" >&2
    exit 1
  fi

  parent_path="$ignored_path"
  while [[ "$parent_path" == */* ]]; do
    parent_path=${parent_path%/*}
    reset_type=""
    if ! reset_type=$(git ls-tree --format='%(objecttype)' "$RESET_POINT" -- "$parent_path"); then
      echo "Could not inspect reset point path '$parent_path'; stop before resetting." >&2
      exit 1
    fi
    if [ -n "$reset_type" ] && [ "$reset_type" != "tree" ]; then
      echo "Ignored path '$ignored_path' is beneath '$parent_path', which the reset restores as a file; move it or stash it with 'git stash --all' first" >&2
      exit 1
    fi
  done
done < "$IGNORED_PATHS_FILE"
