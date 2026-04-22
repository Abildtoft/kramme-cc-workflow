---
name: kramme:code:performance
description: "(experimental) Apply measure-first performance discipline with Core Web Vitals targets when building or optimizing code. Covers synthetic vs RUM measurement, CWV thresholds (LCP, INP, CLS), the MEASURE / IDENTIFY / FIX / VERIFY / GUARD workflow, a diagnostic decision tree for triaging slowness, common bottlenecks (N+1 queries, unbounded fetch, unoptimized images, bundle bloat, unnecessary re-renders, missing caching), and the trap of premature memoization. Use when performance requirements exist, users or monitoring report slowness, CWV scores are below thresholds, or when implementing features that handle large datasets or high traffic. Complements the review-time `performance-oracle` agent with author-time guardrails."
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

**When NOT to use:** do not optimize before you have evidence of a problem. Premature optimization adds complexity that costs more than the performance it gains.

## Core Web Vitals targets

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5 s | ≤ 4.0 s | > 4.0 s |
| **INP** (Interaction to Next Paint) | ≤ 200 ms | ≤ 500 ms | > 500 ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

A change that regresses any metric from Good into Needs Improvement is a regression, even if the absolute number still looks fine. Full measurement commands and the inline copy of this table live in `references/core-web-vitals.md` (self-contained; no cross-skill links).

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

The reason: every "while I'm here" fix dilutes the before/after delta for the change you *are* measuring, and makes it impossible to attribute the gain cleanly.

### Step 1 — Measure

Two complementary approaches — use both:

- **Synthetic** (Lighthouse, Chrome DevTools Performance tab, WebPageTest): controlled conditions, reproducible. Best for CI regression detection and isolating a specific issue.
- **RUM** (`web-vitals` library, Chrome User Experience Report, project APM): real user data in real conditions. Required to validate that a fix actually improved user experience, not just the synthetic number.

**Frontend:**

```ts
// Synthetic: Lighthouse in Chrome DevTools (or CI)
// Chrome DevTools → Performance tab → Record
// Chrome DevTools MCP → Performance trace

// RUM: web-vitals library in code
import { onLCP, onINP, onCLS } from 'web-vitals';

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
console.time('db-query');
const result = await db.query(/* … */);
console.timeEnd('db-query');
```

Record the baseline number *with units* in the ticket or commit message. "Fast enough" is not a baseline.

### Step 2 — Identify the bottleneck

Common bottlenecks by category:

**Frontend:**

| Symptom | Likely cause | Investigation |
|---------|--------------|---------------|
| Slow LCP | Large images, render-blocking resources, slow server | Check network waterfall, image sizes |
| High CLS | Images without dimensions, late-loading content, font shifts | Check layout-shift attribution |
| Poor INP | Heavy JavaScript on main thread, large DOM updates | Check long tasks in Performance trace |
| Slow initial load | Large bundle, many network requests | Check bundle size, code splitting |

**Backend:**

| Symptom | Likely cause | Investigation |
|---------|--------------|---------------|
| Slow API responses | N+1 queries, missing indexes, unoptimized queries | Check database query log |
| Memory growth | Leaked references, unbounded caches, large payloads | Heap snapshot analysis |
| CPU spikes | Synchronous heavy computation, regex backtracking | CPU profiling |
| High latency | Missing caching, redundant computation, network hops | Trace requests through the stack |

### Where to start measuring

Use the symptom to decide what to profile first:

```
What is slow?
├── First page load
│   ├── Large bundle? --> Measure bundle size, check code splitting
│   ├── Slow server response? --> Measure TTFB in DevTools Network waterfall
│   │   ├── DNS long? --> Add dns-prefetch / preconnect for known origins
│   │   ├── TCP/TLS long? --> Enable HTTP/2, check edge deployment, keep-alive
│   │   └── Waiting (server) long? --> Profile backend, check queries and caching
│   └── Render-blocking resources? --> Check network waterfall for CSS/JS blocking
├── Interaction feels sluggish
│   ├── UI freezes on click? --> Profile main thread, look for long tasks (>50 ms)
│   ├── Form input lag? --> Check re-renders, controlled-component overhead
│   └── Animation jank? --> Check layout thrashing, forced reflows
├── Page after navigation
│   ├── Data loading? --> Measure API response times, check for waterfalls
│   └── Client rendering? --> Profile component render time, check for N+1 fetches
└── Backend / API
    ├── Single endpoint slow? --> Profile database queries, check indexes
    ├── All endpoints slow? --> Check connection pool, memory, CPU
    └── Intermittent slowness? --> Check for lock contention, GC pauses, external deps
```

Use the tree as a triage path, not a checklist. Follow one branch per measurement.

### Step 3 — Fix the bottleneck

Six common anti-patterns, each with a canonical fix. The full before/after code examples live in `references/anti-patterns.md` (inline copy; self-contained). The named anti-patterns:

- **N+1 queries** — one query per row of a parent collection. Fix with a single query plus `include` / `join` / eager loading.
- **Unbounded data fetching** — listing endpoints that return every row. Fix with pagination (`take` + `skip` or cursor pagination) and a hard server-side limit.
- **Missing image optimization** — `<img>` without width/height, no `srcset`, no `loading="lazy"`, uncompressed format. Fix with `<picture>`, `srcset`, explicit dimensions, modern formats (AVIF/WebP), `fetchpriority="high"` for LCP image, `loading="lazy"` for below the fold.
- **Unnecessary re-renders (React)** — new object/array literals passed as props on every render, or memoization applied blindly. Fix with stable references (module-scope constants or `useMemo`), `React.memo` only when profiling proves it helps.
- **Large bundle size** — every route ships every dependency. Fix with route-level code splitting (`lazy` + `Suspense`), dynamic imports for heavy features, and tree-shaking (ESM + `sideEffects: false`). Profile before micro-optimizing import styles.
- **Missing caching** — recomputing or re-fetching frequently read, rarely changed data. Fix with an in-memory TTL cache, HTTP `Cache-Control` headers for static assets, and content hashing in filenames for immutable long-cached resources.

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

Budgets are floors, not ceilings — a PR that adds 30 KB to the bundle without justifying it against the budget is a PR that should not merge. The complete checklist and example config files live in `references/performance-checklist.md` (inline; self-contained).

## Exit checklist

Before declaring a perf slice done, confirm every box:

- [ ] Before and after measurements exist (specific numbers with units).
- [ ] The specific bottleneck is identified and addressed (not "general slowness").
- [ ] Core Web Vitals are within Good thresholds.
- [ ] Bundle size has not increased significantly (or the increase is justified against the budget).
- [ ] No new N+1 queries in the data-fetching path.
- [ ] Performance budget passes in CI (if configured).
- [ ] Existing tests still pass — the optimization did not change behavior.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.

## Integration with other skills

- **Downstream review**: the `performance-oracle` agent verifies measurements and bottleneck identification post-hoc. A change that followed this skill's MEASURE/VERIFY discipline makes that review mechanical.
- **Sibling authoring**: `kramme:code:frontend-authoring` — UI slices are where most CWV wins and losses happen. Author the component per `frontend-authoring`; apply the budget and measurement gates per this skill.
- **Companion**: `kramme:code:incremental` — each optimization is one slice through the incremental loop. The five-step workflow (MEASURE / IDENTIFY / FIX / VERIFY / GUARD) fits inside a single increment; the budget becomes the increment's exit criterion.

---

## Common Rationalizations

These are the lies you will tell yourself to justify skipping the measurement or the guard. Each one has a correct response:

- *"We'll optimize later."* → Performance debt compounds. Fix the obvious anti-pattern now; defer only the micro-optimizations.
- *"It's fast on my machine."* → Your machine is not the user's. Profile on representative hardware and the slowest network profile the product supports.
- *"This optimization is obvious — no need to measure."* → If you did not measure, you do not know. Profile first; half the time the "obvious" bottleneck is not the real one.
- *"Users won't notice 100 ms."* → They do. Interaction delays above 100 ms are perceptible, and RUM data consistently shows them degrading conversion.
- *"The framework handles performance."* → Frameworks prevent some classes of issue, but they do not fix N+1 queries, oversized bundles, or unoptimized images. Those are author-level decisions.
- *"I'll add `React.memo` everywhere to be safe."* → Memoization is not free. Each memo adds bookkeeping cost and hides render causes. Apply only when profiling shows a measured win.
- *"The fix is small enough to skip the regression test."* → The next unrelated refactor will delete the fix by accident. A guarded fix is a fix; an unguarded fix is a fix with an expiration date.

## Red Flags

If you notice any of these, stop and return to step 1:

- Optimization without profiling data to justify it.
- N+1 query patterns in new or touched data-fetching code.
- List endpoints shipped without pagination.
- Images without dimensions, lazy loading, or responsive sizes.
- Bundle size growing without review or budget justification.
- No performance monitoring or regression test for a fix that claims a measurable win.
- `React.memo`, `useMemo`, or `useCallback` applied reflexively, without a profile showing it helps.
- A change that improves one CWV metric while silently regressing another.
- A `SIMPLICITY CHECK` that is missing at the top of the fix.

## Verification

Before declaring a perf slice done, self-check:

- Do the before and after numbers exist, with units, in the commit message or PR description?
- Is the specific bottleneck named — a concrete query, component, asset, or code path — not "general slowness"?
- Are Core Web Vitals in Good (or at least out of Poor) after the fix?
- Is there a budget or regression test that will fail if this fix is undone?
- Is there a `NOTICED BUT NOT TOUCHING` entry for every perf smell observed outside the measured bottleneck?
- Did the improvement exceed measurement noise on both p50 and p95?
- Did any adjacent metric (bundle size, another CWV, an API endpoint's latency) regress as a side effect?

If any answer is no, close the gap before declaring done.
