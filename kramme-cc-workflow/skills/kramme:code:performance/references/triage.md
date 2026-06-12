# Triage — symptom tables, decision tree, and anti-pattern summaries

Load this file at Step 2 (Identify the bottleneck). Use the symptom tables and the
decision tree to pick what to profile first, then the anti-pattern summaries at Step 3
to map the identified bottleneck to its canonical fix.

## Common bottlenecks by category

**Frontend:**

| Symptom | Likely cause | Investigation |
| --- | --- | --- |
| Slow LCP | Large images, render-blocking resources, slow server | Check network waterfall, image sizes |
| High CLS | Images without dimensions, late-loading content, font shifts | Check layout-shift attribution |
| Poor INP | Heavy JavaScript on main thread, large DOM updates | Check long tasks in Performance trace |
| Slow initial load | Large bundle, many network requests | Check bundle size, code splitting |

**Backend:**

| Symptom | Likely cause | Investigation |
| --- | --- | --- |
| Slow API responses | N+1 queries, missing indexes, unoptimized queries | Check database query log |
| Memory growth | Leaked references, unbounded caches, large payloads | Heap snapshot analysis |
| CPU spikes | Synchronous heavy computation, regex backtracking | CPU profiling |
| High latency | Missing caching, redundant computation, network hops | Trace requests through the stack |

## Where to start measuring

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

## The six anti-patterns

Each has a canonical fix. Full before/after code examples live in `anti-patterns.md`.

- **N+1 queries** — one query per row of a parent collection. Fix with a single query plus `include` / `join` / eager loading.
- **Unbounded data fetching** — listing endpoints that return every row. Fix with pagination (`take` + `skip` or cursor pagination) and a hard server-side limit.
- **Missing image optimization** — `<img>` without width/height, no `srcset`, no `loading="lazy"`, uncompressed format. Fix with `<picture>`, `srcset`, explicit dimensions, modern formats (AVIF/WebP), `fetchpriority="high"` for LCP image, `loading="lazy"` for below the fold.
- **Unnecessary re-renders (React)** — new object/array literals passed as props on every render, or memoization applied blindly. Fix with stable references (module-scope constants or `useMemo`), `React.memo` only when profiling proves it helps.
- **Large bundle size** — every route ships every dependency. Fix with route-level code splitting (`lazy` + `Suspense`), dynamic imports for heavy features, and tree-shaking (ESM + `sideEffects: false`). Profile before micro-optimizing import styles.
- **Missing caching** — recomputing or re-fetching frequently read, rarely changed data. Fix with an in-memory TTL cache, HTTP `Cache-Control` headers for static assets, and content hashing in filenames for immutable long-cached resources.
