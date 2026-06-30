#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Confirm before committing review artifact files
# Blocks git commit when configured review artifacts are staged, asking for confirmation
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
  [[ "$staged_file" == $artifact ]] && return 0
  [[ "$staged_file" == */$artifact ]] && return 0
  return 1
}

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-parse-utils.sh"

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
  local token value

  while [ $# -gt 0 ]; do
    token="$1"
    value="$(strip_wrapping_quotes "$token")"
    case "$value" in
      -C | --git-dir | --work-tree | --namespace)
        safe_git_prefix_args+=("$value")
        shift
        if [ $# -gt 0 ]; then
          safe_git_prefix_args+=("$(strip_wrapping_quotes "$1")")
          shift
        fi
        ;;
      --git-dir=* | --work-tree=* | --namespace=*)
        safe_git_prefix_args+=("$value")
        shift
        ;;
      -C*)
        safe_git_prefix_args+=("-C" "$(strip_wrapping_quotes "${value#-C}")")
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
        export "$assignment"
      done
    fi
    if [ ${#safe_git_prefix_args[@]} -gt 0 ]; then
      git --no-pager "${safe_git_prefix_args[@]}" -c core.fsmonitor=false diff --cached --name-only --no-ext-diff
    else
      git --no-pager -c core.fsmonitor=false diff --cached --name-only --no-ext-diff
    fi
  )
}

append_git_env_assignment() {
  local assignment="$1"
  local key="${assignment%%=*}"
  local value

  should_replay_git_env "$key" || return 0
  value="$(strip_wrapping_quotes "${assignment#*=}")"
  remove_git_env_assignment "$key"
  git_env+=("$key=$value")
}

remove_git_env_assignment() {
  local key="$1"
  local assignment filtered=()

  if [ ${#git_env[@]} -gt 0 ]; then
    for assignment in "${git_env[@]}"; do
      if [ "${assignment%%=*}" != "$key" ]; then
        filtered+=("$assignment")
      fi
    done
  fi

  git_env=()
  if [ ${#filtered[@]} -gt 0 ]; then
    git_env=("${filtered[@]}")
  fi
}

clear_git_env_assignments() {
  git_env=()
}

append_shell_git_env_assignment() {
  local assignment="$1"
  local key="${assignment%%=*}"
  local value

  should_replay_git_env "$key" || return 0
  value="$(strip_wrapping_quotes "${assignment#*=}")"
  remove_shell_git_env_assignment "$key"
  shell_git_env+=("$key=$value")
}

remove_shell_git_env_assignment() {
  local key="$1"
  local assignment filtered=()

  if [ ${#shell_git_env[@]} -gt 0 ]; then
    for assignment in "${shell_git_env[@]}"; do
      if [ "${assignment%%=*}" != "$key" ]; then
        filtered+=("$assignment")
      fi
    done
  fi

  shell_git_env=()
  if [ ${#filtered[@]} -gt 0 ]; then
    shell_git_env=("${filtered[@]}")
  fi
}

clear_shell_git_env_assignments() {
  shell_git_env=()
}

append_shell_git_var_assignment() {
  local assignment="$1"
  local key="${assignment%%=*}"
  local value

  should_replay_git_env "$key" || return 0
  value="$(strip_wrapping_quotes "${assignment#*=}")"
  remove_shell_git_var_assignment "$key"
  shell_git_vars+=("$key=$value")
}

remove_shell_git_var_assignment() {
  local key="$1"
  local assignment filtered=()

  if [ ${#shell_git_vars[@]} -gt 0 ]; then
    for assignment in "${shell_git_vars[@]}"; do
      if [ "${assignment%%=*}" != "$key" ]; then
        filtered+=("$assignment")
      fi
    done
  fi

  shell_git_vars=()
  if [ ${#filtered[@]} -gt 0 ]; then
    shell_git_vars=("${filtered[@]}")
  fi
}

find_shell_git_var_assignment() {
  local key="$1"
  local assignment

  if [ ${#shell_git_vars[@]} -gt 0 ]; then
    for assignment in "${shell_git_vars[@]}"; do
      if [ "${assignment%%=*}" = "$key" ]; then
        printf '%s\n' "$assignment"
        return 0
      fi
    done
  fi

  return 1
}

merge_shell_git_var_assignments() {
  local assignment

  for assignment in "$@"; do
    append_shell_git_var_assignment "$assignment"
  done
}

export_shell_git_var_assignment() {
  local key="$1"
  local assignment

  if assignment="$(find_shell_git_var_assignment "$key")"; then
    append_shell_git_env_assignment "$assignment"
    append_git_env_assignment "$assignment"
  fi
}

collect_current_git_env_assignments() {
  local key

  for key in "${REPLAY_GIT_ENV_VARS[@]}"; do
    if [ "${!key+x}" = x ]; then
      printf '%s=%s\n' "$key" "${!key}"
    fi
  done
}

emit_git_commit_context() {
  local git_args_json='[]'
  local git_env_json='[]'

  if [ ${#git_args[@]} -gt 0 ]; then
    git_args_json="$(printf '%s\n' "${git_args[@]}" | jq -R . | jq -s .)"
  fi
  if [ ${#git_env[@]} -gt 0 ]; then
    git_env_json="$(printf '%s\n' "${git_env[@]}" | jq -R . | jq -s .)"
  fi

  jq -cn --argjson git_args "$git_args_json" --argjson git_env "$git_env_json" \
    '{git_args: $git_args, git_env: $git_env}'
}

parse_git_commit_segment_fallback() {
  local prefix_git_args="$1"
  local prefix_git_env="$2"
  local prefix_shell_git_vars="${3:-$2}"
  shift 3

  local token inline_command
  local saw_git=false
  local git_args=()
  local git_env=()
  local shell_git_env=()
  local shell_git_vars=()
  local shell_env_persists=true
  local pending_shell_git_vars=()
  local nested_git_args nested_git_env

  PARSED_SEGMENT_CONTEXT_LINES=""
  PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
  PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"

  while IFS= read -r token; do
    [ -z "$token" ] && continue
    git_args+=("$token")
  done << EOF
$prefix_git_args
EOF

  while IFS= read -r token; do
    [ -z "$token" ] && continue
    shell_git_env+=("$token")
  done << EOF
$prefix_git_env
EOF

  while IFS= read -r token; do
    [ -z "$token" ] && continue
    shell_git_vars+=("$token")
  done << EOF
$prefix_shell_git_vars
EOF

  git_env=()
  if [ ${#shell_git_env[@]} -gt 0 ]; then
    git_env=("${shell_git_env[@]}")
  fi

  while [ $# -gt 0 ] && is_shell_keyword_token "$1"; do
    if [ "$(strip_wrapping_quotes "$1")" = "(" ]; then
      shell_env_persists=false
    fi
    shift
  done

  while [ $# -gt 0 ] && token_is_assignment "$(strip_wrapping_quotes "$1")"; do
    token="$(strip_wrapping_quotes "$1")"
    append_git_env_assignment "$token"
    pending_shell_git_vars+=("$token")
    shift
  done

  if [ $# -eq 0 ]; then
    if [ ${#pending_shell_git_vars[@]} -gt 0 ]; then
      merge_shell_git_var_assignments "${pending_shell_git_vars[@]}"
    fi
    if [ "$shell_env_persists" = "true" ]; then
      PARSED_SEGMENT_PERSISTED_GIT_ENV=""
      PARSED_SEGMENT_PERSISTED_GIT_VARS=""
      if [ ${#shell_git_env[@]} -gt 0 ]; then
        PARSED_SEGMENT_PERSISTED_GIT_ENV="$(printf '%s\n' "${shell_git_env[@]}")"
      fi
      if [ ${#shell_git_vars[@]} -gt 0 ]; then
        PARSED_SEGMENT_PERSISTED_GIT_VARS="$(printf '%s\n' "${shell_git_vars[@]}")"
      fi
    else
      PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
      PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"
    fi
    return
  fi

  while [ $# -gt 0 ]; do
    token="$1"
    if token_is_shell_alias_builtin "$token"; then
      PARSED_SEGMENT_CONTEXT_LINES="$(emit_parse_error_context)"
      return
    fi
    case "$(token_basename "$token")" in
      command | builtin)
        shift
        while [ $# -gt 0 ]; do
          parse_command_wrapper_token "$@"
          case "$PARSED_WRAPPER_ACTION" in
            end_of_options | option)
              shift "$PARSED_WRAPPER_CONSUMED"
              [ "$PARSED_WRAPPER_ACTION" = "end_of_options" ] && break
              ;;
            command)
              break
          esac
        done
        ;;
      sudo)
        shift
        while [ $# -gt 0 ]; do
          token="$(strip_wrapping_quotes "$1")"
          parse_sudo_wrapper_token "$@"
          case "$PARSED_WRAPPER_ACTION" in
            end_of_options)
              shift "$PARSED_WRAPPER_CONSUMED"
              break
              ;;
            chdir)
              case "$token" in
                --chdir=*)
                  git_args+=("-C" "$PARSED_WRAPPER_VALUE")
                  ;;
                *)
                  [ "$PARSED_WRAPPER_CONSUMED" -eq 2 ] && git_args+=("-C" "$PARSED_WRAPPER_VALUE")
                  ;;
              esac
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            option)
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            command)
              break
              ;;
          esac
        done
        ;;
      export)
        if [ ${#pending_shell_git_vars[@]} -gt 0 ]; then
          merge_shell_git_var_assignments "${pending_shell_git_vars[@]}"
        fi
        pending_shell_git_vars=()
        shift
        while [ $# -gt 0 ]; do
          token="$(strip_wrapping_quotes "$1")"
          case "$token" in
            --)
              shift
              break
              ;;
            -n)
              shift
              if [ $# -gt 0 ]; then
                remove_shell_git_env_assignment "$(strip_wrapping_quotes "$1")"
                remove_git_env_assignment "$(strip_wrapping_quotes "$1")"
                shift
              fi
              ;;
            -n*)
              remove_shell_git_env_assignment "$(strip_wrapping_quotes "${token#-n}")"
              remove_git_env_assignment "$(strip_wrapping_quotes "${token#-n}")"
              shift
              ;;
            -p | -f)
              shift
              ;;
            [A-Za-z_][A-Za-z0-9_]*=*)
              append_shell_git_var_assignment "$token"
              append_shell_git_env_assignment "$token"
              append_git_env_assignment "$token"
              shift
              ;;
            [A-Za-z_][A-Za-z0-9_]*)
              export_shell_git_var_assignment "$token"
              shift
              ;;
            -*)
              shift
              ;;
            *)
              break
              ;;
          esac
        done
        ;;
      unset)
        pending_shell_git_vars=()
        local unset_targets_variables=true
        shift
        while [ $# -gt 0 ]; do
          token="$(strip_wrapping_quotes "$1")"
          case "$token" in
            --)
              shift
              break
              ;;
            -f | -n)
              unset_targets_variables=false
              shift
              ;;
            -v)
              unset_targets_variables=true
              shift
              ;;
            -*)
              case "$token" in
                *f* | *n*)
                  unset_targets_variables=false
                  ;;
                *v*)
                  unset_targets_variables=true
                  ;;
              esac
              shift
              ;;
            *)
              if [ "$unset_targets_variables" = "true" ]; then
                remove_shell_git_var_assignment "$token"
                remove_shell_git_env_assignment "$token"
                remove_git_env_assignment "$token"
              fi
              shift
              ;;
          esac
        done
        ;;
      env | /usr/bin/env)
        shift
        while [ $# -gt 0 ]; do
          token="$1"
          parse_env_wrapper_token "$@"
          case "$PARSED_WRAPPER_ACTION" in
            end_of_options)
              shift "$PARSED_WRAPPER_CONSUMED"
              break
              ;;
            assignment)
              append_git_env_assignment "$PARSED_WRAPPER_VALUE"
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            ignore_environment)
              clear_git_env_assignments
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            unset)
              remove_git_env_assignment "$PARSED_WRAPPER_VALUE"
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            chdir)
              case "$(strip_wrapping_quotes "$token")" in
                --chdir=* | -C?*)
                  git_args+=("-C" "$PARSED_WRAPPER_VALUE")
                  ;;
                *)
                  [ "$PARSED_WRAPPER_CONSUMED" -eq 2 ] && git_args+=("-C" "$PARSED_WRAPPER_VALUE")
                  ;;
              esac
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            option)
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            command)
              break
              ;;
          esac
        done
        ;;
      sh | bash | zsh | dash | ksh)
        shift
        if inline_command="$(extract_shell_inline_command "$@")"; then
          nested_git_args=""
          nested_git_env=""
          if [ ${#git_args[@]} -gt 0 ]; then
            nested_git_args="$(printf '%s\n' "${git_args[@]}")"
          fi
          if [ ${#git_env[@]} -gt 0 ]; then
            nested_git_env="$(printf '%s\n' "${git_env[@]}")"
          fi
          PARSED_SEGMENT_CONTEXT_LINES="$(
            parse_git_commit_contexts_fallback \
              "$inline_command" \
              "$nested_git_args" \
              "$nested_git_env" \
              "$nested_git_env"
          )"
        fi
        if [ "$shell_env_persists" = "true" ]; then
          PARSED_SEGMENT_PERSISTED_GIT_ENV=""
          PARSED_SEGMENT_PERSISTED_GIT_VARS=""
          if [ ${#shell_git_env[@]} -gt 0 ]; then
            PARSED_SEGMENT_PERSISTED_GIT_ENV="$(printf '%s\n' "${shell_git_env[@]}")"
          fi
          if [ ${#shell_git_vars[@]} -gt 0 ]; then
            PARSED_SEGMENT_PERSISTED_GIT_VARS="$(printf '%s\n' "${shell_git_vars[@]}")"
          fi
        else
          PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
          PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"
        fi
        return
        ;;
      *)
        if [ "$(token_basename "$token")" = "git" ]; then
          saw_git=true
          shift
          break
        fi
        if [ "$shell_env_persists" = "true" ]; then
          PARSED_SEGMENT_PERSISTED_GIT_ENV=""
          PARSED_SEGMENT_PERSISTED_GIT_VARS=""
          if [ ${#shell_git_env[@]} -gt 0 ]; then
            PARSED_SEGMENT_PERSISTED_GIT_ENV="$(printf '%s\n' "${shell_git_env[@]}")"
          fi
          if [ ${#shell_git_vars[@]} -gt 0 ]; then
            PARSED_SEGMENT_PERSISTED_GIT_VARS="$(printf '%s\n' "${shell_git_vars[@]}")"
          fi
        else
          PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
          PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"
        fi
        return
        ;;
    esac
  done

  if [ "$saw_git" != "true" ]; then
    if [ "$shell_env_persists" = "true" ]; then
      PARSED_SEGMENT_PERSISTED_GIT_ENV=""
      PARSED_SEGMENT_PERSISTED_GIT_VARS=""
      if [ ${#shell_git_env[@]} -gt 0 ]; then
        PARSED_SEGMENT_PERSISTED_GIT_ENV="$(printf '%s\n' "${shell_git_env[@]}")"
      fi
      if [ ${#shell_git_vars[@]} -gt 0 ]; then
        PARSED_SEGMENT_PERSISTED_GIT_VARS="$(printf '%s\n' "${shell_git_vars[@]}")"
      fi
    else
      PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
      PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"
    fi
    return
  fi

  parse_git_command_context true true "$@"
  if [ ${#PARSED_GIT_PREFIX_ARGS[@]} -gt 0 ]; then
    git_args+=("${PARSED_GIT_PREFIX_ARGS[@]}")
  fi

  if [ "$PARSED_GIT_SUBCOMMAND" = "commit" ]; then
    PARSED_SEGMENT_CONTEXT_LINES="$(emit_git_commit_context)"
  fi

  if [ "$shell_env_persists" = "true" ]; then
    PARSED_SEGMENT_PERSISTED_GIT_ENV=""
    PARSED_SEGMENT_PERSISTED_GIT_VARS=""
    if [ ${#shell_git_env[@]} -gt 0 ]; then
      PARSED_SEGMENT_PERSISTED_GIT_ENV="$(printf '%s\n' "${shell_git_env[@]}")"
    fi
    if [ ${#shell_git_vars[@]} -gt 0 ]; then
      PARSED_SEGMENT_PERSISTED_GIT_VARS="$(printf '%s\n' "${shell_git_vars[@]}")"
    fi
  else
    PARSED_SEGMENT_PERSISTED_GIT_ENV="$prefix_git_env"
    PARSED_SEGMENT_PERSISTED_GIT_VARS="$prefix_shell_git_vars"
  fi
}

emit_parse_error_context() {
  local reason="${1:-$PARSE_ERROR_REASON}"
  jq -cn --arg reason "$reason" '{parse_error: $reason}'
}

parse_git_commit_contexts_fallback() {
  local raw_command="$1"
  local prefix_git_args="${2:-}"
  local prefix_git_env="${3:-}"
  local prefix_shell_git_vars="${4:-$prefix_git_env}"
  local tokenized token_json token_type token_value substitution
  local current_git_env="$prefix_git_env"
  local current_shell_git_vars="$prefix_shell_git_vars"
  local segment_input_env
  local segment_input_shell_vars
  local segment_substitution_indexes=()
  local used_substitution_indexes=()
  local segment=()
  local sanitized_command
  local substitutions=()

  if ! replace_command_substitutions "$raw_command"; then
    emit_parse_error_context
    return
  fi

  sanitized_command="$SANITIZED_COMMAND"
  substitutions=()
  if [ ${#COMMAND_SUBSTITUTIONS[@]} -gt 0 ]; then
    substitutions=("${COMMAND_SUBSTITUTIONS[@]}")
  fi

  if ! tokenized="$(shell_tokenize "$sanitized_command" true)"; then
    emit_parse_error_context
    return
  fi

  while IFS= read -r token_json; do
    [ -z "$token_json" ] && continue
    token_type="$(printf '%s\n' "$token_json" | jq -r '.type')"
    token_value="$(printf '%s\n' "$token_json" | jq -r '.value')"
    if [ "$token_type" = "control" ]; then
      segment_input_env="$current_git_env"
      segment_input_shell_vars="$current_shell_git_vars"
      segment_substitution_indexes=()
      if [ ${#segment[@]} -gt 0 ]; then
        while IFS= read -r substitution; do
          [ -z "$substitution" ] && continue
          segment_substitution_indexes+=("$substitution")
        done < <(segment_command_substitution_indexes "${segment[@]}")
      fi
      if [ ${#segment_substitution_indexes[@]} -gt 0 ]; then
        for substitution in "${segment_substitution_indexes[@]}"; do
          if [ ${#used_substitution_indexes[@]} -eq 0 ] || ! array_contains "$substitution" "${used_substitution_indexes[@]}"; then
            used_substitution_indexes+=("$substitution")
          fi
          parse_git_commit_contexts_fallback \
            "${substitutions[$substitution]}" \
            "$prefix_git_args" \
            "$segment_input_env" \
            "$segment_input_shell_vars"
        done
      fi
      if [ ${#segment[@]} -gt 0 ]; then
        parse_git_commit_segment_fallback "$prefix_git_args" "$current_git_env" "$current_shell_git_vars" "${segment[@]}"
      else
        parse_git_commit_segment_fallback "$prefix_git_args" "$current_git_env" "$current_shell_git_vars"
      fi
      if [ -n "$PARSED_SEGMENT_CONTEXT_LINES" ]; then
        printf '%s\n' "$PARSED_SEGMENT_CONTEXT_LINES"
      fi
      if control_token_preserves_shell_env "$token_value"; then
        current_git_env="$PARSED_SEGMENT_PERSISTED_GIT_ENV"
        current_shell_git_vars="$PARSED_SEGMENT_PERSISTED_GIT_VARS"
      else
        current_git_env="$segment_input_env"
        current_shell_git_vars="$segment_input_shell_vars"
      fi
      segment=()
      continue
    fi
    segment+=("$token_value")
  done << EOF
$tokenized
EOF

  segment_input_env="$current_git_env"
  segment_input_shell_vars="$current_shell_git_vars"
  segment_substitution_indexes=()
  if [ ${#segment[@]} -gt 0 ]; then
    while IFS= read -r substitution; do
      [ -z "$substitution" ] && continue
      segment_substitution_indexes+=("$substitution")
    done < <(segment_command_substitution_indexes "${segment[@]}")
  fi
  if [ ${#segment_substitution_indexes[@]} -gt 0 ]; then
    for substitution in "${segment_substitution_indexes[@]}"; do
      if [ ${#used_substitution_indexes[@]} -eq 0 ] || ! array_contains "$substitution" "${used_substitution_indexes[@]}"; then
        used_substitution_indexes+=("$substitution")
      fi
      parse_git_commit_contexts_fallback \
        "${substitutions[$substitution]}" \
        "$prefix_git_args" \
        "$segment_input_env" \
        "$segment_input_shell_vars"
    done
  fi

  if [ ${#segment[@]} -gt 0 ]; then
    parse_git_commit_segment_fallback "$prefix_git_args" "$current_git_env" "$current_shell_git_vars" "${segment[@]}"
  else
    parse_git_commit_segment_fallback "$prefix_git_args" "$current_git_env" "$current_shell_git_vars"
  fi
  if [ -n "$PARSED_SEGMENT_CONTEXT_LINES" ]; then
    printf '%s\n' "$PARSED_SEGMENT_CONTEXT_LINES"
  fi

  for ((substitution = 0; substitution < ${#substitutions[@]}; substitution += 1)); do
    if [ ${#used_substitution_indexes[@]} -gt 0 ] && array_contains "$substitution" "${used_substitution_indexes[@]}"; then
      continue
    fi
    parse_git_commit_contexts_fallback \
      "${substitutions[$substitution]}" \
      "$prefix_git_args" \
      "$prefix_git_env" \
      "$prefix_shell_git_vars"
  done
}

parse_git_commit_contexts() {
  local raw_command="$1"
  local inherited_git_env

  inherited_git_env="$(collect_current_git_env_assignments)"

  if command -v python3 > /dev/null 2>&1; then
    python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git_command_parser.py" commit-contexts "$raw_command" "$PARSE_ERROR_REASON"
    return
  fi

  local context_lines
  context_lines="$(parse_git_commit_contexts_fallback "$raw_command" "" "$inherited_git_env" "$inherited_git_env")"
  if [ -z "$context_lines" ]; then
    printf '%s\n' '[]'
    return
  fi

  printf '%s\n' "$context_lines" | jq -s .
}

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Only check git commit commands
if ! commit_contexts="$(parse_git_commit_contexts "$command")"; then
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

# Check if configured artifact files are staged
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
    # Can't confirm the artifact is *not* staged — fail closed so
    # bad-env/repo-corruption can't slip a staged artifact through.
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
  if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    config_path_display="${ARTIFACT_LIST_FILE#${CLAUDE_PLUGIN_ROOT}/}"
  fi

  echo "Review artifact file(s) staged for commit: $blocked_file_list. Please confirm you want to include these files. Configure this list in $config_path_display." >&2
  exit 2
fi

exit 0
