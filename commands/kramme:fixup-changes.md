---
name: kramme:fixup-changes
description: Intelligently fixup unstaged changes into existing commits on the current branch. Maps each changed file to its most recent commit, validates (build/test/lint), creates fixup commits, and autosquashes.
---

# Fixup Changes

Intelligently fixup unstaged changes into existing commits on the current branch, with validation.

## Workflow

### Step 0: Check for Custom Instructions

Before proceeding with the workflow, check if the user provided additional instructions after the command:

1. **Parse arguments and instructions** — If the user wrote `/kramme:fixup-changes <something>`:
   - Extract known flags (`--skip-tests`, `--skip-build`, `--skip-lint`, `--skip-all`, `--no-confirm`, `--base=<branch>`)
   - Any remaining text after flags is treated as **custom instructions**

2. **Apply custom instructions throughout** — If the user provided instructions, keep them in mind when:
   - Deciding which files to include/exclude from the fixup
   - Handling validation failures or edge cases
   - Creating fixup commit groupings
   - Presenting options to the user
   - Any other decision points in the workflow

**Examples of custom instructions:**
- "Only process backend files" → Filter to files in Connect/Connect.Api/
- "Skip the frontend changes for now" → Exclude files in ng-app-monolith/
- "Group all test file changes together" → Create a single fixup for test files
- "Be quick, I've already validated" → Implies --skip-all behavior

### Step 1: Validate Prerequisites

1. **Detect base branch:**

   Try these methods in order:

   1. Check `origin/HEAD` (most reliable - reflects remote's default branch):

      ```bash
      git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
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

   The `--base=<branch>` option always overrides auto-detection.

2. **Check for staged changes:**

   ```bash
   git diff --cached --name-only
   ```

   If staged changes exist, use `AskUserQuestion` to ask whether to:

   - Include them with the other changes (they'll be fixed up too)
   - Abort so user can handle them separately

   If including staged changes, unstage them first (`git reset HEAD <files>`) so they flow through the normal mapping process.

3. **Check for unstaged changes:**

   ```bash
   git diff --name-only
   ```

   If no changes to process (no unstaged, and no staged being included), inform user and exit.

4. **Check branch has commits ahead of base:**

   ```bash
   git log <base>..HEAD --oneline
   ```

   If no commits, inform user this command requires existing commits to fixup into.

### Step 2: Run Validations

Before creating any commits, validate the changes won't break the build.

**IMPORTANT:** Reference the project's `CLAUDE.md` or `AGENTS.md` to find the correct commands for:

- Building the project
- Running tests (unit tests, integration tests)
- Linting and formatting checks

Run validations **scoped to the changed files**:

- Identify which files changed and their type (backend, frontend, tests)
- Run build for affected projects
- Run tests related to the changed files (not full test suite)
- Run lint/format checks on changed files

**Use check-only commands** (e.g., `lint` not `lint --fix`, `format:check` not `format`) to avoid modifying files mid-workflow.

**If validation finds issues**, use `AskUserQuestion` to ask the user:

- **Fix and continue** - Apply fixes (run auto-fix commands), then re-validate and continue. The fixes become part of the unstaged changes to fixup.
- **Continue anyway** - Proceed despite issues (user takes responsibility)
- **Abort** - Stop and let user fix manually

Do NOT silently proceed with validation failures.

### Step 3: Map Changes to Commits

For each changed file (modified, deleted, or renamed), find which commit on the branch most recently touched it:

```bash
git log <base>..HEAD --oneline -- <file_path>
```

Take the first (most recent) commit from the output as the target for that file.

**Note:** Deleted files work the same way - they get fixed up into the commit that originally added/modified them. If a file was added and is now being deleted, the fixup will remove it from that commit entirely (as if it was never added).

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

If orphan files exist, use `AskUserQuestion` to let the user decide:

**Why this happens:**

- New file that should be a separate commit
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

Run an autosquash rebase to squash fixup commits into their targets:

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <base>
```

If the rebase succeeds, proceed to Step 6.

If the rebase fails (conflicts), see Error Handling below.

### Step 6: Update REVIEW_RESPONSES.md (if present)

If `REVIEW_RESPONSES.md` exists in the project root:

1. **Update commit hashes** — For each finding that was addressed, update its `**Commit:**` field with the short hash of the commit containing the fix
2. **Do not commit this file** — `REVIEW_RESPONSES.md` is a working document for tracking review responses; it should never be committed

### Step 7: Report Results

Show the final commit log:

```bash
git log <base>..HEAD --oneline
```

Confirm success and show any remaining unstaged/untracked files.

**Remind user:** If this branch was already pushed, they'll need to force push:

```bash
git push --force-with-lease
```

## Error Handling

### Git lock file exists

Remove `.git/index.lock` and retry once. If it persists, inform user to close other git processes (VS Code, IDE extensions, file watchers, etc.)

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
   - **Retry manually:** User can run `git rebase -i --autosquash <base>` and resolve conflicts themselves
   - **Abandon fixups:** User can remove the fixup commits with `git reset HEAD~N` (where N = number of fixup commits created)

## Options

**Arguments:** `$ARGUMENTS`

**Flags:**
- `--skip-tests` - Skip running tests (use when you've already validated)
- `--skip-build` - Skip build validation
- `--skip-lint` - Skip lint/format validation
- `--skip-all` - Skip all validations
- `--no-confirm` - Skip confirmation prompts (orphan files are skipped automatically)
- `--base=<branch>` - Override auto-detected base branch

**Custom Instructions:**
Any text after the command (and flags) is treated as custom instructions that influence the workflow. These instructions are applied contextually throughout the process.

## Examples

```bash
# Standard usage - auto-detect base, validate and fixup
/fixup-changes

# Skip all validations (already tested manually)
/fixup-changes --skip-all

# Skip only tests
/fixup-changes --skip-tests

# Explicit base branch
/fixup-changes --base=develop

# Non-interactive (for scripting)
/fixup-changes --skip-all --no-confirm

# With custom instructions
/fixup-changes Only process the API controller changes
/fixup-changes --skip-tests Focus on the frontend, ignore backend files
/fixup-changes Group related changes together even if they touched different commits
```

## Notes

- Base branch is auto-detected from `origin/HEAD`, then `main`, then `master`
- If auto-detection fails, use `--base=<branch>` to specify explicitly
- Handles modified, deleted, and renamed files
- Staged changes prompt for handling before proceeding
- Orphan files (not touched by branch) require user decision or are skipped with `--no-confirm`
- After rebase, force push is required if branch was previously pushed
- Validation commands are project-specific - refer to CLAUDE.md/AGENTS.md
