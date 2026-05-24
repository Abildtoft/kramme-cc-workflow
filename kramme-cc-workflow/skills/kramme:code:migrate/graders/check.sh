#!/bin/bash
# Structural validation grader for migrate

passed=0
total=2
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

# Check 1: Plan file exists
PLAN=""
for f in migration-plan.md migrate-plan.md plan.md; do
  if [ -f "$f" ]; then
    PLAN="$f"
    break
  fi
done

if [ -n "$PLAN" ]; then
  check "plan-exists" "true" "$PLAN exists"
else
  check "plan-exists" "false" "No migration plan file found"
fi

# Check 2: Plan has substantive content
if [ -n "$PLAN" ]; then
  char_count=$(wc -c < "$PLAN" | tr -d ' ')
  if [ "$char_count" -ge 500 ]; then
    check "plan-length" "true" "Plan has ${char_count} characters"
  else
    check "plan-length" "false" "Plan too short (${char_count} chars, need 500+)"
  fi
else
  check "plan-length" "false" "Cannot check length — no plan file"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
