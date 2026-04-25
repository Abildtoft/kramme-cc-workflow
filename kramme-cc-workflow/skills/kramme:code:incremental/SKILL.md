---
name: kramme:code:incremental
description: "(experimental) Deliver changes in thin vertical slices with scope discipline, incremental verification between slices, and feature-flag guardrails for incomplete work. Use when implementing any change that spans more than one file or commit. Enforces one-thing-at-a-time, rollback-friendly commits, and explicit separation of in-scope work from noticed-but-untouched observations. Includes a refactor mode (opt-in via --refactor or after kramme:code:refactor-opportunities) that adds an interview-driven Decision Document and a Fowler-style tiny-commits plan where every intermediate state leaves the codebase working."
argument-hint: "[--refactor]"
disable-model-invocation: false
user-invocable: true
---

# Incremental Implementation

Deliver changes in thin vertical slices with scope discipline, incremental verification between slices, and feature-flag guardrails for incomplete work. This is the procedural expression of the rule "don't add features beyond what the task requires": turn implementation into a loop of small, verified, rollback-friendly increments where out-of-scope observations are logged but never silently fixed.

## When to use

- Implementing any change that spans more than one file or more than one logical commit.
- After `kramme:siw:generate-phases` or any planning step — each phase executes as a sequence of increments through this loop.
- Any time scope creep is a realistic risk, especially when touching files adjacent to the target area.
- Refactors where you want each intermediate state to be independently reviewable and revertible.

## The Six Rules

### Rule 0 — Simplicity First

Before writing any code, emit a `SIMPLICITY CHECK` marker stating the simplest version of the change that could satisfy the requirement. Only expand beyond that simplest version if a concrete requirement forces it.

```
SIMPLICITY CHECK: <one-line summary of the minimum viable change>
```

If the simplest version is not what you end up building, write a second line explaining what forced the expansion. If there is no forcing requirement, do the simplest version.

### Rule 0.5 — Scope Discipline

When you notice something outside the scope of the current slice — a typo in an adjacent function, a missing null check three lines above, an import that could be cleaner — emit a `NOTICED BUT NOT TOUCHING` marker and move on. Do not silently fix, refactor, or modernize adjacent code, even if the fix is trivial.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

See `references/scope-discipline.md` for the full prohibition list and rationale. The load-bearing prohibitions:

- Clean up adjacent code you didn't need to touch.
- Refactor imports in untouched files.
- Remove comments you don't understand.
- Add un-specced features.
- Modernize syntax in files you only read.
- "Fix while I'm here".
- Build abstractions before the third use case demands it (rule of three).

### Rule 1 — One thing at a time

One logical change per slice. If a slice is doing two things, split it. A slice can touch multiple files as long as they serve the same single logical change.

Signs you are doing two things:
- The commit message wants to use "and".
- The diff has two independent review paths.
- Reverting one part without the other still leaves a coherent state.

### Rule 2 — Keep it compilable between slices

After every slice, the project builds, typechecks, and existing tests pass. Never commit a broken intermediate state — not even "temporarily." If a slice would break the build, it is too large; split it further, or gate the incomplete half behind a flag (Rule 3).

### Rule 3 — Feature flags for incomplete features (conditional)

If the project uses feature flags, guard incomplete or in-progress work behind a flag so it can ship dark. This lets you land partial work through the normal release process without exposing it to users.

If the project has no flag infrastructure, do not introduce flag machinery just for this skill. Instead, keep slices small enough that each slice is independently releasable on its own. Prefer "smaller slices" over "introduce flags."

### Rule 4 — Safe defaults

New flags, parameters, options, and config fields default to the old behavior. New code paths are opt-in, not opt-out. A user who upgrades and changes nothing should see no behavior change.

### Rule 5 — Rollback-friendly commits

Each commit stands alone and can be reverted without breaking the build or leaving the codebase in a broken state. No "part 1 of 3" commits where part 1 alone is broken.

Rule of thumb: if `git revert` on any single commit would break `main`, the commit is not rollback-friendly.

## The Increment Cycle

Each increment is one pass through this five-step loop:

1. **Slice** — pick one slicing strategy: vertical, contract-first, or risk-first. See `references/slice-strategies.md` for when to use each and concrete examples.
2. **Implement** — build the smallest version of the slice that is coherent and compilable. One logical change.
3. **Verify** — build, typecheck, lint, and run existing tests. Delegate to `kramme:verify:run` to execute the project's verification battery.
4. **Commit** — compose an atomic, descriptive commit message. Delegate to `kramme:git:commit-message`.
5. **Move forward** — carry state to the next slice. Do not restart the loop from scratch; the next slice builds on the committed state.

Emit a `SIMPLICITY CHECK` marker at the start of step 2, and a `NOTICED BUT NOT TOUCHING` marker any time during the loop when you see something out-of-scope.

## Increment checklist (exit criterion)

Before marking a slice done, confirm every box:

- [ ] Does one thing.
- [ ] Existing tests pass.
- [ ] Build succeeds.
- [ ] Typecheck passes.
- [ ] Lint passes.
- [ ] New functionality works.
- [ ] Committed with descriptive message.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.

## Refactor mode

When this skill runs against refactor work — explicit `--refactor` flag, invocation directly after `kramme:code:refactor-opportunities`, or any user ask phrased as "refactor X" — produce a different output shape on top of the same six rules: an interview-driven Decision Document plus an ordered tiny-commits plan.

**When this mode applies** — opt-in. Trigger on `--refactor`, on a refactor candidate handed off from `kramme:code:refactor-opportunities`, or on the user phrase "refactor X" / "consolidate Y" / "extract Z". Feature work does not need this mode.

**How it works** — the increment loop runs a 7-step interview before the first slice (problem statement → verify in code → alternatives considered → scope hammer → test coverage check → tiny-commits plan → file Decision Document), then executes the slices through the standard cycle. Each commit must leave the codebase in a working state — Fowler's bar — and revertible with `git revert` without breaking `main`. Decision Document goes to `siw/REFACTOR_DECISIONS.md` if SIW is active, otherwise inline as a markdown block in the body of the **first** commit (which carries rationale for the whole stack). The full interview, template, and per-commit checklist live in `references/refactor-mode.md`.

**Relationship to the six rules** — refactor mode does not relax any rule. Rule 0 (Simplicity), 0.5 (Scope Discipline), 1 (One thing), 2 (Compilable), 4 (Safe defaults), and 5 (Rollback-friendly) all apply per slice. Rule 3 (Feature flags) is usually inapplicable during a refactor since behavior is unchanged; if the refactor temporarily forks behavior, flag it as for any other in-progress feature.

**Sibling skills.** `kramme:code:refactor-pass` is the simplification-loop sibling — use it when the goal is to shrink or clarify recently changed code without restructuring. Use refactor mode here when the goal is structural change (depth, seams, locality) with a documented rationale that should outlive the diff.

## Integration with other skills

- **Upstream**: typically invoked after `kramme:siw:generate-phases` — each generated phase becomes a sequence of slices through this loop. Any planning skill that produces a phased plan can feed into this one.
- **Step 3 (Verify)**: delegates to `kramme:verify:run` for the project's verification battery.
- **Step 4 (Commit)**: delegates to `kramme:git:commit-message` for commit composition.
- **Sibling**: `kramme:code:refactor-pass` follows the same slice discipline — refactors are a different flavor of increment but obey the same six rules.

---

## Common Rationalizations

These are the lies you will tell yourself to justify scope creep. Each one has a correct response:

- *"It's just a one-line cleanup while I'm here."* → Emit `NOTICED BUT NOT TOUCHING`. Log it for a future slice.
- *"The abstraction is obvious, I'll build it now."* → Rule of three. Wait for the third use case.
- *"This test is flaky, let me rewrite it."* → Unrelated slice. File separately and continue with the current slice.
- *"I'll split the commit later."* → You won't. Split it now.
- *"The build is broken anyway, one more broken commit doesn't matter."* → It matters for bisect and revert. Fix the build before the next commit.
- *"This change is too small to need a flag."* → Then it's too small to be incomplete. Finish it or flag it.

## Red Flags

If you notice any of these, stop and re-slice:

- More than 100 lines of change without running tests.
- Multiple unrelated changes in a single increment.
- "Let me just quickly add this too."
- Touching files "while I'm here."
- Building an abstraction before the third use case.
- Commit message uses "and" to join two independent clauses.
- Reverting the last commit would not leave `main` in a green state.

## Verification

Before declaring the whole feature done, self-check:

- Does every commit build independently? (Spot-check with `git bisect` or by checking out a few commits.)
- Is there a `NOTICED BUT NOT TOUCHING` log for every out-of-scope observation?
- Does each commit message describe exactly one thing?
- If the feature shipped behind a flag, does the flag default to the old behavior?
- Would a reviewer who looks at commits one-by-one understand the progression without reading the whole diff?

If any answer is no, finish the gap before declaring done.
