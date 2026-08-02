# Rollout Decision Thresholds — selection guide

The active thresholds, green/yellow/red rules, evidence sources, and monitoring windows belong in the launch ticket. `SKILL.md` retains only fallback examples and the decision-time procedure. This reference explains how to choose the active values; repository numbers are not facts about the user's system.

## Choose the policy source first

Apply threshold and window sources in this order:

1. Explicit user or organization release policy, SLOs, error budgets, compliance limits, and approved release calendars.
2. Observed system evidence: representative baselines, known variability, traffic, outcome delay, risk, and rehearsed rollback time.
3. A clearly labeled fallback proposal confirmed by the operator when the first two sources leave a gap.

Record the source beside every row in the launch ticket. A user-confirmed fallback becomes the active decision rule for that rollout, but it does not become a universal standard.

## Define a trustworthy baseline

Choose a comparison population and window that represent the exposed cohort. Account for hour-of-day, day-of-week, seasonality, geography, client version, and other known traffic shifts. A contemporaneous control cohort is often stronger than a historical aggregate. Do not compare unlike traffic periods and call the difference a regression.

For each metric, record:

- Query or dashboard and observation timestamp.
- Numerator, denominator, and cohort filters.
- Normal variation and known confounders.
- SLO, error budget, or product tolerance that defines unacceptable impact.

A screenshot estimate or remembered value is `UNVERIFIED`, not a baseline.

## Select windows from sample sufficiency

A monitoring window must pass two gates: enough elapsed time to cover relevant failure modes and enough observations to support the decision.

- Define the minimum events, sessions, requests, or conversions needed for each metric before exposure begins.
- Extend low-traffic stages until their sample rule passes; a clock expiring does not create evidence.
- Cover known cycles and delayed outcomes. Memory leaks, queue buildup, cache eviction, billing cycles, and asynchronous jobs may require longer observation than request metrics.
- Use shorter windows only when the risk, sample rate, observability, and rehearsed rollback time justify them.
- Record disagreements about sufficiency as `CONFUSION` and hold until resolved.

The percentages and windows in `SKILL.md` are a fallback example. Confirm or replace them from these inputs before use.

## Select thresholds from policy and evidence

Prefer existing SLO boundaries and error-budget policy. Where they do not cover a rollout metric, derive green/yellow/red bands from representative variability and the maximum impact the organization is willing to accept.

- **Green** means the sample is sufficient and the result remains inside the confirmed acceptable band.
- **Yellow** means the result is ambiguous or outside the normal band but below the confirmed rollback boundary; hold and investigate.
- **Red** means the confirmed SLO, safety, data-integrity, security, or rollback boundary is breached; roll back immediately.
- Apply the active policy's aggregation rule for multiple yellow signals. When using the `SKILL.md` fallback, treat multiple yellows as red unless each has a demonstrated non-rollout cause.

The example error, latency, client-error, and business-metric numbers in `SKILL.md` are useful only as a proposal when no better policy or evidence exists. Label them `FALLBACK`, obtain confirmation, and retain the confirmer and rationale in the launch ticket.

## When no trustworthy baseline exists

Emit `UNVERIFIED` and state exactly what is missing. Keep the change at no exposure or the initial limited cohort while collecting a representative baseline or contemporaneous control:

```
UNVERIFIED: checkout error baseline lacks a cohort-filtered denominator; owner will collect it from <query> before broader exposure.
```

Do not guess a baseline, substitute a fallback threshold for evidence, or advance to broader external exposure. If the required baseline cannot be collected, emit `MISSING REQUIREMENT` with an owner and stop boundary.
