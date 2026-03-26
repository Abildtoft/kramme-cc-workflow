#!/bin/bash
# Deterministic grader for update-agents-md

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

FILE="AGENTS.md"

# Check 0: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.0,\"details\":\"AGENTS.md not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"AGENTS.md not found\"}]}"
  exit 0
fi

check "file-exists" "true" "AGENTS.md exists"

content=$(cat "$FILE")

# Check 1: Contains "snake_case"
if echo "$content" | grep -q "snake_case"; then
  check "has-snake-case" "true" "Contains snake_case"
else
  check "has-snake-case" "false" "Missing snake_case"
fi

# Check 2: Contains "ALWAYS" (at least 2 — original + new)
always_count=$(echo "$content" | grep -c "ALWAYS" || true)
if [ "$always_count" -ge 2 ]; then
  check "has-always" "true" "Found $always_count ALWAYS directives"
else
  check "has-always" "false" "Only $always_count ALWAYS directive(s) — expected 2+"
fi

# Check 3: Original rules preserved
if echo "$content" | grep -q "TypeScript strict mode"; then
  check "original-preserved" "true" "Original TypeScript strict mode rule preserved"
else
  check "original-preserved" "false" "Original rule about TypeScript strict mode missing"
fi

# Check 4: Contains database/column reference
if echo "$content" | grep -qi "database\|column"; then
  check "has-db-reference" "true" "References database/columns"
else
  check "has-db-reference" "false" "Missing database/column reference"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
