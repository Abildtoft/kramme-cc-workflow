# [Decision Topic] - Architecture Decision Record

## Context

Why this decision is needed now.

## Decision Boundaries

What is being decided here, and what is intentionally left to product or implementation teams.

## Options Considered

### Option 1: [Name]

- **Pros**:
- **Cons**:
- **Effort**:
- **Reversibility**:

### Option 2: [Name]

- **Pros**:
- **Cons**:
- **Effort**:
- **Reversibility**:

## Decision

What we chose and why.

## Tradeoffs Accepted

What we're sacrificing with this choice.

## Constraints & Assumptions

Non-negotiables that shaped this decision.

## Migration Plan

How to get from current state to target.

## Risks & Mitigations

Each risk must be specific. "Migration could be hard" is useless; "queries that join across the legacy/new tables will need to read from both during the dual-write window, which adds 200ms to the order-detail page" is useful.

| Risk | Mitigation |
| ---- | ---------- |

## Success Criteria

How we'll know this was the right choice.

## Review Date

When to revisit this decision.

## Sources

Populate only when Phase R ran. List the files and URLs the research agents returned, grouped by agent.

- **Codebase**: `{path:line-range}` — {what was found}
- **Docs**: `{url}` — {what was found, version it documents}
- **Dependencies**: `{package@version}` — {compatibility note}
