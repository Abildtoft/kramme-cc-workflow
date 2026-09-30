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
EXCLUDE_REVIEW_ARTIFACTS=false
LOCAL_ARTIFACT=""
REVIEW_ARTIFACT_LIST_FILE="$SCRIPT_DIR/../hooks/confirm-review-artifacts.txt"
REVIEW_ARTIFACT_PATTERNS=()

usage() {
  cat >&2 << 'USAGE'
Usage: collect-review-diff.sh [--base <branch-or-ref>] [--base-commit <40-hex-oid>] [--strict|--tolerate-fetch-failure] [--format shell|json|nul] [--exclude-review-artifacts] [--require-local-artifact <path>]
       collect-review-diff.sh --decode-json

Default output is shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES

JSON output fields:
  base_ref base_branch merge_base changed_files

NUL output emits the collected fields directly in this order:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES
Each field has a trailing NUL byte; changed_files remains newline-delimited.
This supports one-invocation, non-evaluating reads with shell read -d ''.

Review-preparation options are opt-in; without them the collected scope and
legacy output formats are unchanged:
  --exclude-review-artifacts     Drop repository-root paths matching
                                 hooks/confirm-review-artifacts.txt from the
                                 collected scope.
  --require-local-artifact PATH  Fail unless PATH is absent or an untracked,
                                 regular, non-symlink local file.

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

emit_nul() {
  printf '%s\0' "$BASE_REF" "$BASE_BRANCH" "$MERGE_BASE" "$CHANGED_FILES"
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
    nul)
      emit_nul
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

# A generated review report is workflow state, never implementation input.
# Only an untracked local copy is eligible as previous-review state: a tracked,
# staged, or otherwise changed copy is branch-controlled input, and a symlink or
# non-regular file can redirect the reader outside the workspace. Fail closed on
# every one of those, so an unreadable trust state can never be read as state.
require_local_review_artifact() {
  local artifact="$1"

  if [ -L "$artifact" ] \
    || { [ -e "$artifact" ] && [ ! -f "$artifact" ]; } \
    || git ls-files --error-unmatch -- "$artifact" > /dev/null 2>&1 \
    || ! git diff --quiet "$MERGE_BASE"...HEAD -- "$artifact" \
    || ! git diff --quiet --cached -- "$artifact" \
    || ! git diff --quiet -- "$artifact"; then
    echo "$artifact must be an untracked local workflow artifact and a regular, non-symlink file; refusing branch-controlled review state." >&2
    exit 1
  fi
}

# The hooks list is the repository's canonical review-artifact inventory. A
# missing or empty list means the caller cannot filter what it asked to filter,
# so stop rather than return an unfiltered scope that silently reads review
# reports as changed content.
load_review_artifact_patterns() {
  local line

  if [ ! -f "$REVIEW_ARTIFACT_LIST_FILE" ]; then
    echo "Review artifact list not found at $REVIEW_ARTIFACT_LIST_FILE; refusing to filter review scope without it." >&2
    exit 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    REVIEW_ARTIFACT_PATTERNS+=("$line")
  done < "$REVIEW_ARTIFACT_LIST_FILE"

  if [ ${#REVIEW_ARTIFACT_PATTERNS[@]} -eq 0 ]; then
    echo "Review artifact list $REVIEW_ARTIFACT_LIST_FILE has no patterns; refusing to filter review scope without them." >&2
    exit 1
  fi
}

# Entries are matched against the repository-root path only, so a same-named
# file nested in a directory stays in review scope as ordinary changed content.
# This is deliberately narrower than hooks/confirm-review-responses.sh, the list's
# other consumer, which also matches basenames in any directory: review skills
# write their reports to the project root, and matching nested paths here would
# silently drop real implementation files from the reviewed scope.
filter_review_artifacts() {
  local changed_file pattern
  local kept=""

  while IFS= read -r changed_file; do
    [ -n "$changed_file" ] || continue
    for pattern in "${REVIEW_ARTIFACT_PATTERNS[@]}"; do
      # shellcheck disable=SC2254
      # Artifact entries intentionally support shell-style globs.
      case "$changed_file" in
        $pattern)
          continue 2
          ;;
      esac
    done
    kept+="${changed_file}"$'\n'
  done <<< "$CHANGED_FILES"

  CHANGED_FILES=${kept%$'\n'}
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
    --exclude-review-artifacts)
      COLLECT_OPTION_SEEN=true
      EXCLUDE_REVIEW_ARTIFACTS=true
      shift
      ;;
    --require-local-artifact)
      COLLECT_OPTION_SEEN=true
      require_value "$1" "${2-}"
      LOCAL_ARTIFACT="$2"
      shift 2
      ;;
    --format)
      COLLECT_OPTION_SEEN=true
      require_value "$1" "${2-}"
      case "$2" in
        shell | json | nul)
          OUTPUT_FORMAT="$2"
          ;;
        *)
          echo "--format must be 'shell', 'json', or 'nul'" >&2
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

if [ "$EXCLUDE_REVIEW_ARTIFACTS" = true ]; then
  load_review_artifact_patterns
fi

RESOLVED=$("$SCRIPT_DIR/resolve-base.sh" --format json "${RESOLVE_ARGS[@]}") || {
  echo "Base resolution failed; see the message above and stop." >&2
  exit 1
}
parse_resolved_json "$RESOLVED"

if [ -n "$LOCAL_ARTIFACT" ]; then
  require_local_review_artifact "$LOCAL_ARTIFACT"
fi

CHANGED_FILES=$({
  git diff --name-only "$MERGE_BASE"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u)

if [ "$EXCLUDE_REVIEW_ARTIFACTS" = true ]; then
  filter_review_artifacts
fi

emit_output
