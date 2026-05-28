# Rollout Decision Thresholds — rationale

The thresholds table, the green/yellow/red reading rules, the immediate rollback triggers, and the window values are all defined in `SKILL.md` and kept inline there because they are load-bearing at decision time. This file does **not** repeat them — it has one home, so a tuned number never disagrees with itself. What lives here is the reasoning: how to define a baseline, why the windows are what they are, why these specific numbers, and what to do when you have no baseline.

## Defining the baseline

Baseline = the equivalent window from the same day-of-week and hour-of-day, pre-rollout. Do not compare midnight traffic to peak traffic and call it a regression.

## Window lengths — the reasoning

The window values live in the Rollout Sequence in `SKILL.md` (team 24h, canary 24–48h, 25%/50% 12–24h each, 100% 1 week). The reasoning behind them:

- The window exists so a slow-burn regression (memory leak, queue backup, cache eviction) has time to surface before the next percentage step. Skipping the wait defeats the staged sequence.
- Shorter windows are acceptable only for reversible flag-gated changes with low blast radius.
- Document any shortened window as `CONFUSION` if the team disagrees on the length.

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
