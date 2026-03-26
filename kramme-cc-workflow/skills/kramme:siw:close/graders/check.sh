#!/bin/bash
# Deterministic grader for kramme:siw:close
# Checks: docs/ dir exists with .md files, siw/ temp files removed

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

# Check 1: A docs/ directory exists (docs/ or docs/<feature-name>/)
docs_dir=""
if [ -d "docs" ]; then
  # Look for any subdirectory or .md files directly in docs/
  md_count=$(find docs -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$md_count" -gt 0 ]; then
    docs_dir="docs"
  fi
fi

if [ -n "$docs_dir" ]; then
  check "docs-dir" "true" "Documentation directory exists with ${md_count} .md files"
else
  check "docs-dir" "false" "No docs/ directory with .md files found"
fi

# Check 2: At least one .md file exists in docs/
if [ -n "$docs_dir" ] && [ "$md_count" -ge 1 ]; then
  check "docs-has-md" "true" "Found ${md_count} markdown files in docs/"
else
  check "docs-has-md" "false" "No markdown files found in docs/"
fi

# Check 3: siw/LOG.md is removed
if [ -f "siw/LOG.md" ]; then
  check "log-removed" "false" "siw/LOG.md still exists"
else
  check "log-removed" "true" "siw/LOG.md removed"
fi

# Check 4: siw/OPEN_ISSUES_OVERVIEW.md is removed
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  check "overview-removed" "false" "siw/OPEN_ISSUES_OVERVIEW.md still exists"
else
  check "overview-removed" "true" "siw/OPEN_ISSUES_OVERVIEW.md removed"
fi

# Check 5: siw/issues/ is removed or empty
if [ -d "siw/issues" ]; then
  issue_count=$(find siw/issues -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$issue_count" -eq 0 ]; then
    check "issues-removed" "true" "siw/issues/ is empty"
  else
    check "issues-removed" "false" "siw/issues/ still has ${issue_count} .md files"
  fi
else
  check "issues-removed" "true" "siw/issues/ directory removed"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
