# Issue Templates

Templates and selection rules for composing local issues. Read this file from the `Phase 5: Issue Composition` step in `SKILL.md`.

## Template Selection

- **Bug (Simple)**: Simple Bug Template
- **All others**: Comprehensive Template

## Terminology: Mode (HITL vs AUTO)

Every issue carries a `Mode` field that signals who should pick it up:

- **AUTO** — an autonomous agent can pick up, implement, verify, and prepare for review without human input.
- **HITL** — human-in-the-loop is required for at least one of: architectural decision, design review, judgment call, manual testing, external system access. HITL issues must include a one-line reason.

Field shape:
- `Mode: AUTO` (no reason needed)
- `Mode: HITL — <one-line reason>` (reason required when HITL)

## Durability rule

Issue bodies must NOT include file paths, line numbers, or internal helper/class names. Describe modules, behaviors, and contracts. Reason: file paths and line numbers rot quickly; the issue should remain useful after major refactors.

- ❌ Bad: "Fix bug in `src/services/orderService.ts:142` where `applyDiscount()` returns NaN"
- ✅ Good: "Order discount calculation returns NaN when applied to gift-card orders; affects checkout total and order summary email"

## Simple Bug Template

**File naming:** `siw/issues/ISSUE-{prefix}-{number}-{short-description}.md`

```markdown
# ISSUE-{prefix}-{number}: Fix {what's broken}

**Status:** Ready | **Priority:** {priority} | **Size:** {XS|S|M|L} | **Phase:** {N or General} | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination} | **Mode:** {AUTO | HITL — <reason>} | **Related:** {tasks if any}

## Problem

{1-2 sentence description of the bug}

**Steps to reproduce:**
1. {Step 1}
2. {Step 2}
3. **Bug:** {What happens}

## Root Cause

{1-2 sentences explaining what's causing the bug}

## Fix

{1-2 sentences describing what needs to change}

**Affected area:** {module / behavior / contract — not file paths or line numbers}
```

## Comprehensive Template

**File naming:** `siw/issues/ISSUE-{prefix}-{number}-{short-description}.md`

```markdown
# ISSUE-{prefix}-{number}: {Title}

**Status:** Ready | **Priority:** {priority} | **Size:** {XS|S|M|L} | **Phase:** {N or General} | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination} | **Mode:** {AUTO | HITL — <reason>} | **Related:** {tasks if any}

## Problem

{What pain point or issue exists}
{Who is affected and how}

## Context

{Current state and background}
{Why this matters now}

## Scope

### In Scope
- {Specific item 1}
- {Specific item 2}

### Out of Scope
- {Explicitly excluded item 1}

## Decision Boundaries
- **Captured in this issue:** {product, behavior, or scope decisions that need alignment}
- **Left to implementation:** {engineering choices that should not be over-specified here}

## Acceptance Criteria

- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}

## Edge Cases

- {Edge case 1}: {Expected behavior}

---

## Technical Notes

### Implementation Approach
{High-level approach — describe components/areas/behaviors that need changes, not file paths}

### Affected Areas
- {Component/module 1}

### Patterns to Follow
{Reference existing patterns by name and behavior; avoid pinning to file paths or line numbers}

### References
- {Related modules / contracts — describe by name and responsibility, not file paths}

## Assumptions Used
- {Only include when the issue had to infer user, why-now, or non-goals from incomplete context}
```
