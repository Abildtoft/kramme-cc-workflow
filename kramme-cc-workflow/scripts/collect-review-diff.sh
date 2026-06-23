#!/usr/bin/env bash
#
# Resolve the PR base and collect the unified review scope:
# committed PR diff, staged local changes, unstaged local changes, and
# untracked files.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

RESOLVE_ARGS=(--strict)

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

parse_resolved_json() {
	local resolved_json="$1"
	local parsed

	if ! command -v python3 >/dev/null 2>&1; then
		echo "python3 is required to parse resolve-base JSON output" >&2
		exit 1
	fi

	parsed=$(RESOLVED_JSON="$resolved_json" python3 - <<'PY'
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
	--base)
		require_value "$1" "${2-}"
		RESOLVE_ARGS+=(--base "$2")
		shift 2
		;;
	--strict)
		RESOLVE_ARGS+=(--strict)
		shift
		;;
	--tolerate-fetch-failure)
		RESOLVE_ARGS+=(--tolerate-fetch-failure)
		shift
		;;
	-h | --help)
		cat >&2 <<'USAGE'
Usage: collect-review-diff.sh [--base <branch-or-ref>] [--strict|--tolerate-fetch-failure]

Outputs shell-quoted assignments:
  BASE_REF BASE_BRANCH MERGE_BASE CHANGED_FILES
USAGE
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
done

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

quote_assignment BASE_REF "$BASE_REF"
quote_assignment BASE_BRANCH "$BASE_BRANCH"
quote_assignment MERGE_BASE "$MERGE_BASE"
quote_assignment CHANGED_FILES "$CHANGED_FILES"
