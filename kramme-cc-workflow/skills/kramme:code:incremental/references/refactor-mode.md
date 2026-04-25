# Refactor Mode

When this skill is invoked for refactor work — `--refactor` flag, after `kramme:code:refactor-opportunities`, or any explicit "refactor X" ask — the increment loop runs the same six rules but produces a different output shape: an interview-driven Decision Document plus an ordered list of tiny commits, each leaving the codebase in a working state (Fowler).

Refactor work has three properties that change the output shape:
- The behavior is the same before and after; the changes are about structure.
- The justification ("why now, why this shape") matters more than the diff and decays out of memory faster than the code.
- The commits should be cherry-pickable and revertible individually — refactors are the most likely thing to bisect.

## Interview structure

Run these 7 short steps in order. Do not skip; refactors often unravel because step 1 was vague.

1. **Problem statement.** What is wrong with the current shape, in one or two sentences? Use vocabulary from `kramme:code:refactor-opportunities/references/architecture-language.md` when applicable (depth, seam, locality). If the problem statement contains "it would be cleaner" with no further evidence, stop — there is no refactor here yet.

2. **Verify in code.** Read the actual code being refactored, not the user's summary of it. Confirm the problem statement matches the source. Surface any mismatch before continuing.

3. **Alternatives considered.** List at least two other shapes the code could take. For each, one line on why it was rejected. Refactors picked without alternatives often reveal mid-refactor that a simpler shape was available.

4. **Scope hammer.** What is **out of scope** for this refactor? Name the adjacent files, modules, and symptoms that will not be touched. Out-of-scope items get logged as `NOTICED BUT NOT TOUCHING` during execution. The hammer protects the refactor from creeping into a rewrite.

5. **Test coverage check.** Identify the tests that exercise the behavior under refactor. If coverage is thin, decide explicitly: add characterization tests first, or accept the risk and proceed. "We'll be careful" is not a decision; pick one.

6. **Tiny-commits plan.** Sketch the commit sequence. Each commit:
   - Does one logical thing.
   - Compiles and passes existing tests at HEAD.
   - Is revertible without breaking `main`.
   - Has a message that does not contain "and".

   The plan is a numbered list (1, 2, 3…) — order matters because each commit assumes the previous ones landed. If you cannot find an order where every intermediate state is green, the refactor is not yet planned; back up to step 3.

7. **File the Decision Document.** Write the decisions out (template below) so the *why* survives long after the diff is reviewable. Location:
   - If `siw/` exists at the project root (SIW workflow active), write `siw/REFACTOR_DECISIONS.md` and append on subsequent refactors.
   - Otherwise, inline the document as a markdown block in the body of the **first commit** of the sequence. The first commit is special — it carries the rationale for the whole stack.

## Decision Document template

```markdown
# Refactor Decision Document — <one-line title>

## Problem Statement
<one or two sentences from interview step 1>

## Solution
<the chosen shape, in one paragraph>

## Commits
1. <commit message — does one thing, leaves codebase working>
2. <commit message — ditto>
3. <commit message — ditto>
…

## Decision Document
- **Modules built / modified:** <list>
- **Interfaces changed:** <list, with before → after signature>
- **Technical clarifications:** <any non-obvious choices a future maintainer would ask about>
- **Architectural decisions:** <decisions that bound future work, beyond the immediate refactor>
- **Schema changes:** <if any>
- **API contracts:** <if any caller-visible contract was touched — should be rare in a refactor; flag if more than incidental>

## Testing Decisions
<what tests were added, what was characterised first, what was deferred>

## Out of Scope
<list from interview step 4>

## Further Notes
<any context that does not fit above and is worth preserving — links, references, related ADRs>
```

For SIW projects, append a new section per refactor in `siw/REFACTOR_DECISIONS.md` with a date heading. Do not overwrite prior entries.

## Tiny-commits framing

Each commit in the plan is held to a stricter bar than feature work:

- **Standalone.** Builds, typechecks, and passes tests on its own. Anyone checking out `HEAD~N` for any N ≤ plan length sees a working tree.
- **Revertible.** `git revert <commit>` leaves `main` green. No "part 1 of 3" commits where part 1 alone is broken.
- **No conjunctions.** A commit message that wants to say "and" is two commits. Split.
- **One logical change per commit.** Sized to one decision, not one file. A move-and-rename across three files is one commit; a rename plus an unrelated typo fix is two.

The discipline is Fowler's: *"After each refactoring step, the code should still work."* Failure mode is ambitious commits that work in aggregate but each break in isolation — they pass review, then fail bisect six months later.

## Checkpoints during execution

After each commit, before moving on:

- [ ] `git revert HEAD` would leave the build green. (Spot-check by considering it; do not actually revert.)
- [ ] Commit message has no "and".
- [ ] Decision Document still matches the actual sequence — if a commit deviated from the plan, update the Decision Document or back out the deviation.
- [ ] Out-of-scope observations from this commit are logged as `NOTICED BUT NOT TOUCHING`, not folded in.

If any check fails, fix before the next commit. Refactor mode is intolerant of "I'll clean up later."
