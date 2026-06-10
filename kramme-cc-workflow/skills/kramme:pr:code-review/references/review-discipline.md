# Review discipline

Guidance for the spawned review agents and for the orchestrator's final-check pass. SKILL.md references this file from Step 7 (when instructing each reviewer) and Step 13 (before posting the aggregated report).

## Review speed norm

One business day is the **maximum** time a PR should sit waiting on review, not the target. If the review slips past a day, the diff stales, the author context-switches, and the eventual review skews toward nitpicks because the reviewer is working against the PR instead of with the author.

## Output markers

Use these markers so the user (and downstream tooling) can skim status at a glance. They are a **plugin-wide convention** for Addy-ported skills. Use them verbatim (uppercase, no decoration), one marker per line.

- **UNVERIFIED** — a finding asserted but not directly confirmed against the code. `UNVERIFIED: agent flagged a race on cache invalidation; I didn't trace all callsites`.
- **NOTICED BUT NOT TOUCHING** — a pre-existing issue or out-of-scope observation surfaced during review. `NOTICED BUT NOT TOUCHING: the whole retry helper swallows errors, but that's outside this PR`.
- **CONFUSION** — the reviewer can't decide whether something is a bug without more context. `CONFUSION: the nullable return from getUser() is new here; is None a valid result or a missing check?`
- **MISSING REQUIREMENT** — spec or intent is ambiguous; a product decision is needed before the review can complete. `MISSING REQUIREMENT: no guidance on how to handle the duplicate-email case — ask before approving`.

## Finding schema

Every active finding must include these fields before it is posted:

| Field | Values | Purpose |
| --- | --- | --- |
| Finding ID | `CR-001`, `CR-002`, ... | Gives downstream workflows a stable source identifier for handoffs and resolution summaries. |
| Severity | Critical, Important, Suggestion, FYI | Describes merge impact. Use the prefix grammar from `output-template.md`. |
| Location | `path/to/file:line`, `review-scope`, or `PR description` | Lets downstream workflows distinguish auto-fixable code findings from manual/process findings. |
| Confidence | `0-100` | States how directly the reviewer traced the issue. During the transition, map reviewer tiers as `high=90`, `medium=60`, `low=30`. |
| Action class | `gated_auto`, `manual`, `advisory` | Separates urgency from safe ownership. |
| Owner | resolver, author, maintainer, reviewer, unknown | Names who can act next. |
| Evidence | concrete trace, location, reproduction, failed expectation, or `UNVERIFIED` reason | Prevents unsupported findings from becoming gatekeeping. |

## Action classes

- **`gated_auto`** — Code-backed Critical or Important finding with a concrete file/line, an unambiguous fix direction, and enough confidence for `/kramme:pr:resolve-review` to attempt it. Do not use this for PR-description drift, product decisions, missing requirements, or broad process issues.
- **`manual`** — The finding needs human judgment, a maintainer decision, product clarification, cross-team ownership, a PR-description update, or a trace the reviewer could not complete. Manual findings may still block merge when impact is high.
- **`advisory`** — Optional polish, FYI, low-confidence observation, or improvement idea. Advisory findings do not block merge and are not eligible for automatic resolution.

## Severity and action-class compatibility

- Critical and Important findings may use only `gated_auto` or `manual`; they must not use `advisory` because those buckets represent blocking or recommended work.
- Suggestions and FYI observations use `advisory`; do not mark optional work as `manual` just because a human would perform it.
- If a finding feels optional, put it in Suggestions instead of keeping it in Critical/Important with `advisory`.
- If a Critical or Important finding cannot be auto-resolved, keep it `manual` and name the decision or owner needed next.

## Confidence and merge rules

- **90-100 confidence** means the reviewer traced the behavior to the changed code, reproduced it, or tied it to a concrete failing expectation.
- **60-89 confidence** means the issue is strongly indicated by the diff but still depends on a nearby assumption, framework behavior, or untested runtime state.
- **0-59 confidence** means the issue is plausible but not traced. Keep the `UNVERIFIED` marker visible and avoid merge-blocking language unless another reviewer proves the same risk.
- Merge duplicate findings only when they identify the same concrete location or review scope and the same root cause.
- Promote confidence only when independent reviewers agree on the same issue, not merely the same broad concern.
- Keep contradictory findings separate and record the conflict as `CONFUSION` or `MISSING REQUIREMENT` with action class `manual`.

## Common rationalizations

Watch for these excuses — they signal the review is slipping into low-value territory.

| Excuse | Reality |
| --- | --- |
| "It's just a nit, skip it." | Nits compound across reviews; ship the `Nit:` prefix and let the author decide, or the diff drifts on every PR. |
| "This doesn't block merge, so it's fine." | "Doesn't block" is not "good." Approve only if the change definitely improves overall code health. |
| "AI wrote it, and the tests pass." | AI-generated code needs more scrutiny, not less — it's confident even when wrong. Read the diff as if a new hire wrote it under deadline. |
| "We can clean this up in a follow-up." | Follow-ups are negotiable; the diff on screen is not. Land the cleanup or mark it `Critical:` now. |
| "I'll re-review when they push again." | Re-review is a checkpoint, not a finding delivery mechanism. Surface every finding on the first pass or they rot across round-trips. |

## Red flags — STOP

If any of these are true, pause and re-scope the review before posting it:

- Every finding you're about to post is marked **Critical:** — the bucket has lost meaning; re-triage.
- The review is older than the PR (you've been reviewing longer than the author spent writing).
- You're rewriting the PR in your head instead of reviewing the diff in front of you.
- You're flagging style issues the project doesn't enforce anywhere else.
- You're requiring defensive checks, logging, retries, or validation layers that nearby code intentionally does not use, and you cannot point to a concrete new failure path.
- You're approving because the CI is green, not because the change definitely improves overall code health.
- A dead-code finding is phrased as an instruction (`"delete X"`) instead of the ask shape (`DEAD CODE IDENTIFIED: X. Safe to remove these?`).
- You have no `FYI` in the Strengths section — a review with zero positive observations is usually miscalibrated, not comprehensive.

## Verification checklist

Before posting the review, confirm:

- [ ] Every finding has a severity prefix (`Critical:`, `Nit:`, `Optional:`, `Consider:`, `FYI`, or no prefix for Required).
- [ ] Every active finding has a stable Finding ID (`CR-001`, `CR-002`, ...).
- [ ] Every active finding includes Location, Confidence, Action class, Owner, and Evidence.
- [ ] Dead-code findings use the verbatim ask shape `DEAD CODE IDENTIFIED: [list]. Safe to remove these?`
- [ ] The Approval Standard line appears: _"Approve if the change definitely improves overall code health."_
- [ ] Pre-existing or out-of-scope observations are labeled `NOTICED BUT NOT TOUCHING`.
- [ ] Every emphasized dimension in `--emphasize` actually produced findings in this review (or you noted that it didn't).
- [ ] No finding is presented as certain when the reviewer didn't trace it — those are labeled `UNVERIFIED`.
- [ ] `gated_auto` appears only on code-backed findings with a concrete location and a clear fix path.
- [ ] `advisory` appears only on Suggestions or FYI observations, never on Critical or Important findings.
