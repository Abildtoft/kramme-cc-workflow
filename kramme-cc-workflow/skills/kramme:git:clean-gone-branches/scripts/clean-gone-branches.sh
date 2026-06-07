#!/usr/bin/env bash
# Discover and optionally delete local branches whose upstream is gone.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-clean-gone-branches
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
set -euo pipefail

DELETE=0
YES=0
FORCE=0
PRUNE=0

usage() {
	cat <<'USAGE'
Usage: clean-gone-branches.sh [--prune] [--delete --yes] [--force] [--help]

Lists local branches whose upstream tracking branch is gone.

Options:
  --prune   Run git fetch --prune before discovery
  --delete  Delete safe candidate branches
  --yes     Required with --delete; indicates explicit user confirmation
  --force   Use git branch -D instead of git branch -d
  --help    Show this help
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
	--delete)
		DELETE=1
		;;
	--yes|-y)
		YES=1
		;;
	--force|-f)
		FORCE=1
		;;
	--prune)
		PRUNE=1
		;;
	--help|-h)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "Error: not inside a git repository" >&2
	exit 1
fi

if [ "$DELETE" -eq 1 ] && [ "$YES" -ne 1 ]; then
	echo "Refusing to delete without --yes. Run discovery first, confirm the plan, then pass --delete --yes." >&2
	exit 1
fi

if [ "$PRUNE" -eq 1 ]; then
	git fetch --prune
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/clean-gone-branches.XXXXXX")
cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

WORKTREES_FILE="$TMP_DIR/worktrees"
GONE_FILE="$TMP_DIR/gone"
: >"$GONE_FILE"
git worktree list --porcelain >"$WORKTREES_FILE"

current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)

worktree_for_branch() {
	local branch="$1"
	awk -v target="$branch" '
		/^worktree / {
			path = substr($0, 10)
		}
		/^branch refs\/heads\// {
			branch = substr($0, 19)
			if (branch == target) {
				print path
				exit
			}
		}
	' "$WORKTREES_FILE"
}

is_conductor_path() {
	local path="$1"
	if [ -z "$path" ]; then
		return 1
	fi
	if [ -n "${CONDUCTOR_WORKSPACE_PATH:-}" ] && [ "$path" = "$CONDUCTOR_WORKSPACE_PATH" ]; then
		return 0
	fi
	case "$path" in
	*/conductor/workspaces/*|*/Conductor/workspaces/*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads |
	while IFS='|' read -r branch upstream track; do
		[ "$track" = "[gone]" ] || continue
		worktree_path=$(worktree_for_branch "$branch")
		flags=""
		if [ "$branch" = "$current_branch" ]; then
			flags="${flags} current"
		fi
		if [ -n "$worktree_path" ]; then
			flags="${flags} checked-out"
		fi
		if is_conductor_path "$worktree_path"; then
			flags="${flags} conductor-workspace"
		fi
		printf '%s\t%s\t%s\t%s\n' "$branch" "$upstream" "${flags# }" "$worktree_path" >>"$GONE_FILE"
	done

if [ ! -s "$GONE_FILE" ]; then
	echo "No local branches have a gone upstream."
	exit 0
fi

echo "Local branches with gone upstreams:"
printf '%-34s %-34s %-34s %s\n' "Branch" "Upstream" "Flags" "Worktree"
printf '%-34s %-34s %-34s %s\n' "------" "--------" "-----" "--------"
while IFS=$'\t' read -r branch upstream flags worktree_path; do
	[ -n "$flags" ] || flags="-"
	[ -n "$worktree_path" ] || worktree_path="-"
	printf '%-34s %-34s %-34s %s\n' "$branch" "$upstream" "$flags" "$worktree_path"
done <"$GONE_FILE"

if [ "$DELETE" -ne 1 ]; then
	echo
	echo "Discovery only. Re-run with --delete --yes after explicit confirmation."
	exit 0
fi

echo
echo "Deleting safe candidates..."
deleted=0
skipped=0
failed=0

while IFS=$'\t' read -r branch upstream flags worktree_path; do
	if [ "$branch" = "$current_branch" ]; then
		echo "SKIP current branch: $branch"
		skipped=$((skipped + 1))
		continue
	fi
	if [ -n "$worktree_path" ]; then
		echo "SKIP checked-out branch: $branch ($worktree_path)"
		skipped=$((skipped + 1))
		continue
	fi

	if [ "$FORCE" -eq 1 ]; then
		if git branch -D -- "$branch"; then
			deleted=$((deleted + 1))
		else
			failed=$((failed + 1))
		fi
	else
		if git branch -d -- "$branch"; then
			deleted=$((deleted + 1))
		else
			failed=$((failed + 1))
		fi
	fi
done <"$GONE_FILE"

echo
echo "Summary: deleted=$deleted skipped=$skipped failed=$failed"
if [ "$failed" -gt 0 ]; then
	echo "Some branches were not deleted. Use --force only after confirming unmerged local work can be discarded." >&2
	exit 1
fi
