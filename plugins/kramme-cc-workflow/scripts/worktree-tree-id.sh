#!/usr/bin/env bash
#
# Print the git tree object ID of the working tree's current content: HEAD's
# tree with every staged, unstaged, and untracked non-ignored change applied.
#
# For a clean worktree the ID equals `git rev-parse 'HEAD^{tree}'`, and
# committing, amending, or recreating commits over the same content leaves it
# unchanged. Verification skills record it with a green run so a later claim
# can prove it concerns the exact content that run checked.
#
# The real index is never touched: changes are staged into a temporary copy of
# it. Staging writes blob objects for changed files into the object database,
# the same objects a later `git add` would write.
#
# Ignored files (build output, caches, local env files) are excluded, so a
# change that only touches ignored inputs keeps the same ID.

set -euo pipefail

usage() {
  cat >&2 << 'USAGE'
Usage: worktree-tree-id.sh

Prints the tree object ID of the working tree's content, including staged,
unstaged, and untracked non-ignored changes. Equals HEAD^{tree} when clean.
USAGE
}

case "${1-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "worktree-tree-id.sh: unknown argument: $1" >&2
    usage
    exit 2
    ;;
esac

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "worktree-tree-id.sh: not inside a git working tree" >&2
  exit 1
fi

# Stage from the repository root so the ID covers the whole tree no matter
# where the caller invoked us.
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

INDEX_PATH=$(git rev-parse --git-path index)
SCRATCH_DIR=$(mktemp -d)
trap 'rm -rf "$SCRATCH_DIR"' EXIT
TMP_INDEX="$SCRATCH_DIR/index"

# Seed from the real index so unchanged files keep their cached stat data and
# are not rehashed. A repository without an index yet starts empty.
if [ -f "$INDEX_PATH" ]; then
  cp "$INDEX_PATH" "$TMP_INDEX"
fi

if ! GIT_INDEX_FILE="$TMP_INDEX" git -c core.splitIndex=false -c core.fsmonitor=false \
  add --all -- . > /dev/null; then
  echo "worktree-tree-id.sh: could not stage the working tree into a temporary index" >&2
  exit 1
fi

if ! TREE_ID=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree); then
  echo "worktree-tree-id.sh: could not write the working-tree content tree" >&2
  exit 1
fi

printf '%s\n' "$TREE_ID"
