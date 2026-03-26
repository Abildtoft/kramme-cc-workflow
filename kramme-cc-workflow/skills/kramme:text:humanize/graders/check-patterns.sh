#!/bin/bash
# Deterministic grader for AI pattern removal
# Checks output.md for absence of known AI writing patterns

passed=0
total=10
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

# Check 1: No em dashes (— or --)
if echo "$content" | grep -qP '\x{2014}|—' 2>/dev/null || echo "$content" | grep -q ' — ' ; then
  check "no-em-dash" "false" "Em dashes still present"
else
  check "no-em-dash" "true" "No em dashes found"
fi

# Check 2: No "Moreover" or "Furthermore"
if echo "$content" | grep -qi "moreover\|furthermore"; then
  check "no-filler-transitions" "false" "Found Moreover/Furthermore"
else
  check "no-filler-transitions" "true" "No Moreover/Furthermore"
fi

# Check 3: No "It's worth noting" or "It is worth mentioning"
if echo "$content" | grep -qi "worth noting\|worth mentioning"; then
  check "no-worth-noting" "false" "Found worth noting/mentioning"
else
  check "no-worth-noting" "true" "No worth noting/mentioning"
fi

# Check 4: No "serves as a testament"
if echo "$content" | grep -qi "serves as a testament\|testament to"; then
  check "no-testament" "false" "Found testament phrase"
else
  check "no-testament" "true" "No testament phrase"
fi

# Check 5: No "It's not just X — it's Y" pattern
if echo "$content" | grep -qi "not just.*it's\|more than.*it's"; then
  check "no-negative-parallelism" "false" "Found negative parallelism pattern"
else
  check "no-negative-parallelism" "true" "No negative parallelism"
fi

# Check 6: No "pivotal" or "paradigm"
if echo "$content" | grep -qi "pivotal\|paradigm"; then
  check "no-ai-buzzwords" "false" "Found pivotal/paradigm"
else
  check "no-ai-buzzwords" "true" "No AI buzzwords (pivotal/paradigm)"
fi

# Check 7: No chatbot sign-off
if echo "$content" | grep -qi "hope this.*helpful\|let me know if"; then
  check "no-chatbot-signoff" "false" "Found chatbot sign-off"
else
  check "no-chatbot-signoff" "true" "No chatbot sign-off"
fi

# Check 8: No "rapidly evolving landscape"
if echo "$content" | grep -qi "rapidly evolving\|evolving landscape"; then
  check "no-landscape" "false" "Found evolving landscape"
else
  check "no-landscape" "true" "No evolving landscape phrase"
fi

# Check 9: Output has substantive content (at least 100 chars)
char_count=${#content}
if [ "$char_count" -ge 100 ]; then
  check "has-content" "true" "Output has ${char_count} characters"
else
  check "has-content" "false" "Output too short (${char_count} chars)"
fi

# Remove trailing comma and close array
checks="${checks%,}]"

score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} AI patterns absent\",\"checks\":${checks}}"
