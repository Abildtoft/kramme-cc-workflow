#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Confirm before committing review artifact files.
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses" ""

if ! command -v jq > /dev/null 2>&1; then
  echo "confirm-review-responses hook: jq not found; refusing to run safety hook without JSON parsing. Install jq or disable this hook explicitly." >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi

ARTIFACT_LIST_FILE="${CONFIRM_REVIEW_ARTIFACT_LIST_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/confirm-review-artifacts.txt}"
COMMAND_SUBSTITUTION_TOKEN="__CMD_SUBST_"
UNSAFE_REPO_SELECTION_REASON="Unable to safely determine the git commit target because repository selection uses command substitution. Use a literal path or commit from within the target repo."
PARSE_ERROR_REASON="Unable to safely parse command. Refusing possible git commit that may stage a review artifact."
PYTHON_REQUIRED_REASON="confirm-review-responses hook: python3 not found; refusing to run safety hook without the shared git command parser. Install python3 or disable this hook explicitly."
REPLAY_GIT_ENV_VARS=(
  GIT_DIR
  GIT_WORK_TREE
  GIT_INDEX_FILE
  GIT_NAMESPACE
  GIT_COMMON_DIR
  GIT_OBJECT_DIRECTORY
  GIT_ALTERNATE_OBJECT_DIRECTORIES
)

load_artifact_list() {
  local list_file="$1"
  local artifact_list=()
  local line

  if [ -f "$list_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line=$(echo "$line" | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//')
      [ -z "$line" ] && continue
      artifact_list+=("$line")
    done < "$list_file"
  fi

  # Safe fallback when list file is missing/empty.
  if [ ${#artifact_list[@]} -eq 0 ]; then
    artifact_list=("REVIEW_OVERVIEW.md")
  fi

  printf '%s\n' "${artifact_list[@]}"
}

matches_artifact() {
  local staged_file="$1"
  local artifact="$2"

  # Artifact entries are shell-style globs.
  # Basename patterns (e.g. REVIEW_OVERVIEW.md, PR_PLAN_*.md) match any folder.
  # Path patterns (e.g. siw/LOG.md) match exact/suffix paths.
  # shellcheck disable=SC2254
  # Artifact entries intentionally support shell-style globs.
  case "$staged_file" in
    $artifact | */$artifact)
      return 0
      ;;
  esac
  return 1
}

should_replay_git_env() {
  case "$1" in
    GIT_DIR | GIT_WORK_TREE | GIT_INDEX_FILE | GIT_NAMESPACE | GIT_COMMON_DIR | GIT_OBJECT_DIRECTORY | GIT_ALTERNATE_OBJECT_DIRECTORIES)
      return 0
      ;;
  esac
  return 1
}

build_safe_git_prefix_args() {
  safe_git_prefix_args=()
  local value

  while [ $# -gt 0 ]; do
    value="$1"
    case "$value" in
      -C | --git-dir | --work-tree | --namespace)
        safe_git_prefix_args+=("$value")
        shift
        if [ $# -gt 0 ]; then
          safe_git_prefix_args+=("$1")
          shift
        fi
        ;;
      --git-dir=* | --work-tree=* | --namespace=*)
        safe_git_prefix_args+=("$value")
        shift
        ;;
      -C*)
        safe_git_prefix_args+=("-C" "${value#-C}")
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

contains_command_substitution_token() {
  case "$1" in
    *"$COMMAND_SUBSTITUTION_TOKEN"*)
      return 0
      ;;
  esac
  return 1
}

context_has_dynamic_repo_selection() {
  # Any prefix arg that still carries a command-substitution placeholder
  # would be expanded by git when we replay it (see also git -c
  # core.fsmonitor=$(...) which achieves RCE). Refuse to replay such
  # args regardless of which flag they sit behind.
  local arg assignment key value
  if [ ${#git_prefix_args[@]} -gt 0 ]; then
    for arg in "${git_prefix_args[@]}"; do
      if contains_command_substitution_token "$arg"; then
        return 0
      fi
    done
  fi

  if [ ${#git_env_assignments[@]} -gt 0 ]; then
    for assignment in "${git_env_assignments[@]}"; do
      key="${assignment%%=*}"
      value="${assignment#*=}"
      if should_replay_git_env "$key" && contains_command_substitution_token "$value"; then
        return 0
      fi
    done
  fi

  return 1
}

list_staged_files_for_commit_context() {
  local assignment

  # Reconstruct only repo/index selection. Replaying config-bearing git
  # prefixes like `-c` or `--config-env` would execute attacker-controlled
  # commands while we inspect the index.
  if [ ${#git_prefix_args[@]} -gt 0 ]; then
    build_safe_git_prefix_args "${git_prefix_args[@]}"
  else
    build_safe_git_prefix_args
  fi

  (
    unset "${REPLAY_GIT_ENV_VARS[@]}"
    unset GIT_EXTERNAL_DIFF GIT_PAGER PAGER
    if [ ${#git_env_assignments[@]} -gt 0 ]; then
      for assignment in "${git_env_assignments[@]}"; do
        export "${assignment?}"
      done
    fi
    if [ ${#safe_git_prefix_args[@]} -gt 0 ]; then
      git --no-pager "${safe_git_prefix_args[@]}" -c core.fsmonitor=false diff --cached --name-only --no-ext-diff
    else
      git --no-pager -c core.fsmonitor=false diff --cached --name-only --no-ext-diff
    fi
  )
}

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command.
[ -z "$command" ] && exit 0

if ! command -v python3 > /dev/null 2>&1; then
  echo "$PYTHON_REQUIRED_REASON" >&2
  exit 2
fi

# Only check git commit commands. Shell/git command parsing is centralized in
# git_command_parser.py; this hook only inspects staged artifacts for returned
# commit contexts.
if ! commit_contexts="$(
  python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git_command_parser.py" commit-contexts "$command" "$PARSE_ERROR_REASON"
)"; then
  echo "$PARSE_ERROR_REASON" >&2
  exit 2
fi
if ! commit_context_count="$(printf '%s\n' "$commit_contexts" | jq -e 'if type == "array" then length else error("expected commit context array") end')"; then
  echo "$PARSE_ERROR_REASON" >&2
  exit 2
fi
if [ "$commit_context_count" -eq 0 ]; then
  exit 0
fi

# Check if configured artifact files are staged.
configured_artifacts="$(load_artifact_list "$ARTIFACT_LIST_FILE")"
blocked_files=()

while IFS= read -r commit_context_json; do
  [ -z "$commit_context_json" ] && continue

  parse_error_reason="$(printf '%s\n' "$commit_context_json" | jq -r '.parse_error // empty')"
  if [ -n "$parse_error_reason" ]; then
    echo "$parse_error_reason" >&2
    exit 2
  fi

  git_prefix_args=()
  while IFS= read -r git_arg_json; do
    git_prefix_args+=("$(printf '%s\n' "$git_arg_json" | jq -r '.')")
  done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_args[]?')

  git_env_assignments=()
  while IFS= read -r git_env_json; do
    git_env_assignments+=("$(printf '%s\n' "$git_env_json" | jq -r '.')")
  done < <(printf '%s\n' "$commit_context_json" | jq -c '.git_env[]?')

  if context_has_dynamic_repo_selection; then
    echo "$UNSAFE_REPO_SELECTION_REASON" >&2
    exit 2
  fi

  staged_files="$(
    # Leave stderr on the hook's stderr so the user sees git's own
    # diagnostic. We then fail closed based on the exit status.
    list_staged_files_for_commit_context
  )"
  diff_exit_status=$?
  if [ "$diff_exit_status" -ne 0 ]; then
    # Can't confirm the artifact is not staged, so fail closed.
    echo "Unable to inspect staged files (git diff --cached exited $diff_exit_status). Refusing possible commit of a review artifact." >&2
    exit 2
  fi

  if [ -n "$staged_files" ]; then
    while IFS= read -r staged_file; do
      [ -z "$staged_file" ] && continue
      while IFS= read -r artifact; do
        [ -z "$artifact" ] && continue
        if matches_artifact "$staged_file" "$artifact"; then
          blocked_files+=("$staged_file")
          break
        fi
      done <<< "$configured_artifacts"
    done <<< "$staged_files"
  fi
done < <(echo "$commit_contexts" | jq -c '.[]')

if [ ${#blocked_files[@]} -gt 0 ]; then
  deduped_blocked_files=()
  for blocked_file in "${blocked_files[@]}"; do
    already_seen=false
    if [ ${#deduped_blocked_files[@]} -gt 0 ]; then
      for existing_blocked_file in "${deduped_blocked_files[@]}"; do
        if [ "$existing_blocked_file" = "$blocked_file" ]; then
          already_seen=true
          break
        fi
      done
    fi
    if [ "$already_seen" != "true" ]; then
      deduped_blocked_files+=("$blocked_file")
    fi
  done
  blocked_files=()
  if [ ${#deduped_blocked_files[@]} -gt 0 ]; then
    blocked_files=("${deduped_blocked_files[@]}")
  fi

  blocked_file_list=$(
    IFS=', '
    echo "${blocked_files[*]}"
  )
  config_path_display="$ARTIFACT_LIST_FILE"
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    config_path_display="${ARTIFACT_LIST_FILE#${CLAUDE_PLUGIN_ROOT}/}"
  fi

  echo "Review artifact file(s) staged for commit: $blocked_file_list. Please confirm you want to include these files. Configure this list in $config_path_display." >&2
  exit 2
fi

exit 0
