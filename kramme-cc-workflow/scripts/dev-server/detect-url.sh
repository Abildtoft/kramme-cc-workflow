#!/usr/bin/env bash
#
# Local wrapper around the shared dev-server detection scripts. It is inspired
# by the ce-polish detection cascade cited in this directory, but is not copied
# from upstream: this script adds the kramme workflow URL contract.
#
# Output contract:
#   http://localhost:<port>      - one reachable URL was resolved
#   __NO_RUNNING_SERVER__        - no reachable dev server was found
#   __MULTIPLE_URLS__ + lines    - multiple reachable URLs need disambiguation

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=""
EXPLICIT_URL=""
EXPLICIT_PORT=""
PROJECT_TYPE=""
LAUNCH_CONFIG=""
APP_CANDIDATES=""

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
    auto)
      shift
      ;;
    --url)
      require_value "$1" "${2-}"
      EXPLICIT_URL="${2:-}"
      shift 2
      ;;
    --port)
      require_value "$1" "${2-}"
      EXPLICIT_PORT="${2:-}"
      shift 2
      ;;
    --type)
      require_value "$1" "${2-}"
      PROJECT_TYPE="${2:-}"
      shift 2
      ;;
    --launch-config)
      require_value "$1" "${2-}"
      LAUNCH_CONFIG="${2:-}"
      shift 2
      ;;
    *)
      if printf '%s' "$1" | grep -qE '^https?://'; then
        EXPLICIT_URL="$1"
      elif [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: not in a git repository and no path provided" >&2
    exit 1
  fi
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: path does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

is_port() {
  local value="$1"
  case "$value" in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ "$value" -ge 1 ] 2>/dev/null && [ "$value" -le 65535 ] 2>/dev/null
}

verify_url() {
  local url="$1"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || true)
  case "$status" in
    2?? | 3?? | 4??) return 0 ;;
    *) return 1 ;;
  esac
}

try_port() {
  local port="$1"
  if ! is_port "$port"; then
    return 1
  fi
  local url="http://localhost:${port}"
  if verify_url "$url"; then
    printf '%s\n' "$url"
    return 0
  fi
  return 1
}

if [ -n "$EXPLICIT_URL" ]; then
  if ! printf '%s' "$EXPLICIT_URL" | grep -qE '^https?://'; then
    echo "ERROR: explicit URL must start with http:// or https://: $EXPLICIT_URL" >&2
    exit 1
  fi
  if verify_url "$EXPLICIT_URL"; then
    echo "$EXPLICIT_URL"
  else
    echo "__NO_RUNNING_SERVER__"
  fi
  exit 0
fi

if [ -n "$EXPLICIT_PORT" ]; then
  if ! is_port "$EXPLICIT_PORT"; then
    echo "ERROR: explicit port must be between 1 and 65535: $EXPLICIT_PORT" >&2
    exit 1
  fi
  resolved_url=$(try_port "$EXPLICIT_PORT" || true)
  if [ -n "$resolved_url" ]; then
    echo "$resolved_url"
  else
    echo "__NO_RUNNING_SERVER__"
  fi
  exit 0
fi

APP_ROOT="$PROJECT_ROOT"

if [ -z "$PROJECT_TYPE" ]; then
  detected_type=$("$SCRIPT_DIR/detect-project-type.sh" "$PROJECT_ROOT" 2>/dev/null || true)
  case "$detected_type" in
    multiple:*)
      APP_CANDIDATES="${detected_type#multiple:}"
      PROJECT_TYPE=""
      ;;
    *@*)
      PROJECT_TYPE="${detected_type%@*}"
      rel_dir="${detected_type#*@}"
      APP_ROOT="$PROJECT_ROOT/$rel_dir"
      ;;
    multiple*)
      PROJECT_TYPE=""
      ;;
    unknown | "")
      PROJECT_TYPE=""
      ;;
    *)
      PROJECT_TYPE="$detected_type"
      ;;
  esac
fi

LAUNCH_PORT=""
if command -v jq >/dev/null 2>&1; then
  launch_json=$("$SCRIPT_DIR/read-launch-json.sh" --root "$PROJECT_ROOT" "$LAUNCH_CONFIG" 2>/dev/null || true)
  if printf '%s' "$launch_json" | grep -q '^{'; then
    LAUNCH_PORT=$(printf '%s' "$launch_json" | jq -r '.port // empty' 2>/dev/null || true)
  elif printf '%s' "$launch_json" | grep -q '^__MULTIPLE_CONFIGS__$'; then
    launch_urls=""
    while IFS= read -r launch_port; do
      [ -n "$launch_port" ] || continue
      launch_url=$(try_port "$launch_port" || true)
      if [ -n "$launch_url" ] && ! printf '%s\n' "$launch_urls" | grep -Fxq "$launch_url"; then
        launch_urls="${launch_urls}
${launch_url}"
      fi
    done < <(
      jq -r '
        .configurations[]
        | .port // empty
        | select(type == "number" or type == "string")
      ' "$PROJECT_ROOT/.claude/launch.json" 2>/dev/null || true
    )

    launch_urls=$(printf '%s\n' "$launch_urls" | sed '/^$/d')
    launch_count=$(printf '%s\n' "$launch_urls" | sed '/^$/d' | wc -l | tr -d ' ')
    case "$launch_count" in
      0)
        echo "__NO_RUNNING_SERVER__"
        ;;
      1)
        printf '%s\n' "$launch_urls"
        ;;
      *)
        echo "__MULTIPLE_URLS__"
        printf '%s\n' "$launch_urls"
        ;;
    esac
    exit 0
  elif [ -n "$LAUNCH_CONFIG" ]; then
    case "$launch_json" in
      __NO_LAUNCH_JSON__)
        echo "ERROR: .claude/launch.json not found for launch configuration: $LAUNCH_CONFIG" >&2
        ;;
      __INVALID_LAUNCH_JSON__)
        echo "ERROR: .claude/launch.json is invalid" >&2
        ;;
      __MISSING_CONFIGURATIONS__)
        echo "ERROR: .claude/launch.json has no configurations" >&2
        ;;
      __CONFIG_NOT_FOUND__)
        echo "ERROR: launch configuration not found: $LAUNCH_CONFIG" >&2
        ;;
      *)
        echo "ERROR: unable to read launch configuration: $LAUNCH_CONFIG" >&2
        ;;
    esac
    echo "__NO_RUNNING_SERVER__"
    exit 0
  fi
fi

if is_port "$LAUNCH_PORT"; then
  resolved_url=$(try_port "$LAUNCH_PORT" || true)
  if [ -n "$resolved_url" ]; then
    echo "$resolved_url"
    exit 0
  fi
fi

if [ -n "$APP_CANDIDATES" ]; then
  candidate_urls=""
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    case "$candidate" in
      *@*)
        candidate_type="${candidate%@*}"
        candidate_dir="${candidate#*@}"
        candidate_root="$PROJECT_ROOT/$candidate_dir"
        ;;
      *)
        continue
        ;;
    esac

    candidate_port=$("$SCRIPT_DIR/resolve-port.sh" "$candidate_root" --type "$candidate_type" 2>/dev/null || true)
    candidate_url=$(try_port "$candidate_port" || true)
    if [ -n "$candidate_url" ] && ! printf '%s\n' "$candidate_urls" | grep -Fxq "$candidate_url"; then
      candidate_urls="${candidate_urls}
${candidate_url}"
    fi
  done < <(printf '%s\n' "$APP_CANDIDATES" | tr ',' '\n')

  candidate_urls=$(printf '%s\n' "$candidate_urls" | sed '/^$/d')
  candidate_count=$(printf '%s\n' "$candidate_urls" | sed '/^$/d' | wc -l | tr -d ' ')
  case "$candidate_count" in
    0)
      echo "__NO_RUNNING_SERVER__"
      ;;
    1)
      printf '%s\n' "$candidate_urls"
      ;;
    *)
      echo "__MULTIPLE_URLS__"
      printf '%s\n' "$candidate_urls"
      ;;
  esac
  exit 0
fi

RESOLVED_PORT=$("$SCRIPT_DIR/resolve-port.sh" "$APP_ROOT" --type "$PROJECT_TYPE" 2>/dev/null || true)
if is_port "$RESOLVED_PORT"; then
  resolved_url=$(try_port "$RESOLVED_PORT" || true)
  if [ -n "$resolved_url" ]; then
    echo "$resolved_url"
    exit 0
  fi
fi

COMMON_PORTS="3000 3001 4200 4201 4321 5000 5173 5174 8000 8080 8888 9000"
FOUND_URLS=""

for port in $COMMON_PORTS; do
  url=$(try_port "$port" || true)
  if [ -n "$url" ] && ! printf '%s\n' "$FOUND_URLS" | grep -Fxq "$url"; then
    FOUND_URLS="${FOUND_URLS}
${url}"
  fi
done

FOUND_URLS=$(printf '%s\n' "$FOUND_URLS" | sed '/^$/d')
FOUND_COUNT=$(printf '%s\n' "$FOUND_URLS" | sed '/^$/d' | wc -l | tr -d ' ')

case "$FOUND_COUNT" in
  0)
    echo "__NO_RUNNING_SERVER__"
    ;;
  1)
    printf '%s\n' "$FOUND_URLS"
    ;;
  *)
    echo "__MULTIPLE_URLS__"
    printf '%s\n' "$FOUND_URLS"
    ;;
esac
