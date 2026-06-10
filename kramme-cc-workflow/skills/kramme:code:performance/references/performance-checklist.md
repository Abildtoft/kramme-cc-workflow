# Performance CI enforcement

The canonical Verification checklist and starting budget defaults live in `SKILL.md`. This file holds the example config files for enforcing the budget in CI.

## Bundle size — `bundlesize`

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

## Lighthouse CI — `lhci`

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

## Custom regression tests

For a hot code path that does not have a clean CWV mapping (a background job, a CLI command, a server-rendered endpoint), write a dedicated timing test:

```ts
import { expect, test } from "vitest";
import { computeReport } from "./report";

test("computeReport stays under 150ms for 10k rows", async () => {
  const rows = Array.from({ length: 10_000 }, (_, i) => ({
    id: i,
    value: i * 2,
  }));
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
