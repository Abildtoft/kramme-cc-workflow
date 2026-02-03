# Open Issues Structure

**Purpose:** Track active blockers and investigations (temporary - deleted at completion)

The issues system uses **progressive disclosure**: a lightweight overview file plus individual issue files for details.

## File Structure

```
siw/OPEN_ISSUES_OVERVIEW.md          # Quick scan table (~20 lines)
siw/issues/
├── ISSUE-001-data-tracking.md       # Full investigation details
├── ISSUE-002-api-design.md
└── ISSUE-003-validation.md
```

## How to Read (for AI agents)

1. **Always read siw/OPEN_ISSUES_OVERVIEW.md first** - See all active issues at a glance
2. **Only read individual issue files when:**
   - You're investigating that specific issue
   - You need the full context/options for a decision
3. **When resolved:** Delete the issue file and remove from overview

---

## siw/OPEN_ISSUES_OVERVIEW.md Template

```markdown
# Open Issues Overview

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| 001 | Data Tracking Strategy | IN PROGRESS | High | Task 1.0, 1.1 |
| 002 | API Design Pattern | IN REVIEW | Medium | Task 2.1 |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-XXX-*.md` files.
```

---

## Individual Issue File Template

File naming: `siw/issues/ISSUE-XXX-short-title.md` (e.g., `ISSUE-001-data-tracking.md`)

```markdown
# ISSUE-001: Data Tracking Strategy

**Status:** IN PROGRESS | **Priority:** High | **Related:** Task 1.0, Task 1.1

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

_To be filled when decision is made, then move to siw/LOG.md and delete this file._
```

---

## Workflow

### Creating a New Issue

**If this is the first issue (no issues exist yet):**
1. Create `siw/issues/` directory
2. Create `siw/OPEN_ISSUES_OVERVIEW.md` using the template above
3. Create `siw/issues/ISSUE-001-short-title.md` using the template above

**If issues already exist:**
1. Find next available issue number (check `siw/OPEN_ISSUES_OVERVIEW.md` table)
2. Create `siw/issues/ISSUE-XXX-short-title.md`
3. Add row to `siw/OPEN_ISSUES_OVERVIEW.md` table

### Resolving an Issue

1. Fill in the "Decision" section in the issue file
2. Copy decision details to siw/LOG.md Decision Log
3. Delete the issue file
4. Remove row from `siw/OPEN_ISSUES_OVERVIEW.md`

### Cleanup at Project Completion

Delete `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/` directory entirely.
