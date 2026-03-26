#!/bin/bash
# Deterministic grader for AI slop cleanup

passed=0
total=6
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

FILE="src/utils.ts"

# Check 0: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.0,\"details\":\"src/utils.ts not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"src/utils.ts not found\"}]}"
  exit 0
fi

check "file-exists" "true" "src/utils.ts exists"

content=$(cat "$FILE")

# Check 1: No "// Initialize the variable" style comments
if echo "$content" | grep -qi "// Initialize the variable"; then
  check "no-restating-comments" "false" "Still has '// Initialize the variable'"
else
  check "no-restating-comments" "true" "Restating comment removed"
fi

# Check 2: No ": any" type annotations (allow rare legitimate uses, but original has many)
any_count=$(echo "$content" | grep -c ": any" || true)
if [ "$any_count" -le 1 ]; then
  check "no-any-types" "true" "At most 1 any annotation remaining (found $any_count)"
else
  check "no-any-types" "false" "Still has $any_count ': any' annotations"
fi

# Check 3: No "// Return the result" or "// Return the formatted date" comments
if echo "$content" | grep -qi "// Return the result\|// Return the formatted date\|// Return false\|// Return a personalized"; then
  check "no-return-comments" "false" "Still has '// Return the...' restating comments"
else
  check "no-return-comments" "true" "Return-restating comments removed"
fi

# Check 4: File has substantive content (not gutted)
char_count=$(wc -c < "$FILE" | tr -d ' ')
if [ "$char_count" -ge 50 ]; then
  check "has-content" "true" "File has ${char_count} characters"
else
  check "has-content" "false" "File too short (${char_count} chars)"
fi

# Check 5: Exported functions still present
missing_exports=""
for fn in formatDate add isEmpty capitalize compact greet; do
  if ! echo "$content" | grep -q "export.*function $fn\|export.*const $fn\|export.*$fn"; then
    missing_exports="$missing_exports $fn"
  fi
done
if [ -z "$missing_exports" ]; then
  check "exports-preserved" "true" "All exported functions present"
else
  check "exports-preserved" "false" "Missing exports:$missing_exports"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
