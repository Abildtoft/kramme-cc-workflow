# Wayfinder Map Contract

Use one `MAP.md` as the low-resolution view of an initiative. The map is an index, not a store: it points to tickets and gives one-line decision gists, while each ticket owns its complete question, evidence, and resolution.

## Required Sections

Keep these sections in this order:

1. **Destination** — one observable planning state that ends wayfinding.
2. **Notes** — local backend, map owner, constraints, and any explicit exception to planning-only behavior.
3. **Decisions so far** — links to resolved tickets plus one-line gists; never restate the full reasoning.
4. **Ticket index** — the complete local query surface for status, blockers, order, and claims.
5. **Not yet specified** — in-scope fog that cannot yet be phrased as a precise question.
6. **Out of scope** — consciously excluded work and links to tickets later found to be mis-scoped.
7. **Handoff** — exit readiness and the downstream workflow once the map is clear.

## Metadata

Record:

- a stable map ID derived from the map slug;
- `Status: DRAFT` while charting is still writing the map, then `ACTIVE`, `CLEAR`, or `ARCHIVED`;
- created and updated timestamps when available;
- the canonical absolute or repository-relative path;
- the map owner when parallel work is active.

Do not use dates or timestamps to decide that a claim is stale. They are diagnostic context only.

## Ticket Index

Use this schema:

```markdown
| ID | Ticket | Type | Mode | Status | Blocked by | Claim |
| --- | --- | --- | --- | --- | --- | --- |
| WF-001 | [Decide the boundary](tickets/WF-001-decide-boundary.md) | grilling | HITL | READY | — | — |
```

Apply these rules:

- Keep ticket IDs stable after file creation. Do not renumber closed or removed entries.
- Use `READY`, `BLOCKED`, `CLAIMED`, `RESOLVED`, or `OUT OF SCOPE`.
- Set `READY` only when every blocker is `RESOLVED`.
- Treat the frontier as `READY` tickets with no claim, in table order.
- When a ticket is claimed, store the exact `Claim token` in the Claim column so the map row can be matched against the ticket metadata.
- Keep blocked tickets in the index; keep indistinct future work in **Not yet specified** instead of inventing ticket boundaries.
- Link each row by its readable ticket name. Keep the ID visible for stable local identity.

## Decision Gists

Append exactly one linked gist for each resolved decision ticket:

```markdown
- [Decide the boundary](tickets/WF-001-decide-boundary.md) — Limit the first release to workspace-local maps.
```

The gist states the outcome, not the argument. Detailed rationale, evidence, alternatives, and consequences remain in the ticket. A prerequisite `task` may appear here only when its result itself changes the route; otherwise keep it resolved in the ticket index without presenting it as a decision.

## Fog and Scope

Use **Not yet specified** when an area is in scope but the question cannot yet be stated precisely. Graduate a fog item into one or more ticket files only when the question boundary becomes sharp. Remove the graduated line in the same update.

Use **Out of scope** when work sits beyond the destination. If an existing ticket proves mis-scoped, set it to `OUT OF SCOPE` and add a linked one-line reason here. Do not add it to **Decisions so far**.

## Consistency and Retry Rules

- Treat a ticket file as authoritative for that ticket's metadata and resolution; treat the map row as a derived index entry.
- Publish `MAP.md` only after every indexed ticket file exists. Keep a freshly charted map at `Status: DRAFT` until its index validates against the ticket files, then promote it to `ACTIVE`. Treat a `DRAFT` map found later as an interrupted chart: rebuild and validate the index from the ticket files before trusting or using it.
- Update the ticket before its map row. On restart, reconcile the row from the ticket rather than repeating work.
- Never duplicate a full resolution on the map.
- Never delete a resolved ticket merely because a later answer supersedes it. Mark the superseding relationship in both affected tickets and update the current gist.
- Set the map to `CLEAR` only when no open ticket and no fog remain and the destination route is decision-complete.
- When clearing the map, update the timestamp and **Handoff** section in the same validated write: mark exit readiness clear and record the intended durable artifact and recommended next workflow.
