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
# CHECK SUBSHELL EXECUTION (before stripping quotes, since rm is inside quotes)
# sh -c "rm -rf", bash -c "rm -rf", zsh -c "rm -rf"
# ============================================================================
if echo "$command" | grep -qE '(bash|sh|zsh)\s+-c\s+'; then
  # Extract content inside quotes after -c
  # Handles both "..." and '...' quoting styles
  subshell_content=$(echo "$command" | grep -oE "(bash|sh|zsh)\s+-c\s+[\"'][^\"']+[\"']" | sed "s/.*-c\s*[\"']//" | sed "s/[\"']$//")
  if [ -n "$subshell_content" ]; then
    if echo "$subshell_content" | grep -qE '\brm\b' && has_rf_flags "$subshell_content"; then
      block "Subshell rm -rf is blocked. Use \`trash\` instead (install: brew install trash)."
    fi
  fi
fi

# ============================================================================
# STRIP QUOTED STRINGS (to avoid false positives like echo "rm -rf")
# ============================================================================
stripped=$(echo "$command" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g')

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
      break
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

    if (( substitution_depth == 0 )) && { [[ "$char" == ';' ]] || [[ "$char" == '&' ]] || [[ "$char" == '|' ]]; }; then
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
