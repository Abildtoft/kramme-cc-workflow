# Work Through a Wayfinder Map

Resolve one ticket per session. Preserve the ticket as the detailed record and the map as the reconciled index.

## 1. Load Low-Resolution State

Read the map's destination, notes, decision gists, ticket index, fog, and out-of-scope sections. Do not read every ticket body. Enumerate `tickets/WF-*.md` and read only their frontmatter-style metadata blocks so the complete same-map ticket set can be compared with the index.

Repair stale or missing rows from ticket metadata before selection. Quarantine ticket files whose map ID or canonical map path does not match, and report any repair that changes status, blockers, claims, or index membership.

If the map's `Status` is `DRAFT`, treat it as an interrupted chart: rebuild the complete index from every same-map ticket file, validate blockers and initial statuses from ticket metadata, then promote the map to `ACTIVE` before selecting work, and report the promotion.

## 2. Select the Frontier

Treat a ticket as frontier work only when:

- its status is `READY`;
- every listed blocker is `RESOLVED`;
- its claim is `—` or empty; and
- it remains inside the destination's scope.

When the user names a ticket, honor it only when it meets those conditions. If it is blocked, claimed, resolved, out of scope, or missing, stop and report that exact reason; do not silently fall back to a different ticket. When no ticket was named, take the first frontier row in map order. Do not skip ahead to a blocked ticket merely because it looks more interesting.

When no frontier exists:

- report unresolved blockers if open tickets remain;
- ask for the missing human input or access when fog cannot yet sharpen;
- mark the map clear only when no open ticket and no fog remain.

## 3. Claim Before Work

The read/write/re-read sequence below is valid only in a solo session where one agent writes the canonical files. Under any parallel or multi-agent use, do not self-claim: the single map owner or coordinator must serialize every claim per `conductor-parallel-handoffs.md`. If no owner is identified, stop before writing.

For a solo session, use this sequence:

1. Re-read the ticket and map row immediately before the claim.
2. Set the ticket to `CLAIMED` and record `Claimed by`, `Claimed at`, and a `Claim token` that uniquely names the workspace or session.
3. Mirror the claim in the map row.
4. Re-read both files. If another valid claim is present, do not work the ticket; yield it and select another frontier item or stop.

Do not infer abandonment from elapsed time. Clear a claim only when its owner releases it or the user explicitly confirms reassignment. Record the release or reassignment in the ticket and recompute its `READY` or `BLOCKED` status from its blockers.

## 4. Resolve the Question

Keep investigation bounded to the ticket's question and resolution conditions. Read a related ticket's full body only when its detailed answer materially affects the current question.

Apply the ticket type's workflow, then record:

- the direct answer;
- source evidence or human confirmation;
- the route decision and consequences;
- linked artifacts;
- newly sharp questions, cleared fog, blocker changes, and scope changes.

Never turn the ticket into implementation of the destination. A prerequisite `task` is the only doing-oriented type, and it must exist solely to unblock a decision.

## 5. Commit the Resolution to Local State

If you are a non-owner worker in any parallel run, write only the resolution handoff packet and stop; the map owner performs all canonical writes. See `conductor-parallel-handoffs.md`. The ordering below applies only to a solo session or the map owner.

Update in this order:

1. Write the complete resolution in the ticket, set `Status: RESOLVED`, clear the active claim, and record resolution metadata.
2. Update the map row to `RESOLVED` and append or revise one linked decision gist when the result is decision-bearing.
3. Plan newly precise questions and blocker changes together, then create stable ticket files only after each new ticket has final initial `Blocked by` and `READY` or `BLOCKED` metadata.
4. Recompute `READY` versus `BLOCKED` for every affected ticket, then rebuild the map index rows from ticket metadata.
5. Remove fog lines that graduated into tickets; add only newly visible but still-imprecise areas.
6. Move any revealed beyond-destination work to **Out of scope** and mark affected tickets `OUT OF SCOPE`.

If interrupted, inspect the ticket first. A resolved ticket means the investigation must not run again; repair the index and remaining derived updates instead.

## 6. Stop

Report:

- resolved ticket name and path;
- one-line answer;
- evidence or human confirmation;
- newly available frontier tickets;
- remaining fog or blockers;
- canonical map path;
- `WAYFINDER CLEAR` and the recommended handoff only when the exit conditions hold.

Stop after this report. Even if several frontier tickets are ready, each belongs to a separate session.

When the exit conditions hold, the map owner first updates `Status: CLEAR`, the updated timestamp, and every **Handoff** field, then validates and re-reads the map before reporting `WAYFINDER CLEAR`. A non-owner worker reports that the map may now be clear and leaves this transition to the owner.
