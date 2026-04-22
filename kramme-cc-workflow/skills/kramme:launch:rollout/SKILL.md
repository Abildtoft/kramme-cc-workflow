---
name: kramme:launch:rollout
description: Execute a post-merge launch with staged rollout, numeric decision thresholds, and rollback triggers. Sequence — staging → prod (flag OFF) → team enable → 5% canary → 25→50→100% gradual → full rollout + 1-week monitor + flag cleanup. Use after merging a user-facing change that needs safe rollout. Complements kramme:pr:finalize (pre-merge readiness) with post-merge verification, canary gates, and rollback paths. Not for PR creation, CI debugging, or pre-merge checks.
disable-model-invocation: true
user-invocable: true
---

# Launch Rollout

Execute a staged, reversible, observable post-merge launch. The goal is not just to deploy — it's to deploy safely, with monitoring in place, a rollback plan ready, and numeric gates that turn "is this healthy?" into a falsifiable question. Every launch should be reversible, observable, and incremental.

## Scope partition (pre-merge vs. post-merge)

This skill owns the **post-merge** half of the shipping lifecycle. It begins at "the PR has landed on main" and ends at "the flag has been cleaned up and the feature is permanent."

- **Pre-merge readiness** — owned by `kramme:pr:finalize`. Covers code-review verdict, UX review, QA run, description generation. Ends at a `READY` verdict.
- **Post-merge launch** — owned by this skill. Covers staged rollout, canary gates, monitoring, rollback triggers, and flag cleanup.

The handoff between the two is the merge commit. If you are still running finalize, you are not yet in rollout territory.

## When to use

- Deploying a user-facing change to production for the first time.
- Releasing a significant change behind a feature flag and working through the rollout stages.
- Migrating data or infrastructure that touches production traffic.
- Opening a beta or early-access program to a controlled cohort.
- Any deployment that carries risk (which is to say, all of them).

## When not to use

- Fixing a failing CI pipeline — use `kramme:pr:fix-ci`.
- Creating the PR itself — use `kramme:pr:create`.
- Pre-merge readiness audit — use `kramme:pr:finalize`.
- Resolving review findings — use `kramme:pr:resolve-review`.
- Pure refactors with no behavioral change — the test suite is the gate, not a canary.
- Emergency hotfixes that must reach 100% immediately — document the exception and still capture first-hour verification after the fact.

## Markers

The markers below anchor this skill's output. Emit them explicitly; do not bury them in prose.

```
STACK DETECTED: <feature-flag platform, deploy target, monitoring tools>
```

State the rollout stack before step 1. Example: `STACK DETECTED: LaunchDarkly flags, Vercel deploy, Datadog metrics + Sentry errors.` If any component is missing (no flag platform, no error reporting), that's a `MISSING REQUIREMENT`.

```
UNVERIFIED: <claim about baseline, capacity, or behavior that has no source>
```

Flag any numeric or behavioral claim the user has not confirmed. "Baseline error rate is ~0.5%" is `UNVERIFIED` until you can point to a dashboard or a log query.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope for this rollout>
```

Use when you spot an unrelated infra problem during rollout (a dashboard gap, an alert with a wrong threshold, a runbook that's stale). Log it and move on. Do not silently fix adjacent issues mid-rollout — silent fixes during a live canary are unreviewable and expand the blast radius.

```
MISSING REQUIREMENT: <which pre-launch checklist item is missing>
Plan: <how to resolve before advancing>
```

Emit when any pre-launch checklist item is unchecked and unowned. Rollout does not advance past the pre-flight gate with a missing requirement.

```
CONFUSION: <ambiguous signal>
```

Use when a metric could have multiple causes. Example: `CONFUSION: P95 latency 30% above baseline at 5% canary — could be cold-start cache warm-up or real regression.` Forces an investigation rather than a snap judgment.

## Pre-flight gate

Before step 1, confirm every box in `references/pre-launch-checklist.md` is checked or explicitly deferred with an owner. The checklist has six sections: Code Quality, Security, Performance, Accessibility, Infrastructure, Documentation.

If any box is unchecked:

- Resolve it, or
- Defer it with a named owner and a ticket, or
- Emit `MISSING REQUIREMENT` and halt the rollout.

Do not proceed past this gate on the assumption that "we can fix it during canary." Problems that ship do not un-ship mid-rollout.

## The Rollout Sequence

The sequence is six staged gates. Each gate has a monitoring window and a set of thresholds that must pass before advancing. Do not compress the sequence to save time — the windows are the whole point.

```
1. DEPLOY to staging
   └── Full test suite passes in the staging environment.
   └── Manual smoke test of the critical user flow.
   └── Verify the feature flag is reachable and togglable from staging's flag UI.

2. DEPLOY to production (feature flag OFF)
   └── Verify the deploy succeeded (health check returns 200).
   └── Check error monitoring — no new error types attributed to the deploy.
   └── Confirm the feature flag is present and defaults to OFF for all users.
   └── Window: immediate — if the deploy itself is unhealthy, stop here.

3. ENABLE for team (flag ON for internal users only)
   └── Team members use the feature in production.
   └── Gather qualitative feedback: does it feel right? any rough edges?
   └── Monitor error rates and latency against the team cohort.
   └── Window: 24 hours minimum.

4. CANARY rollout (flag ON for 5% of users)
   └── Monitor error rates, latency, client errors, and business metrics.
   └── Compare canary cohort vs. control cohort (not against the full population).
   └── Apply the Rollout Decision Thresholds table (see next section).
   └── Window: 24–48 hours. Advance only if all thresholds pass.

5. GRADUAL increase (25% → 50% → 100%)
   └── Same monitoring at each step.
   └── Ability to roll back to the previous percentage at any point.
   └── Window: 12–24 hours per step, depending on traffic volume.

6. FULL rollout (flag ON for all users)
   └── Monitor for 1 week.
   └── Remove the feature flag and the off-state code path (see references/feature-flag-rules.md).
   └── Window: 1 week active monitoring, then flag cleanup within 2 weeks.
```

Write the sequence into the launch ticket verbatim so the on-call can see which gate is current.

## Rollout Decision Thresholds

The numeric gates for advance / hold / rollback decisions. Reproduce the table in the launch ticket so the decision rule is visible, not tribal.

| Metric | Advance (green) | Hold and investigate (yellow) | Roll back (red) |
|--------|-----------------|-------------------------------|-----------------|
| Error rate | Within 10% of baseline | 10–100% above baseline | >2× baseline |
| P95 latency | Within 20% of baseline | 20–50% above baseline | >50% above baseline |
| Client JS errors | No new error types | New errors at <0.1% of sessions | New errors at >0.1% of sessions |
| Business metrics | Neutral or positive | Decline <5% (may be noise) | Decline >5% |

**How to read the table:**

- **Green across the row** — advance.
- **Any yellow** — hold, investigate, advance only when cleared.
- **Any red** — roll back immediately.
- **Multiple yellows** — treat as red unless each has a confirmed non-rollout cause.

`UNVERIFIED` applies if you don't have a real baseline — do not advance past 5% on a guessed baseline.

Full rationale (why these numbers, how to interpret edge cases) lives in `references/rollout-thresholds.md`.

## Immediate rollback triggers

Independent of the thresholds table. Roll back immediately, without waiting for the monitoring window to expire, if any of the following occur:

- **Error rate increases by more than 2× baseline.** Non-negotiable, at any stage.
- **P95 latency increases by more than 50%.** Users feel this.
- **User-reported issues spike.** Support tickets, social mentions, in-product feedback — any of these trending up sharply.
- **Data integrity issues detected.** Corrupted writes, missing fields, inconsistent reads — data bugs compound faster than rollouts.
- **Security vulnerability discovered in the shipped code.** Even a theoretical one — pull back, patch, re-ship.

Pre-agree these triggers with the on-call before step 1. `STACK DETECTED` should include the exact runbook step for each trigger.

## First-hour post-launch verification

Within the first hour after the flag flips on (whether at team enable, canary, or full rollout), complete every item:

1. **Health endpoint returns 200.** Not a 500, not a 503, not a timeout.
2. **Error monitoring dashboard shows no new error types.** Volume bumps on existing errors are separate — brand-new error signatures are the signal.
3. **Latency dashboard shows no regression.** P95 and P99, not just P50.
4. **Critical user flow works end-to-end.** Test it yourself, in production, with a real account.
5. **Logs are flowing and readable.** If the logs are silent, the monitoring is lying.
6. **Rollback mechanism confirmed working.** Dry-run the flag toggle from the flag UI. Never discover the rollback is broken when you need it.

Complete all six. Do not skip any "because it always works" — the one time it doesn't is launch day.

## Feature flag cleanup

Post-100%, the flag has one remaining job: to be removed. See `references/feature-flag-rules.md` for the full rules. The short version:

- Every flag has an owner and an expiration date.
- Clean up the flag within 2 weeks of full rollout.
- Do not nest feature flags.
- Test both flag states (on and off) in CI until the flag is removed.

Removing a flag means removing the check, the off-state code path, the flag-service definition, the CI test matrix entry, and any runbook references. A half-cleaned flag is worse than the original.

## Rollback plan template

Every rollout needs a documented rollback plan *before* step 1. Fill this in for the launch ticket:

```markdown
## Rollback Plan for [Feature/Release]

### Trigger Conditions
- Error rate > 2× baseline.
- P95 latency > [Xms — specific to this feature].
- User reports of [specific expected failure mode].
- [Any feature-specific trigger — e.g., "checkout conversion drops >5%"].

### Rollback Steps
1. Disable the feature flag in the flag UI (expected time: < 1 minute).
   — OR —
1. Redeploy the previous version (`git revert <commit> && git push`, expected time: < 5 minutes).
2. Verify the rollback: health check returns 200, error rate returns to baseline.
3. Communicate: notify the team channel and on-call that a rollback occurred.
4. Open a postmortem ticket within 24 hours.

### Database Considerations
- Migration [X] rollback: [specific command / procedure, or "N/A — schema is backward-compatible"].
- Data inserted by the new feature: [preserved / cleaned up / quarantined].

### Time-to-Rollback
- Feature flag: < 1 minute.
- Redeploy previous version: < 5 minutes.
- Database rollback (if needed): < 15 minutes.
```

A rollback plan that does not fit in the launch ticket is too vague to execute under pressure.

## Output summary template

End the rollout session with a structured summary that an on-call can scan in 30 seconds:

```
CHANGES MADE
- Flag <name> rolled to <percentage>% at <timestamp>.
- Monitoring windows completed: <which gates passed>.
- Feature flag cleanup: <scheduled for DATE | completed | deferred — reason>.

THINGS I DIDN'T TOUCH
- <adjacent infra / monitoring / runbook items noticed but not modified>.

POTENTIAL CONCERNS
- <any yellow metric observations>.
- <any UNVERIFIED assumptions not yet closed>.
- <any CONFUSION entries not yet resolved>.
```

This template replaces handwavy "launch looks good" posts. It documents what happened, what was observed but not changed, and what remains open.

## Integration with other skills

- **Pre-merge** — `kramme:pr:finalize` produces the `READY` verdict that gates merge. This skill picks up at the merge commit.
- **Verification sub-skills** — the pre-launch checklist touches security / performance / accessibility territory owned by sibling skills. The content here is inlined deliberately (self-contained rule). If a sibling skill has deeper content, read it during pre-flight and bring the conclusions back; do not reach into sibling skill files at runtime.
- **Future siblings** — `kramme:launch:monitor` (post-launch canary surveillance via browser MCP) and `kramme:launch:rollback` (execute a rollback when thresholds are breached) are deferred until demand appears. Both would extend this skill, not replace it.

## Common Rationalizations

The lies engineers tell themselves to skip rollout discipline. Each one has a correct response.

| Rationalization | Reality |
|---|---|
| "It works in staging, it'll work in production." | Production has different data, traffic, and edge cases. Staging validates that the code runs; production validates that the code works. |
| "It's a small change, skip the canary." | Small changes break big things. The canary costs one day; a bad full-rollout costs a week. |
| "We don't need a feature flag for this." | Every non-trivial change benefits from a kill switch. Flags are the cheapest insurance in the stack. |
| "Monitoring is overhead." | Not having monitoring means discovering problems from user complaints. That's a worse kind of overhead. |
| "We'll add monitoring later." | Add it before launch. You cannot debug what you cannot see. |
| "Latency is only 30% above baseline — probably fine." | 30% is yellow. The table says hold and investigate. "Probably fine" is not a decision rule. |
| "Rolling back is admitting failure." | Rolling back is responsible engineering. Shipping a broken feature is the failure. |
| "We'll clean up the flag later." | Later is never. Schedule the cleanup ticket before starting the rollout. |
| "The on-call will watch it." | The on-call does not know this feature. You do. Be there for the first-hour verification. |
| "It's Friday afternoon, let's ship it." | No. Ship Monday–Thursday, during working hours, with the team available. |

## Red Flags

If you notice any of these during rollout planning or execution, stop:

- No rollback plan documented before step 1.
- No monitoring or error reporting in production for the changed code path.
- Big-bang release (everything flips at once, no staged sequence).
- Feature flag with no owner or no expiration date.
- Nobody is monitoring the deploy for the first hour.
- Production environment configuration done by memory, not stored in code / infra-as-code.
- Baseline numbers are guesses (`UNVERIFIED` applies and has not been resolved).
- Any `MISSING REQUIREMENT` from the pre-launch checklist has not been resolved.
- A metric is red but the rollout continues ("we'll watch it").
- A rollback trigger is hit but the response is a code-fix-forward instead of a rollback.
- Flag nesting has appeared (flag A only makes sense when flag B is on).
- "It's Friday afternoon" energy.

Any single red flag above is grounds to halt. Two or more is grounds to cancel the rollout and restart from pre-flight.

## Verification

Before declaring the rollout complete, self-check every item:

Before step 1:

- [ ] `STACK DETECTED` line is emitted and names flag platform, deploy target, monitoring tools.
- [ ] Pre-launch checklist is complete across all six sections (or deferrals are owned and ticketed).
- [ ] Rollback plan is documented in the launch ticket.
- [ ] Monitoring dashboards exist and the Rollout Decision Thresholds table has been pasted into the ticket.
- [ ] The on-call knows this launch is happening.

At each gate (team, 5%, 25%, 50%, 100%):

- [ ] Monitoring window has expired before advancing.
- [ ] Every row of the thresholds table is green.
- [ ] No immediate rollback triggers have fired.
- [ ] No new `MISSING REQUIREMENT` has emerged.
- [ ] First-hour verification has been completed (at team enable and canary as a minimum).

After full rollout:

- [ ] 1-week monitoring window has been active (no passive "set and forget").
- [ ] Feature flag cleanup ticket is scheduled within 2 weeks.
- [ ] Postmortem has been written for any yellow/red signal encountered, even if it resolved.
- [ ] Output summary template has been filled in (`CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS`).
- [ ] Every `UNVERIFIED` has been closed or explicitly left open with an owner.
- [ ] Every `CONFUSION` has been resolved.

If any answer is no, the rollout is not done. Close the gap before calling it shipped.
