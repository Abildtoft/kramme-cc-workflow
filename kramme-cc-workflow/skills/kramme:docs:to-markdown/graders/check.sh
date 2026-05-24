#!/bin/bash
# Deterministic grader for HTML-to-markdown conversion

passed=0
total=5
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

OUTPUT="output.md"

# Check 0: Output file exists
if [ ! -f "$OUTPUT" ]; then
  echo "{\"score\":0.0,\"details\":\"output.md not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"output.md not found\"}]}"
  exit 0
fi

check "file-exists" "true" "output.md exists"

content=$(cat "$OUTPUT")

# Check 1: Has markdown heading
if echo "$content" | grep -q "^# "; then
  check "has-heading" "true" "Contains markdown heading (# )"
else
  check "has-heading" "false" "No markdown heading found"
fi

# Check 2: Has list items (- or *)
if echo "$content" | grep -qE "^[[:space:]]*(- |\* )"; then
  check "has-list-items" "true" "Contains list items"
else
  check "has-list-items" "false" "No list items found"
fi

# Check 3: Has substantive content (>100 chars)
char_count=$(wc -c < "$OUTPUT" | tr -d ' ')
if [ "$char_count" -ge 100 ]; then
  check "has-content" "true" "File has ${char_count} characters"
else
  check "has-content" "false" "File too short (${char_count} chars, need 100+)"
fi

# Check 4: Contains table separator (|---|)
if echo "$content" | grep -qE "\|[-:]+\|"; then
  check "has-table" "true" "Contains markdown table syntax"
else
  check "has-table" "false" "No markdown table found"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
