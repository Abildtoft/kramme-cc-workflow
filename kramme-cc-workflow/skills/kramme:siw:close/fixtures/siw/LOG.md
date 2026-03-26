# SIW Progress Log

## Current Progress

### Last Completed
- **Task:** P2-002 - Drag-and-drop UI
- **Date:** 2026-03-25
- **Summary:** Implemented drag-and-drop for lists and cards using dnd-kit. All acceptance criteria met.

### Next Up
_All issues complete. Ready to close._

## Decision Log

### Decision #1: Use Prisma over raw SQL
**Date:** 2026-03-20 | **Issue:** P1-001

**Problem:** Need an ORM for database access that provides type safety.
**Decision:** Use Prisma with PostgreSQL.
**Rationale:** Type-safe queries, auto-generated client, good migration story.
**Alternatives considered:** TypeORM (less type-safe), Drizzle (newer ecosystem).

### Decision #2: JWT over session-based auth
**Date:** 2026-03-21 | **Issue:** P1-003

**Problem:** Need authentication strategy for the API.
**Decision:** Use JWT tokens with refresh token rotation.
**Rationale:** Stateless, works well with REST API pattern, no server-side session store needed.
**Alternatives considered:** Session cookies (requires session store), OAuth only (too complex for MVP).

### Decision #3: dnd-kit over react-beautiful-dnd
**Date:** 2026-03-23 | **Issue:** P2-002

**Problem:** Need drag-and-drop library for board UI.
**Decision:** Use dnd-kit library.
**Rationale:** Actively maintained, better TypeScript support, more flexible API.
**Alternatives considered:** react-beautiful-dnd (deprecated), react-dnd (lower-level API).

## Guiding Principles

1. **API-first design** - Define API contracts before building UI
2. **Progressive enhancement** - Core functionality works without JavaScript heavy features
3. **Type safety end-to-end** - Prisma types flow through to API response types

## Rejected Alternatives Summary

| # | Decision | Rejected Alternative | Reason |
|---|----------|---------------------|--------|
| 1 | Use Prisma over raw SQL | TypeORM | Less type-safe, decorator-heavy |
| 1 | Use Prisma over raw SQL | Drizzle | Newer, less stable ecosystem |
| 2 | JWT over session-based | Session cookies | Requires session store management |
| 3 | dnd-kit over react-beautiful-dnd | react-beautiful-dnd | Deprecated, no longer maintained |
| 3 | dnd-kit over react-beautiful-dnd | react-dnd | Lower-level API, more boilerplate |
