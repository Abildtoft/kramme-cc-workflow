#!/bin/bash
# Deterministic grader for debug:investigate
# Checks that the investigation identifies the wrong comparison operator

shopt -s nullglob

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

# The agent's output is in the conversation transcript, but we can check
# if it modified the file or created a report. Search all .md and .txt files
# for evidence of identifying the bug.

# Check 1: Agent identified the file (src/math.ts or divide mentioned in any output file)
found_file="false"
for f in *.md *.txt; do
  if [ -f "$f" ] && grep -qi "math\.ts\|divide" "$f"; then
    found_file="true"
    break
  fi
done
# Also check if the source file was modified (fix applied)
if [ -f "src/math.ts" ] && grep -q "=== 0\|== 0" "src/math.ts"; then
  found_file="true"
fi
check "identified-file" "$found_file" "Identified math.ts/divide function as bug location"

# Check 2: Agent identified the wrong operator (<= vs ===)
found_operator="false"
for f in *.md *.txt; do
  if [ -f "$f" ] && grep -qiE "<=.*instead.*===|<=.*should.*===|b <= 0|less.than.or.equal|wrong.*(comparison|operator|check|condition)" "$f"; then
    found_operator="true"
    break
  fi
done
# Also check if the fix was applied directly
if [ -f "src/math.ts" ] && grep -q "b === 0" "src/math.ts"; then
  found_operator="true"
fi
check "identified-operator" "$found_operator" "Identified wrong comparison operator (<= instead of ===)"

# Check 3: Agent produced some form of output (report, fix, or investigation log)
has_output="false"
for f in *.md *.txt; do
  if [ -f "$f" ] && [ "$(wc -c < "$f")" -gt 50 ]; then
    has_output="true"
    break
  fi
done
# Fix applied counts as output too
if [ -f "src/math.ts" ] && grep -q "=== 0" "src/math.ts"; then
  has_output="true"
fi
check "has-output" "$has_output" "Produced investigation output or applied fix"

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} checks passed\",\"checks\":${checks}}"
