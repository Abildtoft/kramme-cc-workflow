#!/bin/bash
# Deterministic grader for workflow-artifacts:cleanup
# Checks: artifact files deleted, real source files preserved

passed=0
total=7
checks="["
PROJECT_DIR="project"

check() {
  local name="$1" result="$2" msg="$3"
  if [ "$result" = "true" ]; then
    passed=$((passed + 1))
    checks="${checks}{\"name\":\"${name}\",\"passed\":true,\"message\":\"${msg}\"},"
  else
    checks="${checks}{\"name\":\"${name}\",\"passed\":false,\"message\":\"${msg}\"},"
  fi
}

# Check 1: REVIEW_OVERVIEW.md deleted
if [ ! -f "$PROJECT_DIR/REVIEW_OVERVIEW.md" ]; then
  check "review-deleted" "true" "REVIEW_OVERVIEW.md was deleted"
else
  check "review-deleted" "false" "REVIEW_OVERVIEW.md still exists"
fi

# Check 2: UX_REVIEW_OVERVIEW.md deleted
if [ ! -f "$PROJECT_DIR/UX_REVIEW_OVERVIEW.md" ]; then
  check "ux-review-deleted" "true" "UX_REVIEW_OVERVIEW.md was deleted"
else
  check "ux-review-deleted" "false" "UX_REVIEW_OVERVIEW.md still exists"
fi

# Check 3: AUDIT_SPEC_REPORT.md deleted
if [ ! -f "$PROJECT_DIR/AUDIT_SPEC_REPORT.md" ]; then
  check "audit-deleted" "true" "AUDIT_SPEC_REPORT.md was deleted"
else
  check "audit-deleted" "false" "AUDIT_SPEC_REPORT.md still exists"
fi

# Check 4: QA_REPORT.md deleted
if [ ! -f "$PROJECT_DIR/QA_REPORT.md" ]; then
  check "qa-deleted" "true" "QA_REPORT.md was deleted"
else
  check "qa-deleted" "false" "QA_REPORT.md still exists"
fi

# Check 5: PRODUCT_AUDIT.md deleted
if [ ! -f "$PROJECT_DIR/PRODUCT_AUDIT.md" ]; then
  check "product-audit-deleted" "true" "PRODUCT_AUDIT.md was deleted"
else
  check "product-audit-deleted" "false" "PRODUCT_AUDIT.md still exists"
fi

# Check 6: src/index.ts preserved
if [ -f "$PROJECT_DIR/src/index.ts" ]; then
  check "src-preserved" "true" "src/index.ts was preserved"
else
  check "src-preserved" "false" "src/index.ts was incorrectly deleted"
fi

# Check 7: package.json preserved
if [ -f "$PROJECT_DIR/package.json" ]; then
  check "pkg-preserved" "true" "package.json was preserved"
else
  check "pkg-preserved" "false" "package.json was incorrectly deleted"
fi

checks="${checks%,}]"
score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} checks passed\",\"checks\":${checks}}"
