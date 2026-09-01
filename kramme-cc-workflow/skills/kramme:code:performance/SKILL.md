---
name: kramme:code:performance
description: "(experimental) Measure-first performance discipline tied to Core Web Vitals (LCP, INP, CLS). Use when users or monitoring report slowness, CWV scores miss thresholds, performance requirements exist in the spec, you suspect a recent change introduced a regression, or you're building features that handle large datasets or high traffic. Enforces baseline measurement, single-bottleneck fixes, verification, and regression guards; when explicitly authorized, can persist immutable repository-scoped baseline artifacts for later comparisons. Complements the review-time `kramme:performance-oracle` agent."
disable-model-invocation: false
user-invocable: true
---

<!-- Adapted from addyosmani/agent-skills skills/performance-optimization/SKILL.md at commit 91d4d07522de9577caf5d213e5bf1acc38fa3df2 under the MIT License. Full notice: references/addyosmani-agent-skills-LICENSE. -->

# Performance Optimization

Measure before optimizing. Performance work without measurement is guessing — and guessing leads to premature optimization that adds complexity without improving what matters. Profile first, identify the actual bottleneck, fix it, measure again. Optimize only what measurements prove matters.

## When to use

- Performance requirements exist in the spec (load-time budgets, response-time SLAs).
- Users or monitoring report slow behavior.
- Core Web Vitals scores are below thresholds.
- You suspect a recent change introduced a regression.
- Building features that handle large datasets or high traffic.

## When NOT to use

- The concern is theoretical with no user impact or monitoring signal — premature optimization.
- The codebase has no measurement infrastructure yet — install baseline monitoring first.
- The slowness is in a third-party dependency or platform you do not control — escalate, do not patch around it.
- The bottleneck requires an architectural decision (data model change, service split) — plan first, then return here for the per-slice optimization work.
- The goal is to compare repeatable variants against a harness for bundle size, latency, relevance, ranking, prompt quality, or another metric — use `kramme:code:optimize`.

## Core Web Vitals targets

| Metric | Good | Needs Improvement | Poor |
| --- | --- | --- | --- |
| **LCP** (Largest Contentful Paint) | ≤ 2.5 s | ≤ 4.0 s | > 4.0 s |
| **INP** (Interaction to Next Paint) | ≤ 200 ms | ≤ 500 ms | > 500 ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

A change that regresses any metric from Good into Needs Improvement is a regression, even if the absolute number still looks fine. Full measurement commands, what each metric measures, mobile/desktop differences, and the noise floor live in `references/core-web-vitals.md`.

## The five-step workflow

Each optimization is one pass through this loop:

```
1. MEASURE  → Establish baseline with real data
2. IDENTIFY → Find the actual bottleneck (not assumed)
3. FIX      → Address the specific bottleneck
4. VERIFY   → Measure again, decide disposition, record the outcome
5. GUARD    → Add monitoring or tests to prevent regression
```

### Rule 0 — Simplicity First

Before writing any optimization, emit a `SIMPLICITY CHECK` marker stating the smallest change that would clear the budget. Only expand beyond that if remeasurement proves it is not enough.

```
SIMPLICITY CHECK: <one-line summary of the smallest fix that would clear the budget>
```

If the fix you end up shipping is not the smallest version, write a second line explaining what forced the expansion. Every extra abstraction — a cache wrapper, a memoized selector, a code-split boundary — adds complexity. Only add it when a measurement demands it.

### Rule 0.5 — Scope discipline

When profiling surfaces a second bottleneck outside the current slice — an N+1 query in an adjacent endpoint, a missing image dimension on a neighboring page, a useEffect that looks wrong but is not on the hot path — emit a `NOTICED BUT NOT TOUCHING` marker and keep going. Do not silently fix perf smells that are not on the measured bottleneck.

```
NOTICED BUT NOT TOUCHING: <the perf smell you saw>
Why skipping: <not on measured bottleneck / out of scope / deferred>
```

The reason: every "while I'm here" fix dilutes the before/after delta for the change you _are_ measuring, and makes it impossible to attribute the gain cleanly.

Emit both markers in your response text, using the exact formats above, so a calling agent or reviewer can parse them.

### Step 1 — Measure

Two complementary approaches — use both:

- **Synthetic** (Lighthouse, Chrome DevTools Performance tab, WebPageTest): controlled conditions, reproducible. Best for CI regression detection and isolating a specific issue.
- **RUM** (`web-vitals` library, Chrome User Experience Report, project APM): real user data in real conditions. Required to validate that a fix actually improved user experience, not just the synthetic number.

**Frontend:**

```ts
// Synthetic: Lighthouse in Chrome DevTools (or CI)
// Chrome DevTools → Performance tab → Record

// RUM: web-vitals library in code
import { onCLS, onINP, onLCP } from "web-vitals";

onLCP(console.log);
onINP(console.log);
onCLS(console.log);
```

**Backend:**

```ts
// Response time logging
// Application Performance Monitoring (APM)
// Database query logging with timing

// Simple timing
console.time("db-query");
const result = await db.query(/* … */);
console.timeEnd("db-query");
```

Start the attempt record described in Step 4 with the baseline number _and units_. "Fast enough" is not a baseline.

Write a durable baseline only when the user explicitly requests persistence or the task input identifies a concrete later consumer, such as a specific ticket, PR, regression guard, or remeasurement. A generic mention of those consumer categories in this workflow is not authorization to write. When persistence is authorized, read `references/baseline-artifact.md` and write one repository-scoped JSON artifact; otherwise keep the result inline. The artifact must disclose evidence class, direction, environment, samples, the metric's primary statistic, p50/p75/p95, variance/noise, budgets, and lineage; never overwrite an earlier measurement or store secrets and user-level data. Aggregate-only CrUX and PageSpeed Insights field data stay inline because they cannot supply the complete Version 1 contract; persist RUM only from a producer that supplies every required sample, summary, noise, and comparable-cohort field. If an explicitly requested artifact cannot meet that contract, state that no artifact was written, name only the missing field categories, retain the result inline, and identify the supported measurement needed next.

### Step 2 — Identify the bottleneck

Read `references/triage.md` now. It contains the frontend/backend symptom tables (symptom → likely cause → investigation), the "Where to start measuring" decision tree, and the six anti-pattern summaries. Use the symptom to pick what to profile first, and follow one branch of the tree per measurement.

Before choosing an optimization, inspect the current conversation or task, linked ticket, PR description, and existing project-local performance notes for prior attempts against this bottleneck. Do not repeat the same change or idea after a `REVERT` verdict under comparable conditions unless new evidence or materially different measurement conditions justify it. A different implementation for the same bottleneck is a new attempt.

### Step 3 — Fix the bottleneck

Map the identified bottleneck to one of the six named anti-patterns in `references/triage.md` (N+1 queries, unbounded data fetching, missing image optimization, unnecessary re-renders, large bundle size, missing caching) and apply its canonical fix. Full before/after code examples live in `references/anti-patterns.md`.

**The memoization trap.** `React.memo`, `useMemo`, and `useCallback` everywhere is itself a perf anti-pattern: each adds bookkeeping cost and obscures render causes. Apply only when profiling shows a measured win — and document the measurement next to the memo.

### Step 4 — Verify

Remeasure with the same tool, on the same device class, on the same network profile, with the same cache state, and against the same predetermined workload budget used for the baseline. Choose the budget appropriate to the measurement: a fixed wall-clock duration, sample count, or request count. Then check:

- If a durable baseline exists, read `references/baseline-artifact.md`, validate both artifacts, and run its comparison gate before calculating a delta. On any material mismatch, report `INCOMPARABLE`, list the mismatched fields, and rerun under matched conditions instead of presenting a before/after claim.
- The improvement exceeds measurement noise. A 5% change on Lighthouse is noise; a 30% change is a signal.
- Compare the metric's declared primary statistic plus p50 and p95, not just the average. For RUM Core Web Vitals, the primary statistic is p75. An optimization that only improves p50 can leave the tail unchanged.
- Core Web Vitals are now in Good (or at least moved out of Poor).
- No adjacent metric regressed. A fix that halves LCP but doubles CLS is not a fix.
- Synthetic and lab evidence prove only controlled-environment behavior. RUM-to-RUM evidence under comparable cohorts and windows is required to claim a real-user improvement; never calculate a direct delta between different evidence classes.

Use a binary verdict after every successful comparable remeasurement:

- **KEEP** only when comparable repeated measurements show a reproducible improvement beyond run-to-run variance, the result clears the stated performance budget, and all regression and behavior checks pass.
- **REVERT** when a comparable result is worse, neutral, indistinguishable from measurement noise, still misses the stated budget, or fails an attributable regression or behavior check. Revert the implementation even though its attempt record remains.

If remeasurement crashes, times out, or returns malformed or otherwise unusable output, restore the pre-attempt implementation, record `ERROR`, `TIMEOUT`, or `INCONCLUSIVE` with the failure details, and repair the measurement before retrying the same change. A measurement failure is not a `REVERT` verdict because it did not evaluate the optimization.

Do not stack a second optimization on top of an unverified first one. Apply the verdict, or restore the implementation and record the measurement failure, before returning to Step 2.

#### Record every attempt

Record each attempted optimization in an authorized durable destination: the current task or ticket, the PR description, or an existing project-local performance note. If none is available and writable in this run, emit the complete record in your response as an explicit handoff for later transfer. Include attempts whose code is reverted or whose measurement fails, using this compact field set:

- **Hypothesis** — the bottleneck and expected effect.
- **Change/idea attempted** — the specific implementation evaluated.
- **Conditions** — measurement command/tool, environment, device or dataset, network profile when relevant, cache state, and the chosen fixed wall-clock, sample-count, or request-count budget.
- **Baseline** — the before measurements with units, including p50 and p95 when available.
- **Result** — the after measurements under the same conditions, or `unavailable` with the measurement failure details.
- **Variance/noise** — observed run-to-run spread and whether the result exceeds it, or `unavailable` when measurement failed.
- **Outcome** — `KEEP` or `REVERT` for a comparable result; otherwise `ERROR`, `TIMEOUT`, or `INCONCLUSIVE`.
- **Reason** — why the evidence satisfies that outcome.

This is a review record for a bounded pass, not an experiment system. Do not create a benchmark harness, durable `.context` ledger, or other ongoing infrastructure here; use `kramme:code:optimize` when the work needs repeatable multi-variant experiments.

### Step 5 — Guard

Lock in the fix so it cannot silently regress:

- **Bundle size budget** — `bundlesize` or the bundler's built-in budget, fails CI when a route exceeds the limit.
- **Lighthouse CI** — `lhci autorun` with score thresholds and CWV assertions in the PR pipeline.
- **Synthetic regression test** — a dedicated test that times the specific code path (a slow query, a render path) and fails when it exceeds the threshold.
- **RUM alert** — dashboard alert on the metric's declared primary statistic; use p75 for RUM Core Web Vitals.

A fix without a guard is a fix that will regress the next time someone changes the code.

## Performance budget

Set explicit budgets and enforce them in CI:

```
JavaScript bundle: < 200 KB gzipped (initial load)
CSS: < 50 KB gzipped
Images: < 200 KB per image (above the fold)
Fonts: < 100 KB total
API response time: < 200 ms (p95)
Time to Interactive: < 3.5 s on 4G
Lighthouse Performance score: ≥ 90
```

**Enforce in CI:**

```bash
# Bundle size check
npx bundlesize --config bundlesize.config.json

# Lighthouse CI
npx lhci autorun
```

Budgets are floors, not ceilings — a PR that adds 30 KB to the bundle without justifying it against the budget is a PR that should not merge. Example `bundlesize.config.json`, `lighthouserc.json`, and a custom regression test live in `references/performance-checklist.md`.

## Integration with other skills

If these siblings are installed:

- **Downstream review** — the `kramme:performance-oracle` agent verifies measurements and bottleneck identification post-hoc. Following MEASURE/VERIFY discipline here makes that review mechanical.
- **Boundary** — `kramme:code:optimize` owns repeatable harness-driven experiments across multiple variants; this skill owns one-shot review-and-fix performance passes where the bottleneck and fix are measured directly.

---

## Common Rationalizations

These are the lies you will tell yourself to justify skipping the measurement or the guard. Each one has a correct response:

- _"We'll optimize later."_ → Performance debt compounds. Fix the obvious anti-pattern now; defer only the micro-optimizations.
- _"It's fast on my machine."_ → Your machine is not the user's. Profile on representative hardware and the slowest network profile the product supports.
- _"This optimization is obvious — no need to measure."_ → If you did not measure, you do not know. Profile first; half the time the "obvious" bottleneck is not the real one.
- _"Users won't notice 100 ms."_ → They do. Interaction delays above 100 ms are perceptible, and RUM data consistently shows them degrading conversion.
- _"The framework handles performance."_ → Frameworks prevent some classes of issue, but they do not fix N+1 queries, oversized bundles, or unoptimized images. Those are author-level decisions.
- _"The fix is small enough to skip the regression test."_ → The next unrelated refactor will delete the fix by accident. A guarded fix is a fix; an unguarded fix is a fix with an expiration date.

## Red Flags

If you notice any of these, stop and return to step 1:

- Optimization without profiling data to justify it.
- N+1 query patterns in new or touched data-fetching code.
- List endpoints shipped without pagination.
- Images without dimensions, lazy loading, or responsive sizes.
- Bundle size growing without review or budget justification.
- No performance monitoring or regression test for a fix that claims a measurable win.
- A change that improves one CWV metric while silently regressing another.
- A `SIMPLICITY CHECK` that is missing at the top of the fix.
- Repeating the same documented rejected change without new evidence or materially different measurement conditions.
- Leaving an attempted implementation applied after its measurement failed.

## Verification

Before declaring a perf slice done, confirm every applicable item:

- [ ] For measured attempts, before and after numbers exist with units under the same workload budget and cache state; when a durable comparison is required, both artifact IDs and their predecessor lineage are linked.
- [ ] Every attempted optimization, including reverted code and measurement failures, is recorded using Step 4's destination fallback and complete field set.
- [ ] The outcome is `KEEP` only for a reproducible, budget-clearing improvement with all regression and behavior checks passing; comparable worse, neutral, noise-bound, budget-missing, or test-failing results are `REVERT`.
- [ ] `ERROR`, `TIMEOUT`, and `INCONCLUSIVE` outcomes include failure details, leave the implementation restored, and remain eligible for remeasurement.
- [ ] The specific bottleneck is named — a concrete query, component, asset, or code path — not "general slowness".
- [ ] Core Web Vitals are within Good thresholds (or at least moved out of Poor).
- [ ] The improvement exceeds measurement noise on the declared primary statistic, p50, and p95; RUM Core Web Vitals use p75 as the primary statistic.
- [ ] The evidence classes and collection conditions are comparable; synthetic-only evidence is not described as a real-user outcome.
- [ ] No adjacent metric (bundle size, another CWV, an API endpoint's latency) regressed as a side effect.
- [ ] For a kept fix, a budget or regression test exists that fails if the fix is undone.
- [ ] Bundle size has not increased without justification against the budget.
- [ ] No new N+1 queries in the data-fetching path.
- [ ] Performance budget passes in CI (if configured).
- [ ] A `NOTICED BUT NOT TOUCHING` entry exists for every perf smell observed outside the measured bottleneck.
- [ ] Existing tests still pass — the optimization did not change behavior.

If any item is unchecked, the slice is not done. Fix the gap or split the slice.
