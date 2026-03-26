#!/bin/bash
# Deterministic grader for kramme:siw:generate-phases
# Checks: issue files exist, overview updated, filename patterns

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

# Check 1: At least 2 issue files exist in siw/issues/
issue_count=0
if [ -d "siw/issues" ]; then
  issue_count=$(find siw/issues -name "ISSUE-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$issue_count" -ge 2 ]; then
  check "min-issues" "true" "Found ${issue_count} issue files (need at least 2)"
else
  check "min-issues" "false" "Found ${issue_count} issue files (need at least 2)"
fi

# Check 2: Issue filenames match pattern ISSUE-P*-*.md or ISSUE-G-*.md
pattern_match=0
pattern_total=0
if [ -d "siw/issues" ]; then
  for f in siw/issues/ISSUE-*.md; do
    [ -f "$f" ] || continue
    pattern_total=$((pattern_total + 1))
    base=$(basename "$f")
    if echo "$base" | grep -qE '^ISSUE-(P[0-9]+-[0-9]+|G-[0-9]+)'; then
      pattern_match=$((pattern_match + 1))
    fi
  done
fi

if [ "$pattern_total" -gt 0 ] && [ "$pattern_match" -eq "$pattern_total" ]; then
  check "filename-pattern" "true" "All ${pattern_total} issue files match naming pattern"
elif [ "$pattern_total" -gt 0 ]; then
  check "filename-pattern" "false" "${pattern_match}/${pattern_total} files match naming pattern"
else
  check "filename-pattern" "false" "No issue files found to check pattern"
fi

# Check 3: OPEN_ISSUES_OVERVIEW.md has been updated (has content beyond initial state)
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  # Check if it still has only the placeholder "_None_" or has real issue rows
  if grep -qE '\| (P[0-9]+-[0-9]+|G-[0-9]+) \|' siw/OPEN_ISSUES_OVERVIEW.md; then
    check "overview-updated" "true" "OPEN_ISSUES_OVERVIEW.md has issue entries"
  else
    check "overview-updated" "false" "OPEN_ISSUES_OVERVIEW.md still has no issue entries"
  fi
else
  check "overview-updated" "false" "OPEN_ISSUES_OVERVIEW.md not found"
fi

# Check 4: At least one phase section exists (Phase 1, Phase 2, etc.)
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  if grep -qiE '## Phase [0-9]+' siw/OPEN_ISSUES_OVERVIEW.md; then
    check "has-phases" "true" "Overview has phase sections"
  else
    check "has-phases" "false" "Overview missing phase sections"
  fi
else
  check "has-phases" "false" "OPEN_ISSUES_OVERVIEW.md not found"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
