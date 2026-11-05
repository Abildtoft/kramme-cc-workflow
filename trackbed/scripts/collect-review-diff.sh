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
BASE_SELECTED=false
STACK_CONTEXT_MODE=false
STACK_CONTEXT=""
REVIEW_ARTIFACT_LIST_FILE="$SCRIPT_DIR/../hooks/confirm-review-artifacts.txt"
REVIEW_ARTIFACT_PATTERNS=()

usage() {
  cat >&2 << 'USAGE'
Usage: collect-review-diff.sh [--base <branch-or-ref-or-40-hex-oid>] [--base-commit <40-hex-oid>] [--strict|--tolerate-fetch-failure] [--format shell|json|nul] [--exclude-review-artifacts] [--require-local-artifact <path>] [--stack-context]
       collect-review-diff.sh --decode-json

Default output is shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES [STACK_CONTEXT]

JSON output fields:
  base_ref base_branch merge_base changed_files [stack_context]

NUL output emits the collected fields directly in this order:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES STACK_CONTEXT
Each field has a trailing NUL byte; changed_files remains newline-delimited.
STACK_CONTEXT is empty unless --stack-context was given.
This supports one-invocation, non-evaluating reads with shell read -d ''.

Review-preparation options are opt-in; without them the collected scope and
legacy output formats are unchanged:
  --exclude-review-artifacts     Drop repository-root paths matching
                                 hooks/confirm-review-artifacts.txt from the
                                 collected scope.
  --require-local-artifact PATH  Fail unless PATH is absent or an untracked,
                                 regular, non-symlink local file.
  --stack-context                Describe the branch's Pull Request stack
                                 with resolve-stack-context.py and return it
                                 as the STACK_CONTEXT JSON document. Without
                                 an explicit --base or --base-commit, review
                                 a gh-stack layer that has no open Pull
                                 Request, or that needs a restack, against
                                 the base its stack context names. A helper
                                 failure is reported as an unknown stack,
                                 never as a collection failure.

Decoder mode validates JSON from stdin and emits these four fields once as
NUL-delimited values, with changed_files joined by newlines.
USAGE
}

emit_json() {
  local fields=(
    "str:base_ref" "$BASE_REF"
    "str:base_branch" "$BASE_BRANCH"
    "str:merge_base" "$MERGE_BASE"
    "lines:changed_files" "$CHANGED_FILES"
  )
  [ "$STACK_CONTEXT_MODE" = false ] || fields+=("json:stack_context" "$STACK_CONTEXT")
  emit_json_object "python3 is required for --format json" "${fields[@]}"
}

emit_nul() {
  printf '%s\0' "$BASE_REF" "$BASE_BRANCH" "$MERGE_BASE" "$CHANGED_FILES" "$STACK_CONTEXT"
}

emit_output() {
  case "$OUTPUT_FORMAT" in
    shell)
      quote_assignment BASE_REF "$BASE_REF"
      quote_assignment BASE_BRANCH "$BASE_BRANCH"
      quote_assignment MERGE_BASE "$MERGE_BASE"
      quote_assignment CHANGED_FILES "$CHANGED_FILES"
      [ "$STACK_CONTEXT_MODE" = false ] || quote_assignment STACK_CONTEXT "$STACK_CONTEXT"
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

# Stack context informs review scope and calibration but never blocks a
# review. If the helper itself fails, record an unknown stack with the reason
# so the review proceeds against the default base and says why.
resolve_stack_context() {
  local helper_output helper_stderr helper_status=0

  helper_stderr=$(mktemp "${TMPDIR:-/tmp}/collect-review-diff-stack.XXXXXX") || {
    echo "Could not create a temporary file for stack context; stop." >&2
    exit 1
  }
  helper_output=$(python3 "$SCRIPT_DIR/resolve-stack-context.py" 2> "$helper_stderr") || helper_status=$?
  STACK_CONTEXT=$(
    HELPER_STATUS="$helper_status" HELPER_STDERR="$(cat "$helper_stderr")" python3 -c '
import json
import os
import sys

status = os.environ["HELPER_STATUS"]
try:
    context = json.loads(sys.stdin.read()) if status == "0" else None
except ValueError:
    context = None
if not (isinstance(context, dict) and context.get("state") in ("stacked", "unstacked", "unknown")):
    detail = " ".join(os.environ["HELPER_STDERR"].split())[-300:] or "exit " + status
    reason = "the stack context helper failed: " + detail
    context = {
        "schema_version": 1,
        "state": "unknown",
        "reason": reason,
        "review_base": None,
        "summary": "Stack status unknown: " + reason + ".",
    }
json.dump(context, sys.stdout, separators=(",", ":"))
' <<< "$helper_output"
  ) || {
    rm -f "$helper_stderr"
    echo "Could not record the stack context; stop." >&2
    exit 1
  }
  rm -f "$helper_stderr"
}

# The default base resolution cannot scope a gh-stack layer that has no open
# Pull Request, or one whose parent changed since its last restack; review it
# against the base its stack context names. The commit pins the newest
# downstack commit without fetching. Branch names and object IDs never contain
# tabs, so a tab-separated pair is unambiguous even when the commit is empty.
apply_stack_review_base() {
  local review_base review_branch review_commit

  review_base=$(printf '%s' "$STACK_CONTEXT" | python3 -c '
import json
import sys

base = json.load(sys.stdin).get("review_base")
if isinstance(base, dict) and isinstance(base.get("branch"), str) and base["branch"]:
    commit = base.get("commit")
    print(base["branch"] + "\t" + (commit if isinstance(commit, str) else ""))
') || {
    echo "Could not read the stack review base; stop." >&2
    exit 1
  }
  [ -n "$review_base" ] || return 0
  IFS=$'\t' read -r review_branch review_commit <<< "$review_base"
  RESOLVE_ARGS+=(--base "refs/heads/$review_branch")
  [ -z "$review_commit" ] || RESOLVE_ARGS+=(--base-commit "$review_commit")
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
      BASE_SELECTED=true
      require_value "$1" "${2-}"
      RESOLVE_ARGS+=(--base "$2")
      shift 2
      ;;
    --base-commit)
      COLLECT_OPTION_SEEN=true
      BASE_SELECTED=true
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
    --stack-context)
      COLLECT_OPTION_SEEN=true
      STACK_CONTEXT_MODE=true
      shift
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

if [ "$STACK_CONTEXT_MODE" = true ]; then
  resolve_stack_context
  [ "$BASE_SELECTED" = true ] || apply_stack_review_base
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
