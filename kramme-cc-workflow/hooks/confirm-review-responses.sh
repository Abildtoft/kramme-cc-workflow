#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Confirm before committing review artifact files.
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "confirm-review-responses" ""
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/safety-hook-parser.sh"

ARTIFACT_LIST_FILE="${CONFIRM_REVIEW_ARTIFACT_LIST_FILE:-${CLAUDE_PLUGIN_ROOT}/hooks/confirm-review-artifacts.txt}"
COMMAND_SUBSTITUTION_TOKEN="__CMD_SUBST_"
UNSAFE_REPO_SELECTION_REASON="Unable to safely determine the git commit target because repository selection uses command substitution. Use a literal path or commit from within the target repo."
PARSE_ERROR_REASON="Unable to safely parse command. Refusing possible git commit that may stage a review artifact."
CONTEXT_DECODE_REASON="Unable to safely decode git commit context. Refusing possible commit of a review artifact."
CONTENT_SELECTION_REASON="Unable to safely inspect git commit content selection. Refusing possible commit of a review artifact."
FILTER_SELECTION_REASON="Unable to safely inspect git commit content selection because configured clean filters could execute repository-defined commands."
PYTHON_REQUIRED_REASON="confirm-review-responses hook: python3 not found; refusing to run safety hook without the shared git command parser. Install python3 or disable this hook explicitly."
REPLAY_GIT_ENV_VARS=(
  GIT_DIR
  GIT_WORK_TREE
  GIT_INDEX_FILE
  GIT_NAMESPACE
  GIT_COMMON_DIR
  GIT_OBJECT_DIRECTORY
  GIT_ALTERNATE_OBJECT_DIRECTORIES
  GIT_LITERAL_PATHSPECS
  GIT_GLOB_PATHSPECS
  GIT_NOGLOB_PATHSPECS
  GIT_ICASE_PATHSPECS
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
    GIT_DIR | GIT_WORK_TREE | GIT_INDEX_FILE | GIT_NAMESPACE | GIT_COMMON_DIR | GIT_OBJECT_DIRECTORY | GIT_ALTERNATE_OBJECT_DIRECTORIES | GIT_LITERAL_PATHSPECS | GIT_GLOB_PATHSPECS | GIT_NOGLOB_PATHSPECS | GIT_ICASE_PATHSPECS)
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
      --literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | --icase-pathspecs | --no-replace-objects)
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

context_has_config_override() {
  local arg

  for arg in "${git_prefix_args[@]}"; do
    case "$arg" in
      -c | --config-env | --config-env=*)
        return 0
        ;;
    esac
  done
  return 1
}

context_has_active_clean_filter() {
  local context_tmp_dir="$1"
  local candidate_file="$context_tmp_dir/filter-candidates"
  local attribute_file="$context_tmp_dir/filter-attributes"
  local filter_config_file="$context_tmp_dir/filter-config"
  local _ filter_driver filter_key filter_value git_status
  local configured_filter_drivers=()

  git_status=0
  run_context_git config \
    -z \
    --name-only \
    --get-regexp \
    '^filter\..*\.(clean|process)$' \
    > "$filter_config_file" || git_status=$?
  if [ "$git_status" -eq 1 ]; then
    return 1
  fi
  if [ "$git_status" -ne 0 ]; then
    return 2
  fi

  while IFS= read -r -d '' filter_key; do
    filter_driver="${filter_key#filter.}"
    case "$filter_key" in
      *.clean) filter_driver="${filter_driver%.clean}" ;;
      *.process) filter_driver="${filter_driver%.process}" ;;
      *) return 2 ;;
    esac
    if [ -n "$filter_driver" ]; then
      configured_filter_drivers+=("$filter_driver")
      safe_filter_config_args+=(
        -c "filter.${filter_driver}.process="
        -c "filter.${filter_driver}.clean=/bin/cat"
      )
    fi
  done < "$filter_config_file"
  if [ ${#configured_filter_drivers[@]} -eq 0 ]; then
    return 1
  fi

  case "$selection_mode" in
    all)
      if ! run_context_git ls-files --cached --deduplicate -z > "$candidate_file"; then
        return 2
      fi
      ;;
    include | only)
      if [ "$has_pathspec_from_file" = "true" ]; then
        # ls-files has no pathspec-from-file support. Checking every tracked
        # path is conservative while still ignoring globally configured
        # drivers that no repository path activates.
        if ! run_context_git ls-files --cached --deduplicate -z > "$candidate_file"; then
          return 2
        fi
      elif [ ${#commit_pathspecs[@]} -gt 0 ]; then
        if ! run_context_git ls-files \
          --cached \
          --deduplicate \
          -z \
          -- \
          "${commit_pathspecs[@]}" \
          > "$candidate_file"; then
          return 2
        fi
      else
        : > "$candidate_file"
      fi
      ;;
    *) return 2 ;;
  esac

  if [ ! -s "$candidate_file" ]; then
    return 1
  fi
  if ! run_context_git check-attr \
    -z \
    --stdin \
    filter \
    < "$candidate_file" \
    > "$attribute_file"; then
    return 2
  fi

  while IFS= read -r -d '' _ &&
    IFS= read -r -d '' _ &&
    IFS= read -r -d '' filter_value; do
    for filter_driver in "${configured_filter_drivers[@]}"; do
      if [ "$filter_value" = "$filter_driver" ]; then
        return 0
      fi
    done
  done < "$attribute_file"

  return 1
}

run_context_git() {
  git \
    --no-pager \
    "${safe_git_prefix_args[@]}" \
    -c core.fsmonitor=false \
    -c core.hooksPath=/dev/null \
    "${safe_filter_config_args[@]}" \
    "$@"
}

write_effective_files_for_commit_context() {
  local output_file="$1"
  local context_tmp_dir="$2"
  local assignment original_index original_object_directory original_alternates
  local base_tree selected_tree final_tree filter_status
  local object_directory="$context_tmp_dir/objects"
  local work_index="$context_tmp_dir/work.index"
  local final_index="$context_tmp_dir/final.index"
  local safe_filter_config_args=()
  local selection_args=()

  # Reconstruct only repo/index selection and inert pathspec modifiers.
  # Config-bearing prefixes are never replayed because Git config can name
  # commands such as fsmonitor and clean filters.
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
    export GIT_OPTIONAL_LOCKS=0

    if [ "$selection_mode" = "index" ]; then
      run_context_git diff \
        --cached \
        --name-only \
        -z \
        --no-ext-diff \
        --no-textconv \
        --no-renames \
        > "$output_file"
      exit $?
    fi

    if context_has_config_override; then
      echo "$CONTENT_SELECTION_REASON Config-bearing git prefixes are unsupported for worktree selection." >&2
      exit 1
    fi

    if ! original_index="$(
      run_context_git rev-parse --path-format=absolute --git-path index
    )"; then
      exit 1
    fi
    if [ -f "$original_index" ]; then
      if ! cp "$original_index" "$work_index"; then
        exit 1
      fi
    elif [ -e "$original_index" ]; then
      exit 1
    fi
    export GIT_INDEX_FILE="$work_index"

    context_has_active_clean_filter "$context_tmp_dir"
    filter_status=$?
    if [ "$filter_status" -eq 0 ]; then
      echo "$FILTER_SELECTION_REASON" >&2
      exit 1
    fi
    if [ "$filter_status" -ne 1 ]; then
      exit "$filter_status"
    fi

    if ! original_object_directory="$(
      run_context_git rev-parse --path-format=absolute --git-path objects
    )"; then
      exit 1
    fi
    original_alternates="${GIT_ALTERNATE_OBJECT_DIRECTORIES:-}"
    if ! mkdir -p "$object_directory"; then
      exit 1
    fi
    export GIT_OBJECT_DIRECTORY="$object_directory"
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$original_object_directory${original_alternates:+:$original_alternates}"

    if ! base_tree="$(run_context_git rev-parse --verify 'HEAD^{tree}' 2> /dev/null)"; then
      if ! base_tree="$(run_context_git mktree < /dev/null)"; then
        exit 1
      fi
    fi

    case "$selection_mode" in
      all)
        if ! run_context_git add -u; then
          exit 1
        fi
        ;;
      include | only)
        if [ "$has_pathspec_from_file" = "true" ]; then
          selection_args=("-u" "--pathspec-from-file=$pathspec_from_file")
          if [ "$pathspec_file_nul" = "true" ]; then
            selection_args+=("--pathspec-file-nul")
          fi
        elif [ ${#commit_pathspecs[@]} -gt 0 ]; then
          selection_args=("-u" "--" "${commit_pathspecs[@]}")
        fi
        if [ ${#selection_args[@]} -gt 0 ] && ! run_context_git add "${selection_args[@]}"; then
          exit 1
        fi
        ;;
      *)
        echo "$CONTENT_SELECTION_REASON Unsupported selection mode: $selection_mode." >&2
        exit 1
        ;;
    esac

    if ! selected_tree="$(run_context_git write-tree)"; then
      exit 1
    fi
    final_tree="$selected_tree"

    if [ "$selection_mode" = "only" ]; then
      export GIT_INDEX_FILE="$final_index"
      if ! run_context_git read-tree "$base_tree"; then
        exit 1
      fi
      if [ "$has_pathspec_from_file" = "true" ]; then
        selection_args=("--pathspec-from-file=$pathspec_from_file")
        if [ "$pathspec_file_nul" = "true" ]; then
          selection_args+=("--pathspec-file-nul")
        fi
        if ! run_context_git reset -q --no-refresh "${selection_args[@]}" "$selected_tree"; then
          exit 1
        fi
      elif [ ${#commit_pathspecs[@]} -gt 0 ]; then
        if ! run_context_git reset -q --no-refresh "$selected_tree" -- "${commit_pathspecs[@]}"; then
          exit 1
        fi
      fi
      if ! final_tree="$(run_context_git write-tree)"; then
        exit 1
      fi
    fi

    run_context_git diff-tree \
      --no-commit-id \
      --name-only \
      --no-ext-diff \
      --no-textconv \
      --no-renames \
      -r \
      -z \
      "$base_tree" \
      "$final_tree" \
      > "$output_file"
  )
}

# Only check git commit commands. Shell/git command parsing is centralized in
# git_command_parser.py; this hook inspects the effective content selected by
# each returned commit context.
if ! commit_contexts="$(
  run_safety_hook_parser "confirm-review-responses" "commit-contexts" "$PYTHON_REQUIRED_REASON" "$PARSE_ERROR_REASON"
)"; then
  exit 2
fi
if ! expected_context_count="$(printf '%s\n' "$commit_contexts" | jq -er 'length')"; then
  echo "$CONTEXT_DECODE_REASON" >&2
  exit 2
fi
if [ "$expected_context_count" -eq 0 ]; then
  exit 0
fi

if ! hook_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/confirm-review-responses.XXXXXX")"; then
  echo "$CONTEXT_DECODE_REASON" >&2
  exit 2
fi
cleanup_hook_tmp_dir() {
  rm -rf -- "$hook_tmp_dir"
}
trap cleanup_hook_tmp_dir EXIT

contexts_file="$hook_tmp_dir/contexts.jsonl"
if ! printf '%s\n' "$commit_contexts" | jq -c '.[]' > "$contexts_file"; then
  echo "$CONTEXT_DECODE_REASON" >&2
  exit 2
fi

# Check the effective commit set for configured artifact files.
configured_artifacts="$(load_artifact_list "$ARTIFACT_LIST_FILE")"
blocked_files=()
decoded_context_count=0

while IFS= read -r commit_context_json; do
  [ -z "$commit_context_json" ] && continue
  decoded_context_count=$((decoded_context_count + 1))

  if ! printf '%s\n' "$commit_context_json" | jq -e '
    type == "object" and
    ((.git_args // []) | type == "array" and all(.[]; type == "string")) and
    ((.git_env // []) | type == "array" and all(.[]; type == "string")) and
    ((.pathspecs // []) | type == "array" and all(.[]; type == "string")) and
    ((.selection_mode // "index") | type == "string") and
    ((.pathspec_from_file // "") | type == "string") and
    ((.pathspec_file_nul // false) | type == "boolean") and
    ((.selection_error // "") | type == "string") and
    ((.parse_error // "") | type == "string")
  ' > /dev/null; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi

  if ! parse_error_reason="$(printf '%s\n' "$commit_context_json" | jq -er '.parse_error // ""')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  if [ -n "$parse_error_reason" ]; then
    echo "$parse_error_reason" >&2
    exit 2
  fi
  if ! selection_error_reason="$(printf '%s\n' "$commit_context_json" | jq -er '.selection_error // ""')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  if [ -n "$selection_error_reason" ]; then
    echo "$selection_error_reason" >&2
    exit 2
  fi
  if ! selection_mode="$(printf '%s\n' "$commit_context_json" | jq -er '.selection_mode // "index"')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  case "$selection_mode" in
    index | all | include | only) ;;
    *)
      echo "$CONTENT_SELECTION_REASON" >&2
      exit 2
      ;;
  esac
  if ! has_pathspec_from_file="$(printf '%s\n' "$commit_context_json" | jq -r 'has("pathspec_from_file")')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  pathspec_from_file=""
  if [ "$has_pathspec_from_file" = "true" ]; then
    if ! pathspec_from_file="$(printf '%s\n' "$commit_context_json" | jq -er '.pathspec_from_file')"; then
      echo "$CONTEXT_DECODE_REASON" >&2
      exit 2
    fi
  fi
  if ! pathspec_file_nul="$(printf '%s\n' "$commit_context_json" | jq -r '.pathspec_file_nul // false')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi

  git_prefix_args=()
  git_args_file="$hook_tmp_dir/git-args-$decoded_context_count.jsonl"
  if ! expected_git_arg_count="$(printf '%s\n' "$commit_context_json" | jq -er '(.git_args // []) | length')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  if ! printf '%s\n' "$commit_context_json" | jq -c '(.git_args // [])[]' > "$git_args_file"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  decoded_git_arg_count=0
  while IFS= read -r git_arg_json; do
    [ -z "$git_arg_json" ] && continue
    if ! decoded_git_arg="$(printf '%s\n' "$git_arg_json" | jq -er 'if type == "string" then . else error("expected string") end')"; then
      echo "$CONTEXT_DECODE_REASON" >&2
      exit 2
    fi
    git_prefix_args+=("$decoded_git_arg")
    decoded_git_arg_count=$((decoded_git_arg_count + 1))
  done < "$git_args_file"
  if [ "$decoded_git_arg_count" -ne "$expected_git_arg_count" ]; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi

  git_env_assignments=()
  git_env_file="$hook_tmp_dir/git-env-$decoded_context_count.jsonl"
  if ! expected_git_env_count="$(printf '%s\n' "$commit_context_json" | jq -er '(.git_env // []) | length')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  if ! printf '%s\n' "$commit_context_json" | jq -c '(.git_env // [])[]' > "$git_env_file"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  decoded_git_env_count=0
  while IFS= read -r git_env_json; do
    [ -z "$git_env_json" ] && continue
    if ! decoded_git_env="$(printf '%s\n' "$git_env_json" | jq -er 'if type == "string" then . else error("expected string") end')"; then
      echo "$CONTEXT_DECODE_REASON" >&2
      exit 2
    fi
    git_env_assignments+=("$decoded_git_env")
    decoded_git_env_count=$((decoded_git_env_count + 1))
  done < "$git_env_file"
  if [ "$decoded_git_env_count" -ne "$expected_git_env_count" ]; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi

  commit_pathspecs=()
  pathspecs_file="$hook_tmp_dir/pathspecs-$decoded_context_count.jsonl"
  if ! expected_pathspec_count="$(printf '%s\n' "$commit_context_json" | jq -er '(.pathspecs // []) | length')"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  if ! printf '%s\n' "$commit_context_json" | jq -c '(.pathspecs // [])[]' > "$pathspecs_file"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi
  decoded_pathspec_count=0
  while IFS= read -r pathspec_json; do
    [ -z "$pathspec_json" ] && continue
    if ! decoded_pathspec="$(printf '%s\n' "$pathspec_json" | jq -er 'if type == "string" then . else error("expected string") end')"; then
      echo "$CONTEXT_DECODE_REASON" >&2
      exit 2
    fi
    commit_pathspecs+=("$decoded_pathspec")
    decoded_pathspec_count=$((decoded_pathspec_count + 1))
  done < "$pathspecs_file"
  if [ "$decoded_pathspec_count" -ne "$expected_pathspec_count" ]; then
    echo "$CONTEXT_DECODE_REASON" >&2
    exit 2
  fi

  if context_has_dynamic_repo_selection; then
    echo "$UNSAFE_REPO_SELECTION_REASON" >&2
    exit 2
  fi

  context_tmp_dir="$hook_tmp_dir/context-$decoded_context_count"
  effective_files_file="$context_tmp_dir/effective-files"
  if ! mkdir -p "$context_tmp_dir"; then
    echo "$CONTENT_SELECTION_REASON" >&2
    exit 2
  fi
  if ! write_effective_files_for_commit_context "$effective_files_file" "$context_tmp_dir"; then
    echo "$CONTENT_SELECTION_REASON" >&2
    exit 2
  fi

  while IFS= read -r -d '' effective_file; do
    [ -z "$effective_file" ] && continue
    while IFS= read -r artifact; do
      [ -z "$artifact" ] && continue
      if matches_artifact "$effective_file" "$artifact"; then
        blocked_files+=("$effective_file")
        break
      fi
    done <<< "$configured_artifacts"
  done < "$effective_files_file"
done < "$contexts_file"

if [ "$decoded_context_count" -ne "$expected_context_count" ]; then
  echo "$CONTEXT_DECODE_REASON" >&2
  exit 2
fi

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
