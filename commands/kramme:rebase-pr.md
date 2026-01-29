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

Before pushing, use `AskUserQuestion` to confirm:

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
