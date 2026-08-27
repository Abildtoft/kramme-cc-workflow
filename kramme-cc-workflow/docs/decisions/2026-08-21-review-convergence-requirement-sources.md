# Derive Direct Review-Convergence Requirements

- Status: ACCEPTED
- Date: 2026-08-21
- Last amended: 2026-08-27
- Deciders: repository maintainers
- Review date: 2026-11-21

## Context

The initial extraction of `kramme:pr:review-convergence` required every direct invocation to repeat an authoritative `--requirements` block. That boundary kept the convergence phase independent from issue intake, but it made an already-established conversation or a referenced Linear issue unusable as the direct invocation's requirement source. Some prepared branches also arrive without enough authoritative conversation context even though their implementation evidence can seed a useful draft, provided the user remains the authority. Internal Linear and plan callers freeze their own contracts before delegation and must retain that stronger handoff.

## Decision

Allow direct invocations to freeze requirements from exactly one source, in this order:

1. an explicit inert `--requirements` block;
2. one Linear issue identifier or URL explicitly selected by the user; or
3. an explicit `--derive` mode whose agent-drafted contract the user approves; or
4. user-authored requirement context in the current conversation.

Linear lookup is read-only and conditional. It fetches the selected issue, comments, and only requirement-bearing linked context; it never updates the issue. A missing Linear connection or inaccessible requirement-bearing source blocks that route instead of silently falling back. Ordinary conversation extraction accepts assistant-proposed requirements only after explicit user confirmation and never uses the implementation, diff, commits, or repository conventions to invent missing intent.

The explicit derived mode may inspect user-authored conversation, the committed branch diff, changed files, tests, and commit messages as evidence. It labels inferences, asks consolidated questions when ambiguity could materially change the contract, and requires the user to approve the complete draft before review begins. Implementation evidence never becomes authoritative by itself, and identifiers or links found in the branch do not authorize additional data access.

Internal callers remain unchanged: they must provide the sentinel-last frozen requirements block, and convergence must preserve it byte-for-byte except for the existing plan-derived authority rule. This keeps caller-owned intake and validation-only replay deterministic.

## Consequences

- Direct review is usable after an ordinary implementation conversation without restating the task.
- A user can opt into an agent-drafted requirements contract when conversation context is incomplete, while retaining approval authority and the ability to answer clarifying questions.
- Derived mode adds a mandatory approval pause and still cannot recover intent, constraints, or non-goals that neither the user nor the branch evidence reveals.
- A user can select a Linear issue without invoking the end-to-end implementation workflow or authorizing any Linear mutation.
- The skill remains usable without Linear MCP unless the user selects a Linear source.
- Source ambiguity, conflicting requirements, and inaccessible requirement-bearing context stop before review.
- Public guidance and behavioral contracts must cover all four direct sources and the unchanged internal handoff.

## Alternatives Considered

### Continue requiring `--requirements`

Rejected because it discards authoritative context the agent already has and adds avoidable transcription drift.

### Infer requirements from the branch or commits without opt-in confirmation

Rejected because implementation evidence describes what was built, not necessarily what was requested, including non-goals and omitted acceptance criteria. The accepted derived mode uses that evidence only to draft questions and a candidate contract that the user must approve.

### Infer a Linear issue from the branch name

Rejected because branch naming is supporting evidence, not explicit user selection, and could bind review to stale or unrelated issue context.

## Amendment

The 2026-08-26 SIW boundary decision removed the SIW internal caller. The frozen internal handoff now applies to Linear and archived-plan callers.
