---
name: kramme:create-pr
description: Create a clean PR/MR with narrative commits and comprehensive description
---

# Create Pull Request / Merge Request

Orchestrate the creation of a clean, well-documented draft PR (GitHub) or MR (GitLab) by:
1. Validating git state and detecting platform
2. Setting up the branch (if on main)
3. Creating clean, narrative-quality commits
4. Generating a comprehensive description
5. Pushing and creating the draft PR/MR

## Process Overview

```
/create-pr
    |
    v
[Pre-Validation] -> Error? -> Abort with clear message
    |
    v
[Platform Detection] -> Ambiguous? -> Ask user
    |
    v
[Branch Handling] -> On main? -> Ask for branch name
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
[mr-pr-description-generator Skill]
    |
    v
[Confirmation] -> Abort? -> Rollback
    |
    v
[Push & Create Draft PR/MR]
    |
    v
[Success Output]
```

---

## Step 1: Pre-Validation

**ALWAYS perform these checks before proceeding. Abort on any failure.**

### 1.1 Git Repository Check

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

**If this fails:**
```
Error: Not inside a git repository.

Navigate to a git project directory and run /create-pr again.
```
**Action:** Abort immediately.

### 1.2 Merge Conflict Check

```bash
git ls-files -u
```

**If output is non-empty (conflicts exist):**
```
Error: Merge conflict detected.

Conflicted files:
  - [list files from output]

Please resolve these conflicts before creating a PR:
  1. Edit the conflicted files to resolve markers (<<<<<<<, =======, >>>>>>>)
  2. Stage resolved files: git add <resolved-files>
  3. Complete the merge: git commit

Then run /create-pr again.
```
**Action:** Abort.

### 1.3 Rebase/Merge In Progress Check

Check for these paths:
- `.git/rebase-merge/`
- `.git/rebase-apply/`
- `.git/MERGE_HEAD`

**If any exist:**
```
Error: [Rebase/Merge] operation in progress.

To continue: git [rebase/merge] --continue
To abort: git [rebase/merge] --abort

Resolve the in-progress operation, then run /create-pr again.
```
**Action:** Abort.

### 1.4 Remote Configuration Check

```bash
git remote get-url origin 2>/dev/null
```

**If no remote configured:**
```
Error: No remote 'origin' configured.

Add a remote first:
  git remote add origin <repository-url>

Then run /create-pr again.
```
**Action:** Abort.

---

## Step 2: Platform Detection

Parse the remote URL from Step 1.4:

```bash
REMOTE_URL=$(git remote get-url origin)
```

**Detection logic:**

| URL Contains | Platform | Terminology | CLI Tool |
|--------------|----------|-------------|----------|
| `github.com` | GitHub | Pull Request | `gh` |
| `gitlab.com` | GitLab | Merge Request | `glab` or MCP |
| `consensusaps` | GitLab | Merge Request | `glab` or MCP |

**If platform cannot be determined:**

Use AskUserQuestion:
```yaml
header: "Platform"
question: "Could not detect platform from remote URL. Which platform are you using?"
options:
  - label: "GitHub"
    description: "Will create a Pull Request using the gh CLI"
  - label: "GitLab"
    description: "Will create a Merge Request using glab CLI or MCP tools"
multiSelect: false
```

Store the detected platform for later steps.

---

## Step 3: Branch Handling

### 3.1 Get Current Branch

```bash
git branch --show-current
```

### 3.2 Determine Main Branch

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'
```

If this fails, try `main` then `master`.

### 3.3 Branch Decision

**If current branch is `main` or `master`:**

1. Analyze changed files to suggest branch names:
   ```bash
   # Get changed files (staged + unstaged + untracked)
   git diff --name-only HEAD
   git diff --name-only --cached
   git status --porcelain | grep '^??' | cut -c4-
   ```

2. Generate suggestions based on file paths:
   - Files in `apps/` or `libs/` -> extract component name
   - New files -> prefix with `feature/`
   - Test files only -> prefix with `test/`
   - Config files -> prefix with `chore/`

3. Use AskUserQuestion:
   ```yaml
   header: "Branch name"
   question: "You're on the main branch. What should the new branch be named?"
   options:
     - label: "feature/{suggested-name-1}"
       description: "Based on changes in {primary-area}"
     - label: "fix/{suggested-name-2}"
       description: "Based on modifications to {component}"
     - label: "chore/{suggested-name-3}"
       description: "Based on config/tooling changes"
   multiSelect: false
   ```

4. Create and switch to new branch:
   ```bash
   git checkout -b {chosen-branch-name}
   ```

**If already on a feature branch:**
Continue with current branch. No action needed.

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

Nothing to create a PR for. Make some changes first, then run /create-pr again.
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

## Step 6: Invoke recreate-commits Skill

### 6.1 Confirm Commit Restructuring Approach

Use AskUserQuestion:
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

```
skill: "recreate-commits"
```

This skill will:
- Analyze all changes vs main/master
- Plan a logical commit sequence
- Create narrative-quality commits
- **NEVER include AI attribution** (no "Generated with Claude Code" or Co-Authored-By)

**IMPORTANT: After the skill completes, immediately continue to Step 7.** Do not pause or wait for user input. The skill will handle commit creation; once it finishes, proceed directly to invoking the mr-pr-description-generator skill.

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
  4. Try again with /create-pr
```
**Action:** Execute rollback procedure from Step 5.3, then abort.

---

## Step 7: Invoke mr-pr-description-generator Skill

### 7.1 Invoke the Skill

**IMPORTANT:** Use the Skill tool to invoke `mr-pr-description-generator`:

```
skill: "mr-pr-description-generator"
```

This skill will:
- Analyze git diff and commit history
- Check for Linear issue references in branch name
- Ask clarifying questions about the changes
- Generate comprehensive description with all sections

**IMPORTANT: After the skill completes, immediately continue to Step 8.** Do not pause or wait for user input. The skill will generate the description and may ask its own clarifying questions; once it produces the final description, proceed directly to the Confirmation and Creation step.

### 7.2 Capture the Description

The skill produces a complete markdown description. Capture this for use in Step 8.

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

## Step 8: Confirmation and Creation

### 8.1 Preview Summary

Show the user what will be created:
```
Draft [PR/MR] Ready to Create

Platform: [GitHub/GitLab]
Title: [First commit message or extracted title]
Branch: {feature-branch} -> main
Status: Draft

Description Preview:
---
{first 300 characters of description}...
---
```

### 8.2 Confirm Creation

Use AskUserQuestion:
```yaml
header: "Confirm"
question: "Ready to create the Draft PR/MR?"
options:
  - label: "Create Draft PR/MR"
    description: "Push branch and create draft PR/MR with the generated description"
  - label: "Edit description first"
    description: "Review and modify the description before creating"
  - label: "Abort"
    description: "Cancel and keep local changes without creating PR/MR"
multiSelect: false
```

**If "Abort" selected:**
```
Operation cancelled.

Your changes remain local:
  - Branch: {current-branch}
  - Commits: {number} commits ready
  - Status: Not pushed, no PR/MR created

You can run /create-pr again when ready.
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

The generated description is saved. You can create the PR/MR manually.
```
**Action:** Show the full description for copy/paste, then abort.

### 8.4 Create Draft PR/MR

**For GitHub:**
```bash
gh pr create --draft \
  --title "{title}" \
  --body "$(cat <<'EOF'
{generated description}
EOF
)"
```

**For GitLab (using glab CLI):**
```bash
glab mr create --draft \
  --title "{title}" \
  --description "$(cat <<'EOF'
{generated description}
EOF
)"
```

**For GitLab (using MCP tools, if available):**
Use `mcp__gitlab__create_merge_request` with `draft: true` or prefix title with `Draft: `.

### 8.5 Handle PR/MR Creation Failure

**If creation fails:**
```
Warning: Failed to create [PR/MR] automatically.

Error: {error message}

Manual creation:
  1. Your branch is pushed: origin/{branch-name}
  2. Create manually at:
     [GitHub]: https://github.com/{org}/{repo}/pull/new/{branch}
     [GitLab]: https://gitlab.com/{org}/{repo}/-/merge_requests/new
  3. Copy this description:

---
{full generated description}
---

Remember to mark it as Draft before creating.
```

---

## Step 9: Success Output

On successful creation:
```
Draft [PR/MR] created successfully!

URL: {pr-url}
Branch: {branch} -> main
Status: Draft

Commits included:
  - {commit 1 summary}
  - {commit 2 summary}
  - ...

Next steps:
  1. Review the PR/MR description for accuracy
  2. Add screenshots or videos if applicable
  3. Run tests and ensure CI passes
  4. Mark as ready for review when complete
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

Your work is exactly as it was before running /create-pr.
```

---

## Important Constraints

### No AI Attribution
**NEVER** add these to commits:
- `Generated with [Claude Code]`
- `Co-Authored-By: Claude`
- Any mention of AI assistance

Per the recreate-commits skill requirements, this would cause issues.

### Always Draft
**ALWAYS** create PRs/MRs as Draft:
- GitHub: Use `--draft` flag
- GitLab: Use `--draft` flag or `Draft:` title prefix

Never create a ready-for-review PR/MR directly.

### Preserve Authorship
**NEVER** modify git config or add AI as author. All commits should reflect the user's authorship.

### Complete All Steps
Even for simple changes, invoke both skills:
1. `recreate-commits` for clean commit history
2. `mr-pr-description-generator` for comprehensive description

This ensures consistency across all PRs/MRs.
