---
name: kramme:siw:wayfinder
description: "Charts huge or foggy initiatives into a local `.context` decision map and resolves one typed frontier ticket per session until the work is ready for SIW or another execution workflow. Use when the route to a destination cannot fit in one agent session or parallel workspaces need coordinated planning state. Not for clear specs, ordinary issue decomposition, implementation, or Linear-native tracking."
argument-hint: "[initiative description | map-path [ticket-id]]"
disable-model-invocation: true
user-invocable: true
---

# Wayfinder

Find a route through an initiative that is too large or uncertain for one agent session. Preserve the route as a local decision map, resolve its frontier one ticket at a time, and stop when the destination is clear enough to enter a normal planning or execution workflow.

## Boundaries

- Treat Wayfinder as planning by default: resolve decisions, not the destination's implementation.
- Treat the map as an index, not a store. Keep each decision's detail in exactly one resolved ticket; keep only its linked gist on the map.
- Resolve one ticket per session. Charting a new map also consumes the session and must not continue into ticket resolution.
- Use Wayfinder only while consequential questions or fog prevent a planning-ready spec or bounded implementation plan.
- Hand clear work to `/kramme:siw:init`, `/kramme:siw:generate-phases`, `/kramme:siw:issue-define`, or `/kramme:code:work-from-plan`; do not reproduce those workflows here.
- Use the local `.context` backend in this version. Do not create or mutate Linear, GitHub, Jira, or other tracker records.

## Workflow

### Step 1: Classify the invocation

1. Parse `$ARGUMENTS` as either:
   - an initiative description for **chart mode**; or
   - an existing `MAP.md` path, optionally followed by a ticket ID, for **work mode**.
2. Resolve a directory argument to `<directory>/MAP.md` only when that file exists.
3. Infer the mode from an explicit initiative or map already supplied in the current request when no arguments are present. Otherwise ask for either the initiative or the existing map path.
4. Stop with `WAYFINDER NOT NEEDED` when the route is already clear and the whole planning problem fits in one session. Recommend the smallest matching downstream workflow.
5. Stop with `UNSUPPORTED BACKEND` when the user wants an external tracker to be canonical. Explain that this version is local-only and leave Linear-native blocking as a future extension.

### Step 2: Resolve safe local storage

Read the storage and backend rules from `references/storage.md`.

Resolve the canonical map root before writing. Reuse an explicitly supplied map path; otherwise default to `<worktree>/.context/wayfinder/<map-slug>/`. Verify that `.context` is ignored by Git, refuse silent overwrites, and require explicit confirmation before selecting a shared path outside the current worktree.

### Step 3: Chart a new map

Run this step only in chart mode.

1. Read the map contract from `references/map-format.md` and the type rules from `references/ticket-types.md`.
2. Name one destination: the planning state Wayfinder must make reachable, not a bundle of implementation tasks.
3. Explore breadth-first. Surface consequential decisions takeable now and keep indistinct areas under **Not yet specified**. Stop with `WAYFINDER NOT NEEDED` before creating files if no meaningful fog remains.
4. Copy `assets/ticket-template.md` and create every currently specifiable ticket with a stable `WF-###` ID before wiring blockers. Ticket files are authoritative; if interruption leaves tickets without `MAP.md`, recover only through the directory-without-map rule in `references/storage.md`.
5. Copy `assets/map-template.md` and publish `MAP.md` last. Validate its index against the tickets, promote it from `DRAFT` to `ACTIVE`, report the canonical path and frontier, then stop without claiming a ticket.

### Step 4: Reconcile and claim one frontier ticket

Run this step only in work mode.

1. Read the lifecycle from `references/work-through-map.md` and the type rules from `references/ticket-types.md`; load the map at low resolution and reconcile its derived index before selection.
2. When separate agents or workspaces are involved, read `references/conductor-parallel-handoffs.md`. Require one map owner to serialize claims; stop if no owner is identified. Copy `assets/resolution-handoff-template.md` only when a worker cannot safely edit the canonical ticket.
3. Honor a named ticket only when it is frontier work; otherwise report its exact unavailable state and stop. With no named ticket, select the first frontier row in map order.
4. Claim before investigation using the lifecycle's solo or owner-mediated sequence. Never infer abandonment from elapsed time or clear another session's claim without its release or explicit user confirmation.

### Step 5: Resolve the claimed ticket

1. Work only the claimed question and follow its type in `references/ticket-types.md`. Load related ticket bodies only when their full detail is necessary.
2. Record the full answer and linked evidence without copying secrets, credentials, private data, or sensitive logs; record safe locations or redacted facts instead.
3. Commit the resolution in the role-specific, retry-safe order from `references/work-through-map.md`. In a parallel run, also follow `references/conductor-parallel-handoffs.md`; a non-owner worker must not edit `MAP.md`.
4. Close mis-scoped work as `OUT OF SCOPE`, link it from the map's **Out of scope** section, and omit it from **Decisions so far**.

### Step 6: Stop or hand off

1. The map is clear only when no open ticket remains, **Not yet specified** is empty, and the route to the destination requires no consequential unresolved decision.
2. If it remains active, report the resolved ticket, changed frontier, remaining fog, and canonical map path, then stop even when another ticket is ready.
3. Before declaring `WAYFINDER CLEAR`, the map owner must set `Status: CLEAR`, update the timestamp, set **Handoff** exit readiness to clear, record the intended durable artifact and next workflow, and validate the map against its tickets.
4. Emit a `WAYFINDER EXIT BRIEF` with the destination, one gist and path per resolved decision, remaining assumptions, and intended durable artifact. Require the next workflow to absorb the decisions rather than retain durable links to temporary `.context` files.
5. Classify the exit:
   - route a planning-ready multi-step initiative to `/kramme:siw:init` and later SIW decomposition;
   - route one bounded, implementation-ready plan to `/kramme:code:work-from-plan`;
   - route a single SIW work item to `/kramme:siw:issue-define` after the SIW container exists.
6. Recommend the next workflow and stop. Do not create SIW files or invoke implementation in the same session.

## Artifact Lifecycle

- **Produced by:** Step 3 creates `.context/wayfinder/<map-slug>/MAP.md` plus ticket files and optional evidence or handoff files.
- **Consumed by:** Later Wayfinder sessions read the map index and one claimed ticket; a downstream spec or plan consumes the resolved decisions after the route is clear.
- **Refreshed by:** Every claim, resolution, frontier change, fog graduation, scope change, or explicit reconciliation updates the affected ticket first and the map index second.
- **Retired by:** Archive or delete the map only after its durable decisions have been synthesized into the destination artifact or downstream workflow. Require confirmation before deletion; remove temporary handoff packets after reconciliation.

## Error Handling

| Condition | Response |
| --- | --- |
| Missing initiative and map path | Ask for the smallest missing input. |
| Existing map directory for a new initiative | Offer resume, an explicit new slug, or abort; never overwrite. |
| `.context` is not ignored | Stop and ask for a safe ignored location or permission to update ignore rules. |
| External tracker requested | Stop with `UNSUPPORTED BACKEND`; do not call its API or MCP tools. |
| No frontier but fog remains | Report the blocked area and ask for the human decision or access needed to sharpen the next ticket. |
| Conflicting or stale map metadata | Reconcile from ticket files and report the correction before work. |
| No map owner in a parallel run | Stop and ask the user to identify one owner before any claim or worker write. |
| Competing claim | Yield the ticket and choose another frontier item or stop. |
| Requested ticket unavailable | Stop and report whether the named ticket is blocked, claimed, resolved, out of scope, or missing; do not resolve a different ticket. |
| Malformed canonical map or ticket | Stop. Do not infer or repeat work; recover only from a validated temporary file, handoff, or owner-confirmed source. |
| Interrupted write | Keep the previous canonical file, validate or discard only this session's temporary file, then resume from canonical ticket state and rebuild derived map data. |

## Source Tracking

`references/sources.yaml` records the external Wayfinder concept adapted by this local workflow. Do not load it during normal use unless auditing or refreshing source attribution.
