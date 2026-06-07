#!/usr/bin/env bash
# Experiment worktree manager for kramme:code:optimize.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize/scripts/experiment-worktree.sh
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
#
# Usage:
#   experiment-worktree.sh create <spec_name> <exp_index> <base_branch> [shared_file ...]
#   experiment-worktree.sh cleanup <spec_name> <exp_index>
#   experiment-worktree.sh cleanup-all <spec_name>
#   experiment-worktree.sh count

set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
nc='\033[0m'

git_root=$(git rev-parse --show-toplevel 2> /dev/null) || {
  echo -e "${red}Error: not in a git repository${nc}" >&2
  exit 1
}

worktree_dir="$git_root/.worktrees"

experiment_branch_name() {
  local spec_name="${1:?Error: spec_name required}"
  local padded_index="${2:?Error: padded_index required}"
  echo "optimize-exp/${spec_name}/exp-${padded_index}"
}

ensure_worktree_exclude() {
  local exclude_file
  exclude_file=$(git rev-parse --git-path info/exclude)
  mkdir -p "$(dirname "$exclude_file")"

  if ! grep -q '^\.worktrees$' "$exclude_file" 2> /dev/null; then
    echo ".worktrees" >> "$exclude_file"
  fi
}

is_registered_worktree() {
  local worktree_path="${1:?Error: worktree_path required}"
  git worktree list --porcelain | awk -v target="$worktree_path" '
    $1 == "worktree" && $2 == target { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

is_branch_checked_out() {
  local branch_name="${1:?Error: branch_name required}"
  local branch_ref="refs/heads/$branch_name"
  git worktree list --porcelain | awk -v target="$branch_ref" '
    $1 == "branch" && $2 == target { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

validate_shared_file_path() {
  local shared_file="${1:?Error: shared_file required}"

  case "$shared_file" in
    "" | /* | *"/../"* | "../"* | *"/.." | "..")
      echo -e "${red}Error: shared files must be relative paths inside the repository: $shared_file${nc}" >&2
      return 1
      ;;
  esac
}

reset_worktree_to_base() {
  local worktree_path="${1:?Error: worktree_path required}"
  local branch_name="${2:?Error: branch_name required}"
  local base_branch="${3:?Error: base_branch required}"
  local current_branch

  current_branch=$(git -C "$worktree_path" symbolic-ref --quiet --short HEAD 2> /dev/null || true)
  if [ "$current_branch" != "$branch_name" ]; then
    echo -e "${red}Error: existing worktree is on ${current_branch:-detached}, expected $branch_name${nc}" >&2
    return 1
  fi

  echo -e "${yellow}Resetting existing experiment worktree to $base_branch${nc}" >&2
  git -C "$worktree_path" reset --hard "$base_branch" > /dev/null
  git -C "$worktree_path" clean -fdx > /dev/null
}

create_worktree() {
  local spec_name="${1:?Error: spec_name required}"
  local exp_index="${2:?Error: exp_index required}"
  local base_branch="${3:?Error: base_branch required}"
  shift 3

  if [[ ! "$spec_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo -e "${red}Error: spec_name must be lowercase kebab-case: $spec_name${nc}" >&2
    return 1
  fi

  local padded_index
  padded_index=$(printf "%03d" "$exp_index")
  local worktree_name="optimize-${spec_name}-exp-${padded_index}"
  local branch_name
  branch_name=$(experiment_branch_name "$spec_name" "$padded_index")
  local worktree_path="$worktree_dir/$worktree_name"

  if [ -d "$worktree_path" ]; then
    if ! git -C "$worktree_path" rev-parse --is-inside-work-tree > /dev/null 2>&1 || ! is_registered_worktree "$worktree_path"; then
      echo -e "${red}Error: existing path is not a registered git worktree: $worktree_path${nc}" >&2
      return 1
    fi
    reset_worktree_to_base "$worktree_path" "$branch_name" "$base_branch"
  else
    mkdir -p "$worktree_dir"
    ensure_worktree_exclude

    if ! git worktree add -b "$branch_name" "$worktree_path" "$base_branch" --quiet 2> /dev/null; then
      if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        if is_branch_checked_out "$branch_name"; then
          echo -e "${red}Error: experiment branch is already checked out: $branch_name${nc}" >&2
          return 1
        fi
        git branch -f "$branch_name" "$base_branch" > /dev/null
        git worktree add "$worktree_path" "$branch_name" --quiet
      else
        echo -e "${red}Error: failed to create worktree for $branch_name from $base_branch${nc}" >&2
        return 1
      fi
    fi
  fi

  for shared_file in "$@"; do
    validate_shared_file_path "$shared_file"

    if [ -f "$git_root/$shared_file" ]; then
      mkdir -p "$(dirname "$worktree_path/$shared_file")"
      cp "$git_root/$shared_file" "$worktree_path/$shared_file"
    elif [ -d "$git_root/$shared_file" ]; then
      mkdir -p "$(dirname "$worktree_path/$shared_file")"
      rm -rf "$worktree_path/$shared_file"
      cp -R "$git_root/$shared_file" "$worktree_path/$shared_file"
    fi
  done

  echo "$worktree_path"
}

cleanup_worktree() {
  local spec_name="${1:?Error: spec_name required}"
  local exp_index="${2:?Error: exp_index required}"
  local padded_index
  padded_index=$(printf "%03d" "$exp_index")
  local worktree_name="optimize-${spec_name}-exp-${padded_index}"
  local branch_name
  branch_name=$(experiment_branch_name "$spec_name" "$padded_index")
  local worktree_path="$worktree_dir/$worktree_name"

  if [ -d "$worktree_path" ]; then
    git worktree remove "$worktree_path" --force 2> /dev/null || {
      rm -rf "$worktree_path" 2> /dev/null || true
      git worktree prune 2> /dev/null || true
    }
  fi

  git branch -D "$branch_name" 2> /dev/null || true
  echo -e "${green}Cleaned up: $worktree_name${nc}" >&2
}

cleanup_all() {
  local spec_name="${1:?Error: spec_name required}"
  local prefix="optimize-${spec_name}-exp-"
  local count=0

  if [ ! -d "$worktree_dir" ]; then
    echo -e "${yellow}No worktrees directory found${nc}" >&2
    return 0
  fi

  for worktree_path in "$worktree_dir"/${prefix}*; do
    if [ -d "$worktree_path" ]; then
      local worktree_name
      worktree_name=$(basename "$worktree_path")
      local index_str="${worktree_name#$prefix}"
      local branch_name
      branch_name=$(experiment_branch_name "$spec_name" "$index_str")

      git worktree remove "$worktree_path" --force 2> /dev/null || rm -rf "$worktree_path" 2> /dev/null || true
      git branch -D "$branch_name" 2> /dev/null || true
      count=$((count + 1))
    fi
  done

  git worktree prune 2> /dev/null || true
  if [ -d "$worktree_dir" ] && [ -z "$(ls -A "$worktree_dir" 2> /dev/null)" ]; then
    rmdir "$worktree_dir" 2> /dev/null || true
  fi

  echo -e "${green}Cleaned up $count experiment worktree(s) for $spec_name${nc}" >&2
}

count_worktrees() {
  local count=0
  if [ -d "$worktree_dir" ]; then
    for worktree_path in "$worktree_dir"/*; do
      if [ -d "$worktree_path" ] && [ -e "$worktree_path/.git" ]; then
        count=$((count + 1))
      fi
    done
  fi
  echo "$count"
}

usage() {
  cat << 'USAGE'
Experiment Worktree Manager

Usage:
  experiment-worktree.sh create <spec_name> <exp_index> <base_branch> [shared_file ...]
  experiment-worktree.sh cleanup <spec_name> <exp_index>
  experiment-worktree.sh cleanup-all <spec_name>
  experiment-worktree.sh count

Worktrees: .worktrees/optimize-<spec>-exp-<NNN>/
Branches:  optimize-exp/<spec>/exp-<NNN>
USAGE
}

main() {
  local command="${1:-help}"

  case "$command" in
    create)
      shift
      create_worktree "$@"
      ;;
    cleanup)
      shift
      cleanup_worktree "$@"
      ;;
    cleanup-all)
      shift
      cleanup_all "$@"
      ;;
    count)
      count_worktrees
      ;;
    help | --help | -h)
      usage
      ;;
    *)
      echo -e "${red}Unknown command: $command${nc}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
