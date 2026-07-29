---
name: kramme:code:refactor-pass
description: "Perform a refactor pass focused on simplicity after recent changes, or use --rewrite to scrap a working-but-hacky implementation and reimplement it elegantly. Use for a narrow cleanup, simplification, dead-code removal, or an explicit request to redo mediocre recent work properly. Applies Chesterton's Fence, rejects changes that require modifying tests, and keeps the default mode slice-by-slice."
argument-hint: "[scope ... | --rewrite]"
disable-model-invocation: true
user-invocable: true
---

# Refactor Pass

Perform a simplification pass on recent changes: remove dead code, straighten logic, drop excessive parameters, and verify with build/tests after each change. By default, work one simplification at a time. In rewrite mode, scrap a working-but-hacky implementation and reimplement it elegantly from what you learned. Preserve behavior exactly in either mode.

This skill edits files, so it runs only after explicit user invocation. In default mode, it commits each verified slice.

## Select mode

Parse `$ARGUMENTS` before selecting a mode. Accept no arguments, exactly one `--rewrite` token, or one or more positional scope tokens with no option-prefixed token. Treat accepted positional tokens as the explicit default-mode scope. If `--rewrite` is combined with scope tokens, or any other option token is present, STOP, name the unsupported input, and show the valid invocation shapes. Do not fall through to default mode.

- **Default mode:** use when no arguments were passed, or when positional scope tokens were passed for a refactor, cleanup, simplification, or dead-code removal. Follow the slice-by-slice simplification loop.
- **Rewrite mode:** use when the sole argument is `--rewrite`, or when no arguments were passed and the user explicitly asks to scrap, redo, or reimplement a working but hacky solution elegantly. Validate the current-session context, then follow the rewrite process instead of the default scope-resolution and simplification loop.

## Rewrite mode Step 0: Validate context

Before proceeding in rewrite mode, review the current conversation to confirm:

1. **Implementation work exists** — We've written or modified code in this session.
2. **The work is complete enough** — The fix/feature works (even if inelegantly).
3. **There's something to improve** — The implementation has identifiable inelegance.

**If any of these are missing, STOP and explain:**

- No implementation work? → "There's no implementation in this conversation to refactor. This command is for redoing existing work more elegantly."
- Work isn't complete? → "Let's finish the current implementation first, then we can evaluate whether it needs an elegant refactor."
- Nothing obviously inelegant? → "The current implementation looks reasonable. What specifically feels hacky or inelegant to you?"

Only proceed in rewrite mode if all three conditions are met.

## When to use

- After a feature or fix lands, before merging, to clean up accidental complexity.
- When the user asks for "a refactor pass", "cleanup", "simplification", or "dead-code removal" on recent work.
- When the user asks to scrap a working-but-mediocre fix and redo it properly; select rewrite mode.
- On a narrow scope — typically the diff of the current branch or a few files. Not for codebase-wide scans (use `kramme:code:refactor-opportunities` for that).

## When NOT to proceed

After selecting the mode, apply this gate before changing code.

In either mode, do not proceed if:

- **You don't understand it yet.** Simplifying code you don't fully understand is how subtle behavior gets deleted. Read the code and the tests first; when in doubt, leave it.
- **It's performance-critical and the alternatives are slower.** "Cleaner" is not a goal that overrides measured performance. Check benchmarks before simplifying hot paths.

In default mode, also do not proceed if:

- **Code is already clean.** Not every file needs a pass. If the recent changes read well, stop here.
- **It's about to be rewritten.** If the code will be replaced by other in-flight work, a refactor pass is wasted effort. Surface the overlap and stop.

In rewrite mode, also do not proceed if:

- **The solution is fine, just unfamiliar.** Unfamiliarity is not inelegance. Read the code a second time before deciding to scrap it.
- **Time pressure makes "good enough" acceptable.** A working fix before a deadline is not a candidate for a scrap-and-rewrite. Ship it; log a follow-up if the inelegance matters.
- **The inelegance is inherent to the problem domain.** Some problems are ugly. If the ugliness tracks the domain rather than the implementation, a rewrite will reproduce it in a different shape.

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

## The Rewrite Process

Follow this process only in rewrite mode, after Step 0 and the shared "When NOT to proceed" gate.

### The core insight

First implementations often solve the problem but in a hacky way. Having solved the problem once, you now understand it deeply enough to implement it properly from scratch.

**Do not preserve the mediocre code.** The whole point is to start fresh.

### 1. Extract what you learned

Apply the shared Chesterton's Fence pre-flight to every non-trivial piece of the mediocre version before touching code. For the fifth criterion, check both git history and the current session: identify whether any piece was added in response to a bug discovered during this implementation.

Then articulate:

- What was the actual problem, rather than what you initially thought it was?
- What constraints did you discover?
- What edge cases matter?
- What dependencies or interactions exist?

If you cannot answer the five pre-flight questions for a piece, you haven't earned the right to scrap it. Read more first.

### 2. Identify the inelegance

Be specific about what is wrong with the current solution: unnecessary complexity, the wrong abstraction level, inappropriate coupling, duplicated logic, or difficulty understanding and maintaining it. Do not rewrite for taste alone.

### 3. Design the elegant solution

Think before coding. Emit the exact `SIMPLICITY CHECK` marker at design time:

```
SIMPLICITY CHECK: <one-line summary of the simplest elegant form that handles all discovered cases>
```

Then answer:

- What's the simplest approach that handles all the cases Chesterton's Fence surfaced?
- What abstraction, if any, makes this clearer? Default to none; abstractions are earned.
- How would you explain this solution to someone else?

If the design expands beyond the `SIMPLICITY CHECK`, write a second line naming the concrete requirement that forced the expansion. If there is no forcing requirement, stay at the simpler form.

### 4. Scrap and reimplement

1. **Create a recovery point** — Before reverting, preserve the mediocre fix so you can return to it if the rewrite turns out worse. Commit it on a throwaway branch (`git switch -c rewrite-baseline && git commit -am "baseline: pre-rewrite"`) or stash with a labeled message (`git stash push -u -m "pre-rewrite baseline"`). State the exact recovery command before continuing.
2. **Save the expected behavior** — Note the files touched and the behavior to verify against, including the edge cases surfaced by Chesterton's Fence. This is the spec the rewrite must satisfy.
3. **Revert the changes** — Return the working tree to the state before the mediocre fix.
4. **Implement the elegant solution** — Write it fresh, properly.
5. **Verify equivalence** — Delegate to `kramme:verify:run` for the project's verification battery. Every applicable configured build, typecheck, lint, and test gate must pass. If a test fails, the rewrite changed behavior — restore the recovery point or reclassify it as a behavior change. Apply the catch-all in Verification to every other failed or unavailable required gate.

"Existing tests" includes any tests written or modified during the current session. The rewrite must satisfy them unchanged. **Reject any rewrite that requires modifying tests to pass.**

If you notice adjacent work outside the saved rewrite scope, emit the exact `NOTICED BUT NOT TOUCHING` marker and leave it alone.

## Integration with other skills

- **Verification**: Step 4 delegates to `kramme:verify:run`.
- **Sibling — slice discipline**: `kramme:code:incremental` applies the same one-thing-at-a-time rule to feature work. Refactor passes obey the same six rules; this skill is the refactor-flavored loop.
- **Sibling — AI slop**: this is the general simplification pass for post-feature branch cleanup; for an AI-slop-specific pass via the `kramme:deslop-reviewer` agent, use `kramme:code:cleanup-ai`.
- **Alternative — scrap and rewrite**: if the recent code is inelegant enough that simplification would touch more than ~50% of it, stop the default loop and use this skill's `--rewrite` mode. A mediocre implementation is sometimes best scrapped rather than patched.
- **Broader scan**: if the simplification opportunities extend beyond the recent diff, stop and suggest `kramme:code:refactor-opportunities` for a codebase-wide scan.

## Common Rationalizations

These are the lies you will tell yourself to justify going past the scope of the pass. Each has a correct response:

In default mode:

- _"I'll simplify and fix the broken test together."_ → Run tests **before** simplifying. If tests already fail, that is a separate problem — fix it (or log it) first, then simplify from a green baseline.
- _"This abstraction is obviously useless, I don't need to read the blame."_ → Chesterton's Fence. Read the blame. One of these deletes will eventually remove load-bearing behavior.
- _"The diff is smaller if I inline this helper."_ → Line count is not the goal. Keep the helper if its name carries intent.
- _"I'll combine two simplifications into one commit for cleanliness."_ → No. Each simplification stands alone so the failure surface is obvious if verification breaks.
- _"The test is flaky; I'll just tweak it so it passes."_ → If a simplification requires modifying a test, it is a behavior change, not a simplification. Revert or re-scope.
- _"While I'm here, let me also rename this for consistency."_ → Emit `NOTICED BUT NOT TOUCHING`. Rename is its own slice — often its own PR.

In rewrite mode:

- _"The elegant version should be shorter."_ → Line count is not a goal. Clarity is. An elegant version can be longer if it reads top-to-bottom.
- _"I remember writing this; I don't need to re-read it."_ → You remember the happy path. Chesterton's Fence is for the parts you don't remember writing for a reason.
- _"The test is flaky; I'll just tweak it when the rewrite lands."_ → If the rewrite requires modifying a test, it changed behavior. Restore the baseline or reclassify.
- _"The rewrite surfaced a bug in the original — I'll fix it in the rewrite."_ → No. A bug fix is its own slice. Restore the baseline, land the bug fix separately, then attempt the rewrite from the fixed baseline.
- _"This abstraction is elegant in the abstract; the project just doesn't use it yet."_ → Not elegant — speculative. Wait for the third use case before introducing an abstraction the codebase does not yet need.
- _"I'll rewrite and rename at the same time for consistency."_ → Two changes. Rename is its own slice, often its own PR. Pick one.

## Red Flags

Ways a simplification pass turns into damage. In default mode, reject the slice and revert if any of these happen:

- **Inlining too aggressively.** Inlining a helper that is used once but has a meaningful name destroys a comment. Keep the name if it carries intent.
- **Removing "unnecessary" abstractions without applying the Fence.** An abstraction with only one caller today may be there for a planned second caller, or to isolate volatility.
- **Optimizing for line count.** Shorter is not the goal. A 10-line function that reads top-to-bottom beats a 4-line function that requires a dictionary. If the "simplified" version is longer than the original, discard it.
- **Removing defensive checks without proving they are unreachable.** A `try/catch` wrapping a library call may be absorbing a known failure mode; a `null` check that "can't happen" must be proven unreachable (via types, invariants, or caller analysis) before removal.
- **Renaming for personal taste.** Rename only to restore consistency with the surrounding codebase.

In rewrite mode, restore the recovery point if any of these are true:

- **Modifying tests for a rewrite.** Tests encode behavior. If the rewrite changes test expectations, it is a behavior change, not an elegant refactor. Restore the baseline or reclassify.
- **The rewrite is longer without a stated clarity gain.** Longer code is acceptable only when it reads more clearly top-to-bottom. If you cannot articulate that gain, the original was probably fine.
- **Rewriting for personal preference.** If the old shape matched the codebase and the new shape matches your taste, the old shape wins.
- **Removing defensive checks without proving they are unreachable.** If you cannot prove a check is dead through types, invariants, or caller analysis, keep it. The mediocre version may have encoded a lesson.

## Verification

The default-mode loop enforces most invariants per iteration; this is its residual check:

- The final diff is smaller and clearer than the input. If it is larger or less clear, revert.
- Every observation outside the original scope has a `NOTICED BUT NOT TOUCHING` marker; none were silently fixed.

For rewrite mode, do not declare the rewrite done until:

- [ ] All five Chesterton's Fence criteria were answered for every non-trivial piece of the original before scrapping.
- [ ] A `SIMPLICITY CHECK` marker was emitted at design time; any expansion beyond it has a documented forcing requirement.
- [ ] All existing tests pass **without any test modifications**.
- [ ] Build, typecheck, and lint all pass.
- [ ] The rewrite's behavior matches the saved-state notes, including edge cases.
- [ ] No bug found during the rewrite was silently folded in — any bug fix is a separate slice.
- [ ] The rewrite is shorter or equally clear. If it is longer and less clear, restore the baseline.

If any applicable verification box remains unchecked, finish the gap. If the gap cannot be closed within a behavior-preserving rewrite, or `kramme:verify:run` cannot execute a required gate, restore the recovery point and surface the failure. Do not leave a failed rewrite as the current result.
