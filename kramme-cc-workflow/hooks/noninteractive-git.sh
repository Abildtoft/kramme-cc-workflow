#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Block git commands that open interactive editors
# Forces non-interactive alternatives for rebase, commit, merge, cherry-pick, and add
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "noninteractive-git" ""

if ! command -v jq > /dev/null 2>&1; then
  echo "noninteractive-git hook: jq not found; refusing to run safety hook without JSON parsing. Install jq or disable this hook explicitly." >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Helper to output block decision
block() {
  local reason="$1"
  echo "$reason" >&2
  exit 2
}

PARSE_ERROR_REASON="Unable to safely parse command. Refusing potentially interactive git command."
COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES="mFCctSu"
COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE="mFCct"
COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE="--author --date --message --file --reuse-message --reedit-message --fixup --squash --cleanup --trailer --pathspec-from-file"
MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES="mFsSX"
MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE="mFsX"
MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE="--message --file --strategy --strategy-option --cleanup --into-name"

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-parse-utils.sh"

args_have_short_option() {
  local wanted="$1"
  shift
  local arg value

  for arg in "$@"; do
    value="$(strip_wrapping_quotes "$arg")"
    [ "$value" = "--" ] && break
    case "$value" in
      --* | -) continue ;;
      -*)
        case "${value#-}" in
          *"$wanted"*) return 0 ;;
        esac
        ;;
    esac
  done
  return 1
}

args_have_short_option_value_aware() {
  local wanted="$1"
  local options_with_values="$2"
  shift 2
  local arg value short_options idx option

  for arg in "$@"; do
    value="$(strip_wrapping_quotes "$arg")"
    [ "$value" = "--" ] && break
    case "$value" in
      --* | -) continue ;;
      -*)
        short_options="${value#-}"
        for ((idx = 0; idx < ${#short_options}; idx += 1)); do
          option="${short_options:$idx:1}"
          if [ "$option" = "$wanted" ]; then
            return 0
          fi
          case "$options_with_values" in
            *"$option"*)
              break
              ;;
          esac
        done
        ;;
    esac
  done
  return 1
}

short_option_consumes_next_value() {
  local arg="$1"
  local options_with_values="$2"
  local short_options idx option

  case "$arg" in
    --* | -) return 1 ;;
    -*)
      short_options="${arg#-}"
      for ((idx = 0; idx < ${#short_options}; idx += 1)); do
        option="${short_options:$idx:1}"
        case "$options_with_values" in
          *"$option"*)
            [ "$idx" -eq "$((${#short_options} - 1))" ]
            return
            ;;
        esac
      done
      ;;
  esac
  return 1
}

args_have_long_option_value_aware() {
  local wanted="$1"
  local short_options_with_values="$2"
  local long_options_with_values="$3"
  shift 3
  local arg value skip_next=false

  for arg in "$@"; do
    value="$(strip_wrapping_quotes "$arg")"
    if [ "$skip_next" = "true" ]; then
      skip_next=false
      continue
    fi
    [ "$value" = "--" ] && break
    [ "$value" = "$wanted" ] && return 0
    case "$value" in
      "$wanted"=*) return 0 ;;
    esac
    if short_option_consumes_next_value "$value" "$short_options_with_values"; then
      skip_next=true
      continue
    fi
    case " $long_options_with_values " in
      *" $value "*)
        skip_next=true
        ;;
    esac
  done
  return 1
}

args_have_long_option() {
  local wanted="$1"
  shift
  local arg value

  for arg in "$@"; do
    value="$(strip_wrapping_quotes "$arg")"
    [ "$value" = "--" ] && break
    [ "$value" = "$wanted" ] && return 0
    case "$value" in
      "$wanted"=*) return 0 ;;
    esac
  done
  return 1
}

fixup_value_is_interactive() {
  case "$1" in
    amend:* | reword:*)
      return 0
      ;;
  esac
  return 1
}

classify_commit_fixup() {
  local arg value skip_next=false expecting_fixup_value=false

  for arg in "$@"; do
    value="$(strip_wrapping_quotes "$arg")"
    if [ "$expecting_fixup_value" = "true" ]; then
      if fixup_value_is_interactive "$value"; then
        printf 'interactive\n'
      else
        printf 'safe\n'
      fi
      return
    fi
    if [ "$skip_next" = "true" ]; then
      skip_next=false
      continue
    fi
    [ "$value" = "--" ] && break
    case "$value" in
      --fixup)
        expecting_fixup_value=true
        continue
        ;;
      --fixup=*)
        if fixup_value_is_interactive "${value#*=}"; then
          printf 'interactive\n'
        else
          printf 'safe\n'
        fi
        return
        ;;
    esac
    if short_option_consumes_next_value "$value" "$COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE"; then
      skip_next=true
      continue
    fi
    case " $COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE " in
      *" $value "*)
        skip_next=true
        ;;
    esac
  done

  printf 'none\n'
}

merge_edit_is_safe() {
  args_have_long_option "--ff-only" "$@" && ! args_have_long_option "--no-ff" "$@"
}

commit_has_message_source() {
  local commit_fixup_mode="$1"
  shift
  commit_requests_editor "$@" && return 1
  args_have_short_option_value_aware "m" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
    || args_have_short_option_value_aware "F" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
    || args_have_short_option_value_aware "C" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
    || commit_has_safe_fixup "$@" \
    || args_have_long_option "--message" "$@" \
    || args_have_long_option "--file" "$@" \
    || [ "$commit_fixup_mode" = "safe" ] \
    || args_have_long_option "--reuse-message" "$@" \
    || args_have_long_option "--no-edit" "$@"
}

merge_has_message_source() {
  args_have_short_option_value_aware "m" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
    || args_have_short_option_value_aware "F" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
    || args_have_long_option "--message" "$@" \
    || args_have_long_option "--file" "$@"
}

commit_requests_editor() {
  local value short_options short_name consume_next

  while [ $# -gt 0 ]; do
    value="$(strip_wrapping_quotes "$1")"
    [ "$value" = "--" ] && break

    consume_next=0
    case "$value" in
      --edit | --reedit-message | --reedit-message=*)
        return 0
        ;;
      --message | --file | --reuse-message | --fixup)
        consume_next=1
        ;;
      --message=* | --file=* | --reuse-message=* | --fixup=*) ;;
      -[!-]*)
        short_options="${value#-}"
        while [ -n "$short_options" ]; do
          short_name="${short_options%"${short_options#?}"}"
          short_options="${short_options#?}"
          case "$short_name" in
            e | c)
              return 0
              ;;
            m | F | C)
              [ -z "$short_options" ] && consume_next=1
              short_options=""
              ;;
          esac
        done
        ;;
    esac

    shift
    [ "$consume_next" -eq 1 ] && [ $# -gt 0 ] && shift
  done

  return 1
}

commit_has_safe_fixup() {
  local value target

  while [ $# -gt 0 ]; do
    value="$(strip_wrapping_quotes "$1")"
    [ "$value" = "--" ] && break
    case "$value" in
      --fixup)
        shift
        [ $# -gt 0 ] || return 1
        target="$(strip_wrapping_quotes "$1")"
        case "$target" in
          amend:* | reword:*)
            return 1
            ;;
          *)
            return 0
            ;;
        esac
        ;;
      --fixup=*)
        target="${value#*=}"
        case "$target" in
          amend:* | reword:*)
            return 1
            ;;
          *)
            return 0
            ;;
        esac
        ;;
    esac
    shift
  done
  return 1
}

record_git_editor_env() {
  local assignment="$1"
  local key="${assignment%%=*}"

  case "$key" in
    GIT_EDITOR)
      has_git_editor=true
      ;;
    GIT_SEQUENCE_EDITOR)
      has_git_sequence_editor=true
      ;;
  esac
}

unset_git_editor_env() {
  case "$1" in
    GIT_EDITOR)
      has_git_editor=false
      ;;
    GIT_SEQUENCE_EDITOR)
      has_git_sequence_editor=false
      ;;
  esac
}

clear_git_editor_env() {
  has_git_editor=false
  has_git_sequence_editor=false
}

apply_exported_editor_env_segment() {
  local inherited_has_git_editor="${1:-false}"
  local inherited_has_git_sequence_editor="${2:-false}"
  local inherited_shell_has_git_editor="${3:-$inherited_has_git_editor}"
  local inherited_shell_has_git_sequence_editor="${4:-$inherited_has_git_sequence_editor}"
  local value token command_name
  local shell_env_persists=true
  local pending_shell_has_git_editor=""
  local pending_shell_has_git_sequence_editor=""

  shift 4

  PARSED_PERSISTED_HAS_GIT_EDITOR="$inherited_has_git_editor"
  PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR="$inherited_has_git_sequence_editor"
  PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR="$inherited_shell_has_git_editor"
  PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR="$inherited_shell_has_git_sequence_editor"

  while [ $# -gt 0 ] && is_shell_keyword_token "$1"; do
    if [ "$(strip_wrapping_quotes "$1")" = "(" ]; then
      shell_env_persists=false
    fi
    shift
  done

  while [ $# -gt 0 ] && token_is_assignment "$(strip_wrapping_quotes "$1")"; do
    token="$(strip_wrapping_quotes "$1")"
    case "${token%%=*}" in
      GIT_EDITOR)
        pending_shell_has_git_editor=true
        ;;
      GIT_SEQUENCE_EDITOR)
        pending_shell_has_git_sequence_editor=true
        ;;
    esac
    shift
  done

  if [ $# -eq 0 ]; then
    if [ "$shell_env_persists" = "true" ]; then
      [ -n "$pending_shell_has_git_editor" ] && PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR="$pending_shell_has_git_editor"
      [ -n "$pending_shell_has_git_sequence_editor" ] && PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR="$pending_shell_has_git_sequence_editor"
    fi
    return
  fi

  [ "$shell_env_persists" = "true" ] || return
  command_name="$(token_basename "$1")"

  case "$command_name" in
    export)
      [ -n "$pending_shell_has_git_editor" ] && PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR="$pending_shell_has_git_editor"
      [ -n "$pending_shell_has_git_sequence_editor" ] && PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR="$pending_shell_has_git_sequence_editor"
      shift

      while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
          --)
            shift
            break
            ;;
          -n)
            shift
            if [ $# -gt 0 ]; then
              case "$(strip_wrapping_quotes "$1")" in
                GIT_EDITOR)
                  PARSED_PERSISTED_HAS_GIT_EDITOR=false
                  ;;
                GIT_SEQUENCE_EDITOR)
                  PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR=false
                  ;;
              esac
              shift
            fi
            ;;
          -n*)
            case "$(strip_wrapping_quotes "${value#-n}")" in
              GIT_EDITOR)
                PARSED_PERSISTED_HAS_GIT_EDITOR=false
                ;;
              GIT_SEQUENCE_EDITOR)
                PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR=false
                ;;
            esac
            shift
            ;;
          [A-Za-z_][A-Za-z0-9_]*=*)
            case "${value%%=*}" in
              GIT_EDITOR)
                PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR=true
                PARSED_PERSISTED_HAS_GIT_EDITOR=true
                ;;
              GIT_SEQUENCE_EDITOR)
                PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR=true
                PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR=true
                ;;
            esac
            shift
            ;;
          [A-Za-z_][A-Za-z0-9_]*)
            case "$value" in
              GIT_EDITOR)
                if [ "$PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR" = "true" ]; then
                  PARSED_PERSISTED_HAS_GIT_EDITOR=true
                fi
                ;;
              GIT_SEQUENCE_EDITOR)
                if [ "$PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR" = "true" ]; then
                  PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR=true
                fi
                ;;
            esac
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
      local unset_targets_variables=true
      shift

      while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
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
            case "$value" in
              *f* | *n*)
                unset_targets_variables=false
                ;;
              *v*)
                unset_targets_variables=true
                ;;
            esac
            shift
            ;;
          GIT_EDITOR)
            if [ "$unset_targets_variables" = "true" ]; then
              PARSED_PERSISTED_HAS_GIT_EDITOR=false
              PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR=false
            fi
            shift
            ;;
          GIT_SEQUENCE_EDITOR)
            if [ "$unset_targets_variables" = "true" ]; then
              PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR=false
              PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR=false
            fi
            shift
            ;;
          *)
            shift
            ;;
        esac
      done
      ;;
    *)
      return
      ;;
  esac
}

evaluate_find_exec_segments() {
  local inherited_has_git_editor="${1:-false}"
  local inherited_has_git_sequence_editor="${2:-false}"
  local value reason
  local exec_segment=()

  shift 2

  while [ $# -gt 0 ]; do
    value="$(strip_wrapping_quotes "$1")"
    case "$value" in
      -exec | -execdir)
        shift
        exec_segment=()
        while [ $# -gt 0 ]; do
          value="$(strip_wrapping_quotes "$1")"
          case "$value" in
            ';' | '+')
              break
              ;;
          esac
          exec_segment+=("$1")
          shift
        done
        reason="$(
          if [ ${#exec_segment[@]} -gt 0 ]; then
            evaluate_simple_git_segment \
              "$inherited_has_git_editor" \
              "$inherited_has_git_sequence_editor" \
              "${exec_segment[@]}"
          else
            evaluate_simple_git_segment \
              "$inherited_has_git_editor" \
              "$inherited_has_git_sequence_editor"
          fi
        )"
        if [ "$reason" != "__ALLOW__" ]; then
          printf '%s\n' "$reason"
          return
        fi
        ;;
    esac
    shift
  done

  printf '__ALLOW__\n'
}

evaluate_simple_git_segment() {
  local inherited_has_git_editor="${1:-false}"
  local inherited_has_git_sequence_editor="${2:-false}"
  local token base value subcmd inline_command reason
  local has_git_editor="$inherited_has_git_editor"
  local has_git_sequence_editor="$inherited_has_git_sequence_editor"

  shift 2

  [ $# -eq 0 ] && {
    printf '__ALLOW__\n'
    return
  }

  while [ $# -gt 0 ] && is_shell_keyword_token "$1"; do
    shift
  done

  while [ $# -gt 0 ] && token_is_assignment "$(strip_wrapping_quotes "$1")"; do
    record_git_editor_env "$(strip_wrapping_quotes "$1")"
    shift
  done

  while [ $# -gt 0 ]; do
    token="$1"
    base="$(token_basename "$token")"
    case "$base" in
      env)
        shift
        while [ $# -gt 0 ]; do
          parse_env_wrapper_token "$@"
          case "$PARSED_WRAPPER_ACTION" in
            end_of_options)
              shift "$PARSED_WRAPPER_CONSUMED"
              break
              ;;
            assignment)
              record_git_editor_env "$PARSED_WRAPPER_VALUE"
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            ignore_environment)
              clear_git_editor_env
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            unset)
              unset_git_editor_env "$PARSED_WRAPPER_VALUE"
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            chdir | option)
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            command)
              break
              ;;
          esac
        done
        ;;
      command)
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
          parse_sudo_wrapper_token "$@"
          case "$PARSED_WRAPPER_ACTION" in
            end_of_options)
              shift "$PARSED_WRAPPER_CONSUMED"
              break
              ;;
            option | chdir)
              shift "$PARSED_WRAPPER_CONSUMED"
              ;;
            command)
              break
              ;;
          esac
        done
        ;;
      xargs)
        shift
        while [ $# -gt 0 ]; do
          value="$(strip_wrapping_quotes "$1")"
          case "$value" in
            --)
              shift
              break
              ;;
            -d | -E | -I | -L | -P | -n | -s | --delimiter | --eof | --max-args | --max-chars | --max-procs | --replace)
              shift
              [ $# -gt 0 ] && shift
              ;;
            --delimiter=* | --eof=* | --max-args=* | --max-chars=* | --max-procs=* | --replace=*)
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
      find)
        reason="$(evaluate_find_exec_segments "$has_git_editor" "$has_git_sequence_editor" "$@")"
        printf '%s\n' "$reason"
        return
        ;;
      -exec | -execdir)
        shift
        ;;
      sh | bash | zsh | dash | ksh)
        shift
        if inline_command="$(extract_shell_inline_command "$@")"; then
          if [ "$(fallback_noninteractive_reason "$inline_command" "$has_git_editor" "$has_git_sequence_editor")" != "__ALLOW__" ]; then
            printf '%s\n' "$PARSE_ERROR_REASON"
            return
          fi
        fi
        printf '__ALLOW__\n'
        return
        ;;
      git)
        shift
        break
        ;;
      *)
        printf '__ALLOW__\n'
        return
        ;;
    esac
  done

  parse_git_command_context false false "$@"

  if [ -z "$PARSED_GIT_SUBCOMMAND" ]; then
    printf '__ALLOW__\n'
    return
  fi

  subcmd="$PARSED_GIT_SUBCOMMAND"
  if [ ${#PARSED_GIT_SUBCOMMAND_ARGS[@]} -gt 0 ]; then
    set -- "${PARSED_GIT_SUBCOMMAND_ARGS[@]}"
  else
    set --
  fi

  case "$subcmd" in
    commit)
      local commit_fixup_mode has_no_edit=false

      if args_have_short_option_value_aware "e" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" || args_have_long_option_value_aware "--edit" "$COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE" "$COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE" "$@"; then
        printf '%s\n' 'git commit --edit opens an editor. Remove --edit to keep the commit non-interactive.'
        return
      fi
      commit_fixup_mode="$(classify_commit_fixup "$@")"
      if args_have_long_option "--no-edit" "$@"; then
        has_no_edit=true
      fi
      if [ "$commit_fixup_mode" = "interactive" ] && [ "$has_no_edit" != "true" ]; then
        printf '%s\n' 'git commit --fixup=amend:<commit> and --fixup=reword:<commit> open an editor unless you also pass --no-edit.'
        return
      fi
      if ! commit_has_message_source "$commit_fixup_mode" "$@"; then
        printf '%s\n' 'git commit without a message source may open an editor. Use: git commit -m "your message" (or --no-edit for amend)'
        return
      fi
      ;;
    rebase)
      if (args_have_short_option "i" "$@" || args_have_long_option "--interactive" "$@") && [ "$has_git_sequence_editor" != "true" ]; then
        printf '%s\n' 'Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ...'
        return
      fi
      if args_have_long_option "--continue" "$@" && [ "$has_git_editor" != "true" ]; then
        printf '%s\n' 'git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue'
        return
      fi
      ;;
    add)
      if args_have_short_option "p" "$@" || args_have_short_option "i" "$@" || args_have_long_option "--patch" "$@" || args_have_long_option "--interactive" "$@"; then
        printf '%s\n' 'Interactive git add opens a prompt. Use explicit paths: git add <files>'
        return
      fi
      ;;
    merge)
      if (args_have_short_option_value_aware "e" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" || args_have_long_option_value_aware "--edit" "$MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE" "$MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE" "$@") && ! merge_edit_is_safe "$@"; then
        printf '%s\n' 'git merge --edit opens an editor. Remove --edit to keep the merge non-interactive.'
        return
      fi
      if ! (args_have_long_option "--abort" "$@" || args_have_long_option "--quit" "$@" || args_have_long_option "--no-edit" "$@" || args_have_long_option "--no-commit" "$@" || args_have_long_option "--squash" "$@" || args_have_long_option "--ff-only" "$@" || args_have_long_option "--ff" "$@" || merge_has_message_source "$@"); then
        printf '%s\n' 'git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>'
        return
      fi
      ;;
    cherry-pick)
      if ! (args_have_long_option "--continue" "$@" || args_have_long_option "--abort" "$@" || args_have_long_option "--quit" "$@" || args_have_long_option "--skip" "$@" || args_have_long_option "--no-edit" "$@" || args_have_long_option "--no-commit" "$@" || args_have_short_option "n" "$@"); then
        printf '%s\n' 'git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>'
        return
      fi
      ;;
  esac

  printf '__ALLOW__\n'
}

fallback_noninteractive_reason() {
  local raw_command="$1"
  local inherited_has_git_editor="${2:-false}"
  local inherited_has_git_sequence_editor="${3:-false}"
  local token_json token_type token_value reason substitution
  local has_git_editor="$inherited_has_git_editor"
  local has_git_sequence_editor="$inherited_has_git_sequence_editor"
  local shell_has_git_editor="$inherited_has_git_editor"
  local shell_has_git_sequence_editor="$inherited_has_git_sequence_editor"
  local segment_input_has_git_editor
  local segment_input_has_git_sequence_editor
  local segment_input_shell_has_git_editor
  local segment_input_shell_has_git_sequence_editor
  local segment_substitution_indexes=()
  local used_substitution_indexes=()
  local segment=()
  local sanitized_command
  local substitutions=()

  if ! replace_command_substitutions "$raw_command"; then
    printf '%s\n' "$PARSE_ERROR_REASON"
    return
  fi

  sanitized_command="$SANITIZED_COMMAND"
  substitutions=()
  if [ ${#COMMAND_SUBSTITUTIONS[@]} -gt 0 ]; then
    substitutions=("${COMMAND_SUBSTITUTIONS[@]}")
  fi

  local tokenized
  if ! tokenized="$(shell_tokenize "$sanitized_command" true)"; then
    printf '%s\n' "$PARSE_ERROR_REASON"
    return
  fi

  while IFS= read -r token_json; do
    [ -z "$token_json" ] && continue
    token_type="$(printf '%s\n' "$token_json" | jq -r '.type')"
    token_value="$(printf '%s\n' "$token_json" | jq -r '.value')"
    if [ "$token_type" = "control" ]; then
      segment_input_has_git_editor="$has_git_editor"
      segment_input_has_git_sequence_editor="$has_git_sequence_editor"
      segment_input_shell_has_git_editor="$shell_has_git_editor"
      segment_input_shell_has_git_sequence_editor="$shell_has_git_sequence_editor"
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
          reason="$(fallback_noninteractive_reason "${substitutions[$substitution]}" "$segment_input_has_git_editor" "$segment_input_has_git_sequence_editor")"
          if [ "$reason" != "__ALLOW__" ]; then
            printf '%s\n' "$reason"
            return
          fi
        done
      fi
      if [ ${#segment[@]} -gt 0 ]; then
        apply_exported_editor_env_segment \
          "$has_git_editor" \
          "$has_git_sequence_editor" \
          "$shell_has_git_editor" \
          "$shell_has_git_sequence_editor" \
          "${segment[@]}"
        reason="$(evaluate_simple_git_segment "$has_git_editor" "$has_git_sequence_editor" "${segment[@]}")"
      else
        apply_exported_editor_env_segment \
          "$has_git_editor" \
          "$has_git_sequence_editor" \
          "$shell_has_git_editor" \
          "$shell_has_git_sequence_editor"
        reason="$(evaluate_simple_git_segment "$has_git_editor" "$has_git_sequence_editor")"
      fi
      if [ "$reason" != "__ALLOW__" ]; then
        printf '%s\n' "$reason"
        return
      fi
      if control_token_preserves_shell_env "$token_value"; then
        has_git_editor="$PARSED_PERSISTED_HAS_GIT_EDITOR"
        has_git_sequence_editor="$PARSED_PERSISTED_HAS_GIT_SEQUENCE_EDITOR"
        shell_has_git_editor="$PARSED_PERSISTED_SHELL_HAS_GIT_EDITOR"
        shell_has_git_sequence_editor="$PARSED_PERSISTED_SHELL_HAS_GIT_SEQUENCE_EDITOR"
      else
        has_git_editor="$segment_input_has_git_editor"
        has_git_sequence_editor="$segment_input_has_git_sequence_editor"
        shell_has_git_editor="$segment_input_shell_has_git_editor"
        shell_has_git_sequence_editor="$segment_input_shell_has_git_sequence_editor"
      fi
      segment=()
      continue
    fi
    segment+=("$token_value")
  done << EOF
$tokenized
EOF

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
      reason="$(fallback_noninteractive_reason "${substitutions[$substitution]}" "$has_git_editor" "$has_git_sequence_editor")"
      if [ "$reason" != "__ALLOW__" ]; then
        printf '%s\n' "$reason"
        return
      fi
    done
  fi

  if [ ${#segment[@]} -gt 0 ]; then
    apply_exported_editor_env_segment \
      "$has_git_editor" \
      "$has_git_sequence_editor" \
      "$shell_has_git_editor" \
      "$shell_has_git_sequence_editor" \
      "${segment[@]}"
    reason="$(evaluate_simple_git_segment "$has_git_editor" "$has_git_sequence_editor" "${segment[@]}")"
  else
    apply_exported_editor_env_segment \
      "$has_git_editor" \
      "$has_git_sequence_editor" \
      "$shell_has_git_editor" \
      "$shell_has_git_sequence_editor"
    reason="$(evaluate_simple_git_segment "$has_git_editor" "$has_git_sequence_editor")"
  fi
  if [ "$reason" != "__ALLOW__" ]; then
    printf '%s\n' "$reason"
    return
  fi

  for substitution in "${!substitutions[@]}"; do
    if [ ${#used_substitution_indexes[@]} -gt 0 ] && array_contains "$substitution" "${used_substitution_indexes[@]}"; then
      continue
    fi
    reason="$(fallback_noninteractive_reason "${substitutions[$substitution]}" "$inherited_has_git_editor" "$inherited_has_git_sequence_editor")"
    if [ "$reason" != "__ALLOW__" ]; then
      printf '%s\n' "$reason"
      return
    fi
  done

  printf '__ALLOW__\n'
}

# If python3 is unavailable, fall back to a conservative shell parser.
if ! command -v python3 > /dev/null 2>&1; then
  reason="$(fallback_noninteractive_reason "$command")"
  if [ "$reason" = "__ALLOW__" ]; then
    exit 0
  fi
  block "$reason"
fi

if ! decision=$(
  python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git_command_parser.py" noninteractive "$command"
); then
  block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if ! reason=$(echo "$decision" | jq -r '.block // "__ALLOW__"'); then
  block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if [ "$reason" != "__ALLOW__" ]; then
  block "$reason"
fi

exit 0
