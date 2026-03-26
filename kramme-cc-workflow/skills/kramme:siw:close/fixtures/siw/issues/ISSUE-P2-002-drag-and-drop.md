# ISSUE-P2-002: Drag-and-drop UI

**Status:** DONE | **Priority:** High | **Phase:** 2 | **Related:** P2-001

## Problem
Implement drag-and-drop for reordering lists within a board and cards within/between lists.

## Acceptance Criteria
- [x] Lists can be dragged to reorder within a board
- [x] Cards can be dragged within a list to reorder
- [x] Cards can be dragged between lists
- [x] Position updates persist to backend

## Technical Notes
### Implementation Approach
Used dnd-kit with sortable preset. Custom drag overlay for visual feedback.
Optimistic updates with React Query mutation + rollback on failure.

### Affected Areas
- src/components/Board.tsx
- src/components/List.tsx
- src/components/Card.tsx
- src/hooks/useBoardDnd.ts
