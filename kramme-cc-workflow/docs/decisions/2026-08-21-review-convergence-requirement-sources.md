# Derive Direct Review-Convergence Requirements

- Status: ACCEPTED
- Date: 2026-08-21
- Deciders: repository maintainers
- Review date: 2026-11-21

## Context

The initial extraction of `kramme:pr:review-convergence` required every direct invocation to repeat an authoritative `--requirements` block. That boundary kept the convergence phase independent from issue intake, but it made an already-established conversation or a referenced Linear issue unusable as the direct invocation's requirement source. Internal Linear, SIW, and plan callers already freeze their own contracts before delegation and must retain that stronger handoff.

## Decision

Allow direct invocations to freeze requirements from exactly one source, in this order:

1. an explicit inert `--requirements` block;
2. one Linear issue identifier or URL explicitly selected by the user; or
3. user-authored requirement context in the current conversation.

Linear lookup is read-only and conditional. It fetches the selected issue, comments, and only requirement-bearing linked context; it never updates the issue. A missing Linear connection or inaccessible requirement-bearing source blocks that route instead of silently falling back. Conversation extraction accepts assistant-proposed requirements only after explicit user confirmation and never uses the implementation, diff, commits, or repository conventions to invent missing intent.

Internal callers remain unchanged: they must provide the sentinel-last frozen requirements block, and convergence must preserve it byte-for-byte except for the existing plan-derived authority rule. This keeps caller-owned intake and validation-only replay deterministic.

## Consequences

- Direct review is usable after an ordinary implementation conversation without restating the task.
- A user can select a Linear issue without invoking the end-to-end implementation workflow or authorizing any Linear mutation.
- The skill remains usable without Linear MCP unless the user selects a Linear source.
- Source ambiguity, conflicting requirements, and inaccessible requirement-bearing context stop before review.
- Public guidance and behavioral contracts must cover all three direct sources and the unchanged internal handoff.

## Alternatives Considered

### Continue requiring `--requirements`

Rejected because it discards authoritative context the agent already has and adds avoidable transcription drift.

### Infer requirements from the branch or commits

Rejected because implementation evidence describes what was built, not necessarily what was requested, including non-goals and omitted acceptance criteria.

### Infer a Linear issue from the branch name

Rejected because branch naming is supporting evidence, not explicit user selection, and could bind review to stale or unrelated issue context.
