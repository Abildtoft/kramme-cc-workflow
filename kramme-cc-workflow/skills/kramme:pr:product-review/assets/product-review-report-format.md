# Product Review Summary

**Date:** {date}
**Base Branch:** {base_branch}

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Critical Product Issues (X found)

### PROD-NNN: {title}

**Severity:** Critical
**Dimension:** {dimension name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** High

**Issue:** {user-facing scenario description}

**Recommendation:** {specific fix}

---

## Important Product Issues (X found)

### PROD-NNN: {title}

**Severity:** Important
**Dimension:** {dimension name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** Medium

**Issue:** {user-facing scenario description}

**Recommendation:** {specific fix}

---

## Product Suggestions (X found)

### PROD-NNN: {title}

**Severity:** Suggestion
**Dimension:** {dimension name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** Low

**Issue:** {user-facing scenario description}

**Recommendation:** {specific fix}

---

## Open Questions
- {things that need product owner input}

## Assumptions Used
- {only include when the reviewer inferred target user, value, or non-goals from incomplete context}

## Filtered (Pre-existing/Out-of-scope)
<collapsed>
- [file:line]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)
<collapsed>
- [file:line]: Brief description
  Matched: PRODUCT_REVIEW_OVERVIEW.md - [action taken summary]
</collapsed>

## Product Strengths
- {what's well done from a product perspective}

## Recommended Next Actions
1. Fix critical issues first
2. Address important issues
3. Discuss open questions with product owner
4. Re-run after fixes

**To resolve findings, run:** `/kramme:pr:resolve-review --local`
