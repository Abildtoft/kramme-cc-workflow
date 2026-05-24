#!/bin/bash
# Structural validation grader for copy-review

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

# Check 1: Report file exists (try common names)
REPORT=""
for f in copy-review-report.md copy-review.md report.md; do
  if [ -f "$f" ]; then
    REPORT="$f"
    break
  fi
done

if [ -n "$REPORT" ]; then
  check "report-exists" "true" "$REPORT exists"
else
  check "report-exists" "false" "No report file found"
fi

# Check 2: Report has substantive content
if [ -n "$REPORT" ]; then
  char_count=$(wc -c < "$REPORT" | tr -d ' ')
  if [ "$char_count" -ge 300 ]; then
    check "report-length" "true" "Report has ${char_count} characters"
  else
    check "report-length" "false" "Report too short (${char_count} chars, need 300+)"
  fi
else
  check "report-length" "false" "Cannot check length — no report file"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
