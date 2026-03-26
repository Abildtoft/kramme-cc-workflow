#!/bin/bash
# Deterministic grader for kramme:siw:init
# Checks: siw/ dir, LOG.md, OPEN_ISSUES_OVERVIEW.md, issues/ dir, spec file

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

# Check 1: siw/ directory exists
if [ -d "siw" ]; then
  check "siw-dir" "true" "siw/ directory exists"
else
  check "siw-dir" "false" "siw/ directory not found"
fi

# Check 2: siw/LOG.md exists
if [ -f "siw/LOG.md" ]; then
  check "log-exists" "true" "siw/LOG.md exists"
else
  check "log-exists" "false" "siw/LOG.md not found"
fi

# Check 3: siw/OPEN_ISSUES_OVERVIEW.md exists
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  check "overview-exists" "true" "siw/OPEN_ISSUES_OVERVIEW.md exists"
else
  check "overview-exists" "false" "siw/OPEN_ISSUES_OVERVIEW.md not found"
fi

# Check 4: siw/issues/ directory exists
if [ -d "siw/issues" ]; then
  check "issues-dir" "true" "siw/issues/ directory exists"
else
  check "issues-dir" "false" "siw/issues/ directory not found"
fi

# Check 5: A spec file exists (any .md in siw/ that is not LOG.md or OPEN_ISSUES_OVERVIEW.md)
spec_found="false"
if [ -d "siw" ]; then
  for f in siw/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      LOG.md|OPEN_ISSUES_OVERVIEW.md|AUDIT_IMPLEMENTATION_REPORT.md|AUDIT_SPEC_REPORT.md|SPEC_STRENGTHENING_PLAN.md)
        continue ;;
      *)
        spec_found="true"
        break ;;
    esac
  done
fi

if [ "$spec_found" = "true" ]; then
  check "spec-exists" "true" "Spec file found: $base"
else
  check "spec-exists" "false" "No spec file found in siw/"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
