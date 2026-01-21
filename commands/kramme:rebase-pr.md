---
name: kramme:rebase-pr
description: Rebase current branch onto latest main/master, then force push. Use when your PR is behind the base branch.
---

# Rebase PR

Rebase the current branch onto the latest base branch and force push.

## Options

**Flags:**
- `--base=<branch>` - Override auto-detected base branch (e.g., `--base=develop`)

## Workflow

### Step 1: Validate Prerequisites

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

1. Abort the rebase:
   ```bash
   git rebase --abort
   ```

2. Inform user clearly:
   > "Rebase failed due to conflicts. The branch has been restored to its pre-rebase state."
   >
   > "Conflicting files: `<list files from error output>`"
   >
   > "To resolve, run `git rebase origin/<base-branch>`, fix conflicts, then `git rebase --continue`."

3. Stop execution. Do not attempt to resolve conflicts automatically.

### Step 4: Force Push

Push the rebased branch:

```bash
git push --force-with-lease origin $(git branch --show-current)
```

**Note:** `--force-with-lease` refuses to overwrite remote commits you haven't fetched, providing safety against overwriting others' work.

### Step 5: Report Results

Show the commit log relative to base:

```bash
git log --oneline origin/<base-branch>..HEAD
```

Confirm success:
> "Branch rebased onto `origin/<base-branch>` and pushed."
