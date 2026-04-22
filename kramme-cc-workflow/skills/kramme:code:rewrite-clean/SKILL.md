---
name: kramme:code:rewrite-clean
description: "Scrap a working-but-mediocre fix and reimplement elegantly. Use after making a fix that works but feels hacky. Applies Chesterton's Fence before scrapping, emits SIMPLICITY CHECK at design time, and rejects rewrites that require modifying tests to pass."
disable-model-invocation: true
user-invocable: true
---

# Elegant Refactor

Knowing everything you know now, scrap this and implement the elegant solution.

## Step 0: Validate Context

Before proceeding, review the current conversation to confirm:

1. **Implementation work exists** — We've written or modified code in this session.
2. **The work is complete enough** — The fix/feature works (even if inelegantly).
3. **There's something to improve** — The implementation has identifiable inelegance.

**If any of these are missing, STOP and explain:**

- No implementation work? → "There's no implementation in this conversation to refactor. This command is for redoing existing work more elegantly."
- Work isn't complete? → "Let's finish the current implementation first, then we can evaluate whether it needs an elegant refactor."
- Nothing obviously inelegant? → "The current implementation looks reasonable. What specifically feels hacky or inelegant to you?"

Only proceed if all three conditions are met.

## Prerequisites — When NOT to rewrite

Even when Step 0 passes, do not proceed if any of these apply:

- **The solution is fine, just unfamiliar.** Unfamiliarity is not inelegance. Read the code a second time before deciding to scrap it.
- **You don't understand the problem yet.** Rewriting code you don't fully understand deletes subtle behavior. If you cannot explain what edge cases the mediocre version handles, stop.
- **Time pressure makes "good enough" acceptable.** A working fix before a deadline is not a candidate for a scrap-and-rewrite. Ship it; log a follow-up if the inelegance matters.
- **The inelegance is inherent to the problem domain.** Some problems are ugly. If the ugliness tracks the domain rather than the implementation, a rewrite will reproduce it in a different shape.
- **It's performance-critical and the current shape is measured-fast.** "Elegant" does not override measured performance. Check benchmarks before rewriting hot paths.

## The Core Insight

First implementations often solve the problem but in a hacky way. Having solved the problem once, you now understand it deeply enough to implement it properly from scratch.

**Do not preserve the mediocre code.** The whole point is to start fresh.

## Process

### 1. Extract What You Learned

Before touching any code, apply **Chesterton's Fence** to the mediocre version. You wrote it; that does not mean you remember every decision inside it. Verify you understand why each non-trivial piece exists:

1. **Responsibility** — What does each part do, including side effects?
2. **Callers** — Who depends on the current shape? (Other modules? Tests? External consumers?)
3. **Edge cases** — What hidden inputs does it handle that the happy path obscures?
4. **Tests** — What behaviors do the tests lock in? Read them.
5. **Git blame / session history** — Why did each piece get added? Was any part added in response to a bug you hit during this session?

If you cannot answer all five for a given piece, you haven't earned the right to scrap it. Read more first.

Then articulate:

- What was the actual problem? (Not what you thought it was initially.)
- What constraints did you discover?
- What edge cases matter?
- What dependencies or interactions exist?

### 2. Identify the Inelegance

Be specific about what's wrong with the current solution:

- Unnecessary complexity?
- Wrong abstraction level?
- Coupling that shouldn't exist?
- Duplicated logic?
- Hard to understand or maintain?

### 3. Design the Elegant Solution

Think before coding. Emit a `SIMPLICITY CHECK` marker stating the minimum shape of the elegant solution:

```
SIMPLICITY CHECK: <one-line summary of the simplest elegant form that handles all discovered cases>
```

Then answer:

- What's the simplest approach that handles all the cases Chesterton's Fence surfaced?
- What abstraction, if any, makes this clearer? (Default: none. Abstractions are earned.)
- How would you explain this solution to someone else?

If the design expands beyond the `SIMPLICITY CHECK`, write a second line explaining what forced the expansion. If there is no forcing requirement, stay at the simpler form.

### 4. Scrap and Reimplement

1. **Save the current state** — Note the files and behavior to verify against. Record the expected behavior (including edge cases from Chesterton's Fence) so you can check the rewrite against it.
2. **Revert the changes** — Go back to before the mediocre fix.
3. **Implement the elegant solution** — Write it fresh, properly.
4. **Verify equivalence** — Delegate to `kramme:verify:run` for the project's verification battery. All existing tests must pass **without modification**. If a test fails, the rewrite changed behavior — revert or reclassify as a behavior change.

## When to Use This

- After a fix that works but makes you wince.
- When you realize mid-implementation there's a better way.
- When the solution has grown tentacles.
- When explaining the code would be embarrassing.

## When NOT to Use This

Covered in "Prerequisites — When NOT to rewrite" above.

---

## Common Rationalizations

These are the lies you will tell yourself to justify scrapping code that should stand. Each has a correct response:

- *"The elegant version should be shorter."* → Line count is not a goal. Clarity is. An elegant version can be longer if it reads top-to-bottom.
- *"I remember writing this; I don't need to re-read it."* → You remember the happy path. Chesterton's Fence is for the parts you don't remember writing for a reason.
- *"The test is flaky; I'll just tweak it when the rewrite lands."* → If the rewrite requires modifying a test, it changed behavior. Revert or reclassify.
- *"The rewrite surfaced a bug in the original — I'll fix it in the rewrite."* → No. A bug fix is its own slice. Revert, land the bug fix separately, then attempt the rewrite from the fixed baseline.
- *"This abstraction is elegant in the abstract; the project just doesn't use it yet."* → Not elegant — speculative. Wait for the third use case before introducing an abstraction the codebase does not yet need.
- *"I'll rewrite and rename at the same time for consistency."* → Two changes. Rename is its own slice, often its own PR. Pick one.

## Red Flags

Rejection criteria. If any of these are true, revert the rewrite:

- **The rewrite requires modifying tests to pass.** Tests encode behavior. If the rewrite changes test expectations, it is a behavior change, not an elegant refactor. Revert or reclassify.
- **The rewrite is longer than the original.** If "elegant" turned out longer, the original was probably fine. Discard the rewrite.
- **Rewriting for personal preference, not codebase consistency.** If the old shape matched the codebase and the new shape matches your taste, the old shape wins.
- **Removing defensive checks without proving they're unreachable.** If you cannot prove a check is dead (via types, invariants, or caller analysis), keep it. The mediocre version may have encoded a lesson.

## Verification

Before declaring the rewrite done, self-check:

- [ ] All five Chesterton's Fence criteria were answered for every non-trivial piece of the original before scrapping.
- [ ] A `SIMPLICITY CHECK` marker was emitted at design time; any expansion beyond it has a documented forcing requirement.
- [ ] All existing tests pass **without any test modifications**.
- [ ] Build, typecheck, and lint all pass.
- [ ] The rewrite's behavior matches the saved-state notes, including edge cases.
- [ ] No bug found during the rewrite was silently folded in — any bug fix is a separate slice.
- [ ] The rewrite is shorter or equally clear. If it is longer and less clear, revert.

If any box is unchecked, finish the gap or revert before declaring done.
