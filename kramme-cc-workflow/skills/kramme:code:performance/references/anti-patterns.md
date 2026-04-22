# Performance anti-patterns — before/after

Inline copy. Self-contained; no cross-skill references.

Six named anti-patterns with canonical fixes. Each one comes up enough that "I saw the smell, I knew the fix" should be the reflex.

## N+1 queries (backend)

Loading a list of rows, then issuing one query per row to fetch a related entity. The database round-trip count grows linearly with the list size — every page of results pays the tax.

```ts
// BAD: N+1 — one query per task for the owner
const tasks = await db.tasks.findMany();
for (const task of tasks) {
  task.owner = await db.users.findUnique({ where: { id: task.ownerId } });
}

// GOOD: single query with join / include
const tasks = await db.tasks.findMany({
  include: { owner: true },
});
```

Detection: turn on query logging and count queries per request. A list endpoint that issues more than `1 + (number of related collections)` queries per page is N+1.

## Unbounded data fetching

Endpoint returns every row in the table. Works for 100 rows in staging, falls over at 100 000 in production.

```ts
// BAD: fetches all records
const allTasks = await db.tasks.findMany();

// GOOD: paginated with hard limits
const tasks = await db.tasks.findMany({
  take: 20,
  skip: (page - 1) * 20,
  orderBy: { createdAt: 'desc' },
});
```

Always enforce a server-side maximum `take` — never trust the caller to send a reasonable `limit`. Cursor pagination is strictly better than offset pagination for large tables; offset paginations gets slower as `skip` grows.

## Missing image optimization (frontend)

No width/height → layout shift. No `srcset` → desktop-sized image served to a phone. No modern format → 2× the bytes. No `loading="lazy"` for below-the-fold → wasted bandwidth on first paint.

```html
<!-- BAD: no dimensions, no format optimization -->
<img src="/hero.jpg" />

<!-- GOOD: LCP image — art direction + resolution switching, high priority -->
<!--
  Two techniques combined:
  - Art direction (media): different crop/composition per breakpoint
  - Resolution switching (srcset + sizes): right file size per screen density
-->
<picture>
  <!-- Mobile: portrait crop (8:10) -->
  <source
    media="(max-width: 767px)"
    srcset="/hero-mobile-400.avif 400w, /hero-mobile-800.avif 800w"
    sizes="100vw"
    width="800"
    height="1000"
    type="image/avif"
  />
  <source
    media="(max-width: 767px)"
    srcset="/hero-mobile-400.webp 400w, /hero-mobile-800.webp 800w"
    sizes="100vw"
    width="800"
    height="1000"
    type="image/webp"
  />
  <!-- Desktop: landscape crop (2:1) -->
  <source
    srcset="/hero-800.avif 800w, /hero-1200.avif 1200w, /hero-1600.avif 1600w"
    sizes="(max-width: 1200px) 100vw, 1200px"
    width="1200"
    height="600"
    type="image/avif"
  />
  <source
    srcset="/hero-800.webp 800w, /hero-1200.webp 1200w, /hero-1600.webp 1600w"
    sizes="(max-width: 1200px) 100vw, 1200px"
    width="1200"
    height="600"
    type="image/webp"
  />
  <img
    src="/hero-desktop.jpg"
    width="1200"
    height="600"
    fetchpriority="high"
    alt="Hero image description"
  />
</picture>

<!-- GOOD: below-the-fold image — lazy loaded + async decoding -->
<img
  src="/content.webp"
  width="800"
  height="400"
  loading="lazy"
  decoding="async"
  alt="Content image description"
/>
```

Rules of thumb:

- Always set `width` and `height` — prevents CLS.
- Hero / LCP image: `fetchpriority="high"`, no `loading="lazy"`.
- Below the fold: `loading="lazy"`, `decoding="async"`.
- Ship AVIF or WebP with a JPEG/PNG fallback.

## Unnecessary re-renders (React)

New object or array literals created during render become fresh references every time. Children that receive them as props re-render unnecessarily. Memoization can help — but blanket memoization is its own perf smell.

```tsx
// BAD: creates new object on every render, children re-render
function TaskList() {
  return <TaskFilters options={{ sortBy: 'date', order: 'desc' }} />;
}

// GOOD: stable reference (module scope or useMemo)
const DEFAULT_OPTIONS = { sortBy: 'date', order: 'desc' } as const;
function TaskList() {
  return <TaskFilters options={DEFAULT_OPTIONS} />;
}

// Use React.memo only when profiling shows the child is expensive
const TaskItem = React.memo(function TaskItem({ task }: Props) {
  return <div>{/* expensive render */}</div>;
});

// Use useMemo only when the computation itself is expensive
function TaskStats({ tasks }: Props) {
  const stats = useMemo(() => calculateStats(tasks), [tasks]);
  return <div>{stats.completed} / {stats.total}</div>;
}
```

The memoization trap: `React.memo` / `useMemo` / `useCallback` applied to everything. Each adds bookkeeping cost and hides the render cause when something does re-render. Only apply when:

1. A profile shows the component or computation is a measurable hot path, and
2. The memo boundary is stable (the inputs actually memoize — an object prop without a stable reference defeats the memo).

## Large bundle size

Every route ships every dependency. Mobile users on 3G pay for code they never run.

```ts
// Modern bundlers (Vite, webpack 5+) handle named imports with tree-shaking automatically,
// provided the dependency ships ESM and is marked `sideEffects: false` in package.json.
// Profile before changing import styles — the real gains come from splitting and lazy loading.

// GOOD: dynamic import for heavy, rarely-used features
const ChartLibrary = lazy(() => import('./ChartLibrary'));

// GOOD: route-level code splitting wrapped in Suspense
const SettingsPage = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <SettingsPage />
    </Suspense>
  );
}
```

Investigation:

- Run `vite build --sourcemap` (or the webpack equivalent) and load the output into `source-map-explorer` or `webpack-bundle-analyzer`.
- Look for: duplicate dependencies, large dependencies used by only one route, icon libraries imported wholesale, locale data for unused languages.

## Missing caching (backend)

Recomputing or re-fetching data that changes rarely, on every request. A 20 ms query called 100 times per second is more expensive than the same query called once and cached for a minute.

```ts
// In-process TTL cache for frequently read, rarely changed config
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes
let cachedConfig: AppConfig | null = null;
let cacheExpiry = 0;

async function getAppConfig(): Promise<AppConfig> {
  if (cachedConfig && Date.now() < cacheExpiry) {
    return cachedConfig;
  }
  cachedConfig = await db.config.findFirst();
  cacheExpiry = Date.now() + CACHE_TTL;
  return cachedConfig;
}

// HTTP caching for static assets — content hashing in filenames lets you cache forever
app.use('/static', express.static('public', {
  maxAge: '1y',
  immutable: true,
}));

// Cache-Control for API responses that change on a cadence
res.set('Cache-Control', 'public, max-age=300'); // 5 minutes
```

Caching rules of thumb:

- Cache **read-mostly, write-rarely** data. Do not cache data that changes on every request.
- Prefer a **TTL** over manual invalidation — cache invalidation is the hard problem.
- Always have a **bypass** (header, query param, env var) so you can test without the cache.
- For cross-process caches (Redis, Memcached): measure — a cache miss that adds 20 ms of network round-trip can be slower than no cache.
