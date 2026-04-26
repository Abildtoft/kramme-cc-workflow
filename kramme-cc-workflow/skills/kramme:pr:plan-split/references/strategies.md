# Splitting strategies

Four named strategies. **Prefer Vertical.**

| Strategy | When | Example |
|---|---|---|
| **Vertical** | One user-visible capability, end-to-end. The default choice. | A branch bundles "user import" and "CSV export." Split into one PR per feature, each touching DB → API → UI → tests. |
| **Stack** | Sequential changes that build on each other and need ordered review. Cap at **4–5 PRs deep**. | Schema migration → service layer wired to new schema → UI wired to new service. Each PR depends on the prior one merging first. |
| **By file group** | Clean directory or module seams where one group has no dependency on the other. | `src/auth/*` changes are independent of `src/billing/*` changes. Two parallel PRs, either order. |
| **Horizontal** | By layer (DB → API → UI). **Avoid unless vertical is impossible.** Each layer ships un-exercised until the next lands. | A standalone DB index that has no callers yet, or a config-only change that no service consumes. |

## Why Vertical wins

A vertical slice ships one user-visible capability end to end. It exercises every layer at once, so regressions surface during review, not three PRs later. A horizontal split (DB PR, then API PR, then UI PR) leaves each layer un-exercised until the next merge, which makes the early PRs a leap of faith and the later ones a forced "ship it, the earlier work is already in."

When in doubt, ask: *if only the first slice merged and the rest got abandoned, would users see any benefit?* Vertical: yes. Horizontal: no.

## How to phrase a recommendation

Name the strategy and the seam. Authors already know the diff is big — the value is naming the **specific cut**.

> **Vertical.** Two features bundled here: user import + CSV export. Each becomes an independently mergeable PR with its own tests. No shared code beyond a small parser utility, which travels with the import slice.

> **Stack.** The schema migration must merge before the service layer change can deploy without errors. Two PRs in order: PR 1 = migration + backfill; PR 2 = service + UI on the new columns.

> **By file group.** `packages/auth/*` and `packages/billing/*` changes share no imports. Ship as two parallel PRs; order doesn't matter.

> **Horizontal — last resort.** The only seam available is the DB index, which has no callers in this branch. Ship the index alone; the consuming code can land separately once it's written.

Avoid vague framings: *"this is too big," "consider splitting,"* or *"break this up somehow."* Those are the symptom, not the diagnosis.

## Concrete git recipes per strategy

These are the manual steps the author runs after the plan is approved. The skill never executes them.

**Vertical / By file group** — branch off the base, then pull only the slice's files from the working branch:

```bash
git switch <base-branch>           # e.g. main
git switch -c slice-1-<feature>
git checkout <big-branch> -- path/to/feature/   # pull whole subtree
git checkout <big-branch> -- src/lib/parser.ts  # or specific files
git status                                       # review what came across
git add <intentional files>
git commit -m "..."
```

When commits on the working branch are already well-organized, prefer cherry-pick:

```bash
git switch -c slice-1-<feature> <base-branch>
git cherry-pick <hash> <hash> <hash>
```

Use `git cherry-pick -n` to stage without committing if you need to drop or split hunks.

**Stack** — chain branches, each rooted on the previous; each becomes a PR targeting the previous PR's branch:

```bash
git switch -c stack-1-schema     <base-branch>
# ... bring in schema files, commit ...
git switch -c stack-2-service    stack-1-schema
# ... bring in service files, commit ...
git switch -c stack-3-ui         stack-2-service
# ... bring in UI files, commit ...
```

Open PRs in order: `stack-1-schema → base`, `stack-2-service → stack-1-schema`, etc. Re-target each downstream PR to `base` after its parent merges.

Tooling exists to automate the chain (Graphite, gh-stack, git-spice, Mergify Stacks). This skill doesn't pick one — the author keeps whatever workflow they already use.

**Horizontal** — same mechanics as By file group. Only choose this strategy when the layer slice is genuinely standalone (a DB index without callers, a config-only change with no consumers). Otherwise, the early slices ship un-exercised and the later slices land under "well, the rest is already in" pressure.

## When a stack would need 6+ slices

The 4–5 cap is a default, not a refusal. Some sequences (multi-step migrations, layered API rewrites, generated-code regenerations with manual touch-ups) genuinely have 6+ ordered steps. Work through these escape hatches in order before recommending a long chain:

1. **Combine adjacent slices.** Two of the proposed slices probably don't need independent review — they touch the same module, share the same test plan, and would land same-day. Fold them. A 7-step plan collapses to 5 surprisingly often.

2. **Carve off the tail.** Ship the foundation now as a 4–5 PR stack; open the remaining slices as a *future branch* rooted on whatever lands. This is two short stacks in sequence, not one long stack. The author stays unblocked, and the second stack gets fresh reviewer attention rather than fatigue.

3. **Promote parallel slices out of the chain.** If slices N+1 and N+2 don't actually depend on each other — they just both depend on slice N — they don't need to stack on each other. Once N merges, ship them as parallel "by file group" PRs. The stack is only as deep as its *true* dependency chain.

4. **Question the underlying scope.** A 6+ slice stack often signals the branch is doing too much. Is the migration covering two unrelated things at once? Could the second feature wait for its own branch? Reducing scope upstream is cheaper than managing a long stack downstream.

If steps 1–4 don't get you under 5, ship the long stack — but pay for it with explicit coordination. Include these in the recommendation:

- **Name the chain in every PR description.** "PR 4 of 7. Parents: #100, #101, #102. Children: #104, #105, #106." Reviewers shouldn't have to reconstruct the topology from branch names.
- **Pre-brief the reviewer.** Before opening the stack, share a short note: what the chain accomplishes, why it can't be shorter, the merge order, and the rebase plan. Reviewers who know the shape upfront tolerate length far better.
- **Lock in one reviewer for the whole chain.** A long stack reviewed by three different people becomes inconsistent fast — earlier-PR decisions get re-litigated in later PRs. Get one person to commit to the chain end-to-end.
- **Decide the rebase cadence in advance.** Either rebase the whole chain on every accepted change to an early PR, or batch rebases at agreed checkpoints. Either is fine; *not deciding* is what causes the chain to drift.
- **Set a merge cadence target.** "One PR landed per day" is concrete; "we'll merge as we go" stalls the tail. The longer the chain, the more important the cadence.

A 6+ stack with this coordination is reviewable. A 6+ stack without it is the anti-pattern.

## Anti-patterns

- **Splitting on file count instead of intent.** "5 files per PR" is not a strategy; it slices a single feature into unreviewable shards.
- **Splitting tests away from code.** Tests should ship with the code they exercise. A "tests-only" follow-up PR is a signal the original cut was wrong.
- **Splitting refactors away from the feature that motivated them.** If a refactor only makes sense in service of feature X, ship it with feature X. Standalone refactors that stand alone are a separate (legitimate) slice.
- **Long stacks without coordination.** The 4–5 PR ceiling is the default. If you need 6+, see *When a stack would need 6+ slices* above — the chain naming, reviewer lock-in, rebase plan, and merge cadence are what make it reviewable.
- **Reviewer carrying the split burden.** Splitting is the author's responsibility. A reviewer asking for a split is feedback; the author runs this skill, not the reviewer.
- **Inventing artificial seams.** If the work is genuinely one atomic change, recommend KEEP AS ONE rather than fabricating slices.
