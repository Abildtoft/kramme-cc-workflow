#!/usr/bin/env bash
# Resolve and validate the base ref for kramme:git:recreate-commits.
#
# Usage: resolve-base.sh [--base <ref>] [--after <commit>] [--force-backup]
#
# On success, prints the resolved values as shell-quoted KEY=VALUE lines to
# stdout (consume with `eval "$(resolve-base.sh ...)"`):
#   BASE_REF       resolved, validated base ref
#   BASE_BRANCH    short base branch name (empty for non-branch refs)
#   MERGE_BASE     merge base of BASE_REF and HEAD
#   AFTER_COMMIT   resolved --after commit (empty when --after not given)
#   RESET_POINT    where the branch is reset to (AFTER_COMMIT or MERGE_BASE)
#   ORIGINAL_TIP   HEAD before any reset — the byte-identical target end state
#   BACKUP_REF     recovery branch created at ORIGINAL_TIP
#
# Side effects: fetches the base branch, fast-forwards a matching local base
# branch to its remote, and creates the recovery backup branch. Aborts with a
# message on stderr (non-zero exit) if any precondition fails. Refuses to run
# on a dirty tree before mutating any branch state.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
BASE_FLAG=""
AFTER_ARG=""
FORCE_BACKUP=0
while [ $# -gt 0 ]; do
	case "$1" in
	--base)
		if [ $# -lt 2 ]; then
			echo "--base requires a ref value" >&2
			exit 1
		fi
		BASE_FLAG="$2"
		shift 2
		;;
	--after)
		if [ $# -lt 2 ]; then
			echo "--after requires a commit value" >&2
			exit 1
		fi
		AFTER_ARG="$2"
		shift 2
		;;
	--force-backup)
		FORCE_BACKUP=1
		shift
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
done

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
	echo "Not inside a git repository; run from the user's repo, not the skill directory" >&2
	exit 1
fi
REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P)
if [ "$SCRIPT_DIR" = "$REPO_ROOT" ] || [[ "$SCRIPT_DIR" == "$REPO_ROOT"/* ]]; then
	echo "Refusing to run against the repository that contains this skill script." >&2
	echo 'Run from the user repository with "$SKILL_DIR/scripts/resolve-base.sh"; do not cd into the skill directory.' >&2
	exit 1
fi

# Refuse to run on a dirty tree before touching any branch state.
if ! git diff --quiet || ! git diff --cached --quiet; then
	echo "Working tree has uncommitted changes; commit or stash them first" >&2
	exit 1
fi

CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD || true)
if [ -z "$CURRENT_BRANCH" ]; then
	echo "HEAD is detached; switch to the feature branch first" >&2
	exit 1
fi

BASE_BRANCH=""
if [ -n "$BASE_FLAG" ]; then
	# Explicit --base: resolve it locally, falling back to a remote fetch.
	BASE_REF="$BASE_FLAG"
	if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
		case "$BASE_REF" in
		refs/remotes/*/*)
			BASE_REMOTE=${BASE_REF#refs/remotes/}
			BASE_REMOTE=${BASE_REMOTE%%/*}
			BASE_BRANCH=${BASE_REF#refs/remotes/${BASE_REMOTE}/}
			;;
		refs/heads/*)
			BASE_REMOTE=origin
			BASE_BRANCH=${BASE_REF#refs/heads/}
			;;
		*/*)
			BASE_REMOTE=${BASE_REF%%/*}
			BASE_BRANCH=${BASE_REF#*/}
			if ! git remote get-url "$BASE_REMOTE" >/dev/null 2>&1; then
				echo "Explicit base ref '$BASE_REF' does not resolve locally and does not name a configured remote" >&2
				exit 1
			fi
			;;
		*)
			BASE_REMOTE=origin
			BASE_BRANCH=$BASE_REF
			;;
		esac
		if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
			echo "Explicit base ref '$BASE_REF' is not a valid branch name or ref" >&2
			exit 1
		fi
		if ! git fetch "$BASE_REMOTE" "refs/heads/${BASE_BRANCH}:refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"; then
			echo "Failed to fetch ${BASE_REMOTE}/${BASE_BRANCH} for explicit base ref '$BASE_REF'" >&2
			exit 1
		fi
		BASE_REF="refs/remotes/${BASE_REMOTE}/${BASE_BRANCH}"
	fi
else
	# No --base: try PR metadata, then origin/HEAD, then origin/main|master.
	BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || true)
	if [ -z "$BASE_BRANCH" ]; then
		BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
	fi
	if [ -z "$BASE_BRANCH" ]; then
		BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@' || true)
	fi
	if [ -z "$BASE_BRANCH" ]; then
		echo "Could not determine base branch; expected origin/HEAD, origin/main, or origin/master" >&2
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
	if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"; then
		echo "Failed to fetch origin/$BASE_BRANCH" >&2
		exit 1
	fi
	BASE_REF="origin/$BASE_BRANCH"
fi

# Validate the resolved base ref regardless of how it was determined.
if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
	echo "Base ref '$BASE_REF' does not resolve to a commit" >&2
	exit 1
fi
if [ -n "$BASE_BRANCH" ] && [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
	echo "Current branch is the base branch '$BASE_BRANCH'; switch to a feature branch first" >&2
	exit 1
fi
if ! git merge-base "$BASE_REF" HEAD >/dev/null; then
	echo "No merge base between '$BASE_REF' and HEAD; histories are unrelated" >&2
	exit 1
fi
MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)

# Validate --after, if provided.
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

# Fast-forward a matching local base branch to its remote, without switching
# branches. Abort if the local base has diverged (non-fast-forward).
if [ -n "$BASE_BRANCH" ] &&
	{ [ "$BASE_REF" = "origin/$BASE_BRANCH" ] || [ "$BASE_REF" = "refs/remotes/origin/$BASE_BRANCH" ]; } &&
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

# Reset point and recovery backup, captured before anything destructive runs.
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

printf 'BASE_REF=%q\n' "$BASE_REF"
printf 'BASE_BRANCH=%q\n' "$BASE_BRANCH"
printf 'MERGE_BASE=%q\n' "$MERGE_BASE"
printf 'AFTER_COMMIT=%q\n' "$AFTER_COMMIT"
printf 'RESET_POINT=%q\n' "$RESET_POINT"
printf 'ORIGINAL_TIP=%q\n' "$ORIGINAL_TIP"
printf 'BACKUP_REF=%q\n' "$BACKUP_REF"
