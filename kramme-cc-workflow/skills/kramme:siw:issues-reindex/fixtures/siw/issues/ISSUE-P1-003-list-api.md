# ISSUE-P1-003: List CRUD API

**Status:** READY | **Priority:** Medium | **Phase:** 1 | **Related:** P1-002

## Problem

Implement REST API endpoints for list management within boards.

## Context

After board endpoints are done, we need list management to enable the card workflow.

## Scope

### In Scope
- POST /api/boards/:boardId/lists - create list
- GET /api/boards/:boardId/lists - get lists for board
- PUT /api/lists/:id - update list (name, position)
- DELETE /api/lists/:id - delete list

### Out of Scope
- Drag-and-drop reordering (separate issue)
- Card endpoints

## Acceptance Criteria

- [ ] List CRUD endpoints work correctly
- [ ] Lists are scoped to boards
- [ ] Position field supports reordering
- [ ] Deleting a list cascades to its cards

## Validation

- [ ] Code compiles/builds
- [ ] Tests: API integration tests pass
- [ ] Manual verification: lists appear in board detail response

---

## Technical Notes

### Implementation Approach
Express router nested under boards. Position uses integer ordering.

### Affected Areas
- src/routes/lists.ts
- src/routes/boards.ts (nested includes)

### Dependencies
- Blocked by: P1-002
- Blocks: P2-001
