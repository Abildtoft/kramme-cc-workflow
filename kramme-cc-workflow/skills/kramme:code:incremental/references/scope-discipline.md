# Scope Discipline

The load-bearing discipline behind Rule 0.5. When you are implementing a change, anything outside the current slice is out of scope — even if the fix would take one line.

## The "Do NOT" list

During an increment, do NOT:

- Clean up adjacent code you didn't need to touch.
- Refactor imports in untouched files.
- Remove comments you don't understand.
- Add un-specced features.
- Modernize syntax in files you only read.
- "Fix while I'm here."
- Build abstractions before the third use case demands it (rule of three).

Every item on this list is a failure mode observed repeatedly in AI-assisted coding. Each one seems harmless on its own; together they turn a scoped change into a sprawling diff that no one can review, bisect, or revert cleanly.

## The `NOTICED BUT NOT TOUCHING` marker

When you see something that belongs on the list above, don't fix it and don't ignore it. Log it:

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

Examples:

```
NOTICED BUT NOT TOUCHING: UserProfile has a typo in the "recieved" field name.
Why skipping: out-of-scope — current slice is the auth middleware, not the profile schema.
```

```
NOTICED BUT NOT TOUCHING: api/orders.ts still uses the old logger pattern.
Why skipping: deferred — bulk migration is tracked separately.
```

```
NOTICED BUT NOT TOUCHING: The retry helper here could be generalized and reused elsewhere.
Why skipping: rule of three — only two call sites exist; wait for the third.
```

The marker is both a promise (to come back later, as a separate slice) and a reviewer aid (so reviewers can see what you consciously skipped versus what you missed).

## Why this matters

**Regression blast radius.** An unscoped edit in an adjacent file is still a change to production code. If it breaks something, bisect points at the commit that was supposed to be about auth, not about formatting. Keeping slices scoped keeps bisect useful.

**Commit legibility.** A commit that does one thing has a commit message that describes one thing. A reviewer can read the message, predict the diff, and verify. A commit that does "the real change, plus some cleanup, plus a rename" cannot be described in one sentence and is harder to review, revert, or cherry-pick.

**Reviewer cognitive load.** Reviewers have finite attention. If 30% of a PR is unrelated cleanup, the real change gets 70% of the attention it deserves. Scope discipline is a respect-the-reviewer policy.

**Rule of three.** The first time you write a pattern, write it inline. The second time, notice the duplication but leave it. The third time, extract. This is not pedantry — premature abstractions are the expensive kind, because you generalize against the wrong axis before the third data point reveals what the real axis is.
