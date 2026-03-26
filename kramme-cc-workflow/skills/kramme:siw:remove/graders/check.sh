#!/bin/bash
# Deterministic grader for kramme:siw:remove
# Checks: LOG.md gone, OPEN_ISSUES_OVERVIEW.md gone, issues/ gone or empty, SPEC.md gone

passed=0
total=4
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

# Check 1: siw/LOG.md does not exist
if [ -f "siw/LOG.md" ]; then
  check "log-removed" "false" "siw/LOG.md still exists"
else
  check "log-removed" "true" "siw/LOG.md removed"
fi

# Check 2: siw/OPEN_ISSUES_OVERVIEW.md does not exist
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  check "overview-removed" "false" "siw/OPEN_ISSUES_OVERVIEW.md still exists"
else
  check "overview-removed" "true" "siw/OPEN_ISSUES_OVERVIEW.md removed"
fi

# Check 3: siw/issues/ does not exist or is empty
if [ -d "siw/issues" ]; then
  issue_count=$(find siw/issues -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$issue_count" -eq 0 ]; then
    check "issues-removed" "true" "siw/issues/ is empty (no .md files)"
  else
    check "issues-removed" "false" "siw/issues/ still has ${issue_count} .md files"
  fi
else
  check "issues-removed" "true" "siw/issues/ directory removed"
fi

# Check 4: siw/SPEC.md does not exist (user chose to delete everything)
if [ -f "siw/SPEC.md" ]; then
  check "spec-removed" "false" "siw/SPEC.md still exists"
else
  # Also check for other spec patterns the skill might match
  spec_found="false"
  for f in $(ls siw/*SPEC*.md siw/*SPECIFICATION*.md siw/*PLAN*.md siw/*DESIGN*.md 2>/dev/null); do
    if [ -f "$f" ]; then
      spec_found="true"
      break
    fi
  done
  if [ "$spec_found" = "true" ]; then
    check "spec-removed" "false" "Spec file still exists: $f"
  else
    check "spec-removed" "true" "Spec file removed"
  fi
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
