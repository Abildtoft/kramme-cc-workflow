# UX Audit Summary

**Mode:** {Code-only | Visual + Code} **Agents Run:** {list of agents that ran} **Categories:** {list of categories audited}

## Relevance Filter

- X findings validated as in-scope (PR/local)
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Coverage Status (omit when complete)

Coverage degraded: {agent names} failed; findings below exclude {categories}.

## Critical UX Issues (X found)

### UX-NNN: {Brief title}

**Agent:** {kramme:ux-reviewer | kramme:product-reviewer | kramme:visual-reviewer | kramme:a11y-auditor} **Category:** {specific category within agent's domain} **File:** `path/to/file.tsx:42` **Confidence:** {0-100} **User Impact:** {High | Medium | Low}

All UX audit findings use the artifact-scoped `UX` prefix (`UX-001`, `UX-002`, ...), numbered sequentially across the report regardless of source agent. Older per-agent IDs (`PROD-NNN`, `VIS-NNN`, and `A11Y-NNN`) in `UX_REVIEW_OVERVIEW.md` remain valid only for previously-addressed matching during the transition.

**Issue:** {Description}

**Recommendation:** {Specific fix}

---

## Important UX Issues (X found)

{Same format}

## UX Suggestions (X found)

{Same format}

## Filtered (Pre-existing/Out-of-scope)

<collapsed>
- [file:line]: Brief description - Reason filtered
</collapsed>

## Filtered (Previously Addressed)

<collapsed>
- [file:line]: Brief description
  Matched: UX_REVIEW_OVERVIEW.md - [action taken summary]
</collapsed>

## UX Strengths

- {What's well-done from a UX perspective}

## Recommended Action

1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run audit after fixes

**To resolve findings, run:** `/kramme:pr:resolve-review`
