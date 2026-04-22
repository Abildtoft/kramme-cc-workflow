# Core Web Vitals — thresholds and measurement

Inline copy. This file is self-contained; no cross-skill references.

## Thresholds

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5 s | ≤ 4.0 s | > 4.0 s |
| **INP** (Interaction to Next Paint) | ≤ 200 ms | ≤ 500 ms | > 500 ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

A single metric regressing from Good into Needs Improvement is a regression. All three must be in Good for the page to qualify as "passing CWV."

## What each metric measures

- **LCP** — time from navigation to when the largest visible content element finishes rendering. Typical bottleneck: hero image, above-the-fold media, render-blocking CSS/JS.
- **INP** — delay between a user interaction (click, tap, key press) and the next paint that reflects the response. Typical bottleneck: long JavaScript tasks on the main thread.
- **CLS** — cumulative movement of visible elements during the page lifetime (unitless score). Typical bottleneck: images without dimensions, late-injected banners, web fonts swapping in.

## Measurement — synthetic

Synthetic measurement runs the page under controlled conditions. Use for CI and issue isolation.

```bash
# Lighthouse CLI (one-off)
npx lighthouse https://example.com --only-categories=performance --output=json

# Lighthouse CI (budgeted, fails on regression)
npx lhci autorun

# WebPageTest (more realistic device + network emulation)
# https://www.webpagetest.org — fill form or use its API
```

Chrome DevTools Performance tab (interactive):

1. Open DevTools → **Performance** tab.
2. Set throttling to **Slow 4G** and **4× CPU slowdown** (representative hardware).
3. Click **Record**, interact with the page, click **Stop**.
4. Look at the **Timings** lane (LCP marker), **Long Tasks** lane (INP culprits), **Layout Shifts** lane (CLS culprits).

## Measurement — RUM (Real User Monitoring)

RUM captures real traffic in real conditions. Required to confirm a synthetic fix actually improved user experience.

```ts
// web-vitals library — report every metric to your analytics endpoint
import { onLCP, onINP, onCLS } from 'web-vitals';

function report(metric: { name: string; value: number; id: string }) {
  navigator.sendBeacon('/analytics/rum', JSON.stringify(metric));
}

onLCP(report);
onINP(report);
onCLS(report);
```

Other RUM sources:

- **Chrome User Experience Report (CrUX)** — 28-day field data aggregated by origin. Query via the CrUX API or the Public Dataset in BigQuery.
- **PageSpeed Insights** — surfaces both Lighthouse (synthetic) and CrUX (RUM) side by side.
- **Project APM** — Datadog, New Relic, Sentry Performance, or equivalent usually expose CWV as first-class metrics.

## Mobile vs desktop

CrUX reports mobile and desktop separately. Optimize for mobile first — it is typically the worse profile and the larger share of traffic for consumer products. A page that is Good on desktop and Poor on mobile does not pass.

## Noise floor

Single-run synthetic measurements vary by several percent across runs. Rules of thumb:

- One Lighthouse run is anecdata. Use at least 3 runs and take the median.
- A < 5% change on a single Lighthouse metric is inside noise.
- A > 20% change is a signal worth acting on.
- RUM data over 24 hours is more stable than one synthetic run — but requires enough traffic.
