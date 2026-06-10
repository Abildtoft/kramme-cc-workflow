# Residual Work Gate

Before choosing the verdict, every unresolved or noteworthy item from verification, code review, product review, UX review, and QA must receive exactly one disposition:

| Disposition | Use when | Required fields |
| --- | --- | --- |
| `fixed_now` | The issue was resolved during this finalize run, usually through `--fix` and re-verification. | source, previous severity, fix summary, verification result |
| `deferred_with_owner` | The work can wait without invalidating the PR, and someone owns the follow-up. | source, owner, rationale, follow-up path |
| `accepted_risk` | The maintainer intentionally accepts the remaining risk. | source, owner/approver, rationale, rollback or monitoring note |
| `blocked_by_missing_information` | The orchestrator cannot determine readiness without a product, design, security, infrastructure, or release decision. | source, missing decision, who must answer |
| `not_relevant` | The item was filtered, previously addressed, out of scope, or not caused by the branch. | source, reason |

## Rules

- Unclassified residual work is a blocker. Do not return `READY WITH CAVEATS` while any remaining item lacks a disposition.
- Critical review findings, QA blockers, verification failures, and `blocked_by_missing_information` items are blockers unless they were fixed now and re-verified.
- `COULD NOT RUN` steps are residual work. Classify them as `blocked_by_missing_information` when their result is necessary for merge confidence; otherwise classify as `deferred_with_owner` or `accepted_risk` with rationale.
- Suggestions and advisory findings may be `deferred_with_owner`, `accepted_risk`, or `not_relevant`, but they still need an explicit disposition.
- `gated_auto` code-review findings are eligible for `--fix`; `manual` findings remain human follow-up; `advisory` findings must not become automatic fix work.
- Description generation runs after the readiness verdict and reports its own result separately. Do not include generation output in the residual-work gate.

Store all residual item dispositions for the verdict template, not only blockers. `READY WITH CAVEATS` must show the actual deferred and accepted-risk items so the user can review what remains before creating the PR.
