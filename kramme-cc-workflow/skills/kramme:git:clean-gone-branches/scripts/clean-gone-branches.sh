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
CONFIRMED_BRANCHES=()

usage() {
	cat <<'USAGE'
Usage: clean-gone-branches.sh [--prune] [--delete --yes <branch>...] [--force] [--help]

Lists local branches whose upstream tracking branch is gone.

Options:
  --prune   Run git fetch --prune before discovery
  --delete  Delete only the confirmed branch names passed as arguments
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
	--)
		shift
		while [ $# -gt 0 ]; do
			CONFIRMED_BRANCHES+=("$1")
			shift
		done
		break
		;;
	-*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	*)
		CONFIRMED_BRANCHES+=("$1")
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

if [ "$DELETE" -ne 1 ] && [ "${#CONFIRMED_BRANCHES[@]}" -gt 0 ]; then
	echo "Branch names are only accepted with --delete --yes after confirmation." >&2
	usage >&2
	exit 2
fi

if [ "$DELETE" -eq 1 ] && [ "${#CONFIRMED_BRANCHES[@]}" -eq 0 ]; then
	echo "Refusing to delete without confirmed branch names. Run discovery first, confirm the exact branches, then pass them after --delete --yes." >&2
	exit 1
fi

if [ "$DELETE" -eq 1 ] && [ "$PRUNE" -eq 1 ]; then
	echo "Ignoring --prune in delete mode; prune only before discovery so the confirmed delete set cannot change." >&2
	PRUNE=0
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

append_branch_row() {
	local branch="$1"
	local upstream="${2:-}"
	local flags="${3:-}"
	local worktree_path

	worktree_path=$(worktree_for_branch "$branch")
	if [ "$branch" = "$current_branch" ]; then
		flags="${flags} current"
	fi
	if [ -n "$worktree_path" ]; then
		flags="${flags} checked-out"
	fi
	if is_conductor_path "$worktree_path"; then
		flags="${flags} conductor-workspace"
	fi
	printf '%s\t%s\t%s\t%s\n' "$branch" "${upstream:-"-"}" "${flags# }" "$worktree_path" >>"$GONE_FILE"
}

if [ "$DELETE" -eq 1 ]; then
	for branch in "${CONFIRMED_BRANCHES[@]}"; do
		if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
			printf '%s\t%s\t%s\t%s\n' "$branch" "-" "invalid" "" >>"$GONE_FILE"
			continue
		fi
		if ! git show-ref --verify --quiet "refs/heads/$branch"; then
			printf '%s\t%s\t%s\t%s\n' "$branch" "-" "missing" "" >>"$GONE_FILE"
			continue
		fi
		ref_info=$(git for-each-ref --format='%(upstream:short)|%(upstream:track)' "refs/heads/$branch")
		upstream=${ref_info%%|*}
		track=${ref_info#*|}
		if [ "$track" != "[gone]" ]; then
			append_branch_row "$branch" "$upstream" "not-gone"
			continue
		fi
		append_branch_row "$branch" "$upstream"
	done
else
	git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads |
		while IFS='|' read -r branch upstream track; do
			[ "$track" = "[gone]" ] || continue
			append_branch_row "$branch" "$upstream"
		done
fi

if [ ! -s "$GONE_FILE" ]; then
	echo "No local branches have a gone upstream."
	exit 0
fi

if [ "$DELETE" -eq 1 ]; then
	echo "Confirmed branches selected for deletion:"
else
	echo "Local branches with gone upstreams:"
fi
printf '%-34s %-34s %-34s %s\n' "Branch" "Upstream" "Flags" "Worktree"
printf '%-34s %-34s %-34s %s\n' "------" "--------" "-----" "--------"
while IFS=$'\t' read -r branch upstream flags worktree_path; do
	[ -n "$flags" ] || flags="-"
	[ -n "$worktree_path" ] || worktree_path="-"
	printf '%-34s %-34s %-34s %s\n' "$branch" "$upstream" "$flags" "$worktree_path"
done <"$GONE_FILE"

if [ "$DELETE" -ne 1 ]; then
	echo
	echo "Discovery only. Re-run with --delete --yes and the confirmed branch names after explicit confirmation."
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
	case " $flags " in
	*" invalid "*)
		echo "SKIP invalid branch name: $branch"
		skipped=$((skipped + 1))
		continue
		;;
	*" missing "*)
		echo "SKIP missing branch: $branch"
		skipped=$((skipped + 1))
		continue
		;;
	*" not-gone "*)
		echo "SKIP branch no longer has a gone upstream: $branch"
		skipped=$((skipped + 1))
		continue
		;;
	esac
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
