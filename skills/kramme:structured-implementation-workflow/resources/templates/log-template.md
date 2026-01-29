# LOG.md Template

**Purpose:** Session continuity + decision rationale (temporary - deleted at completion)

**Create on demand** when first decision made OR first task completed.

**Update:** After completing tasks, before ending sessions, when making decisions.

---

## How to Read This Document (for AI agents)

This document is designed for **progressive reading**:

1. **Always start with "Current Progress"** (first ~50 lines) - Sufficient for resuming. Contains status, last completed task, and next steps.

2. **Decision Log is reference material** - Only read specific decisions when:
   - A task references a decision number (e.g., "per Decision #5")
   - You need to understand why something was done a certain way

3. **Use search, not full reads:**
   ```bash
   grep -n "Decision.*keyword" LOG.md
   ```
   Then read just that section (~10 lines per decision).

---

## Required Sections (in order)

1. **Current Progress** (MUST be first) - What was done, what's next
2. **Decision Log** - WHY decisions were made, with template
3. **Rejected Alternatives Summary** - Table of rejected options
4. **Guiding Principles** - Project principles
5. **References** - Links to materials

---

## Section Details

### Current Progress Section

**Update after:** Completing numbered tasks/subtasks, before ending sessions, after resolving blockers. NOT after every file edit.

**Structure:** Project Status → Last Completed → Next Steps

```markdown
## Current Progress

**Last Updated:** YYYY-MM-DD HH:MM
**Quick Summary:** [One-line description of project state, e.g., "Implementing user tracking on MyEntity, 5/12 tasks done, working on API endpoint"]

### 📍 Project Status

- **Status:** In Progress | **Current Phase:** Phase 3: Execution - Task 1.2 | **Overall Progress:** 3 of 12 tasks

### ✅ Last Completed

- **Task:** Task 1.1 - Add tracking properties
- **What was done:** Added ActionNote/ActionByUserId properties with nullability
- **Files:** `MyEntity.cs`, `MyEntityConfiguration.cs` | **Status:** Completed
- **Notes:** Made nullable after investigation (Decision #5)

### ⏭️ Next Steps

1. Task 1.2 - Update PerformAction() signature (~30 min)
2. Task 1.3 - Add validation (~20 min)
3. **Blockers:** None
```

### Decision Log Section

**Structure:** Date | Category | Status | Problem | Decision | Rationale | Alternatives | Impact

```markdown
## Decision Log

### Decision Template

### Decision #X: [Title]

**Date**: YYYY-MM-DD | **Category**: [Architecture/Data Model/UI/UX/etc.] | **Status**: [✅ Implemented/🔄 Partial/📋 Planned]

**Problem**: [what needed to be decided]
**Decision**: [chosen approach]
**Rationale**: [why this was chosen]
**Alternatives**: [rejected options + why]
**Impact**: [changes made, files affected]
```

**Example:**

```markdown
### Decision #5: Make ActionByUserId Nullable

**Date**: 2025-11-05 | **Category**: Data Model | **Status**: ✅ Implemented

**Problem**: Not all entities undergo this action
**Decision**: Nullable at storage; required when calling PerformAction()
**Rationale**: Matches ActionAt pattern; semantically correct
**Alternatives**: Non-nullable - rejected (doesn't reflect reality)
**Impact**: Updated spec + `MyEntity.cs:23`, `MyEntityConfiguration.cs:74`
```

### Rejected Alternatives Summary

```markdown
## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| IAuditable interface | Action tracking | Redundant fields | #1 |
| Non-nullable ActionByUserId | Data model | Unrealistic | #5 |
```

### Guiding Principles

```markdown
## Guiding Principles

1. Explicit over implicit
2. Match existing patterns
3. Semantic correctness
4. Testability first
```

### References

```markdown
## References

- Spec: `FEATURE_SPECIFICATION.md`
- Similar: ActionAt pattern
- AGENTS.md: EF nullable guidelines
```

---

## Complete LOG.md Example

```markdown
# LOG.md

## Current Progress

**Last Updated:** 2025-11-05 16:45
**Quick Summary:** Implementing user action tracking on MyEntity, 5/12 tasks done, working on API endpoint.

### 📍 Project Status

- **Status:** In Progress | **Phase:** Phase 3: Execution - Task 2.1 | **Progress:** 5 of 12 tasks

### ✅ Last Completed

- **Task:** Task 1.3 - Add validation | **Files:** `MyEntity.cs`, `MyEntityValidator.cs`, `MyEntityTests.cs`
- **Status:** Completed | **Notes:** Tests passing, ready for Task 2.1

### ⏭️ Next Steps

1. Task 2.1 - Create API endpoint (~45 min)
2. Task 2.2 - Add endpoint tests (~30 min)
3. **Blockers:** None

---

## Decision Log

### Planning Phase Decisions

#### Decision #1: Use Explicit Properties Over IAuditable

**Date**: 2025-11-04 | **Category**: Architecture | **Status**: ✅ Implemented
**Problem**: Need action tracking without redundant audit data
**Decision**: Explicit ActionByUserId/ActionNote properties vs IAuditable interface
**Rationale**: Clearer intent, avoids redundant fields, not all entities need full audit
**Alternatives**: IAuditable - rejected (redundant data) | **Impact**: Spec Task 1.1, MyEntity

#### Decision #5: Make ActionByUserId Nullable

**Date**: 2025-11-05 | **Category**: Data Model | **Status**: ✅ Implemented
**Problem**: Not all entities undergo action | **Decision**: Nullable at storage, required in PerformAction()
**Rationale**: Matches ActionAt pattern, semantically correct
**Alternatives**: Non-nullable - rejected (doesn't reflect reality)
**Impact**: Spec (lines 361,367,374,392), `MyEntity.cs:23`, `MyEntityConfiguration.cs:74`

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| IAuditable interface | Action tracking | Redundant fields | #1 |
| Non-nullable ActionByUserId | Data model | Unrealistic | #5 |

---

## Guiding Principles

1. Explicit over implicit
2. Match existing patterns
3. Semantic correctness
4. Testability first

## References

- Spec: `FEATURE_SPECIFICATION.md`
- Similar: ActionAt pattern
- AGENTS.md: EF nullable guidelines
```
