#!/usr/bin/env bash
#
# Adapted from EveryInc/compound-engineering-plugin:
# plugins/compound-engineering/skills/ce-polish/scripts/read-launch-json.sh
# Reviewed at commit 6f9ab03a031c054a8046659926251fb6c149269f.
# Upstream license: MIT.
#
# Read .claude/launch.json and emit the selected configuration as compact JSON.

set -euo pipefail

PROJECT_ROOT=""
REQUESTED_NAME=""

require_value() {
  local flag="$1"
  local value="${2-}"
  case "$value" in
    "" | --*)
      echo "ERROR: $flag requires a value" >&2
      exit 1
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      require_value "$1" "${2-}"
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    *)
      if [ -z "$REQUESTED_NAME" ]; then
        REQUESTED_NAME="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: not in a git repository and no --root provided" >&2
    exit 1
  fi
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: path does not exist or is not a directory: $PROJECT_ROOT" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

LAUNCH_PATH="$PROJECT_ROOT/.claude/launch.json"

if [ ! -f "$LAUNCH_PATH" ]; then
  echo "__NO_LAUNCH_JSON__"
  exit 0
fi

if ! jq empty "$LAUNCH_PATH" >/dev/null 2>&1; then
  echo "__INVALID_LAUNCH_JSON__"
  exit 0
fi

CONFIG_COUNT=$(jq 'if (.configurations | type) == "array" then .configurations | length else 0 end' "$LAUNCH_PATH")

if [ "$CONFIG_COUNT" = "0" ]; then
  echo "__MISSING_CONFIGURATIONS__"
  exit 0
fi

if [ -n "$REQUESTED_NAME" ]; then
  MATCH=$(jq -c --arg name "$REQUESTED_NAME" 'first(.configurations[] | select(.name == $name)) // empty' "$LAUNCH_PATH")
  if [ -z "$MATCH" ]; then
    echo "__CONFIG_NOT_FOUND__"
    exit 0
  fi
  echo "$MATCH"
  exit 0
fi

if [ "$CONFIG_COUNT" = "1" ]; then
  jq -c '.configurations[0]' "$LAUNCH_PATH"
  exit 0
fi

echo "__MULTIPLE_CONFIGS__"
jq -c '[.configurations[].name]' "$LAUNCH_PATH"
