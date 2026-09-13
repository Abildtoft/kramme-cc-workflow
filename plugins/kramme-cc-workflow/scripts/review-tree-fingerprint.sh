#!/usr/bin/env bash
#
# Emit a manifest of every working-tree path a review agent could read as
# evidence and could also mutate: tracked files that differ from HEAD (staged
# or unstaged) and untracked, non-ignored files.
#
# Output starts with one "@head<TAB><commit>" metadata record, followed by one
# sorted "<state><TAB><path>" line per path. <state> is a git blob OID for a
# regular file, "absent" for a listed-but-missing path, "symlink:<target>",
# "nonfile", or "unreadable".
#
# Capture the manifest before launching review agents and again after
# collecting their findings. Changed HEAD metadata invalidates the complete
# review batch; changed path records require re-verifying findings for those
# paths against the current working tree.
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
The first record identifies the captured HEAD commit. Compare it before path
records; a different commit invalidates the review rather than naming a path.
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

if ! CAPTURED_HEAD=$(git rev-parse --verify --quiet 'HEAD^{commit}'); then
  echo "review-tree-fingerprint.sh: HEAD has no commit to compare against" >&2
  exit 1
fi

# Run from the repository root so the manifest covers the whole tree and the
# paths git reports resolve for hashing no matter where the caller invoked us.
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

collect_paths() {
  local captured_head=$1

  # This function runs in a tested pipeline, where Bash suppresses errexit.
  # Propagate each producer failure explicitly so the manifest fails closed.
  git diff --name-only -z "$captured_head" -- || return 1
  git ls-files --others --exclude-standard -z || return 1
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

if ! PATH_MANIFEST=$(collect_paths "$CAPTURED_HEAD" | describe_paths | LC_ALL=C sort -u); then
  echo "review-tree-fingerprint.sh: could not capture working-tree paths" >&2
  exit 1
fi

CURRENT_HEAD=$(git rev-parse --verify 'HEAD^{commit}')
if [ "$CURRENT_HEAD" != "$CAPTURED_HEAD" ]; then
  echo "review-tree-fingerprint.sh: HEAD changed during manifest capture" >&2
  exit 1
fi

printf '@head\t%s\n' "$CAPTURED_HEAD"
if [ -n "$PATH_MANIFEST" ]; then
  printf '%s\n' "$PATH_MANIFEST"
fi
