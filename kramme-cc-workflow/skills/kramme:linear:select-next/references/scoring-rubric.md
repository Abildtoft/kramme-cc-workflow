# Scoring Rubric

Use this rubric to compare issues consistently. Scores are a thinking aid, not a public precision claim. In the final answer, explain the concrete evidence instead of reporting only a number.

## Value Signals

Add value for evidence that the issue matters now:

| Signal | Guide |
| --- | --- |
| Linear priority | Urgent +30, High +22, Medium +12, Low +4, None +0 |
| Active project, initiative, milestone, release, or due date | +8 to +18 depending on proximity and explicit delivery pressure |
| Customer evidence | +5 to +20 for customer needs, named customer impact, tier/revenue signal, support pain, or repeated asks |
| Unblocks work | +5 per dependent issue, max +20; prefer explicit `blocks` relations over vague claims |
| Incident, regression, security, data loss, billing, or trust impact | +12 to +25 depending on severity and evidence |
| Product/user impact | +5 to +20 for clear workflow, revenue, activation, retention, reliability, or usability value |
| Engineering leverage | +4 to +12 when the issue removes repeated manual work, reduces operational risk, or simplifies future delivery |
| Assigned to the logged-in user | +3 as an ownership tie-breaker only; do not let it override much higher-value unassigned work |

## Preference Fit

Apply this section only when the user provided `--interest` or equivalent clarified preference text. Preference fit adjusts close rankings; value and readiness still decide the recommendation unless the user explicitly asked for only that work type.

| Fit | Guide |
| --- | --- |
| Strong | +8 to +12 when title, labels, project, description, and likely implementation area clearly match the stated work type |
| Partial | +3 to +7 when one or two signals match but the issue also includes unrelated work |
| Weak | +0 to +2 when the match is speculative or based only on broad keywords |
| Conflict | -5 to -12 when the issue is clearly the opposite of the stated preference, such as high-coordination architecture work when the user asked for small isolated bugs |

Examples of useful preference dimensions: frontend/backend, bug/feature/refactor/docs, small/large scope, exploratory/planned, customer-facing/internal, high-impact/low-coordination, design-heavy/implementation-heavy, cleanup/architecture.

## Readiness Modifiers

Subtract when the issue is not safe to start:

| Condition | Guide |
| --- | --- |
| Explicit blocker, blocked state, waiting state, or blocking label | -40 and classify as `blocked` unless the blocker is already resolved |
| Missing acceptance criteria or unclear success condition | -8 to -15 and usually classify as `clarify-first` |
| Missing product/design/security decision | -12 to -25 depending on whether implementation would be guesswork |
| Large ambiguous scope or likely cross-team coordination | -8 to -18 |
| Duplicate-looking or superseded by another issue | -20 and classify as `not-now` unless evidence says otherwise |
| No description or context beyond the title | -15 and classify as `clarify-first` unless the title is fully operational |

## Readiness Classes

- `ready`: the issue has enough context to start, no unresolved blockers, and a plausible completion boundary.
- `clarify-first`: value is real, but a question must be answered before implementation should begin.
- `blocked`: Linear state/labels/relations/comments show a dependency, waiting condition, or approval gate.
- `not-now`: low value relative to alternatives, duplicate-looking, stale without evidence, or outside the requested team/project focus.

## Autonomous Agent-Readiness

Synced Linear agent-readiness contract (keep aligned across Linear readiness workflows): An issue is `agent-ready` only when every item passes. Record the failing items for every other issue.

| Item | Test |
| --- | --- |
| Problem is stated | The issue says what is wrong or missing and for whom, not only what to build. |
| Outcome is observable | A reader can describe the user-visible or system-visible behavior after the change. |
| Acceptance criteria are verifiable by running something | Each criterion can be checked by a test, a command, a request, or a reproducible manual step with a stated expected result; none requires taste or a stakeholder's opinion. |
| Scope is bounded | The work is Pull Request-sized, and at least one explicit non-goal or boundary prevents the agent from expanding into neighboring work. |
| Decisions are made | No open questions, "TBD", "discuss with", or competing options remain in the body or recent comments. Decisions that were made in comments are reflected in the description. |
| Inputs are reachable | Reproduction steps, sample data, links, designs, or API contracts the work depends on are either in the issue or derivable from the repository. Nothing requires credentials, unreleased assets, or a person's tacit knowledge. |
| Dependencies are clear | Blocking relations are resolved or explicitly stated as prerequisites with their identifiers. |
| Done is detectable | The issue says how to confirm completion (tests to add or pass, behavior to demonstrate), so the agent can stop at the right point. |

| Grade | Meaning |
| --- | --- |
| `agent-ready` | Every item passes. |
| `needs-refinement` | One or more items fail, and the gap can be closed by a rewrite grounded in the repository or by one answer from a person. |
| `human-only` | The gap is a product decision, design direction, or access an agent cannot obtain, and closing it is itself the work; or the issue is exploratory by nature ("investigate", "spike", "decide"). Keep such issues clear for humans; do not force them toward `agent-ready`. |

Do not infer agent-readiness from priority, an `agent-ready` label, assignment, state name, or a phrase such as "straightforward" alone. Those are supporting signals, not substitutes for the checklist. When evidence for an applicable item is unavailable, classify the issue as `needs-refinement` rather than guessing unless the missing input or decision requires a person, which makes it `human-only`.

When `--agent-ready-only` is active, these classes are a hard eligibility gate rather than a score adjustment.

## Parallelism Checklist

Highlight issues as parallel candidates only when all relevant checks pass:

- No explicit `blockedBy`, `blocks`, duplicate, or parent/child dependency connects them.
- Different projects, feature areas, workflows, or likely code ownership areas.
- No shared migration, schema change, API contract, feature flag, release gate, or design approval.
- Each issue has its own acceptance criteria and can be verified independently.
- The order of merging should not matter, or the only coordination is routine conflict avoidance.

When evidence is weak, report `possible parallel candidates` and name the uncertainty.
