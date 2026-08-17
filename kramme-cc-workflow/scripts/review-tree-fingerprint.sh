#!/usr/bin/env bash
#
# Emit a manifest of every working-tree path a review agent could read as
# evidence and could also mutate: tracked files that differ from HEAD (staged
# or unstaged) and untracked, non-ignored files.
#
# Output is one "<state><TAB><path>" line per path, sorted, where <state> is a
# git blob OID for a regular file, "absent" for a listed-but-missing path,
# "symlink:<target>", "nonfile", or "unreadable".
#
# Capture the manifest before launching review agents and again after
# collecting their findings. Any difference means the shared working tree
# changed during the review, so findings citing the differing paths were
# formed against text that no longer exists on disk.
#
# Ignored files are deliberately excluded: build output and caches are not
# review evidence, and hashing them would make every incidental write look
# like a mutated review scope.

set -euo pipefail

usage() {
  cat >&2 << 'USAGE'
Usage: review-tree-fingerprint.sh

Prints a sorted manifest of the working tree's mutable review surface:
tracked paths differing from HEAD plus untracked, non-ignored paths.
Diff two captures to see which paths changed during a review.
USAGE
}

case "${1-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "review-tree-fingerprint.sh: unknown argument: $1" >&2
    usage
    exit 2
    ;;
esac

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "review-tree-fingerprint.sh: not inside a git working tree" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet HEAD > /dev/null; then
  echo "review-tree-fingerprint.sh: HEAD has no commit to compare against" >&2
  exit 1
fi

# Run from the repository root so the manifest covers the whole tree and the
# paths git reports resolve for hashing no matter where the caller invoked us.
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

collect_paths() {
  git diff --name-only -z HEAD --
  git ls-files --others --exclude-standard -z
}

describe_paths() {
  local path state
  while IFS= read -r -d '' path; do
    if [ -L "$path" ]; then
      state="symlink:$(readlink -- "$path" 2> /dev/null || printf '?')"
    elif [ -f "$path" ]; then
      state=$(git hash-object -- "$path" 2> /dev/null) || state="unreadable"
    elif [ -e "$path" ]; then
      state="nonfile"
    else
      state="absent"
    fi
    printf '%s\t%s\n' "$state" "$path"
  done
}

collect_paths | describe_paths | LC_ALL=C sort -u
