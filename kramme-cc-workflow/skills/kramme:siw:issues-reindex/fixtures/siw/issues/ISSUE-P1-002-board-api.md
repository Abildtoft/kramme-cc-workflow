# ISSUE-P1-002: Board CRUD API

**Status:** READY | **Priority:** High | **Phase:** 1 | **Related:** P1-001

## Problem

Implement REST API endpoints for board create, read, update, and delete operations.

## Context

With the database schema in place (P1-001), we need API endpoints to manage boards.

## Scope

### In Scope
- POST /api/boards - create board
- GET /api/boards - list user boards
- GET /api/boards/:id - get board detail
- PUT /api/boards/:id - update board
- DELETE /api/boards/:id - delete board

### Out of Scope
- Board member management
- List/card endpoints

## Acceptance Criteria

- [ ] All five endpoints return correct HTTP status codes
- [ ] Board creation validates required fields (name)
- [ ] Board deletion cascades to lists and cards
- [ ] Unauthorized access returns 401

## Validation

- [ ] Code compiles/builds
- [ ] Tests: API integration tests pass
- [ ] Manual verification: Postman collection works

---

## Technical Notes

### Implementation Approach
Express router with Prisma client. Input validation with zod.

### Affected Areas
- src/routes/boards.ts
- src/middleware/auth.ts

### Dependencies
- Blocked by: P1-001
- Blocks: P1-003
