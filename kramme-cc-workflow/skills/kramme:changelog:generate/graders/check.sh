#!/bin/bash
# Deterministic grader for changelog generation
# Checks: file exists, sufficient content, contains expected sections

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

FILE="CHANGELOG.md"

# Check 1: File exists
if [ ! -f "$FILE" ]; then
  echo "{\"score\":0.00,\"details\":\"CHANGELOG.md not found\",\"checks\":[{\"name\":\"file-exists\",\"passed\":false,\"message\":\"CHANGELOG.md not found\"}]}"
  exit 0
fi
check "file-exists" "true" "CHANGELOG.md exists"

content=$(cat "$FILE")
char_count=${#content}

# Check 2: Has >200 characters
if [ "$char_count" -gt 200 ]; then
  check "min-length" "true" "File has ${char_count} chars (>200)"
else
  check "min-length" "false" "File has ${char_count} chars (need >200)"
fi

# Check 3: Contains feature-related content
if echo "$content" | grep -qi "feat\|feature\|new feature"; then
  check "has-features" "true" "Contains feature references"
else
  check "has-features" "false" "Missing feature references"
fi

# Check 4: Contains fix-related content
if echo "$content" | grep -qi "fix\|bug\|bugfix\|bug fix"; then
  check "has-fixes" "true" "Contains fix/bug references"
else
  check "has-fixes" "false" "Missing fix/bug references"
fi

# Check 5: References PR numbers from the input
if echo "$content" | grep -q "#1[3-4][0-9]\|#142\|#139\|#137\|#136\|#135\|#131"; then
  check "has-pr-numbers" "true" "Contains PR number references"
else
  check "has-pr-numbers" "false" "Missing PR number references"
fi

# Check 6: Mentions at least one contributor name
if echo "$content" | grep -qi "Sarah\|Marcus\|Aisha\|Tom"; then
  check "has-contributors" "true" "Mentions contributor names"
else
  check "has-contributors" "false" "Missing contributor names"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} checks passed\",\"checks\":${checks}}"
