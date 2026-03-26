#!/bin/bash
# Deterministic grader for kramme:siw:issues-reindex
# Checks: DONE issue deleted, remaining renamed, overview updated

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

# Check 1: DONE issue (P1-001 setup-database) is deleted
if ls siw/issues/ISSUE-P1-001-setup-database* 2>/dev/null | grep -q .; then
  check "done-deleted" "false" "DONE issue ISSUE-P1-001-setup-database still exists"
else
  check "done-deleted" "true" "DONE issue ISSUE-P1-001-setup-database deleted"
fi

# Check 2: Former P1-002 (board-api) is renumbered to P1-001
if ls siw/issues/ISSUE-P1-001-board-api* 2>/dev/null | grep -q .; then
  check "p1-002-renamed" "true" "P1-002 (board-api) renumbered to P1-001"
elif ls siw/issues/ISSUE-P1-001* 2>/dev/null | grep -q .; then
  # Accept if renamed to P1-001 with any suffix (the title slug may vary)
  check "p1-002-renamed" "true" "An issue exists as P1-001 (likely renumbered from P1-002)"
else
  check "p1-002-renamed" "false" "P1-002 (board-api) not found as P1-001"
fi

# Check 3: Former P1-003 (list-api) is renumbered to P1-002
if ls siw/issues/ISSUE-P1-002-list-api* 2>/dev/null | grep -q .; then
  check "p1-003-renamed" "true" "P1-003 (list-api) renumbered to P1-002"
elif ls siw/issues/ISSUE-P1-002* 2>/dev/null | grep -q .; then
  check "p1-003-renamed" "true" "An issue exists as P1-002 (likely renumbered from P1-003)"
else
  check "p1-003-renamed" "false" "P1-003 (list-api) not found as P1-002"
fi

# Check 4: G-001 (ci-setup) still exists (was not DONE, should not be deleted)
if ls siw/issues/ISSUE-G-001* 2>/dev/null | grep -q .; then
  check "g001-kept" "true" "G-001 (ci-setup) preserved"
else
  check "g001-kept" "false" "G-001 (ci-setup) was incorrectly deleted or renamed"
fi

# Check 5: OPEN_ISSUES_OVERVIEW.md no longer lists DONE issue P1-001 setup-database
if [ -f "siw/OPEN_ISSUES_OVERVIEW.md" ]; then
  if grep -q "Setup Database" siw/OPEN_ISSUES_OVERVIEW.md; then
    check "overview-cleaned" "false" "OPEN_ISSUES_OVERVIEW.md still lists the DONE issue (Setup Database)"
  else
    check "overview-cleaned" "true" "OPEN_ISSUES_OVERVIEW.md no longer lists the DONE issue"
  fi
else
  check "overview-cleaned" "false" "OPEN_ISSUES_OVERVIEW.md not found"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\",\"checks\":${checks}}"
