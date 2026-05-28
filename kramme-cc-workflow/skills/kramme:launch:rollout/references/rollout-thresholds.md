# Rollout Decision Thresholds — rationale

The threshold table, the green/yellow/red read rule, and the immediate rollback triggers live in `SKILL.md`. This file is the rationale behind those numbers: how to define a baseline, why each threshold sits where it does, and what to do when you have no baseline. It deliberately does not restate the table — one authoritative copy prevents the two from silently diverging.

## Defining the baseline

Baseline = the equivalent window from the same day-of-week and hour-of-day, pre-rollout. Do not compare midnight traffic to peak traffic and call it a regression.

## Why these specific numbers

- **10% / 2× error rate** — anything inside 10% is usually noise; anything past 2× is a clear signal regardless of baseline volume.
- **20% / 50% P95 latency** — 20% is below user-perceptible for most flows; 50% is past the point where cache warm-up or cold-start reasoning can justify it.
- **0.1% client JS errors** — at 1k sessions/hour, 0.1% = 1 affected session/hour. Above that, real users are hitting it.
- **5% business metrics** — below 5% is within normal variance for most flows; above 5% is a conversion cliff.

Tune the numbers to the product only if you have a documented reason. An untuned table beats a handwavy "feels fine" heuristic.

## Window lengths

The monitoring window for each gate is specified in the Rollout Sequence in `SKILL.md`. Shorter windows are acceptable only for reversible flag-gated changes with low blast radius. Document the exception as `CONFUSION` if the team disagrees on the window.

## What to do when you don't have the baseline

`UNVERIFIED` applies. State the assumption explicitly:

```
UNVERIFIED: baseline error rate is ~0.5% based on last week's dashboard screenshot.
```

Then either (a) capture a proper baseline before opening the canary, or (b) pin the team-enable window until enough pre-rollout data is collected. Do not advance past 5% without a real baseline.
