#!/usr/bin/env bash

set -euo pipefail

CHECK_VISIBLE_STATUS=true
case "$#" in
  0) ;;
  1)
    if [ "$1" != "--allow-visible" ]; then
      echo "Usage: verify-clean-worktree.sh [--allow-visible]" >&2
      exit 2
    fi
    CHECK_VISIBLE_STATUS=false
    ;;
  *)
    echo "Usage: verify-clean-worktree.sh [--allow-visible]" >&2
    exit 2
    ;;
esac

WORKTREE_STATUS=""
if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
  echo "Could not inspect the working tree; stop before creating the Pull Request." >&2
  exit 1
fi
if [ "$CHECK_VISIBLE_STATUS" = true ] && [ -n "$WORKTREE_STATUS" ]; then
  echo "Working tree has uncommitted or untracked changes; preserve or commit them before creating the Pull Request." >&2
  exit 1
fi

TRACKED_FLAGS_FILE=""
HIDDEN_TRACKED_PATHS_FILE=""
TEMP_INDEX=""
cleanup() {
  [ -z "$TRACKED_FLAGS_FILE" ] || rm -f "$TRACKED_FLAGS_FILE"
  [ -z "$HIDDEN_TRACKED_PATHS_FILE" ] || rm -f "$HIDDEN_TRACKED_PATHS_FILE"
  [ -z "$TEMP_INDEX" ] || rm -f "$TEMP_INDEX"
}
trap cleanup EXIT

TRACKED_FLAGS_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-create-tracked-flags.XXXXXX") || {
  echo "Could not create a temporary tracked-path inventory; stop before creating the Pull Request." >&2
  exit 1
}
HIDDEN_TRACKED_PATHS_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-create-hidden-tracked-paths.XXXXXX") || {
  echo "Could not create a temporary hidden tracked-path inventory; stop before creating the Pull Request." >&2
  exit 1
}
if ! git ls-files -v -z > "$TRACKED_FLAGS_FILE"; then
  echo "Could not inspect tracked path flags; stop before creating the Pull Request." >&2
  exit 1
fi
while IFS= read -r -d '' tracked_entry; do
  tracked_flag=${tracked_entry:0:1}
  tracked_path=${tracked_entry:2}
  case "$tracked_flag" in
    h) printf '%s\0' "$tracked_path" >> "$HIDDEN_TRACKED_PATHS_FILE" ;;
    S | s)
      # An absent skip-worktree path is normal in a sparse checkout. Materialized
      # paths still need comparison because Git otherwise hides their edits.
      if [ -e "$tracked_path" ] || [ -L "$tracked_path" ]; then
        printf '%s\0' "$tracked_path" >> "$HIDDEN_TRACKED_PATHS_FILE"
      fi
      ;;
  esac
done < "$TRACKED_FLAGS_FILE"

if [ -s "$HIDDEN_TRACKED_PATHS_FILE" ]; then
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
    echo "Could not copy the Git index for hidden tracked-path validation; stop before creating the Pull Request." >&2
    exit 1
  fi
  if ! GIT_INDEX_FILE="$TEMP_INDEX" git update-index --no-assume-unchanged -z --stdin < "$HIDDEN_TRACKED_PATHS_FILE" \
    || ! GIT_INDEX_FILE="$TEMP_INDEX" git update-index --no-skip-worktree -z --stdin < "$HIDDEN_TRACKED_PATHS_FILE"; then
    echo "Could not validate hidden tracked paths; stop before creating the Pull Request." >&2
    exit 1
  fi

  HIDDEN_TRACKED_PATHS=()
  while IFS= read -r -d '' hidden_path; do
    HIDDEN_TRACKED_PATHS[${#HIDDEN_TRACKED_PATHS[@]}]="$hidden_path"
  done < "$HIDDEN_TRACKED_PATHS_FILE"

  set +e
  GIT_INDEX_FILE="$TEMP_INDEX" git diff-files --quiet --no-ext-diff --ignore-submodules=none -- "${HIDDEN_TRACKED_PATHS[@]}"
  HIDDEN_DIFF_STATUS=$?
  set -e
  case "$HIDDEN_DIFF_STATUS" in
    0) ;;
    1)
      echo "Hidden tracked content differs from the index; preserve or restore it before creating the Pull Request." >&2
      exit 1
      ;;
    *)
      echo "Could not compare hidden tracked paths with the index; stop before creating the Pull Request." >&2
      exit 1
      ;;
  esac
fi
