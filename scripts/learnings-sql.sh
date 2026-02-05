#!/bin/bash
# Helpers for safely building sqlite3 queries in learnings commands.

sql_escape() {
  local value="$1"
  value=${value//\'/\'\'}
  printf "%s" "$value"
}

require_numeric() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Invalid $name: $value" >&2
    exit 1
  fi
}

require_optional_numeric() {
  local name="$1"
  local value="$2"
  if [ -n "$value" ] && ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Invalid $name: $value" >&2
    exit 1
  fi
}
