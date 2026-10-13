# Product Review Summary

**Mode:** {Code-only | Visual + Code} **Agents Run:** {list of agents that ran} **Categories:** {list of categories audited}

## Relevance Filter

- X findings validated as in-scope (PR/local)
- X findings filtered (pre-existing or out-of-scope)
- X findings filtered (previously addressed)

## Coverage Status (omit when complete)

Coverage degraded: {agent names} failed; findings below exclude {categories}.

Working tree mutated during audit: {paths}; findings citing them were re-verified against disk and {count} were dropped.

UX, visual, and accessibility review not run: no UI-relevant files matched (changed file types: {types}).

## Critical Product Issues (X found)

### PROD-NNN: {Brief title}

**Agent:** {kramme:ux-reviewer | kramme:product-reviewer | kramme:visual-reviewer | kramme:a11y-auditor} **Category:** {specific category within agent's domain} **File:** `path/to/file.tsx:42` **Confidence:** {0-100} **User Impact:** {High | Medium | Low}

**Issue:** {Description}

**Recommendation:** {Specific fix}

---

## Important Product Issues (X found)

{Same format}

## Product Suggestions (X found)

{Same format}

## Open Questions (omit when the product reviewer did not run)

- {What needs product owner input}

## Assumptions Used (omit when the product reviewer did not run)

- {Target user, value, or non-goal the product reviewer inferred from incomplete context}

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

- {What's well-done from a product and UX perspective}

## Recommended Action

1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Discuss open questions with the product owner
5. Re-run audit after fixes

**To resolve findings, run:** `/kramme:pr:resolve-review`
