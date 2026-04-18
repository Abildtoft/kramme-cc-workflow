#!/bin/bash
# Deterministic grader for test generation

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

# Check 0: A test file exists
TEST_FILE=""
for f in src/math.test.ts src/math.spec.ts src/__tests__/math.test.ts src/__tests__/math.spec.ts; do
  if [ -f "$f" ]; then
    TEST_FILE="$f"
    break
  fi
done

if [ -n "$TEST_FILE" ]; then
  check "test-file-exists" "true" "Test file found: $TEST_FILE"
else
  echo "{\"score\":0.0,\"details\":\"No test file found\",\"checks\":[{\"name\":\"test-file-exists\",\"passed\":false,\"message\":\"No *.test.ts or *.spec.ts found in src/\"}]}"
  exit 0
fi

content=$(cat "$TEST_FILE")

# Check 1: File has substantive content (>200 chars)
char_count=$(wc -c < "$TEST_FILE" | tr -d ' ')
if [ "$char_count" -ge 200 ]; then
  check "has-content" "true" "Test file has ${char_count} characters"
else
  check "has-content" "false" "Test file too short (${char_count} chars, need 200+)"
fi

# Check 2: Contains describe or test/it blocks
if echo "$content" | grep -qE "describe\(|it\(|test\("; then
  check "has-test-blocks" "true" "Contains describe/it/test blocks"
else
  check "has-test-blocks" "false" "No describe/it/test blocks found"
fi

# Check 3: Tests the divide function
if echo "$content" | grep -qi "divide"; then
  check "tests-divide" "true" "References divide function"
else
  check "tests-divide" "false" "Does not reference divide function"
fi

# Check 4: Has error/throw test case
if echo "$content" | grep -qi "throw\|error\|toThrow\|rejects"; then
  check "tests-errors" "true" "Contains error/throw test cases"
else
  check "tests-errors" "false" "No error/throw test cases found"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":$score,\"details\":\"$passed/$total passed\",\"checks\":$checks}"
