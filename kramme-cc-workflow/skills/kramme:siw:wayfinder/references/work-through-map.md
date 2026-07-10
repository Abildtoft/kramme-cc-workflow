# Work Through a Wayfinder Map

Resolve one ticket per session. Preserve the ticket as the detailed record and the map as the reconciled index.

## 1. Load Low-Resolution State

Read the map's destination, notes, decision gists, ticket index, fog, and out-of-scope sections. Do not read every ticket body. Compare index rows with the frontmatter-style metadata blocks of only the tickets needed to verify frontier state.

Repair stale rows from ticket metadata before selection. Report any repair that changes status, blockers, or claims.

If the map's `Status` is `DRAFT`, treat it as an interrupted chart: reconcile every index row against the ticket files, then promote the map to `ACTIVE` before selecting work, and report the promotion.

## 2. Select the Frontier

Treat a ticket as frontier work only when:

- its status is `READY`;
- every listed blocker is `RESOLVED`;
- its claim is empty; and
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

If you are a non-owner worker in a coordinator-copy parallel run, write only the resolution handoff packet and stop; the map owner performs all canonical writes. In an approved shared-root parallel run, a non-owner worker may complete step 1 only when the owner explicitly assigned direct ticket editing and the worker first re-reads the canonical ticket and map row, verifies that the active `Claim token` exactly matches this workspace or session, and stops if it does not. The map owner performs steps 2–6. See `conductor-parallel-handoffs.md`. The ordering below applies to a solo session or the map owner, plus the guarded direct-ticket write described above.

Update in this order:

1. Write the complete resolution in the ticket, set `Status: RESOLVED`, clear the active claim, and record resolution metadata.
2. Update the map row to `RESOLVED` and append or revise one linked decision gist when the result is decision-bearing.
3. Create stable files for newly precise questions, then add their index rows.
4. Wire new or changed blockers and recompute `READY` versus `BLOCKED`.
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
