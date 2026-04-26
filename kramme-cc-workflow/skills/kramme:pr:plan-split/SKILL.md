---
name: kramme:pr:plan-split
description: Analyze the current branch's diff and recommend how to break it into smaller, independently mergeable PRs. Categorizes changes by feature, layer, and module; detects coupling; and proposes a concrete seam (vertical, stack, by file group, or horizontal — preferring vertical) for each suggested slice with file lists, line counts, dependency order, test plan, and rationale. Use before opening a PR that bundles unrelated work, when a reviewer asks for a split, or when a branch has grown to the point where reviewers stop reading. Reports inline; does not edit code or rewrite git history.
argument-hint: "[--base <branch>]"
disable-model-invocation: true
user-invocable: true
---

# PR Split Planner

Recommend how to break the current branch's changes into smaller, independently mergeable PRs.

This skill is a **planning aid**. It reads the diff, names seams, and prints a recommendation. It never edits code, creates branches, or rewrites history — those are manual follow-ups.

## Workflow

### 1. Resolve Base Branch

3-tier resolution.

**Tier 1: Explicit override**
If `--base <branch>` was provided, use it directly.

**Tier 2: PR/MR target detection**
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if printf '%s' "$REMOTE_URL" | grep -q 'github.com' && command -v gh >/dev/null 2>&1; then
  BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
elif command -v glab >/dev/null 2>&1; then
  BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
fi
```

**Tier 3: Fallback**
```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
```

Normalize, validate, and fetch:
```bash
BASE_BRANCH=${BASE_BRANCH#refs/heads/}
BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
BASE_BRANCH=${BASE_BRANCH#origin/}

if [ -z "$BASE_BRANCH" ]; then
  echo "Error: Could not determine base branch. Re-run with --base <branch>." >&2
  exit 1
fi
git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null || true
git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null || {
  echo "Error: origin/$BASE_BRANCH not found. Re-run with --base <branch>." >&2
  exit 1
}
```

### 2. Build the Change Set

Combine committed, staged, unstaged, and untracked changes:
```bash
BASE_REF=$(git merge-base origin/$BASE_BRANCH HEAD)
{
  git diff --name-only "$BASE_REF"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u
```

For each file, capture:
- Insertions / deletions (`git diff --numstat "$BASE_REF"...HEAD` plus `git diff --numstat HEAD` for local).
- Whether it's new, modified, deleted, or renamed.
- File category — source, test, config, lock file, snapshot, generated.

### 3. Read the Diff

Read the actual diff content for source and test files:
```bash
git diff "$BASE_REF"...HEAD
git diff --cached
git diff
```

Skip lock files, snapshots, and generated files when interpreting intent — they travel with their owning slice rather than defining one.

### 4. Categorize Changes

Build a table mapping each file to:

| Dimension | Examples |
|---|---|
| **Intent** | Feature A / Feature B / refactor-for-feature-A / standalone refactor / bug fix / dependency bump / cleanup |
| **Layer** | UI / API / business logic / DB schema / config / infra / tests / docs |
| **Module** | Directory or package boundary (`src/auth`, `packages/billing`) |
| **Change type** | New, modified, deleted, renamed |

Assigning each file to one **intent** is the load-bearing step — it's how you find the seams. If a file legitimately serves two intents (e.g., a shared utility extended for two features), note that and treat it as carried with the earlier slice.

**Refactor classification matters.** A refactor that exists *to enable* feature X belongs with feature X — splitting it off forces reviewers to evaluate motion without context. A refactor that stands alone (renaming, dead-code removal, internal cleanup independent of any new behavior) belongs in its own slice and should ship before the feature work that follows.

### 5. Detect Coupling

For each candidate seam, ask:

- Can the slice ship alone without breaking the build, type checks, or existing tests?
- Does any other slice import or call into this one?
- Does the slice exercise its layer end-to-end, or stop mid-stack (an API route with no caller, a UI component with no backend)?
- Are there shared types, schema migrations, or config flags that force ordering?

Flag tight coupling explicitly when proposing slices: *"Slice B depends on Slice A because B imports the new `UserSession` type defined in A."*

### 6. Choose Seams

Read `references/strategies.md` for the four named strategies and selection guidance. **Prefer Vertical.**

For each proposed slice, produce:
- A short name describing the user-visible capability (vertical) or boundary (other strategies).
- The file list, with per-file line counts.
- Total line count for the slice.
- An estimated review time (see sizing heuristic below).
- Dependencies — which slices, if any, must merge first.
- A one-line test plan: what tests verify the slice in isolation.
- A one-sentence rationale: why this seam, not an arbitrary cut.

The rationale is the load-bearing field. *"Smaller"* is not a reason; *"these two features share no code and ship value independently"* is.

**Per-slice sizing heuristic.** A reviewable PR usually lands in the **~50–200 source-line range** and takes **~10–15 minutes** to read carefully. If a candidate slice meaningfully exceeds that — say, >300 source lines or >20 minutes of estimated review — propose a sub-split inside that slice. Treat estimated review time as the practical test, not raw line count: 400 mechanical-rename lines may read in 5 minutes; 80 lines of intricate state-machine logic may read in 25.

There is no hard upper-bound rule that classifies a PR as "too large" purely by line count. The heuristic is a *target for each slice*, not a gate against the whole branch.

**Stack depth.** When a vertical or stacked plan naturally runs to **6 or more ordered slices**, work through the escape hatches in `references/strategies.md` § *When a stack would need 6+ slices* before recommending a long chain — combine adjacent slices, carve off the tail as a future branch, promote parallel slices, or reduce scope. If the long stack is genuinely the right answer, fold the coordination guidance from that section (chain naming in PR bodies, single reviewer, rebase cadence, merge cadence) into the recommendation so the user gets a *workable* long stack, not a cap-and-refuse.

### 7. Decide Whether to Split

Recommend **SPLIT** when at least one of these is true:

- Two or more clearly unrelated intents are bundled (Feature A + Feature B; feature + standalone refactor; bug fix + dependency bump).
- The total estimated review time would exceed roughly **30 minutes**, and the diff has at least one clean seam.
- A refactor was bundled with a feature it doesn't strictly enable — separate the refactor so reviewers can evaluate it on its own merits.
- Reviewers from different domains would each need to read only their slice (UI reviewer + backend reviewer).

Recommend **KEEP AS ONE** when:

- The change is one tight feature that loses meaning when sliced (a single public-API surface that has to land atomically; an atomic schema migration with its single dependent service).
- The candidate slices would each be <50 lines of source — the review overhead exceeds the value.
- The bulk is generated code, lock files, or snapshots from one logical seed change.
- All slices would have the same reviewer and same test plan — splitting just doubles the ceremony.

Either way, say so explicitly and explain why. The user asked for a split plan; refusing to invent one is a valid answer when the diff is genuinely atomic.

### 8. Print the Recommendation

Reply inline using the template in `references/output-template.md` verbatim. Do not write a file unless the user explicitly asks — this skill is exploratory.

## Usage

```
/kramme:pr:plan-split
# Plan splits against the auto-detected base.

/kramme:pr:plan-split --base develop
# Plan splits against an explicit base.
```

## Notes

- This skill never edits code or rewrites git history. The user runs `git switch -c`, `git cherry-pick`, branch resets, etc. themselves.
- Use after a code review surfaces *"this is doing too much"*, when a reviewer asks for a split, or before opening a PR you suspect bundles unrelated work.
- **Author-driven, not reviewer-driven.** Splitting is the author's responsibility — reviewers shouldn't carry it. Self-review the diff first (a quick read-through, or run `kramme:pr:code-review`) so the seams reflect what the code actually does, not just what the file tree looks like.
- Pair with `kramme:pr:code-review` for correctness; this skill only addresses scope and seams.
- The recommendation is advice, not a verdict. If the user disagrees with a proposed seam, that's a useful signal — ask what they'd cut differently before re-planning.
