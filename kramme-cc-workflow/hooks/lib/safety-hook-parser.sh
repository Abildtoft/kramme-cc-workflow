#!/bin/bash

# Shared fail-closed wrapper mechanics for command-safety hooks.

safety_hook_block() {
  local reason="$1"
  echo "$reason" >&2
  exit 2
}

run_safety_hook_parser() {
  local hook_id="$1"
  local parser_mode="$2"
  local python_required_reason="$3"
  local parser_error_reason="$4"
  local input command parser_output reason
  local parser_args=()

  if ! command -v jq > /dev/null 2>&1; then
    echo "$hook_id hook: jq not found; refusing to run safety hook without JSON parsing. Install jq or disable this hook explicitly." >&2
    [ ! -t 0 ] && cat > /dev/null
    exit 2
  fi

  if ! input=$(cat); then
    safety_hook_block "$parser_error_reason"
  fi
  if ! command=$(printf '%s\n' "$input" | jq -er 'if type == "object" then .tool_input.command // "" else error("expected hook input object") end'); then
    safety_hook_block "$parser_error_reason"
  fi

  if [ -z "$command" ]; then
    if [ "$parser_mode" = "commit-contexts" ]; then
      printf '[]\n'
    fi
    return 0
  fi

  if ! command -v python3 > /dev/null 2>&1; then
    safety_hook_block "$python_required_reason"
  fi

  parser_args=("$parser_mode" "$command")
  if [ "$parser_mode" = "commit-contexts" ]; then
    parser_args+=("$parser_error_reason")
  fi
  if ! parser_output=$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git_command_parser.py" "${parser_args[@]}"); then
    safety_hook_block "$parser_error_reason"
  fi

  case "$parser_mode" in
    commit-contexts)
      if ! printf '%s\n' "$parser_output" | jq -e 'if type == "array" then . else error("expected commit context array") end' > /dev/null; then
        safety_hook_block "$parser_error_reason"
      fi
      printf '%s\n' "$parser_output"
      ;;
    noninteractive | rm-rf)
      if ! reason=$(printf '%s\n' "$parser_output" | jq -r 'if type != "object" then error("expected parser decision object") elif has("block") and .block != null and (.block | type) != "string" then error("expected block reason string") else .block // "__ALLOW__" end'); then
        safety_hook_block "$parser_error_reason"
      fi
      if [ "$reason" != "__ALLOW__" ]; then
        safety_hook_block "$reason"
      fi
      ;;
    *)
      safety_hook_block "$parser_error_reason"
      ;;
  esac
}
