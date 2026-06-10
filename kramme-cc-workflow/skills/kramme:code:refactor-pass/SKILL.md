---
name: kramme:code:refactor-pass
description: "Perform a refactor pass focused on simplicity after recent changes. Use when the user asks for a refactor/cleanup pass, simplification, or dead-code removal on a narrow scope and expects build/tests to verify behavior. Applies Chesterton's Fence before removing code, rejects simplifications that require modifying tests, and works one slice at a time."
disable-model-invocation: true
user-invocable: true
---

# Refactor Pass

Perform a simplification pass on recent changes: remove dead code, straighten logic, drop excessive parameters, and verify with build/tests after each change. One simplification at a time, preserving behavior exactly.

This skill edits files and commits each verified slice, so it runs only after explicit user invocation.

## When to use

- After a feature or fix lands, before merging, to clean up accidental complexity.
- When the user asks for "a refactor pass", "cleanup", "simplification", or "dead-code removal" on recent work.
- On a narrow scope — typically the diff of the current branch or a few files. Not for codebase-wide scans (use `kramme:code:refactor-opportunities` for that).

## When NOT to simplify

Before starting, check that simplification is actually warranted. Do not proceed if:

- **Code is already clean.** Not every file needs a pass. If the recent changes read well, stop here.
- **You don't understand it yet.** Simplifying code you don't fully understand is how subtle behavior gets deleted. Read the code and the tests first; when in doubt, leave it.
- **It's performance-critical and the alternatives are slower.** "Cleaner" is not a goal that overrides measured performance. Check benchmarks before simplifying hot paths.
- **It's about to be rewritten.** If the code will be replaced by other in-flight work, a refactor pass is wasted effort. Surface the overlap and stop.

If any of these apply to the whole scope, stop and tell the user why. If they apply to specific sections, skip those sections.

## Resolve scope

Before picking simplifications, decide what "recent changes" means for this invocation:

1. If the user named files or a directory, use that.
2. Otherwise, default to the current branch's diff against the base branch (e.g. `git diff origin/main...HEAD`), plus uncommitted working-tree changes.
3. If the resulting scope is empty (clean working tree, no diff against base), stop and ask the user what to scope to. Do not invent a scope.

Record the scope before starting the loop. Every simplification must fall inside it; observations outside it become `NOTICED BUT NOT TOUCHING` markers, not new work.

## Markers

This skill emits two markers. Use these exact formats so a calling agent can parse them.

`SIMPLICITY CHECK` — the minimum change you intend to make for the current slice:

```
SIMPLICITY CHECK: <one-line summary of the minimum change>
```

If the change ends up larger than that minimum, add a second line naming the concrete requirement that forced the expansion.

`NOTICED BUT NOT TOUCHING` — anything adjacent you saw while editing but are intentionally leaving alone:

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: out-of-scope for this simplification
```

Log; do not silently resolve. A future pass can address it as its own slice.

## Pre-flight: Chesterton's Fence

Before removing or substantially changing any piece of code, verify you understand why it exists. Answer all five:

1. **Responsibility** — What does it do? (Trace inputs → outputs, including side effects.)
2. **Callers** — Who depends on it? (Grep for usages; check exported symbols.)
3. **Edge cases** — What hidden inputs does it handle? (Null, empty, error paths, rare type variants.)
4. **Tests** — What behaviors does it lock in? (Read the tests that cover it.)
5. **Git blame** — Why was it added? (`git log -L` or `git blame` on the lines. A named bug in the commit message is load-bearing context.)

If you can't answer all five, you haven't earned the right to remove it. Either read more, or emit `NOTICED BUT NOT TOUCHING` and move on.

## The Simplification Loop

Each simplification is one pass through this loop. **One simplification at a time** — verify after each. Do not batch.

### 1. Pick one simplification

From the resolved scope, pick exactly one target. Candidates:

- Dead code or dead paths.
- Twisted logic that can be straightened.
- Excessive parameters, flags that select behavior, options objects that are always the same shape.
- Premature optimization that adds indirection for no measured gain.
- Unnecessary abstraction layers — wrappers that forward with no logic.

### 2. Emit a SIMPLICITY CHECK

State the minimum change that accomplishes the simplification (see Markers).

### 3. Apply the change

Apply only that one change. Keep the diff small. If the diff grows past a few files or a few dozen lines, you are probably doing more than one thing — split the slice.

If you notice something adjacent that also wants fixing, do not fix it — emit a `NOTICED BUT NOT TOUCHING` marker and continue.

### 4. Verify and commit

Run the project's verification battery via `kramme:verify:run` — build, typecheck, lint, and existing tests must all pass. **Tests must pass unmodified.** If a test fails, you changed behavior: revert the slice (`git restore` the touched files) and either re-plan or reclassify it as a behavior change handled outside this skill.

If `kramme:verify:run` cannot run (no test/lint/build configured, tool errors, etc.), stop and surface the gap. Do not declare the slice verified.

When verification passes, commit the slice on its own. The committed state becomes the baseline for the next iteration.

### 5. Move to the next simplification

Return to step 1 with the new committed baseline. Do not accumulate simplifications into one large diff.

## Integration with other skills

- **Verification**: Step 4 delegates to `kramme:verify:run`.
- **Sibling — slice discipline**: `kramme:code:incremental` applies the same one-thing-at-a-time rule to feature work. Refactor passes obey the same six rules; this skill is the refactor-flavored loop.
- **Alternative — scrap and rewrite**: if the recent code is inelegant enough that simplification would touch more than ~50% of it, stop and use `kramme:code:rewrite-clean` instead. A mediocre implementation is sometimes best scrapped rather than patched.
- **Broader scan**: if the simplification opportunities extend beyond the recent diff, stop and suggest `kramme:code:refactor-opportunities` for a codebase-wide scan.

## Common Rationalizations

These are the lies you will tell yourself to justify going past the scope of the pass. Each has a correct response:

- _"I'll simplify and fix the broken test together."_ → Run tests **before** simplifying. If tests already fail, that is a separate problem — fix it (or log it) first, then simplify from a green baseline.
- _"This abstraction is obviously useless, I don't need to read the blame."_ → Chesterton's Fence. Read the blame. One of these deletes will eventually remove load-bearing behavior.
- _"The diff is smaller if I inline this helper."_ → Line count is not the goal. Keep the helper if its name carries intent.
- _"I'll combine two simplifications into one commit for cleanliness."_ → No. Each simplification stands alone so the failure surface is obvious if verification breaks.
- _"The test is flaky; I'll just tweak it so it passes."_ → If a simplification requires modifying a test, it is a behavior change, not a simplification. Revert or re-scope.
- _"While I'm here, let me also rename this for consistency."_ → Emit `NOTICED BUT NOT TOUCHING`. Rename is its own slice — often its own PR.

## Red Flags

Ways a simplification pass turns into damage. If any of these happen, reject the slice and revert:

- **Inlining too aggressively.** Inlining a helper that is used once but has a meaningful name destroys a comment. Keep the name if it carries intent.
- **Removing "unnecessary" abstractions without applying the Fence.** An abstraction with only one caller today may be there for a planned second caller, or to isolate volatility.
- **Optimizing for line count.** Shorter is not the goal. A 10-line function that reads top-to-bottom beats a 4-line function that requires a dictionary. If the "simplified" version is longer than the original, discard it.
- **Removing defensive checks without proving they are unreachable.** A `try/catch` wrapping a library call may be absorbing a known failure mode; a `null` check that "can't happen" must be proven unreachable (via types, invariants, or caller analysis) before removal.
- **Renaming for personal taste.** Rename only to restore consistency with the surrounding codebase.

## Verification

The loop enforces most invariants per-iteration; this is the residual check:

- The final diff is smaller and clearer than the input. If it is larger or less clear, revert.
- Every observation outside the original scope has a `NOTICED BUT NOT TOUCHING` marker; none were silently fixed.
