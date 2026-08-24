#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "Usage: verify-clean-worktree.sh" >&2
  exit 2
fi

WORKTREE_STATUS=""
if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
  echo "Could not inspect the working tree; stop before creating the Pull Request." >&2
  exit 1
fi
if [ -n "$WORKTREE_STATUS" ]; then
  echo "Working tree has uncommitted or untracked changes; preserve or commit them before creating the Pull Request." >&2
  exit 1
fi

TRACKED_FLAGS_FILE=""
ASSUME_UNCHANGED_PATHS_FILE=""
TEMP_INDEX=""
cleanup() {
  [ -z "$TRACKED_FLAGS_FILE" ] || rm -f "$TRACKED_FLAGS_FILE"
  [ -z "$ASSUME_UNCHANGED_PATHS_FILE" ] || rm -f "$ASSUME_UNCHANGED_PATHS_FILE"
  [ -z "$TEMP_INDEX" ] || rm -f "$TEMP_INDEX"
}
trap cleanup EXIT

TRACKED_FLAGS_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-create-tracked-flags.XXXXXX") || {
  echo "Could not create a temporary tracked-path inventory; stop before creating the Pull Request." >&2
  exit 1
}
ASSUME_UNCHANGED_PATHS_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-create-assume-unchanged-paths.XXXXXX") || {
  echo "Could not create a temporary assume-unchanged inventory; stop before creating the Pull Request." >&2
  exit 1
}
if ! git ls-files -v -z > "$TRACKED_FLAGS_FILE"; then
  echo "Could not inspect tracked path flags; stop before creating the Pull Request." >&2
  exit 1
fi
while IFS= read -r -d '' tracked_entry; do
  if [ "${tracked_entry:0:1}" = "h" ]; then
    printf '%s\0' "${tracked_entry:2}" >> "$ASSUME_UNCHANGED_PATHS_FILE"
  fi
done < "$TRACKED_FLAGS_FILE"

if [ -s "$ASSUME_UNCHANGED_PATHS_FILE" ]; then
  INDEX_PATH=$(git rev-parse --git-path index) || {
    echo "Could not locate the Git index; stop before creating the Pull Request." >&2
    exit 1
  }
  case "$INDEX_PATH" in
    /*) ;;
    *) INDEX_PATH="$PWD/$INDEX_PATH" ;;
  esac
  TEMP_INDEX=$(mktemp "$(dirname "$INDEX_PATH")/pr-create-check-index.XXXXXX") || {
    echo "Could not create a temporary Git index; stop before creating the Pull Request." >&2
    exit 1
  }
  if ! cp -- "$INDEX_PATH" "$TEMP_INDEX"; then
    echo "Could not copy the Git index for assume-unchanged validation; stop before creating the Pull Request." >&2
    exit 1
  fi
  if ! GIT_INDEX_FILE="$TEMP_INDEX" git update-index --no-assume-unchanged -z --stdin < "$ASSUME_UNCHANGED_PATHS_FILE"; then
    echo "Could not validate assume-unchanged paths; stop before creating the Pull Request." >&2
    exit 1
  fi

  set +e
  GIT_INDEX_FILE="$TEMP_INDEX" git diff --quiet --no-ext-diff --ignore-submodules=none --
  HIDDEN_DIFF_STATUS=$?
  set -e
  case "$HIDDEN_DIFF_STATUS" in
    0) ;;
    1)
      echo "Assume-unchanged tracked content differs from the index; preserve or restore it before creating the Pull Request." >&2
      exit 1
      ;;
    *)
      echo "Could not compare assume-unchanged paths with the index; stop before creating the Pull Request." >&2
      exit 1
      ;;
  esac
fi
