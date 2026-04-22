# Performance exit checklist and CI budget

Inline copy. Self-contained; no cross-skill references.

## Exit checklist

Before declaring a performance slice done, every box must be checked:

- [ ] Before and after measurements exist (specific numbers with units).
- [ ] The specific bottleneck is identified and addressed (not "general slowness").
- [ ] Core Web Vitals are within Good thresholds.
- [ ] Bundle size has not increased significantly (or the increase is justified against the budget).
- [ ] No new N+1 queries in the data-fetching path.
- [ ] Performance budget passes in CI (if configured).
- [ ] Existing tests still pass — the optimization did not change behavior.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.

## Performance budget (starting defaults)

Treat these as a floor — tighten per product, never loosen silently.

```
JavaScript bundle (initial):  < 200 KB gzipped
CSS:                          < 50 KB gzipped
Images (above the fold):      < 200 KB per image
Fonts (total):                < 100 KB
API response time (p95):      < 200 ms
Time to Interactive (4G):     < 3.5 s
Lighthouse Performance score: ≥ 90
```

## CI enforcement

### Bundle size — `bundlesize`

`bundlesize.config.json`:

```json
{
  "files": [
    {
      "path": "./dist/assets/index-*.js",
      "maxSize": "200 KB",
      "compression": "gzip"
    },
    {
      "path": "./dist/assets/index-*.css",
      "maxSize": "50 KB",
      "compression": "gzip"
    }
  ]
}
```

Run in CI:

```bash
npx bundlesize
```

### Lighthouse CI — `lhci`

`lighthouserc.json`:

```json
{
  "ci": {
    "collect": {
      "numberOfRuns": 3,
      "url": ["http://localhost:3000/"]
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.9 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
        "interaction-to-next-paint": ["error", { "maxNumericValue": 200 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.1 }]
      }
    }
  }
}
```

Run in CI:

```bash
npx lhci autorun
```

### Custom regression tests

For a hot code path that does not have a clean CWV mapping (a background job, a CLI command, a server-rendered endpoint), write a dedicated timing test:

```ts
import { test, expect } from 'vitest';
import { computeReport } from './report';

test('computeReport stays under 150ms for 10k rows', async () => {
  const rows = Array.from({ length: 10_000 }, (_, i) => ({ id: i, value: i * 2 }));
  const start = performance.now();
  await computeReport(rows);
  const elapsed = performance.now() - start;
  expect(elapsed).toBeLessThan(150);
});
```

Guard principles:

- Set the threshold at roughly **1.5× the measured "good" value** — tight enough to catch regression, loose enough to survive noise.
- Run on representative data sizes, not toy inputs.
- Pin the test to CI-stable hardware (use the same runner class every time).
