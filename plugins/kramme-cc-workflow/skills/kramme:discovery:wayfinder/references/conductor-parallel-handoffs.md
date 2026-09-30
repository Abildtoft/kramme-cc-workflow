# Conductor Parallel Handoffs

Use parallel Conductor workspaces only for independent frontier tickets. Each workspace is a separate Git worktree and branch; do not assume two workspace-local `.context` directories synchronize automatically.

## Choose a Coordination Pattern

### Same workspace, multiple agents

Use one canonical map directory. Assign one map owner. The owner assigns one claimed ticket to each worker; workers never claim for themselves. Workers return handoff packets, while the owner applies canonical ticket updates, reconciles the ticket index, and records newly surfaced work.

### Separate Conductor workspaces

Choose one of these explicitly:

1. **Approved shared root:** Keep the canonical map under a user-approved shared path, such as `$CONDUCTOR_ROOT_PATH/.context/wayfinder/<map-slug>/`. Workers write only handoff packets; the map owner edits canonical tickets and `MAP.md`.
2. **Coordinator copies:** Keep the canonical map in one coordinator workspace. Give a worker a read-only map snapshot plus one ticket, then return a resolution packet for reconciliation.

Do not begin parallel work until the user knows which path is canonical. Do not commit `.context` artifacts merely to move them between branches.

## Claim Protocol

A worker must never self-claim in a parallel run: a read/write/re-read on its own does not stop two workers from claiming the same ticket at once. Every parallel run requires one map owner or coordinator as the claim serializer. If none is identified, stop and ask the user to choose one before any worker writes.

Let the map owner or coordinator serialize claims:

1. Re-read the canonical map and ticket.
2. Confirm the ticket is frontier work.
3. Write the worker's workspace/session claim into the canonical ticket as the exact `Claim token`.
4. Mirror the claim in the map index.
5. Re-read both canonical files. If interrupted between steps 3 and 4, reconcile the map from the authoritative ticket before assigning anything else.
6. Give the worker the canonical path or an exact snapshot only after the claim token is visible in both files.

One ticket belongs to one worker session. A second worker skips any claimed ticket. Never clear or steal a claim without the claimant's release or explicit user confirmation.

## Worker Handoff

When a worker starts its assigned ticket, create the temporary resolution packet that the main workflow selected and fill it with:

- the canonical map and ticket identity;
- the claim token observed before work;
- the ticket question, resolution conditions, and observed ticket version before work;
- the direct answer and evidence links;
- proposed decision gist;
- new ticket, blocker, fog, and scope consequences;
- prototype cleanup state or manual follow-up.

Return the packet through the approved shared root or copy it into the coordinator's canonical `handoffs/` directory. Treat it as temporary transport, not a second decision store.

## Coordinator Reconciliation

The map owner must:

1. Verify that the handoff matches the current claim token, ticket question, resolution conditions, and observed ticket version. If the canonical ticket changed, keep the handoff pending and ask the claimant, owner, or named decision-maker to reconcile before changing canonical state.
2. Detect whether another resolution or map change landed first.
3. Copy the accepted full resolution into the canonical ticket.
4. Update the map gist, status, blockers, frontier, fog, and scope in retry-safe order.
5. Mark the handoff reconciled and remove it after confirming the canonical files contain the result.

If two answers conflict, do not silently choose. Keep both handoffs, leave the canonical ticket `CLAIMED`, and ask the user or named decision-maker to reconcile them before the owner changes canonical state.

## Branch and Prototype Safety

- Planning artifacts under `.context` do not need branch merges.
- A prototype workspace remains throwaway. Do not merge prototype code into a production branch as a side effect of resolving the ticket.
- If a ticket unexpectedly needs production implementation, stop and create a downstream implementation handoff after Wayfinder is clear.
- Start additional workspaces only when frontier tickets are independent; blocked or shared-state work stays sequential.
