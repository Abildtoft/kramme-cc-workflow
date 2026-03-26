#!/bin/bash
# Deterministic grader for rewrite-clean

passed=0
total=4
checks="["

check() {
  local name="$1" result="$2" msg="$3"
  if [ "$result" = "true" ]; then
    passed=$((passed + 1))
    checks="${checks}{\"name\":\"${name}\",\"passed\":true,\"message\":\"${msg}\"},"
  else
    checks="${checks}{\"name\":\"${name}\",\"passed\":false,\"message\":\"${msg}\"},"
  fi
}

FILE="src/parser.ts"

# Check 0: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.0,\"details\":\"src/parser.ts not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"src/parser.ts not found\"}]}"
  exit 0
fi

check "file-exists" "true" "src/parser.ts exists"

content=$(cat "$FILE")

# Check 1: File has substantive content
char_count=$(wc -c < "$FILE" | tr -d ' ')
if [ "$char_count" -ge 100 ]; then
  check "has-content" "true" "File has ${char_count} characters"
else
  check "has-content" "false" "File too short (${char_count} chars, need 100+)"
fi

# Check 2: Contains export (still provides public API)
if echo "$content" | grep -q "export"; then
  check "has-exports" "true" "File has exports"
else
  check "has-exports" "false" "No exports found"
fi

# Check 3: No magic number comments (e.g. "34 is", "44 is", "48-57")
if echo "$content" | grep -qE "34 is|44 is|48.57|// 0 means|// 100 means"; then
  check "no-magic-comments" "false" "Still has magic number comments"
else
  check "no-magic-comments" "true" "Magic number comments removed"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
