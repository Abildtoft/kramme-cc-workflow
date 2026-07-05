---
name: kramme:code:performance
description: "(experimental) Measure-first performance discipline tied to Core Web Vitals (LCP, INP, CLS). Use when users or monitoring report slowness, CWV scores miss thresholds, performance requirements exist in the spec, you suspect a recent change introduced a regression, or you're building features that handle large datasets or high traffic. Enforces baseline measurement, single-bottleneck fixes, verification, and regression guards. Complements the review-time `kramme:performance-oracle` agent."
disable-model-invocation: false
user-invocable: true
---

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
4. VERIFY   → Measure again, confirm improvement
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

Record the baseline number _with units_ in the ticket or commit message. "Fast enough" is not a baseline.

### Step 2 — Identify the bottleneck

Read `references/triage.md` now. It contains the frontend/backend symptom tables (symptom → likely cause → investigation), the "Where to start measuring" decision tree, and the six anti-pattern summaries. Use the symptom to pick what to profile first, and follow one branch of the tree per measurement.

### Step 3 — Fix the bottleneck

Map the identified bottleneck to one of the six named anti-patterns in `references/triage.md` (N+1 queries, unbounded data fetching, missing image optimization, unnecessary re-renders, large bundle size, missing caching) and apply its canonical fix. Full before/after code examples live in `references/anti-patterns.md`.

**The memoization trap.** `React.memo`, `useMemo`, and `useCallback` everywhere is itself a perf anti-pattern: each adds bookkeeping cost and obscures render causes. Apply only when profiling shows a measured win — and document the measurement next to the memo.

### Step 4 — Verify

Remeasure with the same tool, on the same device class, on the same network profile you used for the baseline. Then check:

- The improvement exceeds measurement noise. A 5% change on Lighthouse is noise; a 30% change is a signal.
- Compare p95 (tail) and p50 (typical), not just the average. An optimization that only improves p50 can leave the tail unchanged.
- Core Web Vitals are now in Good (or at least moved out of Poor).
- No adjacent metric regressed. A fix that halves LCP but doubles CLS is not a fix.

If the change does not clear the budget, revert and re-identify — do not stack a second optimization on top of an unverified first one.

### Step 5 — Guard

Lock in the fix so it cannot silently regress:

- **Bundle size budget** — `bundlesize` or the bundler's built-in budget, fails CI when a route exceeds the limit.
- **Lighthouse CI** — `lhci autorun` with score thresholds and CWV assertions in the PR pipeline.
- **Synthetic regression test** — a dedicated test that times the specific code path (a slow query, a render path) and fails when it exceeds the threshold.
- **RUM alert** — dashboard alert on the p95 of the metric you just fixed.

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
- **Companion** — `kramme:code:incremental`: each optimization is one slice through the incremental loop. The five-step workflow fits inside a single increment; the budget becomes the increment's exit criterion.
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

## Verification

Before declaring a perf slice done, confirm every item:

- [ ] Before and after numbers exist with units, recorded in the commit message or PR description.
- [ ] The specific bottleneck is named — a concrete query, component, asset, or code path — not "general slowness".
- [ ] Core Web Vitals are within Good thresholds (or at least moved out of Poor).
- [ ] The improvement exceeds measurement noise on both p50 and p95.
- [ ] No adjacent metric (bundle size, another CWV, an API endpoint's latency) regressed as a side effect.
- [ ] A budget or regression test exists that fails if this fix is undone.
- [ ] Bundle size has not increased without justification against the budget.
- [ ] No new N+1 queries in the data-fetching path.
- [ ] Performance budget passes in CI (if configured).
- [ ] A `NOTICED BUT NOT TOUCHING` entry exists for every perf smell observed outside the measured bottleneck.
- [ ] Existing tests still pass — the optimization did not change behavior.

If any item is unchecked, the slice is not done. Fix the gap or split the slice.
