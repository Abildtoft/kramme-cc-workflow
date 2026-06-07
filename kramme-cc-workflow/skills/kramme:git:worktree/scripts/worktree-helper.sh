#!/usr/bin/env bash
# Conservative worktree helper for kramme:git:worktree.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-worktree
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage:
  worktree-helper.sh list
  worktree-helper.sh create --path <path> --branch <branch> [--base <ref>]
  worktree-helper.sh remove --path <path> --yes [--force] [--allow-conductor]

Safety:
  remove requires --yes.
  Conductor workspace paths require --allow-conductor.
USAGE
}

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

action="${1:-list}"
if [ $# -gt 0 ]; then
  shift
fi

is_conductor_path() {
  local path="$1"
  if [ -n "${CONDUCTOR_WORKSPACE_PATH:-}" ] && [ "$path" = "$CONDUCTOR_WORKSPACE_PATH" ]; then
    return 0
  fi
  case "$path" in
    */conductor/workspaces/* | */Conductor/workspaces/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_existing_path() {
  local path="$1"
  local dir
  local base
  dir=$(dirname "$path")
  base=$(basename "$path")

  if [ ! -d "$dir" ]; then
    printf '%s\n' "$path"
    return
  fi

  (
    cd "$dir"
    printf '%s/%s\n' "$(pwd -P)" "$base"
  )
}

branch_worktree_path() {
  local branch="$1"
  git worktree list --porcelain \
    | awk -v target="$branch" '
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
		'
}

default_base_ref() {
  local base=""
  base=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@' || true)
  if [ -n "$base" ] && git rev-parse --verify --quiet "origin/$base^{commit}" > /dev/null; then
    echo "origin/$base"
    return
  fi
  if git rev-parse --verify --quiet "origin/main^{commit}" > /dev/null; then
    echo "origin/main"
    return
  fi
  if git rev-parse --verify --quiet "origin/master^{commit}" > /dev/null; then
    echo "origin/master"
    return
  fi
  echo "HEAD"
}

list_worktrees() {
  git worktree list --porcelain \
    | awk '
			function flush() {
				if (path == "") {
					return
				}
				if (branch == "") {
					branch = detached
				}
				print path "\t" branch "\t" commit
				path = ""
				branch = ""
				commit = ""
				detached = "detached"
			}
			BEGIN {
				detached = "detached"
			}
			/^worktree / {
				flush()
				path = substr($0, 10)
			}
			/^HEAD / {
				commit = substr($0, 6)
			}
			/^branch refs\/heads\// {
				branch = substr($0, 19)
			}
			END {
				flush()
			}
		' \
    | while IFS=$'\t' read -r path branch commit; do
      flags="-"
      if is_conductor_path "$path"; then
        flags="conductor-workspace"
      fi
      printf '%-60s %-34s %-14s %s\n' "$path" "$branch" "${commit:0:12}" "$flags"
    done
}

case "$action" in
  list)
    printf '%-60s %-34s %-14s %s\n' "Path" "Branch" "Commit" "Flags"
    printf '%-60s %-34s %-14s %s\n' "----" "------" "------" "-----"
    list_worktrees
    ;;
  create)
    path=""
    branch=""
    base=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --path)
          path="${2:-}"
          shift
          ;;
        --branch)
          branch="${2:-}"
          shift
          ;;
        --base)
          base="${2:-}"
          shift
          ;;
        --help | -h)
          usage
          exit 0
          ;;
        *)
          echo "Unknown create argument: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
      if [ $# -gt 0 ]; then
        shift
      fi
    done
    if [ -z "$path" ] || [ -z "$branch" ]; then
      echo "create requires --path and --branch" >&2
      exit 2
    fi
    if [ -e "$path" ]; then
      echo "Refusing to create worktree at existing path: $path" >&2
      exit 1
    fi
    if ! git check-ref-format --branch "$branch" > /dev/null 2>&1; then
      echo "Invalid branch name: $branch" >&2
      exit 1
    fi
    existing_path=$(branch_worktree_path "$branch")
    if [ -n "$existing_path" ]; then
      echo "Branch '$branch' is already checked out at $existing_path" >&2
      exit 1
    fi
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git worktree add "$path" "$branch"
    else
      if [ -z "$base" ]; then
        base=$(default_base_ref)
      fi
      if ! git rev-parse --verify --quiet "$base^{commit}" > /dev/null; then
        echo "Base ref does not resolve to a commit: $base" >&2
        exit 1
      fi
      git worktree add -b "$branch" "$path" "$base"
    fi
    ;;
  remove)
    path=""
    yes=0
    force=0
    allow_conductor=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --path)
          path="${2:-}"
          shift
          ;;
        --yes | -y)
          yes=1
          ;;
        --force | -f)
          force=1
          ;;
        --allow-conductor)
          allow_conductor=1
          ;;
        --help | -h)
          usage
          exit 0
          ;;
        *)
          echo "Unknown remove argument: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
      if [ $# -gt 0 ]; then
        shift
      fi
    done
    if [ -z "$path" ]; then
      echo "remove requires --path" >&2
      exit 2
    fi
    if [ "$yes" -ne 1 ]; then
      echo "Refusing to remove worktree without --yes." >&2
      exit 1
    fi
    normalized_path=$(normalize_existing_path "$path")
    if is_conductor_path "$normalized_path" && [ "$allow_conductor" -ne 1 ]; then
      echo "Refusing to remove likely Conductor workspace without --allow-conductor: $normalized_path" >&2
      exit 1
    fi
    if [ "$force" -eq 1 ]; then
      git worktree remove --force "$normalized_path"
    else
      git worktree remove "$normalized_path"
    fi
    ;;
  --help | -h | help)
    usage
    ;;
  *)
    echo "Unknown action: $action" >&2
    usage >&2
    exit 2
    ;;
esac
