#!/usr/bin/env bash
#
# Resolve the PR base and collect the unified review scope:
# committed PR diff, staged local changes, unstaged local changes, and
# untracked files.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/shell-helpers.sh
source "$SCRIPT_DIR/lib/shell-helpers.sh"

RESOLVE_ARGS=(--strict)
OUTPUT_FORMAT="shell"
DECODE_JSON=false
COLLECT_OPTION_SEEN=false

usage() {
  cat >&2 << 'USAGE'
Usage: collect-review-diff.sh [--base <branch-or-ref>] [--base-commit <40-hex-oid>] [--strict|--tolerate-fetch-failure] [--format shell|json]
       collect-review-diff.sh --decode-json

Default output is shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES

JSON output fields:
  base_ref base_branch merge_base changed_files

Decoder mode validates JSON from stdin and emits these four fields once as
NUL-delimited values, with changed_files joined by newlines.
USAGE
}

emit_json() {
  emit_json_object \
    "python3 is required for --format json" \
    "str:base_ref" "$BASE_REF" \
    "str:base_branch" "$BASE_BRANCH" \
    "str:merge_base" "$MERGE_BASE" \
    "lines:changed_files" "$CHANGED_FILES"
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
  read_json_string_fields \
    "python3 is required to decode collect-review-diff JSON output" \
    "Invalid collect-review-diff JSON output" \
    "collect-review-diff JSON" \
    nul \
    base_ref base_branch merge_base changed_files:list
}

parse_resolved_json() {
  local resolved_json="$1"
  local decoded

  decoded=$(
    printf '%s' "$resolved_json" | read_json_string_fields \
      "python3 is required to parse resolve-base JSON output" \
      "Invalid resolve-base JSON output" \
      "resolve-base JSON" \
      newline \
      base_ref base_branch merge_base
  ) || {
    echo "Base resolution returned malformed JSON; stop." >&2
    exit 1
  }

  BASE_REF=$(printf '%s\n' "$decoded" | sed -n '1p')
  BASE_BRANCH=$(printf '%s\n' "$decoded" | sed -n '2p')
  MERGE_BASE=$(printf '%s\n' "$decoded" | sed -n '3p')
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
    --base-commit)
      COLLECT_OPTION_SEEN=true
      require_value "$1" "${2-}"
      RESOLVE_ARGS+=(--base-commit "$2")
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
