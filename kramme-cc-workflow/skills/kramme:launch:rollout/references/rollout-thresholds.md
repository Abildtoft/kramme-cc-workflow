# Rollout Decision Thresholds

The load-bearing artifact of this skill. Concrete numeric gates turn "is the rollout healthy?" into a falsifiable question. Use the table at every stage of the staged rollout sequence (team enable, 5% canary, 25%, 50%, 100%).

## The table

| Metric | Advance (green) | Hold and investigate (yellow) | Roll back (red) |
|--------|-----------------|-------------------------------|-----------------|
| Error rate | Within 10% of baseline | 10–100% above baseline | >2× baseline |
| P95 latency | Within 20% of baseline | 20–50% above baseline | >50% above baseline |
| Client JS errors | No new error types | New errors at <0.1% of sessions | New errors at >0.1% of sessions |
| Business metrics | Neutral or positive | Decline <5% (may be noise) | Decline >5% |

Baseline = the equivalent window from the same day-of-week and hour-of-day, pre-rollout. Do not compare midnight traffic to peak traffic and call it a regression.

## How to apply

- **Green across the table** — advance to the next percentage after the window expires.
- **Any yellow** — hold. Investigate the specific metric. Advance only after the signal clears or the investigation proves it unrelated.
- **Any red** — roll back immediately. Do not negotiate. The cost of a false-positive rollback is small; the cost of a false-negative is a production incident.

One yellow does not cancel another yellow. Multiple yellows → treat as red unless each has a confirmed non-rollout cause.

## Immediate rollback triggers

Independent of the thresholds table — roll back immediately if any of the following occur, even at the team-enable or 5% canary stage:

- Error rate increases by more than 2× baseline.
- P95 latency increases by more than 50%.
- User-reported issues spike (support tickets, social mentions, in-product feedback).
- Data integrity issues detected (corrupted writes, missing fields, inconsistent reads).
- Security vulnerability discovered in the shipped code.

These are non-negotiable. Surface them as `STACK DETECTED` triggers during rollout planning so the on-call has a pre-agreed action.

## Window lengths

- **Team enable** — 24 hours minimum before canary.
- **5% canary** — 24–48 hours.
- **25% / 50%** — 12–24 hours each, depending on traffic volume.
- **100%** — 1 week of active monitoring before flag cleanup.

Shorter windows are acceptable only for reversible flag-gated changes with low blast radius. Document the exception as `CONFUSION` if the team disagrees on the window.

## Why these specific numbers

- **10% / 2× error rate** — anything inside 10% is usually noise; anything past 2× is a clear signal regardless of baseline volume.
- **20% / 50% P95 latency** — 20% is below user-perceptible for most flows; 50% is past the point where cache warm-up or cold-start reasoning can justify it.
- **0.1% client JS errors** — at 1k sessions/hour, 0.1% = 1 affected session/hour. Above that, real users are hitting it.
- **5% business metrics** — below 5% is within normal variance for most flows; above 5% is a conversion cliff.

Tune the numbers to the product only if you have a documented reason. An untuned table beats a handwavy "feels fine" heuristic.

## What to do when you don't have the baseline

`UNVERIFIED` applies. State the assumption explicitly:

```
UNVERIFIED: baseline error rate is ~0.5% based on last week's dashboard screenshot.
```

Then either (a) capture a proper baseline before opening the canary, or (b) pin the team-enable window until enough pre-rollout data is collected. Do not advance past 5% without a real baseline.
