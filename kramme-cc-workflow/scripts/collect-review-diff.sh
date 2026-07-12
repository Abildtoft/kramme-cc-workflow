#!/usr/bin/env bash
#
# Resolve the PR base and collect the unified review scope:
# committed PR diff, staged local changes, unstaged local changes, and
# untracked files.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

RESOLVE_ARGS=(--strict)
OUTPUT_FORMAT="shell"
DECODE_JSON=false
COLLECT_OPTION_SEEN=false

usage() {
  cat >&2 << 'USAGE'
Usage: collect-review-diff.sh [--base <branch-or-ref>] [--strict|--tolerate-fetch-failure] [--format shell|json]
       collect-review-diff.sh --decode-json

Default output is shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES

JSON output fields:
  base_ref base_branch merge_base changed_files

Decoder mode validates JSON from stdin and emits these four fields once as
NUL-delimited values, with changed_files joined by newlines.
USAGE
}

require_value() {
  local flag="$1"
  local value="${2-}"
  case "$value" in
    "" | --*)
      echo "$flag requires a value" >&2
      exit 1
      ;;
  esac
}

quote_assignment() {
  local name="$1"
  local value="${2-}"
  printf '%s=%q\n' "$name" "$value"
}

emit_json() {
  if ! command -v python3 > /dev/null 2>&1; then
    echo "python3 is required for --format json" >&2
    exit 1
  fi

  BASE_REF="$BASE_REF" \
    BASE_BRANCH="$BASE_BRANCH" \
    MERGE_BASE="$MERGE_BASE" \
    CHANGED_FILES="$CHANGED_FILES" \
    python3 - << 'PY'
import json
import os
import sys

json.dump(
    {
        "base_ref": os.environ.get("BASE_REF", ""),
        "base_branch": os.environ.get("BASE_BRANCH", ""),
        "merge_base": os.environ.get("MERGE_BASE", ""),
        "changed_files": os.environ.get("CHANGED_FILES", "").splitlines(),
    },
    sys.stdout,
    separators=(",", ":"),
)
sys.stdout.write("\n")
PY
}

emit_output() {
  case "$OUTPUT_FORMAT" in
    shell)
      quote_assignment BASE_REF "$BASE_REF"
      quote_assignment BASE_BRANCH "$BASE_BRANCH"
      quote_assignment MERGE_BASE "$MERGE_BASE"
      quote_assignment CHANGED_FILES "$CHANGED_FILES"
      ;;
    json)
      emit_json
      ;;
  esac
}

decode_json() {
  if ! command -v python3 > /dev/null 2>&1; then
    echo "python3 is required to decode collect-review-diff JSON output" >&2
    exit 1
  fi

  python3 3<&0 - << 'PY'
import json
import os
import sys

try:
    with os.fdopen(3, encoding="utf-8") as input_stream:
        data = json.load(input_stream)
except (json.JSONDecodeError, UnicodeDecodeError) as exc:
    print(f"Invalid collect-review-diff JSON output: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print("collect-review-diff JSON output must be an object", file=sys.stderr)
    sys.exit(1)

values = []
for field in ("base_ref", "base_branch", "merge_base"):
    value = data.get(field)
    if not isinstance(value, str):
        print(f"collect-review-diff JSON field '{field}' must be a string", file=sys.stderr)
        sys.exit(1)
    values.append(value)

changed_files = data.get("changed_files")
if not isinstance(changed_files, list) or not all(
    isinstance(item, str) for item in changed_files
):
    print(
        "collect-review-diff JSON field 'changed_files' must be a string list",
        file=sys.stderr,
    )
    sys.exit(1)
values.append("\n".join(changed_files))

for field, value in zip(
    ("base_ref", "base_branch", "merge_base", "changed_files"), values
):
    if "\0" in value:
        print(
            f"collect-review-diff JSON field '{field}' must not contain NUL",
            file=sys.stderr,
        )
        sys.exit(1)

for value in values:
    sys.stdout.buffer.write(value.encode("utf-8") + b"\0")
PY
}

parse_resolved_json() {
  local resolved_json="$1"
  local parsed

  if ! command -v python3 > /dev/null 2>&1; then
    echo "python3 is required to parse resolve-base JSON output" >&2
    exit 1
  fi

  parsed=$(
    RESOLVED_JSON="$resolved_json" python3 - << 'PY'
import json
import os
import sys

try:
    data = json.loads(os.environ["RESOLVED_JSON"])
except (KeyError, json.JSONDecodeError) as exc:
    print(f"Invalid resolve-base JSON output: {exc}", file=sys.stderr)
    sys.exit(1)

for key in ("base_ref", "base_branch", "merge_base"):
    value = data.get(key)
    if not isinstance(value, str):
        print(f"resolve-base JSON field '{key}' must be a string", file=sys.stderr)
        sys.exit(1)
    print(value)
PY
  ) || {
    echo "Base resolution returned malformed JSON; stop." >&2
    exit 1
  }

  BASE_REF=$(printf '%s\n' "$parsed" | sed -n '1p')
  BASE_BRANCH=$(printf '%s\n' "$parsed" | sed -n '2p')
  MERGE_BASE=$(printf '%s\n' "$parsed" | sed -n '3p')
}

while [ $# -gt 0 ]; do
  case "$1" in
    --decode-json)
      DECODE_JSON=true
      shift
      ;;
    --base)
      COLLECT_OPTION_SEEN=true
      require_value "$1" "${2-}"
      RESOLVE_ARGS+=(--base "$2")
      shift 2
      ;;
    --strict)
      COLLECT_OPTION_SEEN=true
      RESOLVE_ARGS+=(--strict)
      shift
      ;;
    --tolerate-fetch-failure)
      COLLECT_OPTION_SEEN=true
      RESOLVE_ARGS+=(--tolerate-fetch-failure)
      shift
      ;;
    --format)
      COLLECT_OPTION_SEEN=true
      require_value "$1" "${2-}"
      case "$2" in
        shell | json)
          OUTPUT_FORMAT="$2"
          ;;
        *)
          echo "--format must be 'shell' or 'json'" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$DECODE_JSON" = true ]; then
  if [ "$COLLECT_OPTION_SEEN" = true ]; then
    echo "--decode-json cannot be combined with collection options" >&2
    exit 1
  fi
  decode_json
  exit 0
fi

RESOLVED=$("$SCRIPT_DIR/resolve-base.sh" --format json "${RESOLVE_ARGS[@]}") || {
  echo "Base resolution failed; see the message above and stop." >&2
  exit 1
}
parse_resolved_json "$RESOLVED"

CHANGED_FILES=$({
  git diff --name-only "$MERGE_BASE"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u)

emit_output
