# Usage Guide

Adapted from EveryInc compound-engineering-plugin `ce-optimize/references/usage-guide.md`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.

## What This Skill Is For

Use `kramme:code:optimize` when:

1. Multiple code, config, prompt, or parameter variants are plausible.
2. Every variant can be evaluated by the same measurement harness.
3. You need a durable experiment log instead of conversation-only notes.
4. The winning variant should be kept and the losing variants should be rejected.

It is for search-space work, not routine implementation.

## Hard Metric Mode

Use `metric.primary.type: hard` when the metric is objective and cheap to measure:

- build time,
- bundle size,
- memory usage,
- p95 latency,
- throughput,
- test pass rate,
- error count.

Hard mode still needs degenerate gates. A faster build that skips tests is not an optimization.

## Judge Mode

Use `metric.primary.type: judge` when numeric proxies can lie:

- cluster coherence,
- search relevance,
- prompt quality,
- summary usefulness,
- ranking quality,
- classification quality on semantic edge cases.

Judge mode should still run hard gates first. Gates catch obvious failures cheaply; the judge scores only candidates that pass.

## First-Run Defaults

For a first run:

- use serial execution,
- set `max_concurrent: 1`,
- cap iterations and hours,
- avoid new dependencies,
- keep judge `sample_size` small,
- cap judge cost,
- preserve the harness in `scope.immutable`.

The first run validates the harness. Later runs can widen the search.

## Example Kickoffs

```text
Use kramme:code:optimize to reduce bundle size. The measurement command is `npm run measure:bundle`, and the JSON includes `bundle_kb`, `build_passed`, and `test_pass_rate`.
```

```text
Use kramme:code:optimize to improve search relevance. Hard gates should ensure at least 5 results and no crashes. Use judge mode to score top-10 relevance against a 1-5 rubric.
```

```text
Use kramme:code:optimize to compare prompt variants for issue summaries. Optimize for judge quality after gates confirm JSON validity, token budget, and no empty summaries.
```

## When Not To Use It

- The fix is obvious and one implementation is enough.
- There is no repeatable measurement command.
- The evaluation cost is too high for several variants.
- The only metric is easy to game and no judge rubric is available.
- The user wants a normal performance pass; use `kramme:code:performance`.
