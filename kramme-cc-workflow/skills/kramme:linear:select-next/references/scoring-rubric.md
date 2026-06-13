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

## Parallelism Checklist

Highlight issues as parallel candidates only when all relevant checks pass:

- No explicit `blockedBy`, `blocks`, duplicate, or parent/child dependency connects them.
- Different projects, feature areas, workflows, or likely code ownership areas.
- No shared migration, schema change, API contract, feature flag, release gate, or design approval.
- Each issue has its own acceptance criteria and can be verified independently.
- The order of merging should not matter, or the only coordination is routine conflict avoidance.

When evidence is weak, report `possible parallel candidates` and name the uncertainty.
