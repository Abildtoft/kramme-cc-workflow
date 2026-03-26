#!/bin/bash
# Deterministic grader for simple skill scaffolding
# Checks: directory exists, SKILL.md exists, frontmatter fields present, line count

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

SKILL_DIR="skills/kramme:text:word-count"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

# Check 1: Directory exists
if [ -d "$SKILL_DIR" ]; then
  check "dir-exists" "true" "Skill directory exists"
else
  check "dir-exists" "false" "Skill directory not found at ${SKILL_DIR}"
fi

# Check 2: SKILL.md exists
if [ -f "$SKILL_FILE" ]; then
  check "file-exists" "true" "SKILL.md exists"
else
  check "file-exists" "false" "SKILL.md not found"
fi

# Check 3: Under 500 lines
if [ -f "$SKILL_FILE" ]; then
  lines=$(wc -l < "$SKILL_FILE")
  if [ "$lines" -le 500 ]; then
    check "line-count" "true" "SKILL.md is ${lines} lines (under 500)"
  else
    check "line-count" "false" "SKILL.md is ${lines} lines (over 500)"
  fi
else
  check "line-count" "false" "Cannot check lines - file missing"
fi

# Check 4: Has name field in frontmatter
if [ -f "$SKILL_FILE" ] && grep -q "^name:" "$SKILL_FILE"; then
  check "has-name" "true" "Frontmatter has name field"
else
  check "has-name" "false" "Frontmatter missing name field"
fi

# Check 5: Has description field
if [ -f "$SKILL_FILE" ] && grep -q "^description:" "$SKILL_FILE"; then
  check "has-description" "true" "Frontmatter has description field"
else
  check "has-description" "false" "Frontmatter missing description field"
fi

# Check 6: Has disable-model-invocation field
if [ -f "$SKILL_FILE" ] && grep -q "^disable-model-invocation:" "$SKILL_FILE"; then
  check "has-disable-model" "true" "Frontmatter has disable-model-invocation field"
else
  check "has-disable-model" "false" "Frontmatter missing disable-model-invocation field"
fi

# Remove trailing comma and close array
checks="${checks%,}]"

score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} checks passed\",\"checks\":${checks}}"
