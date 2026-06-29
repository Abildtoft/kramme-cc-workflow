# Interview operations

Load this before Step 3 and consult it again before Step 5.

## Question philosophy

Craft questions that:

- **Challenge assumptions** - Present alternatives the user may not have considered.
- **Expose edge cases** - Surface scenarios that could break the design.
- **Reveal dependencies** - Uncover hidden connections to existing systems.
- **Quantify tradeoffs** - Make abstract concerns concrete.
- **Force prioritization** - Clarify what should not be done in this pass.
- **Separate decision ownership** - Distinguish product calls from implementation choices.
- **Plan the learning loop** - Ask how the team will know quickly if the approach is working.

Avoid obvious questions. Never ask "What is the feature?" or "Why do you want this?" If the artifact or codebase already answers a question, do not ask it again. Explore first, present the inferred answer with the source, and ask only for confirmation or correction.

If a dimension requires information the artifact does not contain and the user has not provided, emit `MISSING REQUIREMENT:` before asking the user to fill the gap.

## Codebase-as-answer-source rule

Before each question in either coverage or decision-tree mode, decide whether the workspace, provided files, or existing docs can answer it.

- Explore instead of asking when the answer is discoverable.
- Ask only for confirmation or correction if the source is stale, ambiguous, or incomplete.
- Skip exploration when the question is about priorities, appetite, ownership, or other context only the user can provide.

## Question mechanics

Before crafting the first interview round, read `references/question-dimensions.md`. It covers:

- AskUserQuestion structure: 2-4 predefined options per question, `header`/`question`/`options`/`multiSelect` fields.
- Question Context Pattern: every question is preceded by "Why this matters" and a recommendation, with complete good/bad examples.
- Question Dimensions by Topic Type: the per-topic dimension catalogs (Software Feature, Process/Workflow, Architecture Decision, Documentation/Proposal) that drive round planning and coverage tracking.

## Round structure and follow-up behavior

Ask **1-4 questions per round** using AskUserQuestion. Mix questions across different dimensions.

For high-stakes or dependency-shaping decisions, ask one question in the round. Apply the Codebase-as-answer-source rule before every question.

After receiving answers, provide a brief synthesis before the next round:

```text
"Based on your answers: [key insight]. This raises follow-up questions about [area]..."
```

After each round, analyze the answers and adapt your next questions:

- **Dig deeper when:** an answer reveals unexpected complexity, the user mentions a constraint or concern in passing, or a decision has significant downstream implications.
- **Pivot when:** answers reveal the problem is different than assumed, a previously unexplored dimension becomes critical, or the user's priorities shift from initial assumptions.
- **Clarify when:** an answer is ambiguous or contradictory, the user selects "Other" with a response that needs unpacking, or technical terms/domain concepts need definition.

Do not just check boxes. The goal is understanding, not coverage. If the remaining gaps are low-value or implementation-level only, stop the interview and move to synthesis.

## ADR-offer hook

After each resolved decision, offer `/kramme:docs:adr` only when all three criteria are true:

1. The decision is hard to reverse.
2. It would be surprising later without context.
3. It came from a real tradeoff, not a default.

Surface the offer via AskUserQuestion with this payload, replacing each `{...}` evidence placeholder with a concrete one-line reason from the interview:

```yaml
AskUserQuestion
header: "ADR offer"
question: |
  This decision looks ADR-worthy:
  - Hard to reverse: {hard_to_reverse_evidence}
  - Surprising without context: {surprising_without_context_evidence}
  - Result of a real tradeoff: {real_tradeoff_evidence}

  Record as an ADR?
options:
  - label: "Author ADR"
    description: "Invoke /kramme:docs:adr now"
  - label: "Skip"
    description: "Don't author, and don't ask again about this decision"
  - label: "Defer"
    description: "Don't author now; allow re-offer if the decision recurs"
multiSelect: false
```

Prompt at most once per decision: track which decisions have already been offered in the current session (by title or stable identifier) and do not re-offer them. `Skip` and `Defer` differ here: `Skip` suppresses re-offers of that decision for the lifetime of the session; `Defer` allows a re-offer only if the same decision resurfaces in a later workflow step.

On "Author ADR", hand off to `/kramme:docs:adr` (optionally pre-loading a decision title and short context summary as its arguments). Do not author the ADR inside this skill.

## Progress tracking

After each round, display coverage status using dimensions relevant to the topic type:

```text
Software Feature: [Architecture: 70%] [Data Model: 60%] [API: 40%] [UX: 80%] [Integration: 20%]
Process/Workflow: [Triggers: 80%] [Steps: 60%] [Roles: 40%] [Exceptions: 20%] [Metrics: 0%]
Architecture Decision: [Options: 90%] [Tradeoffs: 70%] [Constraints: 50%] [Migration: 30%]
Documentation/Proposal: [Clarity: 80%] [Completeness: 60%] [Feasibility: 40%] [Actionability: 20%]
```

Adjust percentages based on how thoroughly each dimension has been explored.

Stop interviewing when:

- All relevant dimensions show 80%+ coverage.
- No major unknowns remain for the topic type.
- User indicates satisfaction with exploration depth.
- Enough information exists to write a comprehensive plan.
- Simple topics have enough coverage; do not artificially extend the interview.

## Common rationalizations

- _"The topic is already clear enough to skip Phase 0."_ Sometimes true. But if you cannot state the concrete outcome in one sentence, the framing is vague and Phase 0 will save rounds.
- _"The user will correct me if I'm wrong."_ They often will not, because they do not know what they do not know. Use `CONFUSION:` to surface mismatches early.
- _"Coverage at 80% across all dimensions means I'm done."_ Coverage is a proxy, not a goal. Stop when no major unknowns remain, even if a dimension sits at 60%.
- _"The template handles all topic types, so classification doesn't matter."_ It does. The template shapes what questions to ask; picking the wrong one produces a weak plan.

## Red flags

- Asking a question whose answer is already in the artifact. Stop and re-read the artifact.
- Generating a plan before the user has confirmed the classification or chosen a Phase 0 framing.
- Auto-running Phase 0 on a concrete topic the user already scoped when `--ideate` was not requested. Skip it.
- Auto-running Phase R on a pure-priorities or business-context topic where research cannot help. Skip it.
- Letting Phase R findings sit unread because they do not fit the original hypothesis. Surface contradictions before the interview, not after.
- Filling in a plan section from assumption rather than interview data. Emit `MISSING REQUIREMENT:` instead.
- Letting a Phase 0 framing change stand without reclassifying the topic type and template choice.
- The interview drifts into implementation minutiae before the problem statement is settled.

## Pre-plan verification

Before writing the plan, confirm:

- [ ] The working hypothesis from Step 1 has been either validated or explicitly corrected during the interview.
- [ ] The topic type from Step 2 matches what the user actually cares about, not just what the artifact happens to contain, and was reclassified if Phase 0 or Phase R changed the framing.
- [ ] If Phase 0 ran, the chosen framing was restated as a concrete problem statement and the user confirmed it.
- [ ] If Phase 0 was auto-triggered, the user was given an explicit skip-or-continue choice before variations were generated.
- [ ] If Phase R ran, the post-research check-in surfaced any contradictions before the interview began, and the chosen template's `Sources` section is populated with the file paths and URLs each agent returned.
- [ ] Every dimension either has interview-grounded content or an explicit `MISSING REQUIREMENT:` marker.
- [ ] If the chosen template includes a non-goals section, each entry includes a rationale instead of a bare placeholder.
- [ ] If the chosen template has a `Risks & Mitigations` (or equivalent) section, each risk is concrete (e.g., "this adds an N+1 query on every page load") rather than vague ("this could be slow").
