#!/bin/bash
# Deterministic grader for visual:project-recap
# Checks output.html exists, has sufficient content, contains expected HTML elements

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

OUTPUT="output.html"

# Check 1: File exists
if [ -f "$OUTPUT" ]; then
  check "file-exists" "true" "output.html exists"
else
  check "file-exists" "false" "output.html not found"
  checks="${checks%,}]"
  echo "{\"score\":0.00,\"details\":\"0/${total} passed\",\"checks\":${checks}}"
  exit 0
fi

content=$(cat "$OUTPUT")
char_count=${#content}

# Check 2: Has >1000 characters
if [ "$char_count" -gt 1000 ]; then
  check "min-length" "true" "File has ${char_count} characters (>1000)"
else
  check "min-length" "false" "File has ${char_count} characters (need >1000)"
fi

# Check 3: Contains <html tag
if echo "$content" | grep -qi '<html'; then
  check "has-html-tag" "true" "Contains <html tag"
else
  check "has-html-tag" "false" "Missing <html tag"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
