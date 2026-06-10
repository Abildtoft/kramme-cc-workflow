---
name: kramme:git:fixup
description: Intelligently fixup unstaged changes into existing commits on the current branch. Maps each changed file to its most recent commit, validates (build/test/lint), creates fixup commits, and autosquashes.
argument-hint: "[--skip-tests|--skip-build|--skip-lint|--skip-all] [--no-confirm] [--base=<branch>] [instructions]"
disable-model-invocation: true
user-invocable: true
---

# Fixup Changes

Intelligently fixup unstaged changes into existing commits on the current branch, with validation.

## When Not to Use

- The branch has no commits ahead of base (nothing to fix up into) — make a normal commit instead.
- You are on a detached HEAD, or on the base branch itself.
- The branch is shared and others have built on its current commits — the autosquash rebase rewrites history and will disrupt them; coordinate first or make a normal commit.

## Workflow

### Step 0: Check for Custom Instructions

Before proceeding with the workflow, check if the user provided additional instructions after the command:

1. **Parse arguments and instructions** — If the user wrote `/kramme:git:fixup <something>`:
   - Extract known flags (`--skip-tests`, `--skip-build`, `--skip-lint`, `--skip-all`, `--no-confirm`, `--base=<branch>`)
   - Any remaining text after flags is treated as **custom instructions**

2. **Apply custom instructions throughout** — If the user provided instructions, keep them in mind when:
   - Deciding which files to include/exclude from the fixup
   - Handling validation failures or edge cases
   - Creating fixup commit groupings
   - Presenting options to the user
   - Any other decision points in the workflow

**Examples of custom instructions:**

- "Only process backend files" → Filter to files in the backend directory
- "Skip the frontend changes for now" → Exclude files in the frontend directory
- "Group all test file changes together" → Create a single fixup for test files
- "Be quick, I've already validated" → Implies --skip-all behavior

### Step 1: Validate Prerequisites

1. **Detect base branch:**

   Try these methods in order:
   1. Check `origin/HEAD` (most reliable - reflects remote's default branch):

      ```bash
      git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@'
      ```

   2. If that fails, check if `main` branch exists locally:

      ```bash
      git show-ref --verify --quiet refs/heads/main
      ```

   3. If that fails, check if `master` branch exists locally:

      ```bash
      git show-ref --verify --quiet refs/heads/master
      ```

   4. If none work, fail with a clear error:
      > "Could not auto-detect base branch. Use `--base=<branch>` to specify. Run `git branch` to see available branches."

   Store the resolved branch name as `BASE_BRANCH`. The `--base=<branch>` option always overrides auto-detection.

2. **Check branch rewrite safety:**

   Confirm `HEAD` is attached to a feature branch before any history-rewriting work:

   ```bash
   CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD) || {
     echo "HEAD is detached; switch to the feature branch before running fixup."
     exit 1
   }
   ```

   If `$CURRENT_BRANCH` is the resolved base branch, abort:

   ```bash
   if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
     echo "Current branch is the base branch '$BASE_BRANCH'; fixup rewrites feature-branch history only."
     exit 1
   fi
   ```

   Check whether the upstream tracking branch has commits that are not in local `HEAD`:

   ```bash
   UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
   UPSTREAM_REWRITE_WARNING=0
   if [ -n "$UPSTREAM" ] && git rev-parse --verify --quiet "$UPSTREAM" >/dev/null; then
     if ! git merge-base --is-ancestor "$UPSTREAM" HEAD; then
       echo "Upstream '$UPSTREAM' is ahead of or diverged from local HEAD; autosquash would rewrite shared history."
       UPSTREAM_REWRITE_WARNING=1
     fi
   fi
   ```

   If `UPSTREAM_REWRITE_WARNING=1`, treat it as a stop-and-confirm moment: ask whether collaborators are coordinated and whether to proceed with rewriting local branch history. Under `--no-confirm`, abort instead of asking.

3. **Check for staged changes:**

   ```bash
   git diff --cached --name-only
   ```

   If staged changes exist, ask the user whether to:
   - Include them with the other changes (they'll be fixed up too)
   - Abort so user can handle them separately

   Under `--no-confirm`, include staged changes automatically (the most common intent for an unattended run).

   If including staged changes, unstage them first (`git reset HEAD <files>`) so they flow through the normal mapping process.

4. **Check for unstaged and untracked changes:**

   Detect tracked changes (with rename detection) and untracked files separately — `git diff` alone omits untracked files:

   ```bash
   git diff --name-status -M                  # tracked: modified (M), deleted (D), renamed (R)
   git ls-files --others --exclude-standard   # untracked (new) files
   ```

   Untracked files have no commit that touched them, so they are always orphans (Step 3b) — they cannot be fixed up.

   If there is nothing to process (no tracked changes, no untracked files, and no staged changes being included), inform the user and exit.

5. **Check branch has commits ahead of base:**

   ```bash
   git log --oneline <base>..HEAD
   ```

   If no commits, inform user this command requires existing commits to fixup into.

6. **Check for leftover fixup commits:**

   ```bash
   git log <base>..HEAD --oneline --grep '^fixup!'
   ```

   Pre-existing `fixup!` commits usually mean a prior run created fixups but did not finish the autosquash rebase. Ask the user whether to resume the autosquash now (skip to Step 5) or abort so they can inspect. Under `--no-confirm`, resume the autosquash.

### Step 2: Run Validations

Before creating any commits, validate the changes won't break the build.

**IMPORTANT:** Reference the project's `AGENTS.md`, `CLAUDE.md`, or equivalent instruction files to find the correct commands for:

- Building the project
- Running tests (unit tests, integration tests)
- Linting and formatting checks

Run validations **scoped to the changed files**:

- Identify which files changed and their type (backend, frontend, tests)
- Run build for affected projects
- Run tests related to the changed files (not full test suite)
- Run lint/format checks on changed files

**Use check-only commands** (e.g., `lint` not `lint --fix`, `format:check` not `format`) to avoid modifying files mid-workflow.

**If validation finds issues**, ask the user:

- **Fix and continue** - Apply fixes (run auto-fix commands), then re-validate and continue. The fixes become part of the unstaged changes to fixup.
- **Continue anyway** - Proceed despite issues (user takes responsibility)
- **Abort** - Stop and let user fix manually

Under `--no-confirm`, abort on validation failure — never rewrite history over failing checks unattended.

Do NOT silently proceed with validation failures.

### Step 3: Map Changes to Commits

For each changed file (modified, deleted, or renamed), find which commit on the branch most recently touched it:

```bash
git log <base>..HEAD --oneline -- <file_path>
```

Take the first (most recent) commit from the output as the target for that file.

**Note:** Deleted files work the same way - they get fixed up into the commit that originally added/modified them. If a file was added and is now being deleted, the fixup will remove it from that commit entirely (as if it was never added).

**Renamed files:** Map using the file's pre-rename (old) path from `git diff --name-status -M`, since the new path has no history yet. The rename targets whichever commit last touched the original path. If only the new path is known, treat it as an orphan.

**Untracked files:** These have no matching commit and are always listed under orphans below.

Create a mapping and **present everything in one view**:

```text
Fixup Plan (base: main):

Matched files:
  → abc1234 "Add feature X"
    - src/file1.ts (modified)
    - src/helper.ts (deleted)
  → def5678 "Fix bug Y"
    - src/file3.ts (modified)

⚠ Orphan files (no matching commit):
  - src/newfile.ts
  - src/unrelated.ts

These orphan files were not modified by any commit on this branch.
They cannot be fixed up and will need a separate commit.
```

### Step 3b: Handle Orphan Files

If orphan files exist, ask the user to decide:

**Why this happens:**

- New / untracked file that should be a separate commit
- File from a different feature that was accidentally modified
- File that was reverted and re-modified

**Options:**

1. **Create separate commit** - Ask for commit message, create new commit for these files
2. **Skip these files** - Leave them unstaged, proceed with fixups only
3. **Abort** - Don't proceed, let user investigate

When `--no-confirm` is set, orphan files are automatically skipped.

### Step 4: Create Fixup Commits

For each target commit, stage the relevant files and create a fixup commit:

```bash
git add <files...>
git commit --fixup=<commit_sha>
```

### Step 5: Autosquash Rebase

Run an autosquash rebase to squash fixup commits into their targets. Use the branch fork point (merge-base) so this rewrites only branch commits and does not pull newer base-branch commits into the feature branch:

```bash
FORK_POINT=$(git merge-base HEAD <base>)
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash "$FORK_POINT"
```

If the rebase succeeds, proceed to Step 6.

If the rebase fails (conflicts), see Error Handling below.

### Step 6: Update REVIEW_OVERVIEW.md (if present)

If `REVIEW_OVERVIEW.md` exists in the project root:

1. **Update commit hashes** — For each finding that was addressed, update its `**Commit:**` field with the short hash of the commit containing the fix
2. **Do not commit this file** — `REVIEW_OVERVIEW.md` is a working document for tracking review responses; it should never be committed

### Step 7: Report Results

Show the final commit log:

```bash
git log --oneline <base>..HEAD
```

Confirm success and show any remaining unstaged/untracked files.

**Remind user:** If this branch was already pushed, they'll need to force push:

```bash
git push --force-with-lease
```

## Error Handling

### Git lock file exists

`.git/index.lock` may be stale, or it may be held by a running git process — deleting it while a process is active can corrupt the index. Do not remove it blindly:

1. Confirm no git operation is in progress (active commit/rebase/merge, IDE git extension, file watcher).
2. Only once you have confirmed none are active, ask the user before deleting `.git/index.lock` (skip the prompt under `--no-confirm`), then retry once.
3. If it persists, stop and ask the user to close other git processes (VS Code, IDE extensions, file watchers, etc.).

### Validation failures

Stop immediately. Do not create any commits. Report the specific failures.

### Rebase conflicts

If the rebase fails mid-way due to conflicts:

1. **Detect failure:** Check exit code of rebase command, or check if `.git/rebase-merge` directory exists.

2. **Abort automatically:** Run `git rebase --abort` to restore the branch to its pre-rebase state.

3. **Inform user clearly:**

   > "Rebase failed due to conflicts between fixup changes and target commit."
   >
   > "The branch has been restored to its pre-rebase state."
   >
   > "**Your fixup commits are NOT lost** - they still exist on the branch."

4. **Provide resolution options:**
   - **Retry manually:** User can run `git rebase -i --autosquash "$(git merge-base HEAD <base>)"` and resolve conflicts themselves
   - **Abandon fixups:** User can remove the fixup commits with `git reset HEAD~N` (where N = number of fixup commits created)
   - **Re-run this skill:** A subsequent run detects the leftover `fixup!` commits in Step 1 and offers to resume the autosquash, instead of finding no unstaged changes and silently exiting

## Options

**Arguments:** `$ARGUMENTS`

**Flags:**

- `--skip-tests` - Skip running tests (use when you've already validated)
- `--skip-build` - Skip build validation
- `--skip-lint` - Skip lint/format validation
- `--skip-all` - Skip all validations
- `--no-confirm` - Skip confirmation prompts. Defaults: staged changes are included, orphan files are skipped, validation failures abort, and leftover fixup commits are autosquashed.
- `--base=<branch>` - Override auto-detected base branch

**Custom Instructions:** Any text after the command (and flags) is treated as custom instructions that influence the workflow. These instructions are applied contextually throughout the process.

## Examples

```bash
# Standard usage - auto-detect base, validate and fixup
/kramme:git:fixup

# Skip all validations (already tested manually)
/kramme:git:fixup --skip-all

# Skip only tests
/kramme:git:fixup --skip-tests

# Explicit base branch
/kramme:git:fixup --base=develop

# Non-interactive (for scripting)
/kramme:git:fixup --skip-all --no-confirm

# With custom instructions
/kramme:git:fixup Only process the API controller changes
/kramme:git:fixup --skip-tests Focus on the frontend, ignore backend files
/kramme:git:fixup Group related changes together even if they touched different commits
```

## Notes

- Base branch is auto-detected from `origin/HEAD`, then `main`, then `master`
- If auto-detection fails, use `--base=<branch>` to specify explicitly
- Handles modified, deleted, and renamed files; untracked (new) files are surfaced as orphans, not fixed up
- Staged changes prompt for handling before proceeding (included automatically under `--no-confirm`)
- Orphan files (not touched by branch) require user decision or are skipped with `--no-confirm`
- Autosquash rebase uses merge-base with the base branch, so fixup does not implicitly rebase onto the latest base tip
- After rebase, force push is required if branch was previously pushed
- Validation commands are project-specific - refer to `AGENTS.md`, `CLAUDE.md`, or equivalent instruction files
- If `REVIEW_OVERVIEW.md` exists in the project root, this skill updates its `**Commit:**` fields in place (never committing the file); otherwise that step is skipped
