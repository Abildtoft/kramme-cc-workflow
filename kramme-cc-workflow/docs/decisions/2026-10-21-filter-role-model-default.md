# Default Review Filter Roles to a Lower Model Class

- Status: PROPOSED
- Date: 2026-10-21
- Deciders: repository maintainer
- Decision review: 2026-11-21

## Context

Review subagents run on the orchestrator's model unless the user passes `--subagent-model` or sets `KRAMME_REVIEW_SUBAGENT_LEVEL=lower`. The [shared review model policy](../../shared/pr-review/references/model-selection.md) treats an unset or empty setting as `same`, and applies it to every review subagent: primary reviewers, team members, refutation and justification passes, relevance validators, slop meta-reviewers, and loop verifiers.

Two of those roles find no defects. They filter or annotate findings that earlier reviewers already produced:

- **Relevance validation.** `kramme:pr-relevance-validator` labels each finding as caused by the review scope or as pre-existing or out of scope. `kramme:pr:code-review` treats its output as "classifications over the original finding records, not replacement findings", and the report keeps filtered findings visible under "Filtered Issues", shown separately. Product review and convention review also list filtered findings in their own section.
- **Slop meta-review.** A second `kramme:deslop-reviewer` invocation, whose prompt opens with `Operate in meta-review mode.`, receives the validated findings without a diff and "Adds slop warnings to flagged suggestions (does not remove them)".

Since the [2026-10-20 risk-routing record](2026-10-20-risk-routed-review-convergence.md), `kramme:pr:code-review` records both stages as `skipped` and launches no agent when no finding reaches them.

Where each role runs:

| Role | Launched by | Loads the shared policy |
| --- | --- | --- |
| Relevance validation | `kramme:pr:code-review` (Step 8 and Team Mode Phase 3), `kramme:pr:product-review` (Step 8 and Team Mode Phase 2), `kramme:pr:convention-review` (after the refutation pass) | Yes |
| Relevance validation | `kramme:code:copy-review` (diff mode) | No |
| Slop meta-review | `kramme:pr:code-review` (Step 9 and Team Mode Phase 4) | Yes |

Both agent definitions declare `model: inherit`.

### Usage evidence

Source: the local skill-usage log and Claude Code transcripts for 2026-10-06 to 2026-10-20.

- `kramme:deslop-reviewer` was the most-launched plugin agent, with 362 launches covering both its primary-review and meta-review invocations. `kramme:pr-relevance-validator` was second, with 201.
- Subagents accounted for 65% of weighted tokens. 2,674 of 2,724 subagent launches inherited the parent (Opus) model, and `KRAMME_REVIEW_SUBAGENT_LEVEL` was unset.
- 64 of 308 Claude Code sessions hit the subscription session limit, on 11 of 15 days. Review-heavy entry skills were hit most: `kramme:pr:github-review` in 15 of 31 sessions, `kramme:code:plan-to-pr` 11 of 18, `kramme:linear:issue-to-pr` 10 of 19, and `kramme:pr:code-review` 6 of 20.
- 62 of the 71 "continue" or "resume" nudges came in sessions that hit the limit.

The data does not separate the filter roles' share of tokens from the rest of a review run, so the size of the saving is not known yet. [Evidence Required Before Acceptance](#evidence-required-before-acceptance) closes that gap.

## Proposal

When none of `--subagent-model`, a conversational reviewer-model choice, or an explicit `KRAMME_REVIEW_SUBAGENT_LEVEL` value is present, review skills that load the shared policy would launch relevance validators and the slop meta-review one class below the trusted orchestrator class, using the policy's existing step-down ladder (for example Claude Opus to Sonnet, Codex Sol to Luna; Haiku and Luna stay at the floor).

Every defect-finding role would stay on the orchestrator's model: primary reviewers, Team Mode reviewer teammates, refutation and justification passes, and loop verifiers.

Explicit choices would keep their current meaning:

- `KRAMME_REVIEW_SUBAGENT_LEVEL=same` keeps every role, filters included, on the orchestrator's model.
- `KRAMME_REVIEW_SUBAGENT_LEVEL=lower` keeps today's meaning and steps every role down.
- `--subagent-model` or a conversational reviewer-model choice still applies to every role.

An unknown orchestrator class, an unavailable step-down model, a host that cannot select a subagent model, and a class already at the floor would keep the policy's existing fallback and reporting rules.

`kramme:code:copy-review` does not load the shared policy and is outside this proposal. Whether its validator should follow is a follow-up for the accepting change.

## Consequences

This record changes no behavior while it is PROPOSED. The change that accepts it would update:

- The shared policy's level semantics and role list, so that unset means "filters lower, everything else same".
- The relevance validation and slop meta-review launch steps in `kramme:pr:code-review`, `kramme:pr:product-review`, and `kramme:pr:convention-review`, and the matching Team Mode references.
- The review-model section of the repository README.
- The review model tests.

If accepted, the two most-launched plugin agents would run on a cheaper class by default, and no defect-finding reviewer would.

## Alternatives Considered

### Keep the deferral unchanged

Every reviewer stays on the orchestrator's model until the 2027-01-20 adoption review. This keeps current cost and session-limit pressure on the review-heavy entry skills for three more months, although the filter-role question can be measured much sooner.

### Lower every reviewer by default

This is the option the 2026-10-20 record deferred. It is rejected here because defect-finding reviewers carry the quality risk: a weaker primary reviewer misses findings that no later stage can recover.

### Add a third setting value or a separate variable for filter roles

An opt-in such as a `filters` level would avoid changing the default, but it keeps today's cost for every user who does not discover it. `KRAMME_REVIEW_SUBAGENT_LEVEL` was unset in every measured session.

### Drop the filter stages

Rejected. The [review execution evidence record](2026-09-08-review-execution-evidence.md) requires the integrity → relevance → slop-meta order, and `kramme:pr:code-review` already skips both stages when no finding reaches them.

## Risks and Mitigations

- **A lower-class validator could mislabel an in-scope finding as pre-existing** and move it out of the active sections. Mitigations: filtered findings remain listed separately in code-review, product-review, and convention-review reports, and acceptance requires the replay threshold below.
- **A lower-class meta-review could miss slop warnings.** The impact is advisory, because the meta-review never removes findings.
- **Users who rely on unset meaning `same` would see a behavior change.** Mitigations: `KRAMME_REVIEW_SUBAGENT_LEVEL=same` restores today's behavior, and the accepting change documents the new default in the README.

## Evidence Required Before Acceptance

1. **Token share.** Measure the filter roles' share of review-run tokens from transcripts, identifying validator launches by subagent metadata that names `kramme:pr-relevance-validator` and meta-review launches by prompts that open with `Operate in meta-review mode.`.
2. **Label agreement replay.** Replay at least ten recent `kramme:pr:code-review` runs that had at least one primary finding. Re-run the relevance stage on the lower class over the saved primary outputs and compare labels with the orchestrator-class labels. Accept only if:
   - no Critical or Important finding labelled in scope at the orchestrator's class is labelled out of scope at the lower class, and
   - overall label agreement is at least 95%.
3. **Session-limit effect.** Note how the measured saving changes the session-limit picture for `kramme:pr:github-review`, `kramme:code:plan-to-pr`, `kramme:linear:issue-to-pr`, and `kramme:pr:code-review`.

## Relation to the 2026-10-20 Record

The [risk-routing record](2026-10-20-risk-routed-review-convergence.md) deferred "Default reviewers to a lower model class" and kept `KRAMME_REVIEW_SUBAGENT_LEVEL=lower` as the opt-in. That deferral weighed the reviewers that find defects. This proposal narrows it to the two roles that only filter or annotate.

Accepting this proposal would:

- amend that record's "Default reviewers to a lower model class" entry,
- move this record to Settled Decisions with status ACCEPTED, and
- leave the routing decision's 2027-01-20 adoption review unchanged.

## Decision Review

On 2026-11-21 the maintainer accepts, rejects, or re-dates this proposal based on the evidence above. If the measurement has not been done, the proposal is re-dated, not accepted.
