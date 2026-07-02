#!/bin/bash
# Tiny shell helpers kept for compatibility with tests and thin hook utilities.
# Semantic git/shell parsing lives in hooks/lib/git_command_parser.py.

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
