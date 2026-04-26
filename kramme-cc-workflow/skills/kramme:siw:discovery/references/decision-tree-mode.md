# Decision-Tree Mode

Use this mode for tightly coupled SIW discovery where one decision determines which questions are meaningful next: high-stakes architecture, data model shape, refactor sequencing, migration approach, or any branch where decision A unlocks decision B.

## Process

1. Identify the root decision in one sentence.
2. Map first-level dependencies as a small tree: `root -> prerequisite -> downstream branch`.
3. Resolve branches depth-first. Do not ask about a downstream branch until its prerequisite is settled.
4. After each answer, update the tree: mark resolved branches, remove invalidated branches, and add newly exposed dependencies.
5. When the active branch is resolved, either choose the next unresolved branch or return to coverage mode for independent confidence gaps.

## Pacing

- Default to one question at a time.
- Batch only when sibling questions are routine, low-stakes, and independent.
- If the answer could change the next question, do not batch.

## Codebase-as-Answer-Source Rule

Before asking, check whether the answer is in the codebase, target spec, SIW docs, or provided artifacts. If yes, explore and report the finding with source references instead of asking. Ask only for confirmation or correction when uncertainty remains.

Skip the check when the question is about preference, priority, organizational context, or business appetite that no artifact could know.

## ADR-Offer Hook

When a resolved decision meets all three criteria, offer to invoke `/kramme:docs:adr`:

1. Hard to reverse.
2. Surprising without context.
3. Result of a real tradeoff.

State the three criteria in the offer so the user can audit the trigger. Do not inline-author the ADR from this skill.

## Switch Back to Coverage

Return to coverage mode when remaining open questions are independent confidence dimensions rather than dependencies in the decision tree.
