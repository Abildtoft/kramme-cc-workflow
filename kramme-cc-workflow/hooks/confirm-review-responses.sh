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
CONTEXT_SCHEMA_REASON="$CONTEXT_DECODE_REASON Parser output does not match the commit-context field contract."
CONTEXT_NUL_REASON="$CONTEXT_DECODE_REASON A commit-context value carries a NUL byte, which no git argument can hold."
CONTEXT_TRUNCATED_REASON="$CONTEXT_DECODE_REASON Decoded commit contexts ended before the parser's context count."
CONTEXT_FRAMING_REASON="$CONTEXT_DECODE_REASON Decoded commit contexts are missing their end marker."
CONTEXT_WORKSPACE_REASON="$CONTEXT_DECODE_REASON Unable to create a private workspace for commit inspection."
CONTENT_SELECTION_REASON="Unable to safely inspect git commit content selection. Refusing possible commit of a review artifact."
FILTER_SELECTION_REASON="Unable to safely inspect git commit content selection because configured clean filters could execute repository-defined commands."
PYTHON_REQUIRED_REASON="confirm-review-responses hook: python3 not found; refusing to run safety hook without the shared git command parser. Install python3 or disable this hook explicitly."
# Exit status the replay subshell uses to say it already printed one specific
# reason, so the caller never adds a second generic message for the same block.
CONTENT_SELECTION_REPORTED_STATUS=3
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

# Validates the whole parser payload in one pass and re-emits it as a
# NUL-delimited token stream. NUL is the only byte a git argument cannot carry,
# so it is the one safe record separator; strings that do carry one are
# rejected rather than silently truncated by the shell. Every context
# contributes a fixed token prefix followed by three counted arrays, and the
# stream is framed by a leading count and a trailing END marker so a truncated
# read is detectable. The payload must be exactly one JSON document: jq applies
# a filter once per document, so a second document would otherwise produce a
# second frame that the reader silently ignores.
COMMIT_CONTEXT_DECODER='
# commit-context decoder
def nul: [0] | implode;
def reject_nul: if (explode | any(. == 0)) then error("nul") else . end;
def string_field($name; $default):
  (.[$name] // $default)
  | if type == "string" then reject_nul else error("field") end;
def counted_array($name):
  (.[$name] // [])
  | if type == "array" then . else error("field") end
  | map(if type == "string" then reject_nul else error("field") end)
  | [(length | tostring)] + .;
def context_tokens:
  if type == "object" then . else error("field") end
  | [
      string_field("parse_error"; ""),
      string_field("selection_error"; ""),
      string_field("selection_mode"; "index"),
      (if has("pathspec_from_file") then "true" else "false" end),
      (if has("pathspec_from_file")
        then string_field("pathspec_from_file"; null)
        else ""
      end),
      ((.pathspec_file_nul // false)
        | if type == "boolean" then tostring else error("field") end)
    ]
  + counted_array("git_args")
  + counted_array("git_env")
  + counted_array("pathspecs");
try (
  ([inputs] | if length == 1 then .[0] else error("field") end)
  | (if type == "array" then . else error("field") end)
  | [.[] | context_tokens] as $contexts
  | ["OK", ($contexts | length | tostring)] + ($contexts | add // []) + ["END"]
  | map(. + nul)
  | add
) catch (["ERR", tostring] | map(. + nul) | add)
'

load_artifact_list() {
  local list_file="$1"
  local line

  configured_artifacts=()
  if [ -f "$list_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      # Strip the comment and surrounding whitespace with parameter expansion:
      # this avoids one sed fork per line of the artifact file.
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [ -z "$line" ] && continue
      configured_artifacts+=("$line")
    done < "$list_file"
  fi

  # Safe fallback when list file is missing/empty.
  if [ ${#configured_artifacts[@]} -eq 0 ]; then
    configured_artifacts=("REVIEW_OVERVIEW.md")
  fi
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
      --literal-pathspecs | --no-literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | --icase-pathspecs | --no-replace-objects)
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

context_has_unsupported_worktree_prefix() {
  local arg

  if [ ${#git_prefix_args[@]} -gt 0 ]; then
    for arg in "${git_prefix_args[@]}"; do
      case "$arg" in
        -c | --config-env | --config-env=* | --attr-source | --attr-source=*)
          return 0
          ;;
      esac
    done
  fi
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

  while IFS= read -r -d '' _ \
    && IFS= read -r -d '' _ \
    && IFS= read -r -d '' filter_value; do
    for filter_driver in "${configured_filter_drivers[@]}"; do
      if [ "$filter_value" = "$filter_driver" ]; then
        return 0
      fi
    done
  done < "$attribute_file"

  return 1
}

run_context_git() {
  local context_git_args=(--no-pager)

  if [ ${#safe_git_prefix_args[@]} -gt 0 ]; then
    context_git_args+=("${safe_git_prefix_args[@]}")
  fi
  context_git_args+=(
    -c core.fsmonitor=false
    -c core.hooksPath=/dev/null
  )
  if [ ${#safe_filter_config_args[@]} -gt 0 ]; then
    context_git_args+=("${safe_filter_config_args[@]}")
  fi

  git "${context_git_args[@]}" "$@"
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
    fail_selection_step() {
      echo "$CONTENT_SELECTION_REASON $1" >&2
      exit "$CONTENT_SELECTION_REPORTED_STATUS"
    }

    unset "${REPLAY_GIT_ENV_VARS[@]}"
    unset GIT_EXTERNAL_DIFF GIT_PAGER PAGER
    if [ ${#git_env_assignments[@]} -gt 0 ]; then
      for assignment in "${git_env_assignments[@]}"; do
        export "${assignment?}"
      done
    fi
    export GIT_OPTIONAL_LOCKS=0

    if [ "$selection_mode" = "index" ]; then
      if ! run_context_git diff \
        --cached \
        --name-only \
        -z \
        --no-ext-diff \
        --no-textconv \
        --no-renames \
        > "$output_file"; then
        fail_selection_step "Unable to read the already staged commit content."
      fi
      exit 0
    fi

    if context_has_unsupported_worktree_prefix; then
      fail_selection_step "Git prefixes that alter config or attributes are unsupported for worktree selection."
    fi

    if ! original_index="$(
      run_context_git rev-parse --path-format=absolute --git-path index
    )"; then
      fail_selection_step "Unable to locate the repository index."
    fi
    if [ -f "$original_index" ]; then
      if ! cp "$original_index" "$work_index"; then
        fail_selection_step "Unable to copy the repository index for inspection."
      fi
    elif [ -e "$original_index" ]; then
      fail_selection_step "Repository index is not a regular file."
    fi
    export GIT_INDEX_FILE="$work_index"

    context_has_active_clean_filter "$context_tmp_dir"
    filter_status=$?
    if [ "$filter_status" -eq 0 ]; then
      echo "$FILTER_SELECTION_REASON" >&2
      exit "$CONTENT_SELECTION_REPORTED_STATUS"
    fi
    if [ "$filter_status" -ne 1 ]; then
      fail_selection_step "Unable to inspect the content filters configured for the selected paths."
    fi

    if ! original_object_directory="$(
      run_context_git rev-parse --path-format=absolute --git-path objects
    )"; then
      fail_selection_step "Unable to locate the repository object store."
    fi
    original_alternates="${GIT_ALTERNATE_OBJECT_DIRECTORIES:-}"
    if ! mkdir -p "$object_directory"; then
      fail_selection_step "Unable to create a private object store for inspection."
    fi
    export GIT_OBJECT_DIRECTORY="$object_directory"
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$original_object_directory${original_alternates:+:$original_alternates}"

    if ! base_tree="$(run_context_git rev-parse --verify 'HEAD^{tree}' 2> /dev/null)"; then
      if ! base_tree="$(run_context_git mktree < /dev/null)"; then
        fail_selection_step "Unable to build an empty base tree for comparison."
      fi
    fi

    case "$selection_mode" in
      all)
        if ! run_context_git add -u; then
          fail_selection_step "Unable to stage tracked worktree changes for inspection."
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
          fail_selection_step "Unable to stage the selected pathspecs for inspection."
        fi
        ;;
      *)
        fail_selection_step "Unsupported commit content selection mode."
        ;;
    esac

    if ! selected_tree="$(run_context_git write-tree)"; then
      fail_selection_step "Unable to record the selected commit content."
    fi
    final_tree="$selected_tree"

    if [ "$selection_mode" = "only" ]; then
      export GIT_INDEX_FILE="$final_index"
      if ! run_context_git read-tree "$base_tree"; then
        fail_selection_step "Unable to rebuild the base tree for the selected commit content."
      fi
      if [ "$has_pathspec_from_file" = "true" ]; then
        selection_args=("--pathspec-from-file=$pathspec_from_file")
        if [ "$pathspec_file_nul" = "true" ]; then
          selection_args+=("--pathspec-file-nul")
        fi
        if ! run_context_git reset -q --no-refresh "${selection_args[@]}" "$selected_tree"; then
          fail_selection_step "Unable to restrict the commit content to the selected pathspecs."
        fi
      elif [ ${#commit_pathspecs[@]} -gt 0 ]; then
        if ! run_context_git reset -q --no-refresh "$selected_tree" -- "${commit_pathspecs[@]}"; then
          fail_selection_step "Unable to restrict the commit content to the selected pathspecs."
        fi
      fi
      if ! final_tree="$(run_context_git write-tree)"; then
        fail_selection_step "Unable to record the selected commit content."
      fi
    fi

    if ! run_context_git diff-tree \
      --no-commit-id \
      --name-only \
      --no-ext-diff \
      --no-textconv \
      --no-renames \
      -r \
      -z \
      "$base_tree" \
      "$final_tree" \
      > "$output_file"; then
      fail_selection_step "Unable to compare the selected commit content with the base tree."
    fi
  )
}

decode_commit_contexts() {
  local parser_output="$1"
  local records_file="$2"

  # -n keeps the filter from running once per input document; the decoder reads
  # the whole payload through `inputs` so it can reject a multi-document stream.
  if ! printf '%s\n' "$parser_output" | jq -j -n "$COMMIT_CONTEXT_DECODER" > "$records_file"; then
    echo "$CONTEXT_DECODE_REASON" >&2
    return 1
  fi
}

read_decoder_header() {
  # Consumes the decoder's status marker and context count from fd 3, turning
  # the marker into the one reason that names why decoding stopped.
  local decoder_status decoder_error=""

  IFS= read -r -d '' -u 3 decoder_status || decoder_status=""
  if [ "$decoder_status" = "ERR" ]; then
    IFS= read -r -d '' -u 3 decoder_error
    case "$decoder_error" in
      field) echo "$CONTEXT_SCHEMA_REASON" >&2 ;;
      nul) echo "$CONTEXT_NUL_REASON" >&2 ;;
      *) echo "$CONTEXT_DECODE_REASON" >&2 ;;
    esac
    return 1
  fi
  if [ "$decoder_status" != "OK" ] ||
    ! IFS= read -r -d '' -u 3 expected_context_count; then
    echo "$CONTEXT_DECODE_REASON" >&2
    return 1
  fi
  case "$expected_context_count" in
    '' | *[!0-9]*)
      echo "$CONTEXT_DECODE_REASON" >&2
      return 1
      ;;
  esac
}

read_decoded_string_array() {
  # Reads one count token plus that many value tokens into decoded_string_array.
  local remaining value

  decoded_string_array=()
  IFS= read -r -d '' -u 3 remaining || return 1
  case "$remaining" in
    '' | *[!0-9]*) return 1 ;;
  esac
  while [ "$remaining" -gt 0 ]; do
    IFS= read -r -d '' -u 3 value || return 1
    decoded_string_array+=("$value")
    remaining=$((remaining - 1))
  done
}

read_commit_context() {
  # Fills the per-context globals that the policy and replay steps read.
  IFS= read -r -d '' -u 3 parse_error_reason || return 1
  IFS= read -r -d '' -u 3 selection_error_reason || return 1
  IFS= read -r -d '' -u 3 selection_mode || return 1
  IFS= read -r -d '' -u 3 has_pathspec_from_file || return 1
  IFS= read -r -d '' -u 3 pathspec_from_file || return 1
  IFS= read -r -d '' -u 3 pathspec_file_nul || return 1

  read_decoded_string_array || return 1
  git_prefix_args=()
  if [ ${#decoded_string_array[@]} -gt 0 ]; then
    git_prefix_args=("${decoded_string_array[@]}")
  fi

  read_decoded_string_array || return 1
  git_env_assignments=()
  if [ ${#decoded_string_array[@]} -gt 0 ]; then
    git_env_assignments=("${decoded_string_array[@]}")
  fi

  read_decoded_string_array || return 1
  commit_pathspecs=()
  if [ ${#decoded_string_array[@]} -gt 0 ]; then
    commit_pathspecs=("${decoded_string_array[@]}")
  fi
}

check_commit_context_policy() {
  # Rejects contexts the parser already flagged, plus selections and repository
  # targets this hook cannot replay safely.
  if [ -n "$parse_error_reason" ]; then
    echo "$parse_error_reason" >&2
    return 1
  fi
  if [ -n "$selection_error_reason" ]; then
    echo "$selection_error_reason" >&2
    return 1
  fi
  case "$selection_mode" in
    index | all | include | only) ;;
    *)
      echo "$CONTENT_SELECTION_REASON Unsupported commit content selection mode." >&2
      return 1
      ;;
  esac
  if context_has_dynamic_repo_selection; then
    echo "$UNSAFE_REPO_SELECTION_REASON" >&2
    return 1
  fi
}

already_blocked() {
  local candidate="$1"
  local blocked_file

  if [ ${#blocked_files[@]} -eq 0 ]; then
    return 1
  fi
  for blocked_file in "${blocked_files[@]}"; do
    if [ "$blocked_file" = "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

collect_blocked_files() {
  local effective_files_file="$1"
  local effective_file artifact

  while IFS= read -r -d '' effective_file; do
    [ -z "$effective_file" ] && continue
    already_blocked "$effective_file" && continue
    for artifact in "${configured_artifacts[@]}"; do
      if matches_artifact "$effective_file" "$artifact"; then
        blocked_files+=("$effective_file")
        break
      fi
    done
  done < "$effective_files_file"
}

inspect_commit_context() {
  local context_index="$1"
  local context_tmp_dir="$hook_tmp_dir/context-$context_index"
  local effective_files_file="$context_tmp_dir/effective-files"
  local selection_status

  if ! mkdir -p "$context_tmp_dir"; then
    echo "$CONTEXT_WORKSPACE_REASON" >&2
    return 1
  fi

  # Closing fd 3 and pinning stdin to /dev/null keeps the decoder stream out of
  # the replay: a parser-supplied --pathspec-from-file=/dev/fd/3 would otherwise
  # let git consume the records the top-level loop is still reading.
  write_effective_files_for_commit_context \
    "$effective_files_file" \
    "$context_tmp_dir" \
    < /dev/null 3<&-
  selection_status=$?
  if [ "$selection_status" -eq "$CONTENT_SELECTION_REPORTED_STATUS" ]; then
    return 1
  fi
  if [ "$selection_status" -ne 0 ]; then
    echo "$CONTENT_SELECTION_REASON" >&2
    return 1
  fi

  collect_blocked_files "$effective_files_file"
}

process_decoded_contexts() {
  # Coordinates the named per-context steps over the decoder stream on fd 3.
  local decoded_context_count=0
  local decoded_end_marker

  if ! read_decoder_header; then
    return 1
  fi
  # Check the effective commit set for configured artifact files. An empty
  # payload still falls through to the END check below, so no frame reaches
  # success without being validated.
  if [ "$expected_context_count" -gt 0 ]; then
    load_artifact_list "$ARTIFACT_LIST_FILE"
  fi

  while [ "$decoded_context_count" -lt "$expected_context_count" ]; do
    decoded_context_count=$((decoded_context_count + 1))
    if ! read_commit_context; then
      echo "$CONTEXT_TRUNCATED_REASON" >&2
      return 1
    fi
    if ! check_commit_context_policy; then
      return 1
    fi
    if ! inspect_commit_context "$decoded_context_count"; then
      return 1
    fi
  done

  if ! IFS= read -r -d '' -u 3 decoded_end_marker || [ "$decoded_end_marker" != "END" ]; then
    echo "$CONTEXT_FRAMING_REASON" >&2
    return 1
  fi
}

report_blocked_files() {
  local config_path_display="$ARTIFACT_LIST_FILE"
  local blocked_file_list
  # Joining through IFS keeps the separator identical to the previous
  # subshell-based join without forking on the block path.
  local IFS=', '

  blocked_file_list="${blocked_files[*]}"
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    config_path_display="${ARTIFACT_LIST_FILE#${CLAUDE_PLUGIN_ROOT}/}"
  fi

  echo "Review artifact file(s) staged for commit: $blocked_file_list. Please confirm you want to include these files. Configure this list in $config_path_display." >&2
}

# Only check git commit commands. Shell/git command parsing is centralized in
# git_command_parser.py; this hook inspects the effective content selected by
# each returned commit context.
if ! commit_contexts="$(
  run_safety_hook_parser "confirm-review-responses" "commit-contexts" "$PYTHON_REQUIRED_REASON" "$PARSE_ERROR_REASON"
)"; then
  exit 2
fi
# Most Bash tool calls contain no commit at all. Recognizing the empty array
# here keeps that path free of both a temporary directory and a jq process.
if [ "${commit_contexts//[[:space:]]/}" = "[]" ]; then
  exit 0
fi

if ! hook_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/confirm-review-responses.XXXXXX")"; then
  echo "$CONTEXT_WORKSPACE_REASON" >&2
  exit 2
fi
cleanup_hook_tmp_dir() {
  rm -rf -- "$hook_tmp_dir"
}
trap cleanup_hook_tmp_dir EXIT

if ! decode_commit_contexts "$commit_contexts" "$hook_tmp_dir/contexts.records"; then
  exit 2
fi
# The decoder stream is read on fd 3 so replayed git commands can never consume
# it. A redirection failure leaves the function unrun and non-zero, which the
# caller turns into a block like any other decode failure.
blocked_files=()
if ! process_decoded_contexts 3< "$hook_tmp_dir/contexts.records"; then
  exit 2
fi

if [ ${#blocked_files[@]} -gt 0 ]; then
  report_blocked_files
  exit 2
fi

exit 0
