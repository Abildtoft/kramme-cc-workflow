#!/bin/bash
# LLM-rubric-only skill — this grader is a placeholder for structural validation.
# The real scoring happens via the llm_rubric grader in eval.yaml.

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

# Check 1: Report file exists
if [ -f "agent-readiness-report.md" ]; then
  check "report-exists" "true" "agent-readiness-report.md exists"
else
  check "report-exists" "false" "agent-readiness-report.md not found"
fi

# Check 2: Report has substantive content
if [ -f "agent-readiness-report.md" ]; then
  char_count=$(wc -c < "agent-readiness-report.md" | tr -d ' ')
  if [ "$char_count" -ge 500 ]; then
    check "report-length" "true" "Report has ${char_count} characters"
  else
    check "report-length" "false" "Report too short (${char_count} chars, need 500+)"
  fi
else
  check "report-length" "false" "Cannot check length — file missing"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
