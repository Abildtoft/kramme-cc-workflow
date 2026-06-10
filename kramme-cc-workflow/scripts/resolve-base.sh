#!/usr/bin/env bash
#
# Resolve a PR base ref for workflow skills.
#
# Output contract: shell-quoted KEY=VALUE lines suitable for:
#   eval "$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" ...)"
#
# Default mode is read-only except for fetching the resolved remote base.
# Recreate-commits passes --backup to enable clean-tree checks, local base
# fast-forwarding, reset-point calculation, and recovery backup creation.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

BASE_FLAG=""
AFTER_ARG=""
FETCH_MODE="strict"
BACKUP_MODE=0
FORCE_BACKUP=0

usage() {
	cat >&2 <<'USAGE'
Usage: resolve-base.sh [--base <branch-or-ref>] [--strict|--tolerate-fetch-failure] [--backup] [--after <commit>] [--force-backup]

Outputs shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE AFTER_COMMIT RESET_POINT ORIGINAL_TIP BACKUP_REF
USAGE
}

require_value() {
	local flag="$1"
	local value="${2-}"
	case "$value" in
	"" | --*)
		echo "$flag requires a value" >&2
		exit 1
		;;
	esac
}

quote_assignment() {
	local name="$1"
	local value="${2-}"
	printf '%s=%q\n' "$name" "$value"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--base)
		require_value "$1" "${2-}"
		BASE_FLAG="$2"
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
	--force-backup)
		FORCE_BACKUP=1
		shift
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

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
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

	if ! git diff --quiet || ! git diff --cached --quiet; then
		echo "Working tree has uncommitted changes; commit or stash them first" >&2
		exit 1
	fi
fi

CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD || true)
if [ "$BACKUP_MODE" -eq 1 ] && [ -z "$CURRENT_BRANCH" ]; then
	echo "HEAD is detached; switch to the feature branch first" >&2
	exit 1
fi

fetch_remote_branch() {
	local remote="$1"
	local branch="$2"
	local label="$3"
	local remote_ref="refs/remotes/${remote}/${branch}"

	if git fetch "$remote" "refs/heads/${branch}:${remote_ref}"; then
		return 0
	fi

	if [ "$FETCH_MODE" = "tolerate" ] && git rev-parse --verify --quiet "${remote_ref}^{commit}" >/dev/null; then
		echo "Warning: failed to fetch ${remote}/${branch}; using existing ${remote_ref}" >&2
		return 0
	fi

	echo "Failed to fetch ${remote}/${branch}${label:+ for $label}" >&2
	exit 1
}

remote_exists() {
	git remote get-url "$1" >/dev/null 2>&1
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
	if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
		echo "Explicit base branch '$BASE_BRANCH' is not a valid branch name" >&2
		exit 1
	fi

	fetch_remote_branch "$BASE_REMOTE" "$BASE_BRANCH" "explicit base ref '$BASE_FLAG'"
	BASE_REF="refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"
else
	if command -v gh >/dev/null 2>&1; then
		BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || true)
	fi
	if [ -z "$BASE_BRANCH" ]; then
		BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
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
	if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
		echo "Base branch '$BASE_BRANCH' is not a valid branch name" >&2
		exit 1
	fi

	fetch_remote_branch origin "$BASE_BRANCH" ""
	BASE_REF="refs/remotes/origin/${BASE_BRANCH}"
fi

if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
	echo "Base ref '$BASE_REF' does not resolve to a commit" >&2
	exit 1
fi
if [ "$BACKUP_MODE" -eq 1 ] && [ -n "$BASE_BRANCH" ] && [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
	echo "Current branch is the base branch '$BASE_BRANCH'; switch to a feature branch first" >&2
	exit 1
fi
if ! git merge-base "$BASE_REF" HEAD >/dev/null; then
	echo "No merge base between '$BASE_REF' and HEAD; histories are unrelated" >&2
	exit 1
fi
MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)

AFTER_COMMIT=""
if [ -n "$AFTER_ARG" ]; then
	if ! AFTER_COMMIT=$(git rev-parse --verify "$AFTER_ARG^{commit}" 2>/dev/null); then
		echo "--after commit '$AFTER_ARG' does not resolve" >&2
		exit 1
	fi
	if ! git merge-base --is-ancestor "$AFTER_COMMIT" HEAD; then
		echo "--after commit '$AFTER_ARG' is not an ancestor of HEAD" >&2
		exit 1
	fi
fi

RESET_POINT=""
ORIGINAL_TIP=""
BACKUP_REF=""

if [ "$BACKUP_MODE" -eq 1 ]; then
	if [ -n "$BASE_BRANCH" ] &&
		[ "$BASE_REMOTE" = "origin" ] &&
		git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}" &&
		git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
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
	ORIGINAL_TIP=$(git rev-parse HEAD)
	BACKUP_REF="${CURRENT_BRANCH}-recreate-backup"
	if git show-ref --verify --quiet "refs/heads/$BACKUP_REF"; then
		EXISTING_BACKUP_TIP=$(git rev-parse "refs/heads/$BACKUP_REF")
		if [ "$FORCE_BACKUP" -ne 1 ]; then
			echo "Backup branch '$BACKUP_REF' already exists at $EXISTING_BACKUP_TIP; refusing to move it." >&2
			echo "Inspect it with: git log --oneline --decorate -n 5 $BACKUP_REF" >&2
			echo "Recover with: git reset --hard $BACKUP_REF" >&2
			echo "After confirming it is safe to replace, rerun with --force-backup." >&2
			exit 1
		fi
		git branch -f "$BACKUP_REF" "$ORIGINAL_TIP" >/dev/null
	else
		git branch "$BACKUP_REF" "$ORIGINAL_TIP" >/dev/null
	fi
fi

quote_assignment BASE_REF "$BASE_REF"
quote_assignment BASE_BRANCH "$BASE_BRANCH"
quote_assignment MERGE_BASE "$MERGE_BASE"
quote_assignment AFTER_COMMIT "$AFTER_COMMIT"
quote_assignment RESET_POINT "$RESET_POINT"
quote_assignment ORIGINAL_TIP "$ORIGINAL_TIP"
quote_assignment BACKUP_REF "$BACKUP_REF"
