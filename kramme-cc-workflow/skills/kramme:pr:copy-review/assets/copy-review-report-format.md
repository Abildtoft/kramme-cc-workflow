# Copy Review Summary

**Date:** {date}
**Base Branch:** {base_branch}

## Relevance Filter
- X findings validated as in-scope
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Critical Copy Issues (X found)

### COPY-NNN: {title}

**Severity:** Critical
**Category:** {category name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** High

**Issue:** {what text exists and what the UI already communicates without it}

**Recommendation:** {what to remove or simplify}

---

## Important Copy Issues (X found)

### COPY-NNN: {title}

**Severity:** Important
**Category:** {category name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** Medium

**Issue:** {what text exists and what the UI already communicates without it}

**Recommendation:** {what to remove or simplify}

---

## Copy Suggestions (X found)

### COPY-NNN: {title}

**Severity:** Suggestion
**Category:** {category name}
**File:** `path/to/file:42`
**Confidence:** {0-100}
**User Impact:** Low

**Issue:** {what text exists and what the UI already communicates without it}

**Recommendation:** {what to remove or simplify}

---

## Filtered (Pre-existing/Out-of-scope)
<collapsed>
- [file:line]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)
<collapsed>
- [file:line]: Brief description
  Matched: COPY_REVIEW_OVERVIEW.md - [action taken summary]
</collapsed>

## Copy Strengths
- {places where the code uses minimal, purposeful text effectively}

## Recommended Next Actions
1. Remove or simplify critical findings first
2. Address important findings
3. Discuss open questions with product owner
4. Re-run after changes

**To resolve findings, run:** `/kramme:pr:resolve-review`
