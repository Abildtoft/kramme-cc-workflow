---
name: kramme:code:refactor-pass
description: "Perform a refactor pass focused on simplicity after recent changes. Use when the user asks for a refactor/cleanup pass, simplification, or dead-code removal and expects build/tests to verify behavior. Applies Chesterton's Fence before removing code, rejects simplifications that require modifying tests, and emits SIMPLICITY CHECK / NOTICED BUT NOT TOUCHING markers."
disable-model-invocation: false
user-invocable: true
---

# Refactor Pass

Perform a simplification pass on recent changes: remove dead code, straighten logic, drop excessive parameters, and verify with build/tests after each change. One simplification at a time, preserving behavior exactly.

## When to use

- After a feature or fix lands, before merging, to clean up accidental complexity.
- When the user asks for "a refactor pass", "cleanup", "simplification", or "dead-code removal" on recent work.
- On a narrow scope — typically the diff of the current branch or a few files. Not for codebase-wide scans (use `kramme:code:refactor-opportunities` for that).

## Prerequisites — When NOT to simplify

Before starting, check that simplification is actually warranted. Do not proceed if:

- **Code is already clean.** Not every file needs a pass. If the recent changes read well, stop here.
- **You don't understand it yet.** Simplifying code you don't fully understand is how subtle behavior gets deleted. Read the code and the tests first; when in doubt, leave it.
- **It's performance-critical and the alternatives are slower.** "Cleaner" is not a goal that overrides measured performance. Check benchmarks before simplifying hot paths.
- **It's about to be rewritten.** If the code will be replaced by other in-flight work, a refactor pass is wasted effort. Surface the overlap and stop.

If any of these apply to the whole scope, stop and tell the user why. If they apply to specific sections, skip those sections.

## Pre-flight: Chesterton's Fence

Before removing or substantially changing any piece of code, verify you understand why it exists. Answer all five:

1. **Responsibility** — What does it do? (Trace inputs → outputs, including side effects.)
2. **Callers** — Who depends on it? (Grep for usages; check exported symbols.)
3. **Edge cases** — What hidden inputs does it handle? (Null, empty, error paths, rare type variants.)
4. **Tests** — What behaviors does it lock in? (Read the tests that cover it.)
5. **Git blame** — Why was it added? (`git log -L` or `git blame` on the lines. A named bug in the commit message is load-bearing context.)

If you can't answer all five, you haven't earned the right to remove it. Either read more, or emit `NOTICED BUT NOT TOUCHING` and move on.

## The Simplification Loop

Each simplification is one pass through this loop. **One simplification at a time** — test after each. Do not batch.

### 1. Pick one simplification

From the recent changes, pick exactly one target. Candidates:

- Dead code or dead paths.
- Twisted logic that can be straightened.
- Excessive parameters, flags that select behavior, options objects that are always the same shape.
- Premature optimization that adds indirection for no measured gain.
- Unnecessary abstraction layers — wrappers that forward with no logic.

### 2. Emit a SIMPLICITY CHECK

State the minimum change that accomplishes the simplification. If you end up doing more, a concrete requirement must force it.

```
SIMPLICITY CHECK: <one-line summary of the minimum change>
```

If the minimum change is not what you build, add a second line explaining what forced the expansion.

### 3. Apply the change

Apply only that one change. Keep the diff small. If the diff grows past a few files or a few dozen lines, you are probably doing more than one thing — split the slice.

While editing, if you notice something adjacent that also wants fixing, do not fix it. Emit a marker:

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: out-of-scope for this simplification
```

Log it; do not silently resolve it. A future pass can address it as its own slice.

### 4. Verify

Run the project's verification battery. Delegate to `kramme:verify:run` — build, typecheck, lint, and existing tests must all pass **without any test modifications**.

If a test fails, you changed behavior. Either revert and re-plan, or accept that this is not a simplification (it's a behavior change) and treat it as such.

### 5. Move to the next simplification

Return to step 1 with the committed state as the new baseline. Do not accumulate simplifications into one large diff.

## Over-simplification traps

These are ways a simplification pass turns into damage. Watch for them while working:

- **Inlining too aggressively.** Inlining a helper that is used once but has a meaningful name destroys a comment. Keep the name if it carries intent.
- **Removing "unnecessary" abstractions.** An abstraction with only one caller today may be there for a planned second caller, or to isolate volatility. Apply Chesterton's Fence before deletion.
- **Optimizing for line count.** Shorter is not the goal. A 10-line function that reads top-to-bottom beats a 4-line function that requires a dictionary.
- **Removing error handling.** Defensive checks that look redundant often are not. A `try/catch` wrapping a library call may be absorbing a known failure mode. Prove the branch is unreachable before removing it.

## Integration with other skills

- **Verification**: Step 4 delegates to `kramme:verify:run`.
- **Sibling — slice discipline**: `kramme:code:incremental` applies the same one-thing-at-a-time rule to feature work. Refactor passes obey the same six rules; this skill is the refactor-flavored loop.
- **Alternative — scrap and rewrite**: if the recent code is inelegant enough that simplification would touch more than ~50% of it, stop and use `kramme:code:rewrite-clean` instead. A mediocre implementation is sometimes best scrapped rather than patched.
- **Broader scan**: if the simplification opportunities extend beyond the recent diff, stop and suggest `kramme:code:refactor-opportunities` for a codebase-wide scan.

---

## Common Rationalizations

These are the lies you will tell yourself to justify going past the scope of the pass. Each has a correct response:

- *"I'll simplify and fix the broken test together."* → Run tests **before** simplifying. If tests already fail, that is a separate problem — fix it (or log it) first, then simplify from a green baseline.
- *"This abstraction is obviously useless, I don't need to read the blame."* → Chesterton's Fence. Read the blame. One of these deletes will eventually remove load-bearing behavior.
- *"The diff is smaller if I inline this helper."* → Line count is not the goal. Keep the helper if its name carries intent.
- *"I'll combine two simplifications into one commit for cleanliness."* → No. Each simplification stands alone so the failure surface is obvious if verification breaks.
- *"The test is flaky; I'll just tweak it so it passes."* → If a simplification requires modifying a test, it is a behavior change, not a simplification. Revert or re-scope.
- *"While I'm here, let me also rename this for consistency."* → Emit `NOTICED BUT NOT TOUCHING`. Rename is its own slice — often its own PR.

## Red Flags

Rejection criteria. If any of these are true, reject the simplification and revert:

- **Simplification that requires modifying tests to pass.** Tests encode behavior. Modifying a test to accommodate a "simplification" means behavior changed. Revert or reclassify.
- **"Simplified" code is longer than the original.** If the simplified version is longer, it is not a simplification. Discard the change.
- **Renaming for personal preference (not codebase consistency).** If the old name matches the codebase and the new name matches your taste, keep the old name. Rename only to restore consistency.
- **Removing defensive checks without proving they're unreachable.** A `null` check that "can't happen" must be proven unreachable (via types, invariants, or caller analysis) before removal. Otherwise, leave it.

## Verification

Before declaring the pass done, self-check:

- [ ] Every simplification was applied and verified in isolation — no batched diffs.
- [ ] All existing tests pass **without any test modifications**.
- [ ] Build, typecheck, and lint all pass.
- [ ] No `SIMPLICITY CHECK` was expanded without a concrete forcing requirement.
- [ ] Every out-of-scope observation has a logged `NOTICED BUT NOT TOUCHING` marker; none were silently fixed.
- [ ] The final diff is smaller and clearer than the input. If it is larger or less clear, revert.

If any box is unchecked, finish the gap or revert before declaring done.
