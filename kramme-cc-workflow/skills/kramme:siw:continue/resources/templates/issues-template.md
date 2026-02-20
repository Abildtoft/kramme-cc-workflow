# Open Issues Structure

**Purpose:** Track active blockers and investigations (temporary - deleted at completion)

The issues system uses **progressive disclosure**: a lightweight overview file plus individual issue files for details.

## Issue Naming Convention

Issues use a **prefix-based numbering** scheme:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `G-` | General issues (non-phase, standalone) | `ISSUE-G-001-setup.md` |
| `P1-` | Phase 1 issues | `ISSUE-P1-001-database.md` |
| `P2-` | Phase 2 issues | `ISSUE-P2-001-api.md` |
| `P3-` | Phase 3 issues (etc.) | `ISSUE-P3-001-frontend.md` |

**Default:** `/kramme:siw:issue-define` defaults to `G-` but can use `P1-`, `P2-`, etc. when the issue fits an active (not completed) phase. `/kramme:siw:generate-phases` typically creates `P1-`, `P2-`, etc. issues (and `G-` for cross-cutting tasks).

## File Structure

```
siw/OPEN_ISSUES_OVERVIEW.md          # Quick scan table (~20 lines)
siw/issues/
├── ISSUE-G-001-setup.md             # General issues
├── ISSUE-G-002-documentation.md
├── ISSUE-P1-001-data-tracking.md    # Phase 1 issues
├── ISSUE-P1-002-api-design.md
└── ISSUE-P2-001-validation.md       # Phase 2 issues
```

## How to Read (for AI agents)

1. **Always read siw/OPEN_ISSUES_OVERVIEW.md first** - See all active issues at a glance
2. **Only read individual issue files when:**
   - You're investigating that specific issue
   - You need the full context/options for a decision
3. **When resolved:** Document the resolution in the issue file's `## Resolution` section, set status to `IN REVIEW` or `DONE` based on confidence, and update the overview row
   - If this was a phase issue (`P1-*`, `P2-*`, etc.) and it was the last open issue in that phase, ask the user whether to mark the phase as DONE in the overview header (append ` (DONE)`).
   - If you later add a new non-DONE issue to a phase marked ` (DONE)`, remove the marker (or ask the user) so the header stays accurate.

---

## siw/OPEN_ISSUES_OVERVIEW.md Template

```markdown
# Open Issues Overview

## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| G-001 | Project Setup | DONE | High | |
| G-002 | Documentation | READY | Low | |

## Phase 1: Foundation

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P1-001 | Data Tracking Strategy | IN PROGRESS | High | Task 1.0, 1.1 |
| P1-002 | API Design Pattern | IN REVIEW | Medium | Task 2.1 |

## Phase 2: Core Features

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P2-001 | Validation Logic | READY | High | P1-001, P1-002 |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

---

## Individual Issue File Template

File naming: `siw/issues/ISSUE-{prefix}-XXX-short-title.md` (e.g., `ISSUE-G-001-setup.md`, `ISSUE-P1-001-data-tracking.md`)

```markdown
# ISSUE-P1-001: Data Tracking Strategy

**Status:** IN PROGRESS | **Priority:** High | **Phase:** 1 | **Related:** Task 1.0, Task 1.1

## Problem

Need tracking strategy for user actions on MyEntity.

## Context

- `MyEntity` doesn't implement `IAuditable` (`MyEntity.cs:9`)
- Similar pattern exists in `OrderEntity` using explicit properties

## Options

### Option A: Add IAuditable Interface

**Pros:**
- Automatic tracking
- Consistent with audit pattern

**Cons:**
- Redundant data (CreatedBy already tracked)
- Not all entities need full audit

### Option B: Explicit ActionByUserId Property

**Pros:**
- Clear intent
- Immutable after action
- Lightweight

**Cons:**
- Manual implementation
- Need to remember to set it

## Questions

- [ ] Which aligns better with existing patterns?
- [ ] Does ActionAt need similar treatment?

## Decision

_To be filled when decision is made, then document in siw/LOG.md._
```

---

## Workflow

### Creating a New Issue

**If this is the first issue (no issues exist yet):**
1. Create `siw/issues/` directory
2. Create `siw/OPEN_ISSUES_OVERVIEW.md` using the template above
3. Create `siw/issues/ISSUE-G-001-short-title.md` using the template above

**If issues already exist:**
1. Determine the prefix:
   - Use `G-` for general/standalone issues (default for `/kramme:siw:issue-define`)
   - Use `P1-`, `P2-`, etc. for phase-specific issues
2. Find next available number within that prefix group (check `siw/OPEN_ISSUES_OVERVIEW.md` table)
3. Create `siw/issues/ISSUE-{prefix}-XXX-short-title.md`
4. Add row to appropriate section in `siw/OPEN_ISSUES_OVERVIEW.md` table
5. If you added a non-DONE issue to a phase section currently marked ` (DONE)`, remove the marker (or ask the user)

### Resolving an Issue

1. Fill in the "Decision" section in the issue file
2. Copy decision details to siw/LOG.md Decision Log
3. Mark the issue `DONE` in `siw/OPEN_ISSUES_OVERVIEW.md`
4. If this was the last open issue in a phase, ask the user if the phase should be marked as DONE by appending ` (DONE)` to the phase section header
5. Document the resolution in the issue file's `## Resolution` section

### Cleanup at Project Completion

Delete `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/` directory entirely.
