# Issue Template

Use this template when creating each issue file in Phase 6.1.

```markdown
# ISSUE-{prefix}-{number}: {Title}

**Status:** READY | **Priority:** {High|Medium|Low} | **Size:** {XS|S|M|L} | **Phase:** {N or General} | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination; include gating note if applicable} | **Mode:** {AUTO | HITL — <one-line reason>} | **Related:** {dependencies}

## Problem

{What this task accomplishes and why it matters}

## Context

{How this fits into the overall project and phase goals}

## Scope

### In Scope

- {Specific deliverable 1}
- {Specific deliverable 2}

### Out of Scope

- {What's NOT included in this task}

## Acceptance Criteria

- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
- [ ] Tests pass: {specific test requirement}

## Validation

{How to verify this task is complete}

- [ ] Code compiles/builds
- [ ] Tests: {specific tests to run or write}
- [ ] Manual verification: {what to check}

---

## Technical Notes

### Implementation Approach

{What needs to change - components, files, patterns}

### Affected Areas

- {Component/file 1}
- {Component/file 2}

### Dependencies

- Blocked by: {P1-001, P2-003, etc. if any, or "None - can start immediately"}
- Blocks: {P1-002, P3-001, etc. if any, or "None"}

### Parallelization Guidance

{Whether this issue can proceed in parallel, must stay sequential, or needs coordination first. Start from the same group-level note shown in Phase 5, then add issue-specific gating detail when needed. If `Blocked by` is not `None - can start immediately`, name the blockers that must be cleared before this issue enters the frontier. `siw/OPEN_ISSUES_OVERVIEW.md` keeps only the group summary line for that section.}
```
