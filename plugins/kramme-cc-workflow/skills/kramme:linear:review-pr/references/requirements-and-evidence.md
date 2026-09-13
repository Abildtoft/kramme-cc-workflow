# Requirement and Evidence Rules

Use these rules to turn Linear intent into a checkable matrix and to judge the Pull Request consistently.

## Requirement Extraction

Extract a requirement when the primary issue or requirement-bearing reference defines a checkable outcome, constraint, boundary, or delivery obligation. Sources include:

- Acceptance-criteria bullets and checklists
- User-visible behavior and state transitions
- Validation, permission, data-access, and failure rules
- Explicit names, API shapes, schema constraints, configuration, and defaults
- Required tests, documentation, telemetry, rollout, or migration work
- Clarifications in comments that explicitly update or narrow the issue

Do not extract:

- Background motivation with no checkable outcome
- Brainstorming, rejected alternatives, or open questions
- Related-issue requirements not adopted by the primary issue
- Future work, follow-ups, or explicitly out-of-scope behavior
- Implementation details invented from the PR itself

When issue text conflicts with a later comment, record both citations. Treat a clear authorized update as superseding earlier text and explain the precedence. Otherwise mark the requirement ambiguous and block if it affects acceptance or scope.

## Matrix Fields

Record each row with:

| Field | Meaning |
| --- | --- |
| ID | Run-local identifier such as `LREQ-001` |
| Linear citation | Issue identifier plus section/bullet, or comment author and timestamp |
| Requirement | One checkable statement in local wording |
| Strict markers | `MUST`, `ONLY`, `NEVER`, or equivalent; otherwise `none` |
| Expected evidence | Behavior, code path, test, docs, configuration, or migration needed |
| Status | One Pass A status from below |
| PR evidence | Diff hunk and resulting code citations |
| Test evidence | Test location and result, or explicit gap |
| Notes | Scope decision, ambiguity, or limitation |

Split compound acceptance criteria when their clauses can succeed or fail independently. Keep one row when the clauses are inseparable parts of one observable outcome.

## Pass A Statuses

- `VERIFIED` — the PR introduces the required behavior and direct evidence covers the material path and constraints.
- `PARTIAL` — the PR implements some but not all of the requirement, or covers only a happy path where the requirement includes material boundary states.
- `MISSING` — no PR-introduced implementation evidence exists for an in-scope requirement.
- `CONTRADICTED` — the PR introduces behavior that violates the requirement.
- `UNVERIFIED` — available evidence cannot establish compliance or noncompliance. Name the exact missing observation, test, environment, or source.
- `OUT_OF_SCOPE` — the issue itself explicitly defers or excludes the item. Cite the scope boundary; do not use this status merely because the PR omitted something.

Pre-existing behavior can support `VERIFIED` only when the issue requires the PR to preserve that behavior and the diff demonstrably does so. It cannot satisfy a requirement that asks this PR to introduce a change.

## Evidence Standard

Findings and verified alignments need all applicable evidence:

1. **Linear citation** — issue section/bullet or comment author and timestamp, with a short quote or faithful paraphrase.
2. **Diff citation** — changed file and hunk/line showing what the PR introduces.
3. **Code citation** — resulting PR-head Git object and snapshot line showing the complete relevant behavior, including surrounding control flow when needed.
4. **Test evidence** — test file and line plus a trusted CI check/result tied to the reviewed head when available; otherwise state why static evidence is sufficient or which runtime proof is missing.
5. **Behavior statement** — concrete input or state, resulting behavior, and why that satisfies or violates the requirement.

Use line numbers from the immutable `PR_HEAD_OID` blob. Distinguish diff evidence from unchanged supporting code. Never cite the PR body or commit message as proof that the code behaves a certain way.

## Trusted CI Evidence

`statusCheckRollup` is discovery data, not sufficient proof on its own. Credit a CI result as trusted runtime evidence only when all of these are established:

1. **Immutable snapshot** — the result belongs to `PR_HEAD_OID`, or to a documented synthetic merge commit whose head and base exactly match `PR_HEAD_OID` and `PR_BASE_OID`.
2. **Terminal conclusion** — the check completed with success or failure. Pending, queued, skipped, neutral, cancelled, stale, or missing results are not runtime evidence.
3. **Approved producer** — GitHub check details identify an approved GitHub App, workflow, or external CI integration. A familiar check name, PR-body claim, or green-looking status is not producer identity.
4. **Controlled execution definition** — the workflow, reusable workflow, local action, runner configuration, and test-command definition are controlled by the pinned base tree or verified unchanged from `MERGE_BASE`. If the PR changes any part of that definition, the result is not trusted runtime evidence unless an independent maintainer-controlled check with an approved producer validates the same behavior.

Query GitHub check-run or status details when `statusCheckRollup` omits a required trust field. If any condition cannot be established, record the result as an `UNVERIFIED` evidence gap. Trust and evidentiary direction are separate: a trusted success may support `VERIFIED`; a trusted failure may support a finding only when its check details or logs concretely trace the failure to the requirement. A failed check by itself does not prove which requirement is unsatisfied.

## Finding Severity

- `Critical` — the PR violates a security, authorization, privacy, destructive-data, contractual, or similarly high-impact requirement; or would make the issue's essential outcome unsafe to ship.
- `Major` — an acceptance criterion is missing, partial, or contradicted; a material undocumented extension or unrelated behavior changes review/rollout risk; or a required migration/configuration path is absent.
- `Minor` — a bounded edge case, test gap, documentation omission, or low-risk extension weakens completeness without defeating the core acceptance outcome.

Do not promote an evidence gap to a defect. Put it under `Unverified requirements` unless direct evidence establishes incorrect behavior.

## Verdict Rules

- `PASS` — every in-scope requirement is `VERIFIED`; every material change is `REQUIRED` or `SUPPORTING`; there are no findings or blocking context gaps.
- `PASS_WITH_CONCERNS` — no requirement is `MISSING`, `PARTIAL`, or `CONTRADICTED`, and no Critical or Major finding exists, but Minor findings or non-blocking verification limitations remain.
- `FAIL` — any Critical or Major implementation/scope finding exists, including a missing, partial, or contradicted acceptance criterion.
- `BLOCKED` — the issue has no checkable requirements, requirement-bearing context is materially inaccessible, the primary issue or PR cannot be resolved, the PR changes repeatedly during review, or evidence ambiguity prevents a defensible acceptance verdict.

`BLOCKED` takes precedence over `FAIL` when the missing evidence could change the overall verdict. Still report directly proven defects found before the blocker.

## Coverage Gates

Before reporting:

- Each extracted requirement has exactly one Pass A status.
- Every changed file belongs to at least one material change group, and each material group has exactly one Pass B classification.
- All `PARTIAL`, `MISSING`, and `CONTRADICTED` rows appear in Findings.
- All `UNDOCUMENTED_EXTENSION`, `UNRELATED`, and `CONTRADICTORY` change groups appear in Findings.
- All `UNVERIFIED` rows state the exact evidence needed to resolve them.
- At least one verified alignment is shown when the verdict is `PASS` or `PASS_WITH_CONCERNS`.
