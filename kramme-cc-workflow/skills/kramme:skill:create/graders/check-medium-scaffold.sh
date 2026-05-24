#!/bin/bash
# Deterministic grader for medium skill scaffolding
# Checks: directory, SKILL.md, references/ dir, frontmatter fields, resource files, line count

passed=0
total=7
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

SKILL_DIR="skills/kramme:code:lint-report"
SKILL_FILE="${SKILL_DIR}/SKILL.md"
REFS_DIR="${SKILL_DIR}/references"

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

# Check 3: references/ directory exists
if [ -d "$REFS_DIR" ]; then
  check "refs-dir" "true" "references/ directory exists"
else
  check "refs-dir" "false" "references/ directory not found"
fi

# Check 4: references/ has at least one file
if [ -d "$REFS_DIR" ]; then
  ref_count=$(find "$REFS_DIR" -type f | wc -l)
  if [ "$ref_count" -gt 0 ]; then
    check "refs-populated" "true" "references/ has ${ref_count} file(s)"
  else
    check "refs-populated" "false" "references/ is empty"
  fi
else
  check "refs-populated" "false" "Cannot check - references/ missing"
fi

# Check 5: Under 500 lines
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

# Check 6: disable-model-invocation is false (auto-triggered)
if [ -f "$SKILL_FILE" ] && grep -q "^disable-model-invocation: false" "$SKILL_FILE"; then
  check "auto-trigger" "true" "disable-model-invocation is false"
else
  check "auto-trigger" "false" "disable-model-invocation should be false for auto-triggered skill"
fi

# Check 7: SKILL.md contains Read instruction referencing resources
if [ -f "$SKILL_FILE" ] && grep -qi "read.*references/" "$SKILL_FILE"; then
  check "jit-loading" "true" "SKILL.md contains JiT Read instruction for references/"
else
  check "jit-loading" "false" "SKILL.md should contain Read instructions for references/ files"
fi

# Remove trailing comma and close array
checks="${checks%,}]"

score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} checks passed\",\"checks\":${checks}}"
