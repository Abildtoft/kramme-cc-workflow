---
name: kramme:pr:create
description: Create a clean PR with narrative commits and comprehensive description
argument-hint: "[--auto] [--draft]"
disable-model-invocation: true
user-invocable: true
---

<!-- TODO: Refactor to <500 lines by moving Step 8: Confirmation and Creation to references/ -->

# Create Pull Request

Orchestrate the creation of a clean, well-documented PR by:
1. Validating git state
2. Setting up the branch (if on main)
3. Creating clean, narrative-quality commits
4. Generating a comprehensive description
5. Pushing and creating the PR

## Process Overview

```
/kramme:pr:create
    |
    v
[Pre-Validation] -> Error? -> Abort with clear message
    |
    v
[Branch Handling] -> On main? -> Linear issue? -> Use Linear branch name / Ask for branch name
    |
    v
[Changes Check] -> No changes? -> Abort
    |
    v
[State Preservation] -> Record original state for rollback
    |
    v
[recreate-commits Skill] -> Failure? -> Rollback
    |
    v
[pr-description-generator Skill]
    |
    v
[Confirmation] -> Abort? -> Rollback
    |
    v
[Push & Create PR]
    |
    v
[Success Output]
```

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for optional flags before starting:

- `--auto` -> set `AUTO_MODE=true` and remove the flag from the remaining arguments.
- `--draft` -> set `DRAFT_MODE=true` and remove the flag from the remaining arguments.

Defaults: `AUTO_MODE=false`, `DRAFT_MODE=false`. Flag order is not significant.

`--auto` means:
- use the recommended commit structure (`Narrative`)
- invoke downstream skills in non-interactive mode
- skip the final PR confirmation
- choose the recommended branch-handling path from the shared reference instructions
- stop only on hard blockers

`--draft` means:
- create the PR as a draft (`gh pr create --draft`).

Without `--draft`, the PR is created ready for review.

---

## Step 1: Pre-Validation

Read the pre-validation checks from `references/pre-validation-checks.md`. Run all four checks (git repo, merge conflicts, rebase/merge in progress, remote configuration) and abort on any failure.

---

## Steps 2-3: Branch Handling

Read the branch handling instructions from `references/branch-and-platform-handling.md`. Validate the branch is a feature branch, detect the base branch, and handle edge cases (detached HEAD, main branch, Linear issue integration, no upstream).

---

## Step 4: Changes Detection

### 4.1 Check for Uncommitted Changes

```bash
git status --porcelain
```

### 4.2 Check for Commits Ahead of Main

```bash
git rev-list --count origin/main..HEAD 2>/dev/null || git rev-list --count origin/master..HEAD
```

### 4.3 Validation

**If both checks return empty/zero:**
```
Error: No changes detected compared to main branch.

Current state:
  - Branch: {current-branch}
  - Uncommitted changes: None
  - Commits ahead of main: 0

Nothing to create a PR for. Make some changes first, then run /kramme:pr:create again.
```
**Action:** Abort.

**If changes exist:** Continue to next step.

---

## Step 5: State Preservation

**Before any destructive operations, record the current state for potential rollback.**

### 5.1 Record Original State

```bash
ORIGINAL_BRANCH=$(git branch --show-current)
ORIGINAL_COMMIT=$(git rev-parse HEAD)
```

### 5.2 Stash Uncommitted Changes

If there are uncommitted changes:
```bash
git stash push -m "create-pr-backup-$(date +%s)"
STASH_CREATED=true
```

### 5.3 Rollback Procedure

If rollback is needed at any point, execute:
```bash
# Return to original branch
git checkout $ORIGINAL_BRANCH

# Delete clean branch if created
git branch -D ${ORIGINAL_BRANCH}-clean 2>/dev/null || true

# Restore stashed changes
if [ "$STASH_CREATED" = "true" ]; then
  git stash pop
fi
```

---

## Step 6: Invoke recreate-commits Skill (Step 6 of 9 - DO NOT STOP AFTER THIS STEP)

### 6.1 Confirm Commit Restructuring Approach

If `AUTO_MODE=true`, skip this question and choose **Narrative (recommended)**.

Otherwise use AskUserQuestion:
```yaml
header: "Commit style"
question: "How should commits be structured for the PR?"
options:
  - label: "Narrative (recommended)"
    description: "Reorganize into logical story: setup, core implementation, tests, polish"
  - label: "Keep original"
    description: "Keep existing commit structure, just clean up messages"
  - label: "Single squash"
    description: "Combine all changes into one well-documented commit"
multiSelect: false
```

### 6.2 Invoke the Skill

**IMPORTANT:** Use the Skill tool to invoke `recreate-commits`:

If `AUTO_MODE=true`:
```yaml
skill: "kramme:git:recreate-commits", args: "--auto"
```

Otherwise:
```
skill: "kramme:git:recreate-commits"
```

This skill will:
- Analyze all changes vs main/master
- Plan a logical commit sequence
- Create narrative-quality commits
- **NEVER include AI attribution** (no "Generated with Claude Code" or Co-Authored-By)

### ⚠️ MANDATORY CONTINUATION - DO NOT STOP HERE

After the recreate-commits skill completes:
1. **DO NOT** end your turn or wait for user input
2. **DO NOT** summarize what was done and ask "what next?"
3. **IMMEDIATELY** invoke the pr-description-generator skill (Step 7)

This is Step 6 of 9. The PR creation workflow is not complete until Step 9.

### 6.3 Handle Skill Failure

**If the skill fails or encounters an error:**
```
Error: The recreate-commits skill encountered an issue.

Original state preserved:
  - Branch: {original-branch}
  - Commit: {original-commit}

What happened:
  {skill error message}

Recovery:
  1. Your original work is safe
  2. Check git status to see current state
  3. If a -clean branch was created: git branch -D {branch}-clean
  4. Try again with /kramme:pr:create
```
**Action:** Execute rollback procedure from Step 5.3, then abort.

---

## Step 7: Invoke pr-description-generator Skill (Step 7 of 9 - DO NOT STOP AFTER THIS STEP)

### 7.1 Invoke the Skill

**IMPORTANT:** Invoke `pr-description-generator` based on mode:

If `AUTO_MODE=true`:
```yaml
skill: "kramme:pr:generate-description", args: "--auto"
```

Otherwise:
```yaml
skill: "kramme:pr:generate-description"
```

This skill will:
- Analyze git diff and commit history
- Check for Linear issue references in branch name
- Generate a conventional commit-style **title** (`<type>(<scope>): <description>`)
- Generate comprehensive description with all sections

### ⚠️ MANDATORY CONTINUATION - DO NOT STOP HERE

After the pr-description-generator skill completes:
1. **DO NOT** end your turn or wait for user input
2. **DO NOT** just show the description and stop
3. **IMMEDIATELY** proceed to Step 8 (Confirmation and Creation)

This is Step 7 of 9. The PR creation workflow is not complete until Step 9. Once the skill produces the final description, proceed directly to the Confirmation and Creation step.

### 7.2 Capture the Title and Description

The skill produces:
1. A conventional commit-style **title** (e.g., `feat(auth): add OAuth2 support`)
2. A complete markdown **description**

Capture both for use in Step 8.

### 7.3 Handle Skill Failure

**If the skill fails:**

Provide a minimal fallback template:
```markdown
## Summary

[Brief description of changes]

## Technical Details

[Implementation approach]

## Test Plan

- [ ] Manual testing completed
- [ ] Unit tests pass

## Breaking Changes

None
```

**Continue to Step 8** with the fallback template.

---

## Step 8: Confirmation and Creation (Step 8 of 9)

### 8.1 Preview Summary

Show the user what will be created. When `DRAFT_MODE=true`, use `Draft [PR] Ready to Create` / `Status: Draft`; otherwise use `[PR] Ready to Create` / `Status: Ready for review`.

```
[PR] Ready to Create

Title: [Generated conventional commit title from pr-description-generator]
Branch: {feature-branch} -> main
Status: Ready for review

Description Preview:
---
{first 300 characters of description}...
---
```

**NOTE**: The title comes from the pr-description-generator skill output and follows conventional commit format (`<type>(<scope>): <description>`).

### 8.2 Confirm Creation

If `AUTO_MODE=true`, skip this confirmation and proceed directly to Step 8.3.

Otherwise use AskUserQuestion. When `DRAFT_MODE=true`, substitute "Draft PR" for "PR" in the question and the first option's label/description.

```yaml
header: "Confirm"
question: "Ready to create the PR?"
options:
  - label: "Create PR"
    description: "Push branch and create the PR with the generated description"
  - label: "Edit description first"
    description: "Review and modify the description before creating"
  - label: "Abort"
    description: "Cancel and keep local changes without creating PR"
multiSelect: false
```

**If "Abort" selected:**
```
Operation cancelled.

Your changes remain local:
  - Branch: {current-branch}
  - Commits: {number} commits ready
  - Status: Not pushed, no PR created

You can run /kramme:pr:create again when ready.
```
**Action:** Abort (no rollback needed - commits are preserved).

**If "Edit description first" selected:**
Allow the user to provide edits, then continue.

### 8.3 Push Branch

```bash
git push -u origin $(git branch --show-current)
```

**If push fails:**
```
Warning: Failed to push branch to remote.

Possible causes:
  - No push access to repository
  - Branch name conflicts with existing remote branch
  - Network connectivity issues

Manual push command:
  git push -u origin {branch-name}

If branch exists remotely:
  git push -u origin {branch-name} --force-with-lease

The generated description is saved. You can create the PR manually.
```
**Action:** Show the full description for copy/paste, then abort.

### 8.4 Create PR

Include the `--draft` flag only when `DRAFT_MODE=true`. The snippet below builds a `DRAFT_FLAG` variable that is empty by default.

```bash
DRAFT_FLAG=""
[ "$DRAFT_MODE" = "true" ] && DRAFT_FLAG="--draft"

gh pr create $DRAFT_FLAG \
  --assignee @me \
  --title "{title}" \
  --body "$(cat <<'EOF'
{generated description}
EOF
)"
```

### 8.5 Handle PR Creation Failure

**If creation fails:**
```
Warning: Failed to create [PR] automatically.

Error: {error message}

Manual creation:
  1. Your branch is pushed: origin/{branch-name}
  2. Create manually at: https://github.com/{org}/{repo}/pull/new/{branch}
  3. Copy this description:

---
{full generated description}
---
```

If `DRAFT_MODE=true`, append a final line: `Remember to mark it as Draft before creating.`

---

## Step 9: Success Output

On successful creation. When `DRAFT_MODE=true`, use `Draft [PR] created successfully!` / `Status: Draft` and keep the final "Mark as ready for review when complete" next-step. Otherwise use the form below.

```
[PR] created successfully!

URL: {pr-url}
Branch: {branch} -> main
Status: Ready for review

Commits included:
  - {commit 1 summary}
  - {commit 2 summary}
  - ...

Next steps:
  1. Review the PR description for accuracy
  2. Add screenshots or videos if applicable
  3. Run tests and ensure CI passes
```

---

## Step 10: Abort and Rollback Handling

If abort is requested at any point, or a critical failure occurs:

### 10.1 Execute Rollback

```bash
# Return to original branch
git checkout $ORIGINAL_BRANCH

# Reset to original commit if needed
git reset --hard $ORIGINAL_COMMIT

# Delete temporary branches
git branch -D ${ORIGINAL_BRANCH}-clean 2>/dev/null || true

# Restore stashed changes
if [ "$STASH_CREATED" = "true" ]; then
  git stash pop
fi
```

### 10.2 Confirm Rollback

```
Operation Aborted

Restored state:
  - Branch: {original-branch}
  - Commit: {original-commit}
  - Uncommitted changes: Restored from stash

Cleanup performed:
  - Deleted temporary branches
  - Restored stashed changes

Your work is exactly as it was before running /kramme:pr:create.
```

---

## Important Constraints

### No AI Attribution
**NEVER** add these to commits:
- `Generated with [Claude Code]`
- `Co-Authored-By: Claude`
- Any mention of AI assistance

Per the recreate-commits skill requirements, this would cause issues.

### Draft Mode (Opt-In)
Draft PRs are opt-in via the `--draft` flag. Default behavior is to create PRs ready for review.

- Pass `--draft` to `gh pr create` only when the user supplied `--draft`.

### Preserve Authorship
**NEVER** modify git config or add AI as author. All commits should reflect the user's authorship.

### Complete All Steps
Even for simple changes, invoke both skills:
1. `recreate-commits` for clean commit history
2. `pr-description-generator` for comprehensive description

This ensures consistency across all PRs.
