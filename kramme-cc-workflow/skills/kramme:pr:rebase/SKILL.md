---
name: kramme:pr:rebase
description: Rebase current branch onto latest main/master, then force push. Use when your PR is behind the base branch.
argument-hint: "[--auto] [--base=<branch>]"
disable-model-invocation: true
user-invocable: true
---

# Rebase PR

Rebase the current branch onto the latest base branch and force push.

## Why rebase — dev branches are costs

A feature branch is a cost that compounds every day it stays open. It drifts from the base branch, it accumulates irrelevant diff when other PRs land, and it forces every reviewer to re-learn a stale context. Rebasing is how you pay down that cost: the branch stays in sync with `main`, the diff stays scoped to the change, and the reviewer's mental model of the base is still valid when they open the PR. Merge commits defer the cost — they hide drift behind a merge marker instead of resolving it — which is why this skill rebases and force-pushes rather than merging `main` in. If the rebase fights you, that is evidence the branch is already too old: finish it or split it, don't patch it with more merges.

## Options

**Flags:**
- `--auto` - Skip the final force-push confirmation and push immediately with `--force-with-lease` after a successful rebase.
- `--base=<branch>` - Override auto-detected base branch (e.g., `--base=develop`)

`--auto` only bypasses the final confirmation prompt. It does not bypass conflict handling, red-flag stops, or the requirement to use `--force-with-lease`.

## Output markers

Use these uppercase markers when reasoning about the rebase and reporting progress. One marker per line, no decoration:

- **STACK DETECTED** — base branch, conflict method, and autostash state at the start. `STACK DETECTED: origin/main, --autostash enabled, 3 uncommitted changes stashed`.
- **UNVERIFIED** — claims about resolved conflicts that haven't been runtime-checked. `UNVERIFIED: conflict auto-resolved in handler.ts but I didn't run the tests after`.
- **NOTICED BUT NOT TOUCHING** — issues visible during rebase that are outside scope. `NOTICED BUT NOT TOUCHING: origin/main has an unrelated lint failure — not this rebase's problem`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-run summary when the rebase completes.
- **CONFUSION** — ambiguous conflict evidence. `CONFUSION: both sides of the conflict add the same function but with different signatures — unclear which is authoritative`.
- **MISSING REQUIREMENT** — a decision is needed before the rebase can proceed. `MISSING REQUIREMENT: origin/main has force-pushed since last fetch — confirm the target is correct before I continue`.
- **PLAN** — announced sequence when conflicts span multiple rounds. `PLAN: resolve handler.ts first, then re-run the rebase; 2 more files likely to conflict afterward`.

## Workflow

### Step 1: Validate Prerequisites

0. **Parse arguments:**

   If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag from remaining arguments before processing `--base=<branch>`.

1. **Check for rebase/merge in progress:**

   ```bash
   ls -d .git/rebase-merge .git/rebase-apply .git/MERGE_HEAD 2>/dev/null
   ```

   If any exist, stop with error:
   > "A rebase or merge is already in progress. Complete or abort it first with `git rebase --abort` or `git merge --abort`."

2. **Detect base branch:**

   If `--base=<branch>` was provided, use that value directly.

   Otherwise, try these methods in order:

   1. Check `origin/HEAD` (most reliable - reflects remote's default branch):

      ```bash
      git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
      ```

   2. If that fails, check if `main` branch exists on remote:

      ```bash
      git show-ref --verify --quiet refs/remotes/origin/main
      ```

   3. If that fails, check if `master` branch exists on remote:

      ```bash
      git show-ref --verify --quiet refs/remotes/origin/master
      ```

   4. If none work, fail with a clear error:
      > "Could not auto-detect base branch. Use `--base=<branch>` to specify explicitly."

3. **Verify current branch is not the base branch:**

   ```bash
   git branch --show-current
   ```

   If current branch equals base branch, stop with error:
   > "You are on the base branch. Switch to a feature branch first."

### Step 2: Fetch Latest

Fetch the latest commits from the remote:

```bash
git fetch origin <base-branch>
```

### Step 3: Rebase

Run the rebase with `--autostash` to automatically handle uncommitted changes:

```bash
git rebase --autostash origin/<base-branch>
```

**Note:** `--autostash` automatically stashes uncommitted changes before rebase and pops them after, handling the common case of rebasing with local modifications.

**If rebase succeeds:** Proceed to Step 4.

**If rebase fails (conflicts):**

1. **Attempt automatic resolution (up to 10 conflict rounds):**

   Track all conflicts and resolutions for the summary.

   For each round:

   a. Get list of conflicting files:
      ```bash
      git diff --name-only --diff-filter=U
      ```

   b. For each conflicting file:
      - Read the file content
      - Resolve conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) by analyzing both versions and choosing the best resolution
      - **Record the conflict and resolution** (file path, what conflicted, how it was resolved)
      - Write the resolved content back
      - Stage the file: `git add <file>`

   c. Continue the rebase:
      ```bash
      GIT_EDITOR=true git rebase --continue
      ```

   d. If rebase completes, proceed to **Step 4: Conflict Summary**

   e. If new conflicts arise, repeat from (a)

2. **If resolution fails** (after 10 rounds or unresolvable conflict):

   Abort the rebase:
   ```bash
   git rebase --abort
   ```

   Inform user:
   > "Automatic conflict resolution failed after X attempts. The branch has been restored to its pre-rebase state."
   >
   > "Conflicting files that could not be resolved: `<list files>`"
   >
   > "To resolve manually, run `git rebase origin/<base-branch>`, fix conflicts, then `git rebase --continue`."

### Step 4: Conflict Summary

If any conflicts were resolved during rebase, present a summary before proceeding:

> **Conflicts resolved during rebase:**
>
> For each resolved conflict, show:
> - **File:** `<file path>`
> - **Conflict:** Brief description of what conflicted (e.g., "Both branches modified the `calculateTotal` function")
> - **Resolution:** How it was resolved (e.g., "Combined changes: kept the new parameter from base branch and the validation logic from feature branch")

This allows the user to review what was automatically resolved before force pushing.

### Step 5: Force Push

If `AUTO_MODE=true`, skip the confirmation prompt and push immediately with `--force-with-lease`.

Otherwise, before pushing, use `AskUserQuestion` to confirm:

> "Ready to force push rebased branch. This will overwrite the remote branch history. Continue?"
>
> Options:
> - **Yes, force push** - Push with `--force-with-lease`
> - **Do not push** - Keep local rebase but don't push

If confirmed, push the rebased branch:

```bash
git push --force-with-lease origin $(git branch --show-current)
```

**Note:** `--force-with-lease` refuses to overwrite remote commits you haven't fetched, providing safety against overwriting others' work.

### Step 6: Report Results

Show the commit log relative to base:

```bash
git log --oneline origin/<base-branch>..HEAD
```

Confirm success:
> "Branch rebased onto `origin/<base-branch>` and pushed."

## Common Rationalizations

Lies you'll tell yourself mid-rebase. Each has a correct response:

- *"I'll just merge `main` in instead — it's faster."* → Faster now, harder to review later. Merges hide drift; rebases resolve it.
- *"The auto-conflict resolution looks right — I don't need to re-run tests."* → Conflict resolution is a code change. Re-run the verify battery or surface it as `UNVERIFIED`.
- *"Force-push is fine; no one else is on this branch."* → If the branch is pushed, assume someone has it. `--force-with-lease` is the floor, not the ceiling — still warn the user.
- *"Ten rounds of auto-resolve failed — I'll just pick one side."* → The skill aborts after 10 rounds for a reason. Escalate to the user; don't guess.

## Red Flags — STOP

Pause and hand back to the user if any of these are true:

- `--force-with-lease` is about to run against `main`, `master`, or `develop`.
- The auto-resolver merged logic from a file it doesn't fully understand.
- The rebase touched migration files or generated artifacts; auto-resolution is unsafe there.
- The branch hadn't been fetched recently and the base has moved significantly (>20 commits).
- Any conflict was resolved by deleting a block instead of merging semantics.

## Verification

Before force-pushing, self-check:

- [ ] Conflict Summary lists every resolved file with file + conflict + resolution.
- [ ] The base branch was freshly fetched (Step 2 ran).
- [ ] The user explicitly confirmed via `AskUserQuestion` (Step 5), or `AUTO_MODE=true`.
- [ ] `--force-with-lease` (not `--force`) is the flag being used.
- [ ] Post-push `git log --oneline origin/<base>..HEAD` shows the expected linear history.
