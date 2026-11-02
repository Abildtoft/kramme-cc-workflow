# Decision-Tree Mode

Use this mode when the topic contains tightly coupled decisions where a later question depends on an earlier answer. It is strongest for architecture decisions, feature scope forks, data model choices, workflow ownership, migration paths, and documentation proposals with unresolved strategic direction.

## Process

1. Identify the root decision in one sentence.
2. Map first-level dependencies as a small tree using the active profile's dimensions. Example: `root architecture choice -> migration path -> rollout risk`.
3. Resolve branches depth-first. Do not ask about a downstream branch until its prerequisite is settled.
4. After each answer, update the tree: mark resolved branches, remove invalidated branches, and add newly exposed dependencies.
5. When the active branch is resolved, choose the next unresolved branch or return to the active coverage profile for independent gaps.

## Pacing

- Default to one question at a time.
- Batch only when sibling questions are routine, low-stakes, and independent.
- If the answer could change the next question, do not batch.

## Codebase-as-Answer-Source Rule

Before asking, check whether the answer is in the codebase, target artifacts, provided files, or existing docs. If yes, explore and report the finding with source references instead of asking. Ask only for confirmation or correction when uncertainty remains.

Skip the check when the question is about preference, priority, organizational context, ownership, or business appetite that no artifact could know.

## ADR-Offer Hook

Use the ADR-offer hook owned by the active progress profile: `interview-operations.md` for topic coverage or `probing-techniques.md` for evidence confidence. This mode changes traversal order, not the interaction contract.

## Switch Back to Coverage

Return to the active coverage profile when remaining open questions are independent dimensions rather than dependencies in the decision tree.
