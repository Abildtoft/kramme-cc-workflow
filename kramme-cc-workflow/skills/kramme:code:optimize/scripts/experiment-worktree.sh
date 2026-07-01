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

validate_spec_name() {
  local spec_name="${1:?Error: spec_name required}"

  if [[ ! "$spec_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo -e "${red}Error: spec_name must be lowercase kebab-case: $spec_name${nc}" >&2
    return 1
  fi
}

validate_exp_index() {
  local exp_index="${1:?Error: exp_index required}"

  if [[ ! "$exp_index" =~ ^[0-9]+$ ]]; then
    echo -e "${red}Error: exp_index must be a nonnegative integer: $exp_index${nc}" >&2
    return 1
  fi
}

format_exp_index() {
  local exp_index="${1:?Error: exp_index required}"
  validate_exp_index "$exp_index" || return 1

  local normalized="$exp_index"
  while [[ "$normalized" == 0* && "${#normalized}" -gt 1 ]]; do
    normalized="${normalized#0}"
  done

  case "${#normalized}" in
    1)
      echo "00$normalized"
      ;;
    2)
      echo "0$normalized"
      ;;
    *)
      echo "$normalized"
      ;;
  esac
}

experiment_branch_name() {
  local spec_name="${1:?Error: spec_name required}"
  local padded_index="${2:?Error: padded_index required}"
  echo "optimize-exp/${spec_name}/exp-${padded_index}"
}

experiment_worktree_name() {
  local spec_name="${1:?Error: spec_name required}"
  local padded_index="${2:?Error: padded_index required}"
  echo "optimize-${spec_name}-exp-${padded_index}"
}

is_expected_experiment_worktree_name() {
  local spec_name="${1:?Error: spec_name required}"
  local worktree_name="${2:?Error: worktree_name required}"
  local prefix="optimize-${spec_name}-exp-"
  local index_str

  if [[ "$worktree_name" != "$prefix"* ]]; then
    return 1
  fi

  index_str="${worktree_name#$prefix}"
  [[ "$index_str" =~ ^[0-9]{3,}$ ]]
}

validate_cleanup_worktree_path() {
  local worktree_path="${1:?Error: worktree_path required}"
  local spec_name="${2:?Error: spec_name required}"
  local worktree_name="${worktree_path##*/}"

  if [ "$worktree_path" != "$worktree_dir/$worktree_name" ]; then
    echo -e "${red}Error: cleanup path must be a direct child of $worktree_dir: $worktree_path${nc}" >&2
    return 1
  fi

  if ! is_expected_experiment_worktree_name "$spec_name" "$worktree_name"; then
    echo -e "${red}Error: cleanup path does not match optimize-${spec_name}-exp-<NNN>: $worktree_path${nc}" >&2
    return 1
  fi
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
    $1 == "worktree" {
      path = substr($0, 10)
      if (path == target) {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  '
}

is_branch_checked_out() {
  local branch_name="${1:?Error: branch_name required}"
  local branch_ref="refs/heads/$branch_name"
  git worktree list --porcelain | awk -v target="$branch_ref" '
    $1 == "branch" {
      branch = substr($0, 8)
      if (branch == target) {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  '
}

registered_experiment_worktrees() {
  local spec_name="${1:?Error: spec_name required}"
  local prefix="optimize-${spec_name}-exp-"

  git worktree list --porcelain | awk -v root="$worktree_dir" -v prefix="$prefix" '
    $1 == "worktree" {
      path = substr($0, 10)
      name = path
      sub(/^.*\//, "", name)

      if (path == root "/" name && index(name, prefix) == 1) {
        index_str = substr(name, length(prefix) + 1)
        if (index_str ~ /^[0-9][0-9][0-9][0-9]*$/) {
          print path
        }
      }
    }
  '
}

remove_registered_worktree() {
  local worktree_path="${1:?Error: worktree_path required}"
  local branch_name="${2:?Error: branch_name required}"
  local spec_name="${3:?Error: spec_name required}"

  validate_cleanup_worktree_path "$worktree_path" "$spec_name" || return 1

  if ! is_registered_worktree "$worktree_path"; then
    echo -e "${red}Error: cleanup target is not a registered git worktree: $worktree_path${nc}" >&2
    return 1
  fi

  if ! git worktree remove "$worktree_path" --force; then
    echo -e "${red}Error: failed to remove registered worktree: $worktree_path${nc}" >&2
    return 1
  fi

  git branch -D "$branch_name" > /dev/null 2>&1 || true
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

  validate_spec_name "$spec_name" || return 1

  local padded_index
  padded_index=$(format_exp_index "$exp_index") || return 1
  local worktree_name
  worktree_name=$(experiment_worktree_name "$spec_name" "$padded_index")
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
      if [ -e "$worktree_path/$shared_file" ] && [ ! -d "$worktree_path/$shared_file" ]; then
        echo -e "${red}Error: shared directory target exists and is not a directory: $shared_file${nc}" >&2
        return 1
      fi
      mkdir -p "$worktree_path/$shared_file"
      cp -R "$git_root/$shared_file/." "$worktree_path/$shared_file/"
    fi
  done

  echo "$worktree_path"
}

cleanup_worktree() {
  local spec_name="${1:?Error: spec_name required}"
  local exp_index="${2:?Error: exp_index required}"
  validate_spec_name "$spec_name" || return 1

  local padded_index
  padded_index=$(format_exp_index "$exp_index") || return 1
  local worktree_name
  worktree_name=$(experiment_worktree_name "$spec_name" "$padded_index")
  local branch_name
  branch_name=$(experiment_branch_name "$spec_name" "$padded_index")
  local worktree_path="$worktree_dir/$worktree_name"

  validate_cleanup_worktree_path "$worktree_path" "$spec_name" || return 1

  if is_registered_worktree "$worktree_path"; then
    remove_registered_worktree "$worktree_path" "$branch_name" "$spec_name" || return 1
  elif [ -e "$worktree_path" ]; then
    echo -e "${red}Error: cleanup target exists but is not a registered git worktree: $worktree_path${nc}" >&2
    return 1
  else
    git branch -D "$branch_name" > /dev/null 2>&1 || true
  fi

  echo -e "${green}Cleaned up: $worktree_name${nc}" >&2
}

cleanup_all() {
  local spec_name="${1:?Error: spec_name required}"
  validate_spec_name "$spec_name" || return 1

  local prefix="optimize-${spec_name}-exp-"
  local count=0

  if [ ! -d "$worktree_dir" ]; then
    echo -e "${yellow}No worktrees directory found${nc}" >&2
    return 0
  fi

  while IFS= read -r worktree_path; do
    [ -n "$worktree_path" ] || continue

    local worktree_name
    worktree_name=$(basename "$worktree_path")
    validate_cleanup_worktree_path "$worktree_path" "$spec_name" || return 1

    local index_str="${worktree_name#$prefix}"
    local branch_name
    branch_name=$(experiment_branch_name "$spec_name" "$index_str")

    remove_registered_worktree "$worktree_path" "$branch_name" "$spec_name" || return 1
    count=$((count + 1))
  done < <(registered_experiment_worktrees "$spec_name")

  git worktree prune 2> /dev/null || true

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
