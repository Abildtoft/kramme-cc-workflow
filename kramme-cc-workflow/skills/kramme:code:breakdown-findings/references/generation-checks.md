# Generation checks

Load this only before Phase 5 or when diagnosing a failed plan-generation pass.

## Common rationalizations

These are stop signs, not exceptions:

- "All findings in one PR is faster." Split sprawling themes.
- "This theme is slightly XL but the engineer will manage." XL means split into a series.
- "Conflicting findings can both be addressed together." Surface the conflict as an open question.

## Red flags

The sizing flags do not apply to a pre-clustered handoff.

Stop and re-cluster if any of these appear:

- Any findings-mode theme lands at 9+ findings, or a single plan touches 9+ files.
- Any generated plan filename or title lacks an execution label such as `W01A`.
- A blocked plan's title, index row, or dependency section omits the label of the plan blocking it.
- Same-wave plans are described as sequential instead of parallel.
- Conflicting findings were silently reconciled instead of flagged as an open question.
- The index excludes nothing even though some findings are duplicates, already resolved, or not actionable.
- A findings-mode plan references "the review" or "finding #3".
- A handoff-mode plan uses findings vocabulary such as "Findings processed", "Findings excluded", "Source findings", or inferred severity.

## Before Phase 5

Verify:

- Every findings-mode theme is sized `L` or smaller.
- Every generated plan is self-contained and has no source back-reference such as "see the review", "per the audit", or "finding #N".
- Every generated plan filename and title includes its execution label.
- Every blocked plan names blocker labels in the title, index row, dependency map, and Dependencies and Sequencing section.
- Every same-wave group is marked as parallel in the index and summary.
- Every conflict between findings is surfaced as an open question.
- Every plan has all template sections populated with concrete content and no `N/A`.
- For a pre-clustered handoff, every declared theme maps to exactly one plan, no themes are merged/split/added/dropped, any supplied Implementation Setup block appears verbatim in every plan, and all summary/index statistics use theme language.
