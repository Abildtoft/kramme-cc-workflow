#!/bin/bash
# Deterministic grader for refactor-pass

passed=0
total=3
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

FILE="src/handler.ts"

# Check 0: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.0,\"details\":\"src/handler.ts not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"src/handler.ts not found\"}]}"
  exit 0
fi

check "file-exists" "true" "src/handler.ts exists"

content=$(cat "$FILE")

# Check 1: File has substantive content
char_count=$(wc -c < "$FILE" | tr -d ' ')
if [ "$char_count" -ge 50 ]; then
  check "has-content" "true" "File has ${char_count} characters"
else
  check "has-content" "false" "File too short (${char_count} chars)"
fi

# Check 2: File is shorter than original (original ~2200 chars)
if [ "$char_count" -lt 2200 ]; then
  check "is-shorter" "true" "File is shorter than original (${char_count} vs ~2200)"
else
  check "is-shorter" "false" "File not shorter than original (${char_count} chars)"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
