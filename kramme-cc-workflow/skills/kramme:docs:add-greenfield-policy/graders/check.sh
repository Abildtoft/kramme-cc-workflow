#!/bin/bash
# Deterministic grader for add-greenfield-policy

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

FILE="CLAUDE.md"

# Check 0: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.0,\"details\":\"CLAUDE.md not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"CLAUDE.md not found\"}]}"
  exit 0
fi

check "file-exists" "true" "CLAUDE.md exists"

content=$(cat "$FILE")

# Check 1: File has grown (original was ~300 chars)
char_count=$(wc -c < "$FILE" | tr -d ' ')
if [ "$char_count" -ge 400 ]; then
  check "file-grew" "true" "File has ${char_count} characters (grew from original)"
else
  check "file-grew" "false" "File has ${char_count} chars — may not have been updated"
fi

# Check 2: Contains "greenfield" or "hard-cut" / "Hard-Cut"
if echo "$content" | grep -qi "greenfield\|hard.cut"; then
  check "has-policy-keyword" "true" "Contains greenfield/hard-cut keyword"
else
  check "has-policy-keyword" "false" "Missing greenfield/hard-cut keyword"
fi

# Check 3: Original content preserved (still has stack info)
if echo "$content" | grep -q "Express\|PostgreSQL\|TypeScript"; then
  check "original-preserved" "true" "Original content preserved"
else
  check "original-preserved" "false" "Original content appears to be missing"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
