---
name: kramme:pr:create
description: Create a clean PR with narrative commits and comprehensive description
argument-hint: "[--auto] [--draft]"
disable-model-invocation: true
user-invocable: true
---

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

## References

- `references/pre-validation-checks.md` - read during Step 1 for required repository safety checks.
- `references/branch-and-platform-handling.md` - read during Steps 2-3 for branch, base, Linear, and upstream handling.
- `references/confirmation-and-creation.md` - read during Steps 8-9 for preview, confirmation, push, PR creation, failure handling, draft mode, and success output.

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
git rev-list --count origin/main..HEAD 2> /dev/null || git rev-list --count origin/master..HEAD
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
git branch -D ${ORIGINAL_BRANCH}-clean 2> /dev/null || true

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

Read `references/confirmation-and-creation.md` and execute Step 8 from that file. It contains the preview format, confirmation prompt, draft-mode substitutions, push command, `gh pr create` invocation, and failure fallbacks.

---

## Step 9: Success Output

Use Step 9 in `references/confirmation-and-creation.md` for the final success message. Preserve the draft-specific wording when `DRAFT_MODE=true`.

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
git branch -D ${ORIGINAL_BRANCH}-clean 2> /dev/null || true

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
