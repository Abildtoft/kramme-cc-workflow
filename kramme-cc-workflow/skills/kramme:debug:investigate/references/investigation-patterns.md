# Common Bug Investigation Patterns

Catalog of recurring bug patterns with symptoms, search strategies, and fixes.

## 1. Null / Undefined Reference

**Symptoms:** `TypeError: Cannot read properties of undefined`, unexpected `undefined` values.
**Grep for:** the null variable name, all assignments to it, functions that return it.
**Check:** initialized before use? Conditional branches that skip assignment? Async value used before resolution? Destructuring assumes wrong shape?
**Fix:** null checks, optional chaining, default values, fix the data source.

## 2. Race Condition

**Symptoms:** intermittent failures, flaky tests, different behavior under load.
**Grep for:** `async`, `await`, `Promise`, `setTimeout`, shared mutable state.
**Check:** two async ops on same state? Assumed execution order? Interleaved DB/API calls? Cache read before populated?
**Fix:** synchronization, atomic operations, reorder to eliminate race window.

## 3. State Corruption

**Symptoms:** wrong data, no error thrown, "impossible" states, stale UI.
**Grep for:** mutation points (direct assignment, setters, dispatches), event handlers on shared state.
**Check:** in-place mutation vs immutable update? Multiple writers? Shared reference where clone intended? Event fires too many times?
**Fix:** immutable patterns, centralized mutations, runtime invariant assertions, cleanup event listeners.

## 4. Off-by-One Error

**Symptoms:** missing first/last item, index out of bounds, wrong counts.
**Grep for:** loop constructs, array indexing `[i]`, `[length - 1]`, `.slice()`.
**Check:** loop start 0 or 1? `<` vs `<=`? `length` vs `length - 1`? Inclusive vs exclusive end?
**Fix:** fix boundaries, use range-based iteration, add boundary test cases.

## 5. Type Coercion / Mismatch

**Symptoms:** `"1" + 1 = "11"`, wrong truthiness, `NaN` propagation.
**Grep for:** `==` (loose equality), `parseInt`, `Number()`, `Boolean()`.
**Check:** string vs number comparison? Missing radix? Falsy 0 or empty string treated as invalid? API returns strings for numbers?
**Fix:** strict equality, explicit type conversion at boundaries, runtime validation.

## 6. Memory Leak

**Symptoms:** increasing memory over time, process crashes, degrading performance.
**Grep for:** `addEventListener` without `removeEventListener`, `setInterval` without `clearInterval`, `subscribe` without `unsubscribe`, unbounded caches.
**Check:** event listeners removed in cleanup? Intervals cleared? Subscriptions disposed? Cache has eviction?
**Fix:** cleanup in unmount/destroy, AbortController, cache eviction, WeakRef/WeakMap.

## 7. Regression

**Symptoms:** previously working feature now broken, correlated with recent deploy.
**Grep for:** `git log --oneline -20`, `git log -- path/to/affected`, `git diff HEAD~5`.
**Check:** recent changes in affected module? Dependency update? Config change? Refactoring changed signatures?
**Strategy:** check git log → review suspect diffs → use git bisect if unclear.
**Fix:** revert introducing commit, or fix the specific issue + add regression test.

## 8. Environment-Specific

**Symptoms:** works locally but not in CI/staging/production.
**Grep for:** `process.env`, `os.environ`, env-specific config files, feature flags, `process.platform`.
**Check:** env vars set correctly? Config differences? Feature flags differ? OS path separators? Timezone? Runtime version?
**Fix:** synchronize env vars, use path utilities, add env-specific CI tests, log effective config at startup.

## 9. Dependency / Third-Party Issue

**Symptoms:** errors in library code, behavior change after update.
**Grep for:** dependency name in lockfile diffs, version constraints, changelog.
**Check:** version changed recently? Known issues upstream? Used per documented API? Breaking changes in new version?
**Fix:** pin to last known-good version, update usage, add abstraction layer, report upstream.

## 10. Concurrency / Deadlock

**Symptoms:** process hangs, timeout errors, operations never complete.
**Grep for:** lock acquisition patterns, nested locks, channel operations.
**Check:** consistent lock ordering? Circular dependency? Full channels? Transaction holding lock while waiting?
**Fix:** global lock ordering, lock timeouts, reduce lock duration, lock-free structures.

## General Checklist

When no pattern matches:
1. Read the error message carefully — every word matters
2. Find the exact line where the error occurs
3. Read 50 lines of surrounding code in each direction
4. Check the inputs — what values reach the error point?
5. Check recent changes — `git log` and `git diff`
6. Check tests — do they exist? Do they pass? Do they cover this case?
7. Simplify — can you reproduce with a minimal example?
8. Question assumptions — what does the code assume that might not be true?
