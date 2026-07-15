---
name: kramme:pr:plan-split
description: Analyze the current branch's diff and break it into smaller, independently mergeable PRs. Categorizes changes by feature, layer, and module; detects coupling; and proposes a concrete seam (vertical, stack, by file group, or horizontal — preferring vertical) for each slice with file lists, line counts, dependency order, test plan, and rationale. Hands the slices to kramme:code:breakdown-findings to write the `PR_PLAN_*.md` artifacts, supplying a worktree-based implementation setup that extracts each slice's changes from the branch the skill is run in. Use before opening a PR that bundles unrelated work, when a reviewer asks for a split, or when a branch has grown too large to review. Plans only; does not edit source code, create branches, or rewrite git history.
argument-hint: "[--base <branch>] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# PR Split Planner

Break the current branch's changes into smaller, independently mergeable PRs.

This skill is a **planning aid**. It reads the diff, names seams, and proposes one slice per mergeable PR. It does not write the plan files itself: once the slices are confirmed, it **delegates to `kramme:code:breakdown-findings`** — the canonical PR-plan generator — handing over the slices as pre-clustered themes plus a worktree-based implementation setup. That skill writes the `PR_PLAN_*.md` artifacts. This skill never edits source code, creates git branches, or rewrites history. Each plan is implemented later, by hand, in its own git worktree.

## Workflow

Before Step 1, parse `$ARGUMENTS` as shell-style arguments. If `--auto` is present, set `AUTO_MODE=true` and remove it before base-branch parsing. If `--base <branch>` is present, set `BASE_BRANCH_OVERRIDE=<branch>` and remove the flag and value. `--auto` skips the slice-confirmation prompt when the skill recommends `SPLIT`; it does not bypass base-branch validation, empty-diff stops, or the `KEEP AS ONE` outcome.

### 1. Resolve Base Branch

Use the shared plugin script. It uses the same 3-tier strategy: explicit `--base`, PR target branch (via `gh`), then `origin/HEAD`/`origin/main`/`origin/master`. Invoke it with `--tolerate-fetch-failure` so a failed fetch falls back to the cached local `origin/<base>` ref with a warning instead of stopping (the script still errors when no cached ref exists):

```bash
RESOLVE_ARGS=(--tolerate-fetch-failure)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
  echo "Error: Could not resolve base branch; see the message above. Re-run with --base <branch>." >&2
  exit 1
}
eval "$RESOLVED"
```

The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE`. If the script printed its stale-ref warning (`Warning: failed to fetch ...; using existing ...`), set `BASE_STALE=1` so later steps can flag that the diff was computed against a possibly stale base.

Then capture the **reference branch** — the branch this skill is run in, which holds the changes being split. Every generated plan extracts its files from this branch.

```bash
REFERENCE_BRANCH=$(git symbolic-ref --quiet --short HEAD 2> /dev/null)
if [ -z "$REFERENCE_BRANCH" ]; then
  echo "Error: HEAD is detached — there is no branch to use as the reference branch for extracting changes. Check out the branch that holds the work and re-run." >&2
  exit 1
fi
```

`REFERENCE_BRANCH` is distinct from `BASE_BRANCH`. `BASE_BRANCH` (e.g. `main`) is what the diff is measured against and what each slice branches off of and merges back into. `REFERENCE_BRANCH` is the current feature branch that actually contains the work. Each plan branches off `BASE_BRANCH` in a fresh worktree and pulls its slice's files from `REFERENCE_BRANCH`. Use both resolved names (never the literal placeholders) when filling the Implementation Setup block handed to `breakdown-findings` in step 8.

### 2. Build the Change Set

Combine committed, staged, unstaged, and untracked changes, using the `MERGE_BASE` exported by the resolve script in step 1:

```bash
{
  git diff --name-only "$MERGE_BASE"...HEAD
  git diff --name-only --cached
  git diff --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u
```

If the deduplicated change set is empty, stop and reply with a single line — `No changes between HEAD and origin/$BASE_BRANCH. Nothing to split.` — and skip the rest of the workflow. If the base ref was used in stale mode (see step 1), say so in the same line.

For each file, capture:

- Insertions / deletions (`git diff --numstat "$MERGE_BASE"...HEAD` plus `git diff --numstat HEAD` for local).
- Whether it's new, modified, deleted, or renamed.
- File category — source, test, config, lock file, snapshot, generated.

Use one combined numstat pass so untracked files are included in per-file slice counts and branch totals. Group rows by path before treating them as per-file records because the same file can appear in both the committed diff and local WIP.

```bash
{
  git diff --numstat "$MERGE_BASE"...HEAD
  git diff --numstat HEAD
  git ls-files --others --exclude-standard -z \
    | while IFS= read -r -d '' file; do
      awk 'END { printf "%d\t0\t%s\n", NR, FILENAME }' "$file"
    done
} | awk '
  BEGIN { FS = OFS = "\t" }
  NF >= 3 {
    ins = ($1 == "-" ? 0 : $1)
    del = ($2 == "-" ? 0 : $2)
    add[$3] += ins
    remove[$3] += del
  }
  END {
    for (file in add) {
      print add[file], remove[file], file
    }
  }
'
```

Untracked files are counted by `NR` (line count) over the file contents, which approximates insertions for text but is meaningless for binaries (images, archives, fixtures). Treat per-file counts for untracked binary assets as approximate, and flag any obvious binary in the report rather than letting its line count drive slice sizing.

To compute branch totals from the grouped rows, sum the first two columns:

```bash
awk 'NF >= 3 { ins += ($1 == "-" ? 0 : $1); del += ($2 == "-" ? 0 : $2) } END { print ins, del, ins + del }'
```

### 3. Read the Diff

Read the actual diff content for source and test files:

```bash
git diff "$MERGE_BASE"...HEAD
git diff --cached
git diff
```

For untracked source and test files from the change set, read their contents directly because regular `git diff` output has no blob to compare:

```bash
git ls-files --others --exclude-standard
sed -n '1,240p' path/to/untracked-source-file
```

Skip lock files, snapshots, and generated files when interpreting intent — they travel with their owning slice rather than defining one.

**Large-diff guardrail.** If the branch total from step 2 exceeds **~2000 source lines** (excluding lock files, snapshots, and generated files), do not read the diff as one blob. Instead, group files by module/directory from step 4's categorization and read each group's diff separately (e.g., `git diff "$MERGE_BASE"...HEAD -- src/auth/`), prioritizing source over tests and skipping snapshots. State in the final report that the diff was read in groups and which groups, if any, were sampled rather than read in full — reviewers need to know which slices were assessed from full content vs. summary.

### 4. Categorize Changes

Build a table mapping each file to:

| Dimension | Examples |
| --- | --- |
| **Intent** | Feature A / Feature B / refactor-for-feature-A / standalone refactor / bug fix / dependency bump / cleanup |
| **Layer** | UI / API / business logic / DB schema / config / infra / tests / docs |
| **Module** | Directory or package boundary (`src/auth`, `packages/billing`) |
| **Change type** | New, modified, deleted, renamed |

Assigning each file to one **intent** is the load-bearing step — it's how you find the seams. If a file legitimately serves two intents (e.g., a shared utility extended for two features), note that and treat it as carried with the earlier slice.

**Refactor classification matters.** A refactor that exists _to enable_ feature X belongs with feature X — splitting it off forces reviewers to evaluate motion without context. A refactor that stands alone (renaming, dead-code removal, internal cleanup independent of any new behavior) belongs in its own slice and should ship before the feature work that follows.

### 5. Detect Coupling

For each candidate seam, ask:

- Can the slice ship alone without breaking the build, type checks, or existing tests?
- Does any other slice import or call into this one?
- Does the slice exercise its layer end-to-end, or stop mid-stack (an API route with no caller, a UI component with no backend)?
- Are there shared types, schema migrations, or config flags that force ordering?

Flag tight coupling explicitly when proposing slices: _"Slice B depends on Slice A because B imports the new `UserSession` type defined in A."_

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

The rationale is the load-bearing field. _"Smaller"_ is not a reason; _"these two features share no code and ship value independently"_ is.

**Per-slice sizing heuristic.** A reviewable PR usually lands in the **~50–200 source-line range** and takes **~10–15 minutes** to read carefully. If a candidate slice meaningfully exceeds that — say, >300 source lines or >20 minutes of estimated review — propose a sub-split inside that slice. Treat estimated review time as the practical test, not raw line count: 400 mechanical-rename lines may read in 5 minutes; 80 lines of intricate state-machine logic may read in 25.

There is no hard upper-bound rule that classifies a PR as "too large" purely by line count. The heuristic is a _target for each slice_, not a gate against the whole branch.

**Stack depth.** When a vertical or stacked plan naturally runs to **6 or more ordered slices**, work through the escape hatches in `references/strategies.md` § _When a stack would need 6+ slices_ before recommending a long chain — combine adjacent slices, carve off the tail as a future branch, promote parallel slices, or reduce scope. If the long stack is genuinely the right answer, fold the coordination guidance from that section (chain naming in PR bodies, single reviewer, rebase cadence, merge cadence) into the recommendation so the user gets a _workable_ long stack, not a cap-and-refuse.

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

### 8. Delegate Artifact Generation to breakdown-findings

This skill does not write the `PR_PLAN_*.md` files itself. It assembles the confirmed slices into a pre-clustered handoff and delegates to `kramme:code:breakdown-findings`, which is the single canonical PR-plan generator (one naming scheme, one index, one cleanup path).

If the recommendation is **KEEP AS ONE**, do not delegate. Report inline why the diff is atomic and stop — there is nothing to split.

If the recommendation is **SPLIT**:

1. **Confirm the slices.** Print the proposed slices (name, strategy, files, dependency order). If `AUTO_MODE=true`, add `AUTO: proceeding to generate plans for these N slices` and continue without asking. Otherwise ask: `Proceed to generate plans for these N slices? (yes / adjust)`. Do not delegate until the user confirms. If they adjust, re-plan.

2. **Assemble one handoff document.** Build a single markdown document — the complete input handed to `breakdown-findings`. It contains, in order:
   - The marker line `PRE-CLUSTERED HANDOFF — themes are fixed; do not re-cluster.` so the delegate detects the mode without guessing.
   - One **theme per slice** (do not merge or re-split — these slices are the seams). For each: the slice name, strategy, the file list with per-file line counts, the dependency relationship (`depends on` / `blocks` / `parallel with`), the one-line test plan, and the one-sentence rationale.
   - A single shared `## Implementation Setup` block (template below), with `{{REFERENCE_BRANCH}}` and `{{BASE_BRANCH}}` already replaced by the resolved names. The block lives **inside** this document — it is not a separate input.

3. **Delegate.** Invoke `/kramme:code:breakdown-findings` with this document as its source (inline findings text), adding `--auto` when `AUTO_MODE=true`. The delegate detects the pre-clustered marker, maps each theme 1:1 to a plan without re-clustering, embeds the Implementation Setup block in every plan, and owns the prior-artifact check, execution-label naming, the per-plan files, the index, and the end-of-turn summary.

   If `/kramme:code:breakdown-findings` is unavailable in this environment, do not silently stop: print the handoff document (themes + Implementation Setup block) inline so the user can generate the plans by hand.

**Implementation Setup block — hand this to `breakdown-findings` verbatim, with `{{REFERENCE_BRANCH}}` and `{{BASE_BRANCH}}` replaced by the resolved branch names (never the placeholder text). It must specify all four points; do not drop any:**

````markdown
## Implementation Setup

Implement this plan in its **own dedicated git worktree**, separate from every other plan in this split.

- **Reference branch (source of the changes):** `{{REFERENCE_BRANCH}}` — the branch this split was planned from. It holds the full set of work being split. Extract **only this slice's files** from it; do not pull changes from any other branch.
- **One worktree per plan:** each plan is built in its own worktree so slices develop and review independently and in parallel.
- **Implementation branch:** use whatever branch is checked out in that worktree. Any name works **except `{{REFERENCE_BRANCH}}`** — never implement onto the reference branch itself.
- **Example setup** (branch name and worktree path are **examples, not requirements** — pick your own):

  ```bash
  # `-b` branch name and the worktree path are EXAMPLES. Substitute any you like;
  # the only rule is the branch must NOT be `{{REFERENCE_BRANCH}}`.
  git worktree add ../<slice-slug> -b <your-branch-name> origin/{{BASE_BRANCH}}
  cd ../<slice-slug>
  git checkout {{REFERENCE_BRANCH}} -- <this slice's files>   # pull only this slice
  git status   # review what came across, then commit
  ```
````

## Usage

```
/kramme:pr:plan-split
# Plan splits against the auto-detected base.

/kramme:pr:plan-split --base develop
# Plan splits against an explicit base.
```

## Notes

- Use after a code review surfaces _"this is doing too much"_, when a reviewer asks for a split, or before opening a PR you suspect bundles unrelated work.
- **Author-driven, not reviewer-driven.** Splitting is the author's responsibility — reviewers shouldn't carry it. Self-review the diff first (a quick read-through, or run `kramme:pr:code-review`) so the seams reflect what the code actually does, not just what the file tree looks like.
- Pair with `kramme:pr:code-review` for correctness; this skill only addresses scope and seams.
- The recommendation is advice, not a verdict. If the user disagrees with a proposed seam, that's a useful signal — ask what they'd cut differently before re-planning.
- Artifact generation is delegated to `kramme:code:breakdown-findings`. That skill writes the `PR_PLAN_*.md` files (working artifacts, clearable with `/kramme:workflow-artifacts:cleanup`) and owns the prior-artifact check, so this skill does not write or guard those files itself.
