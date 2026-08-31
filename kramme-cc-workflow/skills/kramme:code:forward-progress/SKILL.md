---
name: kramme:code:forward-progress
description: "Keeps multi-stage implementations and pipelines moving by separating capability work and correctness evidence from advisory workflow bookkeeping. Use when stale markers, receipts, hashes, dashboards, or progress metadata would cause valid work to be repeated or completed stages to be rewound. Not for bypassing controls that protect identity, authority, integrity, concurrency, resumability, scope, CI, or publication safety."
disable-model-invocation: false
user-invocable: false
---

# Preserve Forward Progress

Keep an active implementation moving from its latest proven capability. Do not confuse advisory workflow state with either working output or evidence that the output is correct.

## Outcome Contract

- Advance from the latest stage whose output and relevant evidence remain valid.
- Replay only work affected by a meaningful change or a demonstrated defect.
- Preserve every control that protects the target, authority, correctness, concurrent work, safe recovery, scope, or publication.
- Report implemented behavior and measured evidence before workflow bookkeeping.

This convention is advisory. It grants no permission to edit files, run stages, clear locks, mutate trackers, bypass CI, publish output, or weaken another workflow's gates.

## Classify the Next Action

Classify a proposed action by what it accomplishes:

1. **Capability work** creates or connects behavior, data, schemas, adapters, fixtures, producers, consumers, or user-visible output.
2. **Correctness evidence** checks the changed behavior through tests, types, schemas, counts, samples, conservation, consistency, nontruncation, or measured resource use.
3. **Workflow control** records or restricts execution through status fields, hashes, locks, receipts, checkpoints, dashboards, approvals, or publication state.

Prefer capability work and the smallest relevant correctness evidence. Evaluate workflow control by its consequence rather than its filename or format.

## Preserve Substantive Controls

Treat workflow control as substantive when getting it wrong could:

- select the wrong input, revision, branch, issue, plan, repository, or destination;
- exceed user authority or skip an approval boundary;
- accept malformed, incomplete, corrupted, or unauthenticated output;
- collide with concurrent work or make lock ownership ambiguous;
- make interruption recovery, retry safety, or idempotency unreliable;
- widen the authorized scope or lose traceability to the governing requirement; or
- publish, deploy, merge, push, release, or claim completion without required evidence.

Follow substantive controls exactly. A status field, hash, receipt, or checkpoint may be the evidence that establishes one of these properties; never dismiss it merely because it is metadata.

Treat control state as advisory only when its absence or staleness changes none of those properties and the active workflow does not require it. Advisory state can describe progress, but it cannot prove correctness or invalidate otherwise proven output.

## Continue From the Forward Point

Establish the forward point as the latest stage with valid output and relevant correctness evidence. Continue from there unless at least one substantive condition requires replay:

- the meaning or identity of an input changed;
- the implementation, contract, target, or pinned revision changed;
- output is malformed, truncated, inconsistent, nonconserving, or incompatible with its consumer;
- an observed run disproves the earlier result; or
- a changed dependency affects the stage.

When replay is required, rerun the smallest affected dependency cone. Do not rewind unrelated stages or rerun unchanged implementation solely to recreate an advisory marker, receipt, dashboard row, or progress record.

A validated completion or implementation checkpoint is part of the forward point. Resume after it instead of repeating the implementation it already proves.

## Handle a Blocking Workflow Safely

When an orchestrator appears to block only on advisory state:

1. Recheck whether the control protects any substantive property above.
2. Follow the workflow's documented recovery or resume path when one exists.
3. If no safe path exists, report the exact blocker and stop unless the user has explicitly authorized a task to change that gate.
4. Change or downgrade the gate only within that explicitly authorized task, with focused tests showing that substantive protections remain intact.

Do not run a blocked stage manually, clear a lock, fabricate a receipt, edit tracker state, or substitute another tool merely to evade the active workflow.

## Choose Evidence That Matches the Change

Use only checks that can prove the affected behavior, such as runtime results, exit status, schema or type validity, exact counts, deterministic samples, identity conservation, join consistency, nontruncation, or bounded time and memory for material stages.

Presence is not correctness. A file, status, receipt, or passing traversal proves only what it actually measures.

## Report the Result

Report in this order:

1. capability or output produced;
2. correctness evidence observed;
3. exact blocker or remaining substantive control;
4. advisory workflow state, when it is useful context.

Success means the run advanced from valid prior work, avoided unnecessary replay, preserved every substantive control, and grounded its claims in relevant evidence.

## Source Tracking

`references/sources.yaml` records the external concept adapted into this original local convention. Do not load it during normal use unless auditing or refreshing source attribution.
