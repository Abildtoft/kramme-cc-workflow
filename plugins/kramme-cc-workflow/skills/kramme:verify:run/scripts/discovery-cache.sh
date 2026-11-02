#!/usr/bin/env bash
#
# Cache kramme:verify:run's repository-root discovery (steps 1-3) across calls.
#
# The key hashes the content of every root input discovery reads, the paths of
# project markers, and this skill's own files, so any change to them is a miss.
# Records live in .context/verify-run/, which must be Git-ignored: an ignored
# record never changes worktree-tree-id.sh's TREE_ID, and caching is disabled
# otherwise. Cached commands run later, so read and write validate every record.
#
#   key                 print {"enabled", "reason", "key", "path"} as JSON
#   read <key>          print a valid record (exit 0); miss (3); rejected (4)
#   write <key> <file>  validate <file> and save it as the record for <key>

set -euo pipefail

CACHE_VERSION=1
CACHE_DIR=".context/verify-run"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

usage() {
  echo "Usage: discovery-cache.sh key | read <key> | write <key> <record-file>" >&2
}

require_key_arg() {
  if [ -z "${1-}" ] || [[ ! "$1" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Expected a 40-character lowercase key from 'discovery-cache.sh key'" >&2
    exit 1
  fi
}

if command -v jq > /dev/null 2>&1; then
  JQ_AVAILABLE=1
else
  JQ_AVAILABLE=0
fi

json_quote() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  value=${value//$'\b'/\\b}
  value=${value//$'\f'/\\f}
  printf '"%s"' "$value"
}

CALLER_DIR="$PWD"
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null); then
  echo "Not inside a git repository" >&2
  exit 1
fi
cd "$REPO_ROOT"

# Print one "content <name> <blob>" or "path <name>" line per discovery input.
# Skill files are named "skill:<path>" so they never collide with repository paths.
list_inputs() {
  local -a content=()
  local path

  shopt -s nullglob
  for path in AGENTS.md CLAUDE.md .github/copilot-instructions.md .claude/*.md \
    .github/workflows/*.yml .github/workflows/*.yaml azure-pipelines.yml Jenkinsfile \
    .circleci/config.yml nx.json package.json pyproject.toml pytest.ini go.mod Cargo.toml; do
    if [ -f "$path" ]; then
      content+=("$path")
    fi
  done
  shopt -u nullglob

  if [ "${#content[@]}" -gt 0 ]; then
    paste -d $'\t' \
      <(printf '%s\n' "${content[@]}") \
      <(printf '%s\n' "${content[@]}" | git hash-object --no-filters --stdin-paths) \
      | sed $'s/^/content\t/'
  fi

  for path in SKILL.md references/commands-by-project-type.md scripts/discovery-cache.sh; do
    printf 'content\tskill:%s\t%s\n' "$path" "$(git hash-object --no-filters "$SKILL_DIR/$path")"
  done

  git ls-files -co --exclude-standard -- \
    ':(glob)**/project.json' ':(glob)**/*.csproj' ':(glob)**/*.sln' \
    | sed $'s/^/path\t/'
}

compute_key() {
  INPUTS=$(list_inputs | LC_ALL=C sort)
  KEY=$({
    printf 'verify-run-discovery-cache %s\n' "$CACHE_VERSION"
    printf '%s\n' "$INPUTS"
  } | git hash-object --stdin)
  RECORD_PATH="$CACHE_DIR/discovery-$KEY.json"
}

cache_disabled_reason() {
  if [ "$JQ_AVAILABLE" -ne 1 ]; then
    echo "jq is not available"
    return
  fi
  if ! git check-ignore -q "$CACHE_DIR/"; then
    echo "$CACHE_DIR/ is not Git-ignored"
  fi
}

# Print nothing when the record is valid, or the first reason it is not.
validate_record() {
  local file="$1"
  local sources

  if ! jq -e . "$file" > /dev/null 2>&1; then
    echo "record is not valid JSON"
    return
  fi
  sources=$(printf '%s\n' "$INPUTS" | awk -F '\t' '$1 == "content" { print $2 }' | jq -R . | jq -s .)
  jq -r --arg key "$KEY" --argjson version "$CACHE_VERSION" --argjson sources "$sources" '
    def source_ok: type == "string"
      and test("^.+:[1-9][0-9]*$")
      and ((capture("^(?<p>.+):[0-9]+$").p) as $p | $sources | index($p) != null);
    def tier_ok: type == "object" and (.source == null or (.source | source_ok));
    def cwd_ok: type == "string" and length > 0
      and (startswith("/") | not)
      and ((split("/") | index("..")) == null);
    def check_ok: type == "object"
      and (.category | IN("formatting", "linting", "type-checking", "build", "unit", "component", "integration", "e2e"))
      and (.command | type == "string" and length > 0 and (test("[\\n\\r]") | not))
      and (.cwd | cwd_ok)
      and (.tiers | type == "array" and length > 0 and all(.[]; IN("fast", "full")))
      and (.base_scoped | type == "boolean")
      and (.side_effecting | type == "boolean")
      and (.source | source_ok);
    if type != "object" then "record is not an object"
    elif .version != $version then "record version is not \($version)"
    elif .key != $key then "record key does not match the current key"
    elif (.created | type) != "string" then "created is missing"
    elif (.project_type | type) != "string" then "project_type is missing"
    elif ((.tiers | type) != "object" or ((.tiers.fast | tier_ok) and (.tiers.full | tier_ok) | not)) then
      "tiers must name a fast and a full entry whose source is null or a hashed input"
    elif (has("base_branch") | not) or (.base_branch != null and (
      (.base_branch | type) != "object" or (.base_branch.name | type) != "string"
      or (.base_branch.source | source_ok | not))) then
      "base_branch must be null or name a branch with a hashed-input source"
    elif ((.checks | type) != "array" or (.checks | length) == 0) then "checks must be a non-empty array"
    elif (.checks | all(.[]; check_ok) | not) then
      "a check is malformed or its source is not a hashed discovery input"
    elif ((.skipped | type) != "array" or (.skipped | all(.[]; type == "string") | not)) then
      "skipped must be an array of strings"
    else empty end
  ' "$file"
}

case "${1-}" in
  key)
    [ $# -eq 1 ] || {
      usage
      exit 1
    }
    compute_key
    REASON=$(cache_disabled_reason)
    if [ "$JQ_AVAILABLE" -eq 1 ]; then
      jq -n --arg reason "$REASON" --arg key "$KEY" --arg path "$REPO_ROOT/$RECORD_PATH" \
        '{enabled: ($reason == ""), reason: $reason, key: $key, path: $path}'
    else
      printf '{"enabled":false,"reason":'
      json_quote "$REASON"
      printf ',"key":'
      json_quote "$KEY"
      printf ',"path":'
      json_quote "$REPO_ROOT/$RECORD_PATH"
      printf '}\n'
    fi
    ;;
  read)
    [ $# -eq 2 ] || {
      usage
      exit 1
    }
    require_key_arg "$2"
    compute_key
    if [ "$2" != "$KEY" ]; then
      echo "Key $2 is stale; discovery inputs changed since it was computed" >&2
      exit 3
    fi
    if [ -n "$(git ls-files --cached -- "$RECORD_PATH")" ]; then
      echo "Rejected $RECORD_PATH: the record is tracked by Git" >&2
      exit 4
    fi
    if [ -n "$(cache_disabled_reason)" ] || [ ! -f "$RECORD_PATH" ]; then
      exit 3
    fi
    PROBLEM=$(validate_record "$RECORD_PATH")
    if [ -n "$PROBLEM" ]; then
      echo "Rejected $RECORD_PATH: $PROBLEM" >&2
      exit 4
    fi
    jq . "$RECORD_PATH"
    ;;
  write)
    [ $# -eq 3 ] || {
      usage
      exit 1
    }
    require_key_arg "$2"
    SOURCE_FILE="$3"
    case "$SOURCE_FILE" in
      /*) ;;
      *) SOURCE_FILE="$CALLER_DIR/$SOURCE_FILE" ;;
    esac
    [ -f "$SOURCE_FILE" ] || {
      echo "Record file not found: $3" >&2
      exit 1
    }
    compute_key
    if [ "$2" != "$KEY" ]; then
      echo "Refusing to save: key $2 is stale; discovery inputs changed since it was computed" >&2
      exit 1
    fi
    REASON=$(cache_disabled_reason)
    if [ -n "$REASON" ]; then
      echo "Refusing to save: cache disabled ($REASON)" >&2
      exit 1
    fi
    PROBLEM=$(validate_record "$SOURCE_FILE")
    if [ -n "$PROBLEM" ]; then
      echo "Refusing to save: $PROBLEM" >&2
      exit 1
    fi
    mkdir -p "$CACHE_DIR"
    TMP_FILE=$(mktemp "$CACHE_DIR/.discovery.XXXXXX")
    jq . "$SOURCE_FILE" > "$TMP_FILE"
    mv -f "$TMP_FILE" "$RECORD_PATH"
    echo "$REPO_ROOT/$RECORD_PATH"
    ;;
  *)
    usage
    exit 1
    ;;
esac
