# Decision-Tree Mode

Use this mode when the topic contains tightly coupled decisions where a later question depends on an earlier answer. It is strongest for architecture decisions, feature scope forks, data model choices, workflow ownership, migration paths, and documentation proposals with unresolved strategic direction.

## Process

1. Identify the root decision for the current Topic Type.
2. Map first-level dependencies using the topic's Question Dimensions. Example: `root architecture choice -> migration path -> rollout risk`.
3. Resolve one branch depth-first before asking about downstream or sibling branches.
4. After each answer, update the dependency tree and coverage notes.
5. Return to the topic-classified coverage flow when remaining gaps are independent dimensions rather than branch dependencies.

## Pacing

- Ask one question at a time by default.
- Batch only routine sibling questions that are independent and low-stakes.
- If the answer could change the next question, do not batch.

## Codebase-as-Answer-Source Rule

Before asking, check whether the answer is in the codebase, provided files, or existing docs. If yes, explore and report the finding with source references instead of asking. Ask only for confirmation or correction when uncertainty remains.

Skip the check when the question is about priorities, appetite, ownership, or business context that no artifact could know.

## ADR-Offer Hook

When a resolved decision meets all three criteria, offer to invoke `/kramme:docs:adr`:

1. Hard to reverse.
2. Surprising without context.
3. Result of a real tradeoff.

State the three criteria in the offer so the user can audit the trigger. Do not inline-author the ADR from this skill.
