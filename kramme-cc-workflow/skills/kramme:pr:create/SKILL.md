---
name: kramme:pr:create
description: Use when creating a PR from the current branch with narrative-quality commits and a generated description. Orchestrates branch setup, commit restructuring via kramme:git:recreate-commits, and description generation via kramme:pr:generate-description before pushing and opening the PR via gh.
argument-hint: "[--auto] [--draft]"
disable-model-invocation: true
user-invocable: true
---

# Create Pull Request

Orchestrate the creation of a clean, well-documented PR by validating git state, setting up the branch, recreating commits as a narrative, generating a description, and pushing + creating the PR via `gh`.

## When NOT to use this skill

- Branch already has an open PR — update it directly (or use `kramme:pr:generate-description` to refresh the description) instead of running the full creation flow.
- Hotfix / cherry-pick that must preserve exact commit boundaries — `recreate-commits` will reorganize history. Push and `gh pr create` manually.
- Working in a stacked-PR setup where the base is another feature branch — this skill assumes the repo default branch (resolved via `origin/HEAD`) as the PR base.
- The current branch hasn't diverged from the base branch — Step 4 will abort, but skip running the skill in the first place.

## Process Overview

```
/kramme:pr:create
    |
    v
Step 1  Pre-Validation .................... abort on any failure
    |
Step 2  Resolve base branch ({base-branch})
Step 3  Branch handling (on base? Linear? upstream?)
    |
Step 4  Changes detection ................. abort if nothing to ship
    |
Step 5  Capture state + decide uncommitted-work handling
    |
Step 6  Invoke kramme:git:recreate-commits  --> on failure, Step 10 rollback
    |
Step 7  Invoke kramme:pr:generate-description (with title-fallback path)
    |
Step 8  Preview + confirmation
        - Abort        --> Step 10 rollback
        - Edit         --> loop until user confirms
        - Create       --> push + gh pr create
    |
Step 9  Success output
```

## Workflow rule — do not stop mid-flow

Steps 6 and 7 each invoke a sub-skill via the Skill tool. After a sub-skill returns, **continue to the next step in this skill**. Do not summarize and wait for user input between sub-skills. The only stop points are: the Step 5 uncommitted-work decision when `AUTO_MODE=false`, a confirmation prompt that explicitly requires input, a `--auto`-suppressed prompt that hits a hard blocker, or a routed-to Step 10 abort.

## References

- `references/pre-validation-checks.md` — Step 1: repository safety checks.
- `references/branch-and-platform-handling.md` — Steps 2–3: base-branch detection, branch creation, Linear lookup, upstream handling.
- `references/state-and-rollback.md` — Steps 5 and 10: state capture, stash handling, abort/rollback.
- `references/confirmation-and-creation.md` — Steps 8–9: preview, confirmation, edit loop, push, `gh pr create`, draft mode, success output.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for optional flags before starting:

- `--auto` -> set `AUTO_MODE=true` and remove the flag from the remaining arguments.
- `--draft` -> set `DRAFT_MODE=true` and remove the flag from the remaining arguments.

Defaults: `AUTO_MODE=false`, `DRAFT_MODE=false`. Flag order is not significant.

`--auto` means:

- use the recommended commit structure (`Narrative`)
- invoke downstream skills in non-interactive mode
- include all uncommitted changes by selecting **Commit and include**
- skip the final PR confirmation
- choose the recommended branch-handling path from the shared reference instructions
- stop only on hard blockers

`--draft` means:

- create the PR as a draft (`gh pr create --draft`).

Without `--draft`, the PR is created ready for review.

---

## Step 1: Pre-Validation

Read the pre-validation checks from `references/pre-validation-checks.md`. Run all checks (GitHub CLI install/authentication, git repo, merge conflicts, rebase/merge in progress, remote configuration) and abort on any failure.

---

## Steps 2-3: Branch Handling

Read the branch handling instructions from `references/branch-and-platform-handling.md`. Validate the branch is a feature branch, detect the base branch (capture as `{base-branch}` — used in later display strings and as the PR base), and handle edge cases (detached HEAD, on base branch, Linear issue integration, no upstream).

---

## Step 4: Changes Detection

### 4.1 Check for Uncommitted Changes

```bash
git status --porcelain
```

### 4.2 Check for Commits Ahead of Base

```bash
git rev-list --count origin/{base-branch}..HEAD
```

### 4.3 Validation

**If both checks return empty/zero:**

```
Error: No changes detected compared to {base-branch}.

Current state:
  - Branch: {feature-branch}
  - Uncommitted changes: None
  - Commits ahead of {base-branch}: 0

Nothing to create a PR for. Make some changes first, then run /kramme:pr:create again.
```

**Action:** Abort.

**If changes exist:** Continue to next step.

---

## Step 5: State Preservation

Read `references/state-and-rollback.md` and execute Step 5 (capture `{original-branch}` / `{original-commit}`, decide whether uncommitted changes are included or excluded, and capture `{stash-created}` only if exclusion requires a temporary stash). Keep these values for the rest of the workflow — they are agent-tracked state, not shell variables.

---

## Step 6: Invoke recreate-commits Skill

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

- Analyze all changes vs `{base-branch}`
- Plan a logical commit sequence
- Create narrative-quality commits
- **NEVER include AI attribution** (no "Generated with Claude Code" or Co-Authored-By)

When it returns, continue to Step 7. See the "Workflow rule" near the top of this skill.

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
  1. Your original work is safe — rollback restored the branch and any included or excluded uncommitted work
  2. Check git status to confirm
  3. Try again with /kramme:pr:create
```

**Action:** Execute Step 10 (rollback via `references/state-and-rollback.md`), then abort.

---

## Step 7: Invoke pr-description-generator Skill

### 7.1 Invoke the Skill

Invoke `kramme:pr:generate-description` via the Skill tool. Always pass `--auto --no-update --base {base-branch}` because this orchestrator owns the review/edit gate and the sub-skill must neither prompt mid-flow nor mutate an existing PR before Step 8 confirmation.

The skill will:

- Analyze git diff and commit history
- Check for Linear issue references in branch name
- Generate a conventional commit-style **title** (`<type>(<scope>): <description>`)
- Generate a comprehensive description

When it returns, continue to Step 8. See the "Workflow rule" near the top of this skill.

### 7.2 Capture the Title and Description

Capture the generated title, the full description for Step 8, and any uppercase output markers from the generator.

If `{linear-issue-id}` is captured from branch handling, normalize the generated description before preview:

- Default to `Closes {linear-issue-id}` for the Linear auto-close line.
- If the generator used `Fixes {linear-issue-id}` or `Resolves {linear-issue-id}`, replace that line with `Closes {linear-issue-id}`.
- If the generator already linked `{linear-issue-id}` with a non-closing keyword (`Related to`, `Refs`, or `References`), preserve that link and do not add a separate `Closes {linear-issue-id}` line.
- If the description has no auto-close line for `{linear-issue-id}`, add `Closes {linear-issue-id}` in the issue-linking location used by the generated body, or append it at the end if no better location exists.
- Do not override an explicit user instruction to use a different keyword (`Fixes`, `Resolves`, `Refs`, `Related to`, etc.).

If the generator emits a blocking `MISSING REQUIREMENT:` marker, do **not** proceed to Step 8 or create the PR from the incomplete description. Blocking markers are the generator's database-migration rationale/rollback-plan gap and feature-flag rollout-context gap.

- If `AUTO_MODE=true`, route to Step 10 rollback and surface the marker as the reason.
- Otherwise, stop before Step 8 and ask the user for the missing context. After the user supplies it, revise `{description}` to include the context before previewing; if the user chooses not to supply it, route to Step 10 rollback.

The non-blocking "no Linear ID" marker may be surfaced in the run output without blocking PR creation.

### 7.3 Handle Skill Failure

If the skill returns no usable output, build a fallback:

**Fallback title** — derive in this order, picking the first that works:

1. `git log --format=%s {base-branch}..HEAD | head -1` if there is at least one commit ahead.
2. Otherwise the current branch name with `/` replaced by `: ` (e.g., `feature/oauth` → `feature: oauth`).
3. Otherwise prompt the user with `AskUserQuestion` (header `"PR title"`, no preset options) — required, do not continue without a title.

**Fallback description**:

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

Apply the same `{linear-issue-id}` normalization from Step 7.2 to the fallback description before preview. If `{linear-issue-id}` is present and the fallback body has no auto-close line or non-closing link for that issue, append `Closes {linear-issue-id}` before continuing unless the user explicitly instructed a different keyword.

Continue to Step 8 with the fallback title and description. When `AUTO_MODE=true`, prefer fallback (1) or (2) over prompting.

---

## Step 8: Confirmation and Creation

Read `references/confirmation-and-creation.md` and execute Step 8 from that file. It contains the preview format, confirmation prompt, the "Edit description first" loop, draft-mode substitutions, push command, `gh pr create` invocation, and failure fallbacks. Substitute `{base-branch}`, `{original-branch}`, the captured title, and the generated or fallback description when emitting commands. Carry `{linear-issue-id}` into Step 8 if captured so edited descriptions still follow the Linear closing-keyword policy.

---

## Step 9: Success Output

Before printing the final success message, execute Step 9.0 from `references/state-and-rollback.md` so any excluded uncommitted changes are restored or explicitly reported. Then use Step 9 in `references/confirmation-and-creation.md` for the final success message. Preserve the draft-specific wording when `DRAFT_MODE=true`.

---

## Step 10: Abort and Rollback Handling

Triggered by an "Abort" choice in Step 8 or a critical failure in Steps 6–8. Execute Step 10 from `references/state-and-rollback.md`, which performs the checkout/reset, restores included or excluded uncommitted work when needed, and prints the rollback confirmation.

---

## Important Constraints

### No AI Attribution

Never add `Generated with [Claude Code]`, `Co-Authored-By: Claude`, or any mention of AI assistance to commits. `recreate-commits` enforces this for commit messages; this skill must not undo it.

### Preserve Authorship

Never modify git config or add AI as author. All commits must reflect the user's authorship.

### Draft Mode (Opt-In)

Draft PRs are opt-in via the `--draft` flag. Default behavior is to create PRs ready for review. Pass `--draft` to `gh pr create` only when `DRAFT_MODE=true`.

### Self-Assignment

This skill creates PRs with `gh pr create --assignee @me`. This is intentional — the author opening the PR is the assignee. If you need to assign someone else, edit the PR after creation.

### Complete All Steps

Even for simple changes, invoke both sub-skills:

1. `kramme:git:recreate-commits` for clean commit history
2. `kramme:pr:generate-description` for a comprehensive description

This keeps PRs consistent across the workflow.
