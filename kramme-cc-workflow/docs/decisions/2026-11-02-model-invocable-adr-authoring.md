# Let the Model Write ADRs and Announce Every Write

- Status: ACCEPTED
- Date: 2026-11-02
- Deciders: repository maintainers

## Context

`trackbed:docs:adr` became model-disabled in #483 because it writes ADR files and may update predecessor ADRs. The repository keeps side-effecting skills model-disabled by default, and the only standing exception covers [orchestration children](2026-08-29-model-invocable-orchestration-children.md) called by named parents.

The ADR skill is not a child. It is the one place a decision recorded mid-task can become a durable record, and requiring the user to type the command means decisions settled during agent work go unrecorded. `trackbed:discovery:interview` already offered ADRs but could only hand the user a command to run.

The maintainer wants the model to write ADRs on its own, on one condition: the user must never miss that it did.

## Decision

- `trackbed:docs:adr` is model-invocable and stays user-invocable.
- When the model starts the skill without a user request for an ADR in the session, it may create only a new ADR file with Status PROPOSED. It asks first before editing, superseding, or deprecating an existing ADR, and before creating an ADR directory the project lacks.
- Every run that leaves an ADR file created or edited, whoever started it, starts its final message with an `ADR WRITTEN` callout block. The block lists each file and its status, who started the run, the decision in one line, and how to undo it. A skill or workflow that invoked the ADR skill repeats the block at the top of its own final message.
- `trackbed:discovery:interview` invokes the skill when the user picks "Author ADR" instead of printing a command.

## Consequences

- Decisions made during agent work can be recorded without the user remembering to ask.
- The ADR skill's name and description enter every session's model-visible skill list.
- The callout and the PROPOSED-only limit are instructions, not a platform-enforced check. Focused tests pin both in `SKILL.md`, but cannot prove a run obeyed them.
- A model-written ADR is never ACCEPTED on its own, so a decision the user has not reviewed cannot read as adopted.

## Alternatives Considered

### Keep the skill model-disabled

Rejected because decisions settled during agent work would keep going unrecorded unless the user stopped to type the command.

### Make it model-invocable with no extra contract

Rejected because an ADR records a team decision, and a silent write could be committed with the rest of a change before anyone read it.

### Let the model draft the ADR in chat and write only after approval

Rejected because the maintainer wants the record on disk without an extra round-trip, and the callout gives the same chance to review before commit.
