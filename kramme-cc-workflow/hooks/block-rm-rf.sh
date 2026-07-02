#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: hook exit codes are semantic (exit 2 blocks the tool call); errors must be handled explicitly.
# Hook: Block destructive file deletion commands
# Recommends using 'trash' CLI instead for safer file deletion
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "block-rm-rf" ""

if ! command -v jq > /dev/null 2>&1; then
  echo "block-rm-rf hook: jq not found; refusing to run safety hook without JSON parsing. Install jq or disable this hook explicitly." >&2
  [ ! -t 0 ] && cat > /dev/null
  exit 2
fi
#
# Blocked patterns:
# - rm -rf (and variants: /bin/rm, sudo rm, command rm, env rm, \rm, xargs rm)
# - find -delete
# - find -exec rm -rf
# - shred
# - unlink
# - Subshell execution: sh -c "rm -rf", bash -c "rm -rf"
#
# Allowed:
# - git rm (tracked by git, recoverable)
# - Quoted strings (echo "rm -rf" is safe)
#
# Note: This is a best-effort defense, not a comprehensive security barrier.

# Read JSON input from stdin
input=$(cat)

# Extract the command from tool_input
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Helper: Check if text contains both recursive (-r/-R/--recursive) and force (-f/--force) flags
has_rf_flags() {
  local cmd="$1"
  local has_r=false
  local has_f=false
  echo "$cmd" | grep -qE '(-[a-zA-Z]*[rR]|--recursive)' && has_r=true
  echo "$cmd" | grep -qE '(-[a-zA-Z]*f|--force)' && has_f=true
  $has_r && $has_f
}

# Helper: Output block message and exit
block() {
  local reason="$1"
  echo "$reason" >&2
  exit 2
}

# ============================================================================
# STRIP QUOTED STRINGS (to avoid false positives like echo "rm -rf")
# ============================================================================
strip_quoted_strings() {
  echo "$1" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g'
}

stripped=$(strip_quoted_strings "$command")

# ============================================================================
# BLOCK: rm -rf (and all variants)
# Catches: rm, /bin/rm, /usr/bin/rm, ./rm, command rm, env rm, \rm, sudo rm
# ============================================================================
rm_prefix='(^|[;&|`]\s*|\$\(\s*)'
rm_command_start_prefix='(^|[;&|][[:space:]]*|`[[:space:]]*|\$\([[:space:]]*)$'
rm_backtick_substitution_prefix='`[[:space:]]*$'
rm_variants='(sudo[[:space:]]+)?((command|env)[[:space:]]+|\\)?((/usr)?/?bin/rm|\.\/rm|rm)([[:space:]]|$)'

is_rm_command_start() {
  local text="$1"
  local index="$2"
  local prefix="${text:0:index}"
  local tail="${text:index}"

  [[ "$prefix" =~ $rm_command_start_prefix ]] && [[ "$tail" =~ ^$rm_variants ]]
}

is_backtick_substitution_start() {
  local text="$1"
  local index="$2"
  local prefix="${text:0:index}"

  [[ "$prefix" =~ $rm_backtick_substitution_prefix ]]
}

extract_rm_segment() {
  local text="$1"
  local start="$2"
  local segment=""
  local i="$start"
  local length="${#text}"
  local substitution_depth=0
  local in_nested_backtick=false
  local outer_backtick=false
  local quote=""
  local char
  local next_char

  if is_backtick_substitution_start "$text" "$start"; then
    outer_backtick=true
  fi

  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$in_nested_backtick" == true ]]; then
      segment+="$char"
      if [[ "$char" == '`' ]]; then
        in_nested_backtick=false
      fi
      ((i++))
      continue
    fi

    if [[ "$quote" == "'" ]]; then
      segment+="$char"
      [[ "$char" == "'" ]] && quote=""
      ((i++))
      continue
    fi

    if [[ "$char" == "'" && -z "$quote" ]]; then
      quote="'"
      segment+="$char"
      ((i++))
      continue
    fi

    if [[ "$quote" == '"' && "$char" == '\' && -n "$next_char" ]]; then
      if [[ "$next_char" == $'\n' ]]; then
        segment+=" "
      else
        segment+="$char$next_char"
      fi
      ((i += 2))
      continue
    fi

    if [[ "$char" == '"' ]]; then
      if [[ "$quote" == '"' ]]; then
        quote=""
      elif [[ -z "$quote" ]]; then
        quote='"'
      fi
      segment+="$char"
      ((i++))
      continue
    fi

    if [[ "$char" == '$' && "$next_char" == '(' ]]; then
      segment+='$('
      ((substitution_depth++))
      ((i += 2))
      continue
    fi

    if [[ "$char" == ')' ]]; then
      if (( substitution_depth > 0 )); then
        segment+="$char"
        ((substitution_depth--))
        ((i++))
        continue
      fi
      if [[ -z "$quote" ]]; then
        break
      fi
    fi

    if [[ "$char" == '`' ]]; then
      if (( substitution_depth == 0 )) && [[ "$outer_backtick" == true ]]; then
        break
      fi
      segment+="$char"
      in_nested_backtick=true
      ((i++))
      continue
    fi

    if [[ "$char" == '\' && "$next_char" == $'\n' && "$quote" != "'" ]]; then
      segment+=" "
      ((i += 2))
      continue
    fi

    if [[ -z "$quote" ]] && (( substitution_depth == 0 )) && { [[ "$char" == ';' ]] || [[ "$char" == '&' ]] || [[ "$char" == '|' ]] || [[ "$char" == $'\n' ]]; }; then
      break
    fi

    segment+="$char"
    ((i++))
  done

  printf '%s\n' "$segment"
}

# Keep flag checks scoped to the rm invocation; nested substitutions may contain
# shell separators that should not end the outer rm segment.
has_blocked_rm_segment() {
  local text="$1"
  local segment
  local i

  for (( i = 0; i < ${#text}; i++ )); do
    if is_rm_command_start "$text" "$i"; then
      segment=$(extract_rm_segment "$text" "$i")
      if has_rf_flags "$segment"; then
        return 0
      fi
      ((i += ${#segment} - 1))
    fi
  done

  return 1
}

# Inspect executable strings before treating quoted text as inert: shell command
# payloads and double-quoted substitutions are still executed by the shell.
read_shell_word() {
  local text="$1"
  local start="$2"
  local length="${#text}"
  local i="$start"
  local word=""
  local quote=""
  local char
  local next_char

  while (( i < length )); do
    char="${text:i:1}"
    if [[ "$char" != $' ' && "$char" != $'\t' && "$char" != $'\n' && "$char" != $'\r' ]]; then
      break
    fi
    ((i++))
  done

  if (( i >= length )); then
    return 1
  fi

  char="${text:i:1}"
  if [[ "$char" == ';' || "$char" == '&' || "$char" == '|' || "$char" == ')' ]]; then
    return 1
  fi

  shell_word_start="$i"
  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$quote" == "'" ]]; then
      if [[ "$char" == "'" ]]; then
        quote=""
      else
        word+="$char"
      fi
      ((i++))
      continue
    fi

    if [[ "$quote" == '"' ]]; then
      if [[ "$char" == '"' ]]; then
        quote=""
      elif [[ "$char" == '\' && -n "$next_char" ]]; then
        word+="$next_char"
        ((i += 2))
        continue
      else
        word+="$char"
      fi
      ((i++))
      continue
    fi

    if [[ "$char" == '$' && ( "$next_char" == "'" || "$next_char" == '"' ) ]]; then
      quote="$next_char"
      ((i += 2))
      continue
    fi

    if [[ "$char" == "'" || "$char" == '"' ]]; then
      quote="$char"
      ((i++))
      continue
    fi

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      word+="$next_char"
      ((i += 2))
      continue
    fi

    if [[ "$char" == '$' && "$next_char" == '(' ]]; then
      if extract_dollar_substitution "$text" "$i"; then
        word+="${text:i:command_substitution_end-i}"
        i="$command_substitution_end"
        continue
      fi
    fi

    if [[ "$char" == '`' ]]; then
      if extract_backtick_substitution "$text" "$i"; then
        word+="${text:i:command_substitution_end-i}"
        i="$command_substitution_end"
        continue
      fi
    fi

    if [[ "$char" == $' ' || "$char" == $'\t' || "$char" == $'\n' || "$char" == $'\r' || "$char" == ';' || "$char" == '&' || "$char" == '|' || "$char" == ')' ]]; then
      break
    fi

    word+="$char"
    ((i++))
  done

  shell_word_value="$word"
  shell_word_end="$i"
  return 0
}

is_shell_command_context() {
  local text="$1"
  local index="$2"
  local prefix="${text:0:index}"

  [[ "$prefix" =~ (^|[;\&\|\`\(][[:space:]]*)$ ]]
}

is_shell_command_separator() {
  local char="$1"

  [[ "$char" == ';' || "$char" == '&' || "$char" == '|' || "$char" == '(' || "$char" == '{' || "$char" == $'\n' ]]
}

is_shell_reserved_command_word() {
  local word="$1"

  [[ "$word" == "if" || "$word" == "then" || "$word" == "do" || "$word" == "else" || "$word" == "elif" || "$word" == "while" || "$word" == "until" || "$word" == "case" || "$word" == "in" || "$word" == "esac" || "$word" == "!" || "$word" == "{" ]]
}

has_literal_rm_rf_text() {
  local text="$1"

  echo "$text" | grep -qE '(^|[^[:alnum:]_])rm([^[:alnum:]_]|$)' && has_rf_flags "$text"
}

is_supported_shell_word() {
  local word="$1"
  local basename="${word##*/}"

  [[ "$basename" == "sh" || "$basename" == "bash" || "$basename" == "zsh" ]]
}

is_shell_assignment_word() {
  local word="$1"

  [[ "$word" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]
}

is_env_word() {
  local word="$1"
  local basename="${word##*/}"

  [[ "$basename" == "env" ]]
}

is_simple_shell_prefix_word() {
  local word="$1"
  local basename="${word##*/}"

  [[ "$basename" == "command" || "$basename" == "exec" || "$basename" == "nohup" || "$basename" == "time" || "$basename" == "sudo" || "$basename" == "nice" || "$basename" == "timeout" ]]
}

shell_prefix_requires_initial_operand() {
  local prefix="$1"

  [[ "$prefix" == "timeout" ]]
}

sudo_short_option_takes_separate_operand() {
  local option="$1"
  local chars
  local i
  local flag

  [[ "$option" == --* || "$option" != -* ]] && return 1
  chars="${option#-}"

  for (( i = 0; i < ${#chars}; i++ )); do
    flag="${chars:i:1}"
    case "$flag" in
      u|g|h|p|C|D|R|r|t|T|U)
        (( i == ${#chars} - 1 ))
        return
        ;;
    esac
  done

  return 1
}

prefix_option_takes_operand() {
  local prefix="$1"
  local option="$2"

  case "$prefix" in
    env)
      case "$option" in
        -u|--unset|-C|--chdir|-S|--split-string)
          return 0
          ;;
      esac
      ;;
    sudo)
      if sudo_short_option_takes_separate_operand "$option"; then
        return 0
      fi
      case "$option" in
        -u|-g|-h|-p|-C|-D|-R|-r|-t|-T|-U|--user|--group|--host|--prompt|--chdir|--chroot|--role|--type|--other-user|--close-from|--login-class)
          return 0
          ;;
      esac
      ;;
    time)
      case "$option" in
        -o|-f|--output|--format)
          return 0
          ;;
      esac
      ;;
    nice)
      case "$option" in
        -n|--adjustment)
          return 0
          ;;
      esac
      ;;
    timeout)
      case "$option" in
        -s|--signal|-k|--kill-after)
          return 0
          ;;
      esac
      ;;
    exec)
      [ "$option" = "-a" ] && return 0
      ;;
  esac

  return 1
}

is_env_split_string_option() {
  local option="$1"

  [[ "$option" == "-S" || "$option" == --split-string || "$option" == --split-string=* ]]
}

prefix_option_prevents_execution() {
  local prefix="$1"
  local option="$2"

  case "$prefix:$option" in
    command:-v|command:-V|env:--help|env:--version|sudo:-V|nice:--help|nice:--version|timeout:--help|timeout:--version)
      return 0
      ;;
  esac

  return 1
}

has_c_option() {
  local word="$1"

  [[ "$word" == -* && "$word" != --* && "$word" == *c* ]]
}

shell_option_takes_operand() {
  local option="$1"

  case "$option" in
    -O|+O|-o|+o|--init-file|--rcfile)
      return 0
      ;;
  esac

  return 1
}

shell_invocation_reads_stdin() {
  local text="$1"
  local start="$2"
  local word
  local skip_option_operand=false

  while read_shell_word "$text" "$start"; do
    word="$shell_word_value"
    start="$shell_word_end"

    if [[ "$skip_option_operand" == true ]]; then
      skip_option_operand=false
      continue
    fi

    if has_c_option "$word"; then
      return 1
    fi

    if shell_option_takes_operand "$word"; then
      skip_option_operand=true
      continue
    fi

    if [[ "$word" == "--" ]]; then
      continue
    fi

    if [[ "$word" == -* || "$word" == +* ]]; then
      continue
    fi

    # A script path before the heredoc means the heredoc is data for that
    # script, not necessarily shell source for the interpreter.
    return 1
  done

  return 0
}

line_has_supported_shell_stdin_heredoc() {
  local line="${1%%<<*}"
  local start=0
  local word
  local active_prefix=""
  local skip_prefix_operand=false
  local skip_initial_prefix_operand=false

  while read_shell_word "$line" "$start"; do
    word="$shell_word_value"
    start="$shell_word_end"

    if [[ "$skip_prefix_operand" == true ]]; then
      skip_prefix_operand=false
      continue
    fi

    if is_shell_assignment_word "$word"; then
      continue
    fi

    if [ -n "$active_prefix" ] && [[ "$word" == "--" ]]; then
      continue
    fi

    if is_env_word "$word"; then
      active_prefix="env"
      skip_initial_prefix_operand=false
      continue
    fi

    if [ -n "$active_prefix" ] && [[ "$word" == -* ]]; then
      if [[ "$word" != *=* ]] && prefix_option_takes_operand "$active_prefix" "$word"; then
        skip_prefix_operand=true
      fi
      continue
    fi

    if [[ "$skip_initial_prefix_operand" == true ]]; then
      skip_initial_prefix_operand=false
      continue
    fi

    if is_simple_shell_prefix_word "$word"; then
      active_prefix="${word##*/}"
      skip_initial_prefix_operand=false
      if shell_prefix_requires_initial_operand "$active_prefix"; then
        skip_initial_prefix_operand=true
      fi
      continue
    fi

    if is_supported_shell_word "$word"; then
      shell_invocation_reads_stdin "$line" "$start"
      return
    fi

    if is_shell_reserved_command_word "$word"; then
      continue
    fi

    return 1
  done

  return 1
}

collect_heredoc_delimiters() {
  local line="$1"
  local length="${#line}"
  local i=0
  local quote=""
  local strip_tabs
  local token
  local char
  local next_char

  heredoc_delimiters=()
  heredoc_strip_tabs=()

  while (( i < length )); do
    char="${line:i:1}"
    next_char="${line:i+1:1}"

    if [[ "$quote" == "'" ]]; then
      [[ "$char" == "'" ]] && quote=""
      ((i++))
      continue
    fi

    if [[ "$quote" == '"' ]]; then
      if [[ "$char" == '"' ]]; then
        quote=""
      elif [[ "$char" == '\' && -n "$next_char" ]]; then
        ((i += 2))
        continue
      fi
      ((i++))
      continue
    fi

    if [[ "$char" == "'" || "$char" == '"' ]]; then
      quote="$char"
      ((i++))
      continue
    fi

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      ((i += 2))
      continue
    fi

    if [[ "$char" != '<' || "$next_char" != '<' ]]; then
      ((i++))
      continue
    fi

    # <<< is a here-string, not a heredoc with a body on following lines.
    if [[ "${line:i+2:1}" == '<' ]]; then
      ((i += 3))
      continue
    fi

    strip_tabs=false
    ((i += 2))
    if [[ "${line:i:1}" == '-' ]]; then
      strip_tabs=true
      ((i++))
    fi

    while (( i < length )); do
      char="${line:i:1}"
      if [[ "$char" != $' ' && "$char" != $'\t' ]]; then
        break
      fi
      ((i++))
    done

    token=""
    char="${line:i:1}"
    if [[ "$char" == "'" || "$char" == '"' ]]; then
      quote="$char"
      ((i++))
      while (( i < length )); do
        char="${line:i:1}"
        if [[ "$char" == "$quote" ]]; then
          ((i++))
          break
        fi
        token+="$char"
        ((i++))
      done
      quote=""
    else
      while (( i < length )); do
        char="${line:i:1}"
        if [[ "$char" == $' ' || "$char" == $'\t' || "$char" == ';' || "$char" == '|' || "$char" == '&' || "$char" == '<' || "$char" == '>' ]]; then
          break
        fi
        if [[ "$char" == '\' && -n "${line:i+1:1}" ]]; then
          ((i++))
          char="${line:i:1}"
        fi
        token+="$char"
        ((i++))
      done
    fi

    if [ -z "$token" ]; then
      continue
    fi

    heredoc_delimiters+=("$token")
    if [[ "$strip_tabs" == "true" ]]; then
      heredoc_strip_tabs+=("true")
    else
      heredoc_strip_tabs+=("false")
    fi
  done
}

heredoc_line_matches_delimiter() {
  local line="$1"
  local delimiter="$2"
  local strip_tabs="$3"

  if [[ "$strip_tabs" == "true" ]]; then
    while [[ "$line" == $'\t'* ]]; do
      line="${line:1}"
    done
  fi

  [ "$line" = "$delimiter" ]
}

strip_non_shell_heredoc_bodies() {
  local text="$1"
  local output=""
  local line
  local keep_body
  local i
  local -a pending_delims=()
  local -a pending_keep=()
  local -a pending_strip_tabs=()

  while IFS= read -r line || [ -n "$line" ]; do
    if (( ${#pending_delims[@]} > 0 )); then
      if [[ "${pending_keep[0]}" == "true" ]]; then
        output+="${line}"$'\n'
      fi
      if heredoc_line_matches_delimiter "$line" "${pending_delims[0]}" "${pending_strip_tabs[0]}"; then
        pending_delims=("${pending_delims[@]:1}")
        pending_keep=("${pending_keep[@]:1}")
        pending_strip_tabs=("${pending_strip_tabs[@]:1}")
      fi
      continue
    fi

    output+="${line}"$'\n'
    collect_heredoc_delimiters "$line"
    if (( ${#heredoc_delimiters[@]} > 0 )); then
      keep_body=false
      if line_has_supported_shell_stdin_heredoc "$line"; then
        keep_body=true
      fi
      for (( i = 0; i < ${#heredoc_delimiters[@]}; i++ )); do
        pending_delims+=("${heredoc_delimiters[i]}")
        pending_keep+=("$keep_body")
        pending_strip_tabs+=("${heredoc_strip_tabs[i]}")
      done
    fi
  done <<< "$text"

  printf '%s' "$output"
}

extract_shell_command_payload() {
  local text="$1"
  local start="$2"
  local option_word
  local payload
  local skip_option_operand=false

  while read_shell_word "$text" "$start"; do
    option_word="$shell_word_value"
    start="$shell_word_end"

    if [[ "$skip_option_operand" == true ]]; then
      skip_option_operand=false
      continue
    fi

    if [[ "$option_word" == "--command" ]]; then
      if read_shell_word "$text" "$start"; then
        printf '%s\n' "$shell_word_value"
        return 0
      fi
      return 1
    fi

    if [[ "$option_word" == --command=* ]]; then
      payload="${option_word#--command=}"
      [ -n "$payload" ] && printf '%s\n' "$payload"
      [ -n "$payload" ]
      return
    fi

    if has_c_option "$option_word"; then
      if read_shell_word "$text" "$start"; then
        if [[ "$shell_word_value" == "--" ]] && read_shell_word "$text" "$shell_word_end"; then
          printf '%s\n' "$shell_word_value"
          return 0
        fi
        printf '%s\n' "$shell_word_value"
        return 0
      fi
      return 1
    fi

    if [[ "$option_word" == "--" ]]; then
      return 1
    fi

    if shell_option_takes_operand "$option_word"; then
      skip_option_operand=true
      continue
    fi

    if [[ "$option_word" == -* || "$option_word" == +* ]]; then
      continue
    fi

    return 1
  done

  return 1
}

extract_eval_payload() {
  local text="$1"
  local start="$2"
  local length="${#text}"
  local payload=""
  local char

  while (( start < length )); do
    char="${text:start:1}"
    if [[ "$char" == $' ' || "$char" == $'\t' || "$char" == $'\r' ]]; then
      ((start++))
      continue
    fi
    if [[ "$char" == $'\n' || "$char" == ';' || "$char" == '&' || "$char" == '|' || "$char" == ')' ]]; then
      break
    fi
    if ! read_shell_word "$text" "$start"; then
      break
    fi
    if [ -n "$payload" ]; then
      payload+=" "
    fi
    payload+="$shell_word_value"
    start="$shell_word_end"
  done

  [ -n "$payload" ] && printf '%s\n' "$payload"
  [ -n "$payload" ]
}

extract_prefixed_shell_command_payload() {
  local text="$1"
  local start="$2"
  local word
  local active_prefix=""
  local skip_prefix_operand=false
  local skip_initial_prefix_operand=false
  local split_payload

  while read_shell_word "$text" "$start"; do
    word="$shell_word_value"
    start="$shell_word_end"

    if [[ "$skip_prefix_operand" == true ]]; then
      skip_prefix_operand=false
      continue
    fi

    if is_shell_assignment_word "$word"; then
      continue
    fi

    if [ -n "$active_prefix" ] && [[ "$word" == "--" ]]; then
      continue
    fi

    if is_env_word "$word"; then
      active_prefix="env"
      skip_initial_prefix_operand=false
      continue
    fi

    if [ -n "$active_prefix" ] && [[ "$word" == -* ]]; then
      if prefix_option_prevents_execution "$active_prefix" "$word"; then
        return 1
      fi
      if [[ "$active_prefix" == "env" ]] && is_env_split_string_option "$word"; then
        if [[ "$word" == --split-string=* ]]; then
          split_payload="${word#--split-string=}"
        elif read_shell_word "$text" "$start"; then
          split_payload="$shell_word_value"
          start="$shell_word_end"
        else
          return 1
        fi
        extract_prefixed_shell_command_payload "$split_payload" 0
        return
      fi
      if [[ "$word" != *=* ]] && prefix_option_takes_operand "$active_prefix" "$word"; then
        skip_prefix_operand=true
      fi
      continue
    fi

    if [[ "$skip_initial_prefix_operand" == true ]]; then
      skip_initial_prefix_operand=false
      continue
    fi

    if is_simple_shell_prefix_word "$word"; then
      active_prefix="${word##*/}"
      skip_initial_prefix_operand=false
      if shell_prefix_requires_initial_operand "$active_prefix"; then
        skip_initial_prefix_operand=true
      fi
      continue
    fi

    if is_supported_shell_word "$word"; then
      extract_shell_command_payload "$text" "$start"
      return
    fi

    return 1
  done

  return 1
}

xargs_option_takes_operand() {
  local option="$1"

  case "$option" in
    -I|-i|-J|-L|-n|-P|-s|-E|-a|-d|--replace|--max-lines|--max-args|--max-procs|--max-chars|--eof|--arg-file|--delimiter|--process-slot-var)
      return 0
      ;;
  esac

  return 1
}

xargs_option_has_attached_operand() {
  local option="$1"

  case "$option" in
    -I?*|-i?*|-J?*|-L?*|-n?*|-P?*|-s?*|-E?*|-a?*|-d?*|--replace=*|--max-lines=*|--max-args=*|--max-procs=*|--max-chars=*|--eof=*|--arg-file=*|--delimiter=*|--process-slot-var=*)
      return 0
      ;;
  esac

  return 1
}

extract_xargs_shell_payload() {
  local text="$1"
  local start="$2"
  local word
  local skip_xargs_operand=false

  while read_shell_word "$text" "$start"; do
    word="$shell_word_value"
    start="$shell_word_end"

    if [[ "$skip_xargs_operand" == true ]]; then
      skip_xargs_operand=false
      continue
    fi

    if [[ "$word" == "--" ]]; then
      continue
    fi

    if [[ "$word" == -* ]]; then
      if xargs_option_has_attached_operand "$word"; then
        continue
      fi
      if xargs_option_takes_operand "$word"; then
        skip_xargs_operand=true
      fi
      continue
    fi

    extract_prefixed_shell_command_payload "$text" "$shell_word_start"
    return
  done

  return 1
}

has_blocked_rm_shell_segment() {
  local text="$1"
  local length="${#text}"
  local i=0
  local command_context=true
  local word
  local segment
  local char

  while (( i < length )); do
    char="${text:i:1}"

    if [[ "$char" == $' ' || "$char" == $'\t' || "$char" == $'\r' ]]; then
      ((i++))
      continue
    fi

    if is_shell_command_separator "$char"; then
      command_context=true
      ((i++))
      continue
    fi

    if [[ "$char" == ')' ]]; then
      command_context=true
      ((i++))
      continue
    fi

    if ! read_shell_word "$text" "$i"; then
      ((i++))
      continue
    fi

    word="$shell_word_value"

    if [[ "$command_context" == true ]]; then
      if [[ "${text:shell_word_start}" =~ ^$rm_variants ]]; then
        segment=$(extract_rm_segment "$text" "$shell_word_start")
        if has_rf_flags "$segment"; then
          return 0
        fi
      fi

      if is_shell_reserved_command_word "$word" || is_shell_assignment_word "$word"; then
        command_context=true
      else
        command_context=false
      fi
    else
      command_context=false
    fi

    i="$shell_word_end"
  done

  return 1
}

has_blocked_shell_payload() {
  local text="$1"
  local depth="$2"
  local length="${#text}"
  local i=0
  local command_context=true
  local in_find_command=false
  local next_embedded_shell=false
  local word
  local payload
  local char

  while (( i < length )); do
    char="${text:i:1}"

    if [[ "$char" == $' ' || "$char" == $'\t' || "$char" == $'\r' ]]; then
      ((i++))
      continue
    fi

    if is_shell_command_separator "$char"; then
      command_context=true
      in_find_command=false
      next_embedded_shell=false
      ((i++))
      continue
    fi

    if [[ "$char" == ')' ]]; then
      command_context=true
      ((i++))
      continue
    fi

    if ! read_shell_word "$text" "$i"; then
      ((i++))
      continue
    fi

    word="$shell_word_value"

    if [[ "$next_embedded_shell" == true ]]; then
      payload=$(extract_prefixed_shell_command_payload "$text" "$shell_word_start")
      if [ -n "$payload" ] && has_blocked_rm_in_executable_text "$payload" "$((depth + 1))"; then
        return 0
      fi
      next_embedded_shell=false
    fi

    if [[ "$in_find_command" == true && ( "$word" == "-exec" || "$word" == "-execdir" ) ]]; then
      next_embedded_shell=true
    fi

    if [[ "$command_context" == true ]]; then
      payload=$(extract_prefixed_shell_command_payload "$text" "$shell_word_start")
      if [ -n "$payload" ] && has_blocked_rm_in_executable_text "$payload" "$((depth + 1))"; then
        return 0
      fi

      if [[ "$word" == "find" ]]; then
        in_find_command=true
      fi

      if [[ "$word" == "xargs" ]]; then
        payload=$(extract_xargs_shell_payload "$text" "$shell_word_end")
        if [ -n "$payload" ] && has_blocked_rm_in_executable_text "$payload" "$((depth + 1))"; then
          return 0
        fi
      fi

      if [[ "$word" == "eval" ]]; then
        payload=$(extract_eval_payload "$text" "$shell_word_end")
        if [ -n "$payload" ] && has_blocked_rm_in_executable_text "$payload" "$((depth + 1))"; then
          return 0
        fi
      fi

      if is_shell_reserved_command_word "$word" || is_shell_assignment_word "$word"; then
        command_context=true
      else
        command_context=false
      fi
    else
      command_context=false
    fi

    i="$shell_word_end"
  done

  return 1
}

extract_dollar_substitution() {
  local text="$1"
  local start="$2"
  local length="${#text}"
  local i="$((start + 2))"
  local content_start="$i"
  local depth=1
  local quote=""
  local char
  local next_char

  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      ((i += 2))
      continue
    fi

    if [[ "$quote" == "'" ]]; then
      [[ "$char" == "'" ]] && quote=""
      ((i++))
      continue
    fi

    if [[ "$quote" == '"' ]]; then
      if [[ "$char" == '"' ]]; then
        quote=""
      elif [[ "$char" == '$' && "$next_char" == '(' ]]; then
        ((depth++))
        ((i += 2))
        continue
      elif [[ "$char" == ')' ]]; then
        ((depth--))
        if (( depth == 0 )); then
          command_substitution_content="${text:content_start:i-content_start}"
          command_substitution_end="$((i + 1))"
          return 0
        fi
      fi
      ((i++))
      continue
    fi

    if [[ "$char" == "'" || "$char" == '"' ]]; then
      quote="$char"
      ((i++))
      continue
    fi

    if [[ "$char" == '$' && "$next_char" == '(' ]]; then
      ((depth++))
      ((i += 2))
      continue
    fi

    if [[ "$char" == ')' ]]; then
      ((depth--))
      if (( depth == 0 )); then
        command_substitution_content="${text:content_start:i-content_start}"
        command_substitution_end="$((i + 1))"
        return 0
      fi
    fi

    ((i++))
  done

  return 1
}

extract_backtick_substitution() {
  local text="$1"
  local start="$2"
  local length="${#text}"
  local i="$((start + 1))"
  local content_start="$i"
  local char
  local next_char

  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      ((i += 2))
      continue
    fi

    if [[ "$char" == '`' ]]; then
      command_substitution_content="${text:content_start:i-content_start}"
      command_substitution_end="$((i + 1))"
      return 0
    fi

    ((i++))
  done

  return 1
}

extract_process_substitution() {
  local text="$1"
  local start="$2"
  local length="${#text}"
  local i="$((start + 2))"
  local content_start="$i"
  local depth=1
  local quote=""
  local char
  local next_char

  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      ((i += 2))
      continue
    fi

    if [[ "$quote" == "'" ]]; then
      [[ "$char" == "'" ]] && quote=""
      ((i++))
      continue
    fi

    if [[ "$quote" == '"' ]]; then
      if [[ "$char" == '"' ]]; then
        quote=""
      elif [[ "$char" == '$' && "$next_char" == '(' ]]; then
        ((depth++))
        ((i += 2))
        continue
      elif [[ ( "$char" == '<' || "$char" == '>' ) && "$next_char" == '(' ]]; then
        ((depth++))
        ((i += 2))
        continue
      elif [[ "$char" == ')' ]]; then
        ((depth--))
        if (( depth == 0 )); then
          command_substitution_content="${text:content_start:i-content_start}"
          command_substitution_end="$((i + 1))"
          return 0
        fi
      fi
      ((i++))
      continue
    fi

    if [[ "$char" == "'" || "$char" == '"' ]]; then
      quote="$char"
      ((i++))
      continue
    fi

    if [[ "$char" == '$' && "$next_char" == '(' ]]; then
      ((depth++))
      ((i += 2))
      continue
    fi

    if [[ ( "$char" == '<' || "$char" == '>' ) && "$next_char" == '(' ]]; then
      ((depth++))
      ((i += 2))
      continue
    fi

    if [[ "$char" == ')' ]]; then
      ((depth--))
      if (( depth == 0 )); then
        command_substitution_content="${text:content_start:i-content_start}"
        command_substitution_end="$((i + 1))"
        return 0
      fi
    fi

    ((i++))
  done

  return 1
}

has_blocked_command_substitution() {
  local text="$1"
  local depth="$2"
  local length="${#text}"
  local i=0
  local quote=""
  local char
  local next_char

  while (( i < length )); do
    char="${text:i:1}"
    next_char="${text:i+1:1}"

    if [[ "$char" == '\' && -n "$next_char" ]]; then
      ((i += 2))
      continue
    fi

    if [[ "$quote" == "'" ]]; then
      [[ "$char" == "'" ]] && quote=""
      ((i++))
      continue
    fi

    if [[ "$char" == "'" && "$quote" != '"' ]]; then
      quote="'"
      ((i++))
      continue
    fi

    if [[ "$char" == '"' ]]; then
      if [[ "$quote" == '"' ]]; then
        quote=""
      elif [[ -z "$quote" ]]; then
        quote='"'
      fi
      ((i++))
      continue
    fi

    if [[ "$char" == '$' && "$next_char" == '(' ]]; then
      if extract_dollar_substitution "$text" "$i"; then
        if is_shell_command_context "$text" "$i" && has_literal_rm_rf_text "$command_substitution_content"; then
          return 0
        fi
        if has_blocked_rm_in_executable_text "$command_substitution_content" "$((depth + 1))"; then
          return 0
        fi
        i="$command_substitution_end"
        continue
      fi
    fi

    if [[ "$char" == '`' ]]; then
      if extract_backtick_substitution "$text" "$i"; then
        if is_shell_command_context "$text" "$i" && has_literal_rm_rf_text "$command_substitution_content"; then
          return 0
        fi
        if has_blocked_rm_in_executable_text "$command_substitution_content" "$((depth + 1))"; then
          return 0
        fi
        i="$command_substitution_end"
        continue
      fi
    fi

    if [[ -z "$quote" && ( "$char" == '<' || "$char" == '>' ) && "$next_char" == '(' ]]; then
      if extract_process_substitution "$text" "$i"; then
        if has_blocked_rm_in_executable_text "$command_substitution_content" "$((depth + 1))"; then
          return 0
        fi
        i="$command_substitution_end"
        continue
      fi
    fi

    ((i++))
  done

  return 1
}

has_blocked_rm_in_executable_text() {
  local text="$1"
  local depth="${2:-0}"
  local executable_stripped
  local executable_text

  if (( depth > 5 )); then
    return 1
  fi

  executable_text=$(strip_non_shell_heredoc_bodies "$text")

  if has_blocked_shell_payload "$executable_text" "$depth"; then
    return 0
  fi

  if has_blocked_command_substitution "$executable_text" "$depth"; then
    return 0
  fi

  executable_stripped=$(strip_quoted_strings "$executable_text")
  if has_blocked_rm_shell_segment "$executable_stripped"; then
    return 0
  fi

  has_blocked_rm_segment "$executable_stripped"
}

if has_blocked_rm_in_executable_text "$command"; then
  block "rm -rf is blocked. Use \`trash\` instead (install: brew install trash). Files go to Trash for recovery."
fi

if has_blocked_rm_segment "$stripped"; then
  block "rm -rf is blocked. Use \`trash\` instead (install: brew install trash). Files go to Trash for recovery."
fi

# ============================================================================
# BLOCK: xargs rm -rf
# Catches: find . | xargs rm -rf, ls | xargs rm -rf
# ============================================================================
if echo "$stripped" | grep -qE 'xargs\s+.*\brm\b'; then
  if has_rf_flags "$stripped"; then
    block "xargs rm -rf is blocked. Use \`trash\` instead."
  fi
fi

# ============================================================================
# BLOCK: find -delete (always destructive)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}find\b.*-delete"; then
  block "find -delete is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# BLOCK: find -exec rm -rf
# ============================================================================
if echo "$stripped" | grep -qE 'find\b.*-exec\s+.*\brm\b'; then
  if has_rf_flags "$stripped"; then
    block "find -exec rm -rf is blocked. Use \`trash\` instead."
  fi
fi

# ============================================================================
# BLOCK: shred (secure deletion, no recovery possible)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}(sudo\s+)?(/usr)?(/bin)?/?shred\b"; then
  block "shred is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# BLOCK: unlink (file deletion)
# ============================================================================
if echo "$stripped" | grep -qE "${rm_prefix}(sudo\s+)?(/usr)?(/bin)?/?unlink\b"; then
  block "unlink is blocked. Use \`trash\` instead for recoverable deletion."
fi

# ============================================================================
# ALLOW: Everything else
# ============================================================================
exit 0
