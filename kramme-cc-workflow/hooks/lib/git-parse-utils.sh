#!/bin/bash
# Shared git command parsing utilities used by noninteractive-git.sh
# and confirm-review-responses.sh hooks.

strip_wrapping_quotes() {
  local value="$1"
  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
    \'*\')
      value="${value#\'}"
      value="${value%\'}"
      ;;
  esac
  printf '%s\n' "$value"
}

token_basename() {
  local value
  value="$(strip_wrapping_quotes "$1")"
  printf '%s\n' "${value##*/}"
}

trim_ascii_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

token_is_assignment() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]
}

token_is_shell_alias_builtin() {
  [ "$(token_basename "$1")" = "alias" ]
}

is_shell_keyword_token() {
  case "$(strip_wrapping_quotes "$1")" in
    '!' | if | then | elif | else | fi | do | done | while | until | for | in | case | esac | '{' | '}' | '(' | ')')
      return 0
      ;;
  esac
  return 1
}

array_contains() {
  local wanted="$1"
  shift
  local value

  for value in "$@"; do
    if [ "$value" = "$wanted" ]; then
      return 0
    fi
  done

  return 1
}

control_token_preserves_shell_env() {
  case "$1" in
    ";" | "&&" | "||")
      return 0
      ;;
  esac
  return 1
}

segment_command_substitution_indexes() {
  local token remainder index
  local indexes=()

  for token in "$@"; do
    remainder="$token"
    while [[ "$remainder" =~ __CMD_SUBST_([0-9]+)__ ]]; do
      index="${BASH_REMATCH[1]}"
      if [ ${#indexes[@]} -eq 0 ] || ! array_contains "$index" "${indexes[@]}"; then
        indexes+=("$index")
      fi
      remainder="${remainder#*"${BASH_REMATCH[0]}"}"
    done
  done

  if [ ${#indexes[@]} -gt 0 ]; then
    printf '%s\n' "${indexes[@]}"
  fi
}

extract_shell_inline_command() {
  local value

  while [ $# -gt 0 ]; do
    value="$(strip_wrapping_quotes "$1")"
    case "$value" in
      --)
        return 1
        ;;
      -c | --command)
        shift
        [ $# -gt 0 ] || return 1
        printf '%s\n' "$(strip_wrapping_quotes "$1")"
        return 0
        ;;
      --command=*)
        printf '%s\n' "${value#*=}"
        return 0
        ;;
      --rcfile | --init-file | --startup-file | -o | -O | +O)
        shift
        [ $# -gt 0 ] && shift
        ;;
      --rcfile=* | --init-file=* | --startup-file=*)
        shift
        ;;
      --*)
        shift
        ;;
      -*)
        case "${value#-}" in
          *c*)
            shift
            [ $# -gt 0 ] || return 1
            printf '%s\n' "$(strip_wrapping_quotes "$1")"
            return 0
            ;;
        esac
        shift
        ;;
      +*)
        shift
        ;;
      *)
        return 1
        ;;
    esac
  done

  return 1
}

parse_command_wrapper_token() {
  local value

  PARSED_WRAPPER_ACTION=""
  PARSED_WRAPPER_VALUE=""
  PARSED_WRAPPER_CONSUMED=0

  [ $# -gt 0 ] || {
    PARSED_WRAPPER_ACTION="command"
    return 0
  }

  value="$(strip_wrapping_quotes "$1")"
  case "$value" in
    --)
      PARSED_WRAPPER_ACTION="end_of_options"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -*)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    *)
      PARSED_WRAPPER_ACTION="command"
      ;;
  esac
}

parse_env_wrapper_token() {
  local value

  PARSED_WRAPPER_ACTION=""
  PARSED_WRAPPER_VALUE=""
  PARSED_WRAPPER_CONSUMED=0

  [ $# -gt 0 ] || {
    PARSED_WRAPPER_ACTION="command"
    return 0
  }

  value="$(strip_wrapping_quotes "$1")"
  case "$value" in
    --)
      PARSED_WRAPPER_ACTION="end_of_options"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    [A-Za-z_][A-Za-z0-9_]*=*)
      PARSED_WRAPPER_ACTION="assignment"
      PARSED_WRAPPER_VALUE="$value"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -i | --ignore-environment)
      PARSED_WRAPPER_ACTION="ignore_environment"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -u | --unset)
      PARSED_WRAPPER_ACTION="unset"
      PARSED_WRAPPER_CONSUMED=1
      if [ $# -ge 2 ]; then
        PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "$2")"
        PARSED_WRAPPER_CONSUMED=2
      fi
      ;;
    --unset=*)
      PARSED_WRAPPER_ACTION="unset"
      PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "${value#*=}")"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -u*)
      PARSED_WRAPPER_ACTION="unset"
      PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "${value#-u}")"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -C | --chdir)
      PARSED_WRAPPER_ACTION="chdir"
      PARSED_WRAPPER_CONSUMED=1
      if [ $# -ge 2 ]; then
        PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "$2")"
        PARSED_WRAPPER_CONSUMED=2
      fi
      ;;
    --chdir=*)
      PARSED_WRAPPER_ACTION="chdir"
      PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "${value#*=}")"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -C*)
      PARSED_WRAPPER_ACTION="chdir"
      PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "${value#-C}")"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -*)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    *)
      PARSED_WRAPPER_ACTION="command"
      ;;
  esac
}

parse_sudo_wrapper_token() {
  local value

  PARSED_WRAPPER_ACTION=""
  PARSED_WRAPPER_VALUE=""
  PARSED_WRAPPER_CONSUMED=0

  [ $# -gt 0 ] || {
    PARSED_WRAPPER_ACTION="command"
    return 0
  }

  value="$(strip_wrapping_quotes "$1")"
  case "$value" in
    --)
      PARSED_WRAPPER_ACTION="end_of_options"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -u | -[ugpCRTtrh])
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      [ $# -ge 2 ] && PARSED_WRAPPER_CONSUMED=2
      ;;
    --chdir)
      PARSED_WRAPPER_ACTION="chdir"
      PARSED_WRAPPER_CONSUMED=1
      if [ $# -ge 2 ]; then
        PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "$2")"
        PARSED_WRAPPER_CONSUMED=2
      fi
      ;;
    --user | --group | --host | --prompt | --command-timeout | --close-from | --role | --type | --other-user)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      [ $# -ge 2 ] && PARSED_WRAPPER_CONSUMED=2
      ;;
    --chdir=*)
      PARSED_WRAPPER_ACTION="chdir"
      PARSED_WRAPPER_VALUE="$(strip_wrapping_quotes "${value#*=}")"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    --askpass | --background | --preserve-env | --remove-timestamp | --reset-timestamp | --validate | --version | --list | --non-interactive)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    --host=* | --user=* | --group=* | --prompt=* | --command-timeout=* | --close-from=* | --role=* | --type=* | --other-user=* | --preserve-env=*)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    -*)
      PARSED_WRAPPER_ACTION="option"
      PARSED_WRAPPER_CONSUMED=1
      ;;
    *)
      PARSED_WRAPPER_ACTION="command"
      ;;
  esac
}

parse_git_command_context() {
  # Shared git-command context contract:
  #   PARSED_GIT_PREFIX_ARGS: normalized git global/prefix args
  #   PARSED_GIT_SUBCOMMAND: first non-global-option token after `git`
  #   PARSED_GIT_SUBCOMMAND_ARGS: remaining tokens after the subcommand
  local collect_prefix_args="${1:-false}"
  local collect_command_substitution_prefix="${2:-false}"
  local token value
  shift 2

  PARSED_GIT_PREFIX_ARGS=()
  PARSED_GIT_SUBCOMMAND=""
  PARSED_GIT_SUBCOMMAND_ARGS=()

  while [ $# -gt 0 ]; do
    token="$1"
    value="$(strip_wrapping_quotes "$token")"
    case "$value" in
      --)
        shift
        break
        ;;
      -C | -c | --config-env | --exec-path | --git-dir | --namespace | --super-prefix | --work-tree)
        if [ "$collect_prefix_args" = "true" ]; then
          PARSED_GIT_PREFIX_ARGS+=("$value")
        fi
        if [ $# -ge 2 ]; then
          if [ "$collect_prefix_args" = "true" ]; then
            PARSED_GIT_PREFIX_ARGS+=("$(strip_wrapping_quotes "$2")")
          fi
          shift 2
        else
          shift
        fi
        ;;
      --config-env=* | --exec-path=* | --git-dir=* | --namespace=* | --super-prefix=* | --work-tree=*)
        if [ "$collect_prefix_args" = "true" ]; then
          PARSED_GIT_PREFIX_ARGS+=("${value%%=*}=$(strip_wrapping_quotes "${value#*=}")")
        fi
        shift
        ;;
      -C*)
        if [ "$collect_prefix_args" = "true" ]; then
          PARSED_GIT_PREFIX_ARGS+=("-C" "$(strip_wrapping_quotes "${value#-C}")")
        fi
        shift
        ;;
      -c*)
        if [ "$collect_prefix_args" = "true" ]; then
          PARSED_GIT_PREFIX_ARGS+=("-c" "$(strip_wrapping_quotes "${value#-c}")")
        fi
        shift
        ;;
      -*)
        if [ "$collect_prefix_args" = "true" ]; then
          PARSED_GIT_PREFIX_ARGS+=("$value")
        fi
        shift
        ;;
      __CMD_SUBST_*)
        if [ "$collect_command_substitution_prefix" = "true" ]; then
          if [ "$collect_prefix_args" = "true" ]; then
            PARSED_GIT_PREFIX_ARGS+=("$value")
          fi
          shift
        else
          break
        fi
        ;;
      *)
        break
        ;;
    esac
  done

  if [ $# -gt 0 ]; then
    PARSED_GIT_SUBCOMMAND="$(strip_wrapping_quotes "$1")"
    shift
    PARSED_GIT_SUBCOMMAND_ARGS=("$@")
  fi
}

extract_body_substitutions() {
  # Scan a line for $(...) and `...` substitutions and append them to
  # HEREDOC_BODY_SUBSTITUTIONS. Used for unquoted heredoc bodies, where
  # the shell still performs command substitution.
  local line="$1"
  local length="${#line}"
  local idx=0
  local char

  while [ "$idx" -lt "$length" ]; do
    char="${line:$idx:1}"
    if [ "$char" = '$' ] && [ $((idx + 1)) -lt "$length" ] \
      && [ "${line:$((idx + 1)):1}" = '(' ]; then
      if read_dollar_substitution "$line" "$idx"; then
        HEREDOC_BODY_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
        idx="$SUBSTITUTION_END_INDEX"
        continue
      fi
      return 1
    fi
    if [ "$char" = '`' ]; then
      if read_backtick_substitution "$line" "$idx"; then
        HEREDOC_BODY_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
        idx="$SUBSTITUTION_END_INDEX"
        continue
      fi
      return 1
    fi
    idx=$((idx + 1))
  done
  return 0
}

strip_heredoc_bodies() {
  # Populates STRIPPED_COMMAND and HEREDOC_BODY_SUBSTITUTIONS.
  # Called in the current shell (no subshell) so globals propagate.
  local raw_command="$1"
  local line
  local delimiter=""
  local is_quoted=false
  local is_dashed=false
  local stripped
  local output_lines=()
  # Match quoted delimiters first so we can distinguish them from unquoted.
  # No backreferences — bash ERE does not support them reliably.
  local h_single_pattern='<<(-?)[[:space:]]*'\''([A-Za-z_][A-Za-z0-9_]*)'\'
  local h_double_pattern='<<(-?)[[:space:]]*"([A-Za-z_][A-Za-z0-9_]*)"'
  local h_unquoted_pattern='<<(-?)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)([[:space:]]|$)'

  STRIPPED_COMMAND=""
  HEREDOC_BODY_SUBSTITUTIONS=()

  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$delimiter" ]; then
      stripped="$line"
      if [ "$is_dashed" = "true" ]; then
        # <<- strips leading TABs only (POSIX). Do not strip spaces.
        while [ -n "$stripped" ] && [ "${stripped:0:1}" = $'\t' ]; do
          stripped="${stripped:1}"
        done
      fi
      if [ "$stripped" = "$delimiter" ]; then
        output_lines+=("$line")
        delimiter=""
        is_quoted=false
        is_dashed=false
      else
        if [ "$is_quoted" != "true" ]; then
          # Unquoted heredoc: shell still expands $(...) / `...` in body.
          # Capture substitutions so the parser can inspect them.
          extract_body_substitutions "$line" || return 1
        fi
        output_lines+=("")
      fi
      continue
    fi

    output_lines+=("$line")

    if [[ "$line" =~ $h_single_pattern ]]; then
      delimiter="${BASH_REMATCH[2]}"
      is_quoted=true
      [ -n "${BASH_REMATCH[1]}" ] && is_dashed=true || is_dashed=false
    elif [[ "$line" =~ $h_double_pattern ]]; then
      delimiter="${BASH_REMATCH[2]}"
      is_quoted=true
      [ -n "${BASH_REMATCH[1]}" ] && is_dashed=true || is_dashed=false
    elif [[ "$line" =~ $h_unquoted_pattern ]]; then
      delimiter="${BASH_REMATCH[2]}"
      is_quoted=false
      [ -n "${BASH_REMATCH[1]}" ] && is_dashed=true || is_dashed=false
    fi
  done <<< "$raw_command"

  local joined
  printf -v joined '%s\n' "${output_lines[@]}"
  # Drop the trailing newline that printf adds to the last element.
  STRIPPED_COMMAND="${joined%$'\n'}"
  return 0
}

read_dollar_substitution_end() {
  local raw_command="$1"
  local index="$2"
  local length="${#raw_command}"
  local depth=1
  local char
  local in_single=false
  local in_double=false
  local escaped=false

  index=$((index + 2))

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      escaped=false
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
      escaped=true
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
      if [ "$in_single" = "true" ]; then
        in_single=false
      else
        in_single=true
      fi
      index=$((index + 1))
      continue
    fi

    if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
      if [ "$in_double" = "true" ]; then
        in_double=false
      else
        in_double=true
      fi
      index=$((index + 1))
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
      && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
      depth=$((depth + 1))
      index=$((index + 2))
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$in_double" != "true" ] && [ "$char" = ")" ]; then
      depth=$((depth - 1))
      index=$((index + 1))
      if [ "$depth" -eq 0 ]; then
        SUBSTITUTION_END_INDEX="$index"
        return 0
      fi
      continue
    fi

    index=$((index + 1))
  done

  return 1
}

read_backtick_substitution_end() {
  local raw_command="$1"
  local index="$2"
  local length="${#raw_command}"
  local char
  local escaped=false

  index=$((index + 1))

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      escaped=false
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "\\" ]; then
      escaped=true
      index=$((index + 1))
      continue
    fi

    if [ "$char" = '`' ]; then
      SUBSTITUTION_END_INDEX=$((index + 1))
      return 0
    fi

    index=$((index + 1))
  done

  return 1
}

read_dollar_substitution() {
  local raw_command="$1"
  local index="$2"
  local length="${#raw_command}"
  local depth=1
  local char
  local inner=""
  local in_single=false
  local in_double=false
  local escaped=false

  index=$((index + 2))

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      inner+="$char"
      escaped=false
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
      inner+="$char"
      escaped=true
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
      if [ "$in_single" = "true" ]; then
        in_single=false
      else
        in_single=true
      fi
      inner+="$char"
      index=$((index + 1))
      continue
    fi

    if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
      if [ "$in_double" = "true" ]; then
        in_double=false
      else
        in_double=true
      fi
      inner+="$char"
      index=$((index + 1))
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
      && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
      if ! read_dollar_substitution "$raw_command" "$index"; then
        return 1
      fi
      inner+="\$(${SUBSTITUTION_CONTENT})"
      index="$SUBSTITUTION_END_INDEX"
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$in_double" != "true" ] && [ "$char" = ")" ]; then
      depth=$((depth - 1))
      if [ "$depth" -eq 0 ]; then
        SUBSTITUTION_CONTENT="$inner"
        SUBSTITUTION_END_INDEX=$((index + 1))
        return 0
      fi
    fi

    inner+="$char"
    index=$((index + 1))
  done

  return 1
}

read_backtick_substitution() {
  local raw_command="$1"
  local index="$2"
  local length="${#raw_command}"
  local char
  local inner=""
  local escaped=false

  index=$((index + 1))

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      inner+="$char"
      escaped=false
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "\\" ]; then
      inner+="$char"
      escaped=true
      index=$((index + 1))
      continue
    fi

    if [ "$char" = '`' ]; then
      SUBSTITUTION_CONTENT="$inner"
      SUBSTITUTION_END_INDEX=$((index + 1))
      return 0
    fi

    inner+="$char"
    index=$((index + 1))
  done

  return 1
}

replace_command_substitutions() {
  # strip_heredoc_bodies must run in the current shell so
  # HEREDOC_BODY_SUBSTITUTIONS and STRIPPED_COMMAND propagate.
  if ! strip_heredoc_bodies "$1"; then
    return 1
  fi
  local raw_command="$STRIPPED_COMMAND"
  local length="${#raw_command}"
  local index=0
  local char
  local result=""
  local in_single=false
  local in_double=false
  local escaped=false

  COMMAND_SUBSTITUTIONS=()

  # Substitutions captured from unquoted heredoc bodies still run
  # in the shell; callers must inspect them like any other cmd subst.
  if [ "${#HEREDOC_BODY_SUBSTITUTIONS[@]}" -gt 0 ]; then
    local heredoc_sub
    for heredoc_sub in "${HEREDOC_BODY_SUBSTITUTIONS[@]}"; do
      COMMAND_SUBSTITUTIONS+=("$heredoc_sub")
    done
  fi

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      result+="$char"
      escaped=false
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
      result+="$char"
      escaped=true
      index=$((index + 1))
      continue
    fi

    if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
      if [ "$in_single" = "true" ]; then
        in_single=false
      else
        in_single=true
      fi
      result+="$char"
      index=$((index + 1))
      continue
    fi

    if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
      if [ "$in_double" = "true" ]; then
        in_double=false
      else
        in_double=true
      fi
      result+="$char"
      index=$((index + 1))
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
      && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
      if ! read_dollar_substitution "$raw_command" "$index"; then
        return 1
      fi
      COMMAND_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
      result+="__CMD_SUBST_$((${#COMMAND_SUBSTITUTIONS[@]} - 1))__"
      index="$SUBSTITUTION_END_INDEX"
      continue
    fi

    if [ "$in_single" != "true" ] && [ "$char" = '`' ]; then
      if ! read_backtick_substitution "$raw_command" "$index"; then
        return 1
      fi
      COMMAND_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
      result+="__CMD_SUBST_$((${#COMMAND_SUBSTITUTIONS[@]} - 1))__"
      index="$SUBSTITUTION_END_INDEX"
      continue
    fi

    result+="$char"
    index=$((index + 1))
  done

  SANITIZED_COMMAND="$result"
}

normalize_shell_newlines() {
  local raw_command="$1"
  local length="${#raw_command}"
  local index=0
  local char
  local mode="normal"
  local escaped=false
  local normalized=""

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      normalized+="$char"
      escaped=false
      index=$((index + 1))
      continue
    fi

    case "$mode" in
      single)
        normalized+="$char"
        [ "$char" = "'" ] && mode="normal"
        ;;
      double)
        normalized+="$char"
        if [ "$char" = "\\" ]; then
          escaped=true
        elif [ "$char" = '"' ]; then
          mode="normal"
        fi
        ;;
      *)
        case "$char" in
          "'")
            normalized+="$char"
            mode="single"
            ;;
          '"')
            normalized+="$char"
            mode="double"
            ;;
          "\\")
            normalized+="$char"
            escaped=true
            ;;
          $'\n' | $'\r')
            normalized+=";"
            ;;
          *)
            normalized+="$char"
            ;;
        esac
        ;;
    esac

    index=$((index + 1))
  done

  printf '%s\n' "$normalized"
}

shell_tokenize() {
  local raw_command="$1"
  local split_controls="${2:-false}"
  raw_command="$(normalize_shell_newlines "$raw_command")"
  local length="${#raw_command}"
  local index=0
  local current=""
  local char next
  local mode="normal"
  local escaped=false
  local token_started=false

  while [ "$index" -lt "$length" ]; do
    char="${raw_command:$index:1}"

    if [ "$escaped" = "true" ]; then
      case "$mode" in
        double)
          if [ "$char" = "\\" ] || [ "$char" = '"' ] || [ "$char" = '$' ] || [ "$char" = '`' ]; then
            current+="$char"
          else
            current+="\\$char"
          fi
          ;;
        *)
          current+="$char"
          ;;
      esac
      escaped=false
      token_started=true
      index=$((index + 1))
      continue
    fi

    if [ "$mode" != "single" ]; then
      if [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
        if ! read_dollar_substitution_end "$raw_command" "$index"; then
          return 1
        fi
        current+="__CMD_SUBST__"
        token_started=true
        index="$SUBSTITUTION_END_INDEX"
        continue
      fi

      if [ "$char" = '`' ]; then
        if ! read_backtick_substitution_end "$raw_command" "$index"; then
          return 1
        fi
        current+="__CMD_SUBST__"
        token_started=true
        index="$SUBSTITUTION_END_INDEX"
        continue
      fi
    fi

    case "$mode" in
      single)
        case "$char" in
          "'")
            mode="normal"
            token_started=true
            ;;
          *)
            current+="$char"
            token_started=true
            ;;
        esac
        ;;
      double)
        if [ "$char" = "\\" ]; then
          escaped=true
        elif [ "$char" = '"' ]; then
          mode="normal"
          token_started=true
        else
          current+="$char"
          token_started=true
        fi
        ;;
      *)
        case "$char" in
          [[:space:]])
            if [ "$token_started" = "true" ]; then
              jq -cn --arg value "$current" '{type:"word", value:$value}'
              current=""
              token_started=false
            fi
            ;;
          "'")
            mode="single"
            token_started=true
            ;;
          '"')
            mode="double"
            token_started=true
            ;;
          ';' | '|' | '&' | '(' | ')')
            if [ "$split_controls" = "true" ]; then
              if [ "$token_started" = "true" ]; then
                jq -cn --arg value "$current" '{type:"word", value:$value}'
                current=""
                token_started=false
              fi
              next=""
              if [ $((index + 1)) -lt "$length" ]; then
                next="${raw_command:$((index + 1)):1}"
              fi
              case "$char$next" in
                '&&' | '||' | '|&')
                  jq -cn --arg value "$char$next" '{type:"control", value:$value}'
                  index=$((index + 2))
                  continue
                  ;;
              esac
              jq -cn --arg value "$char" '{type:"control", value:$value}'
            else
              current+="$char"
              token_started=true
            fi
            ;;
          *)
            if [ "$char" = "\\" ]; then
              escaped=true
              token_started=true
            else
              current+="$char"
              token_started=true
            fi
            ;;
        esac
        ;;
    esac

    index=$((index + 1))
  done

  if [ "$escaped" = "true" ] || [ "$mode" != "normal" ]; then
    return 1
  fi

  if [ "$token_started" = "true" ]; then
    jq -cn --arg value "$current" '{type:"word", value:$value}'
  fi
}
