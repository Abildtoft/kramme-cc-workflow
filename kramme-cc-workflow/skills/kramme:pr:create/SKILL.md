---
name: kramme:pr:create
description: Use when creating a PR from the current branch with narrative-quality commits and a generated description. Orchestrates branch setup, commit restructuring via kramme:git:recreate-commits, and description generation via kramme:pr:generate-description before pushing and opening the PR via gh.
argument-hint: "[--auto] [--draft] [--linear-issue <ISSUE-ID>] [--require-generated-description] [--authorize-history-rewrite]"
disable-model-invocation: true
user-invocable: true
---

# Create Pull Request

Orchestrate the creation of a clean, well-documented PR by validating git state, setting up the branch, recreating commits as a narrative, generating a description, and pushing + creating the PR via `gh`.

## When NOT to use this skill

- Branch already has an open PR — update it directly (or use `kramme:pr:generate-description` to refresh the description) instead of running the full creation flow.
- The feature branch already exists on `origin`, even without a Pull Request — this new-Pull-Request workflow cannot atomically lock GitHub PR creation while rewriting an existing remote ref. Coordinate and use a fresh branch.
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
Step 2  Capture entry state + pin base ({base-source-ref}, {base-ref}, {base-branch})
Step 3  Select and validate feature branch without switching
    |
Step 3.5 Existing-PR check ................. abort before rewriting
    |
Step 4  Changes detection ................. abort if nothing to ship
    |
Step 5  Require absent remote ref; create branch from entry HEAD; preserve local state
    |
Step 6  Invoke kramme:git:recreate-commits  --> on failure, Step 10 rollback
    |
Step 7  Invoke kramme:pr:generate-description (fail closed in auto mode)
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
- `references/branch-and-platform-handling.md` — Steps 2–3: entry-state capture, immutable-base resolution, ref validation, and mutation-free feature-branch selection.
- `references/state-and-rollback.md` — Steps 5 and 10: state capture, stash handling, abort/rollback.
- `references/confirmation-and-creation.md` — Steps 8–9: preview, confirmation, edit loop, push, `gh pr create`, draft mode, success output.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for optional flags before starting:

- `--auto` -> set `AUTO_MODE=true`, `AUTHORIZE_HISTORY_REWRITE=true`, and `REQUIRE_GENERATED_DESCRIPTION=true`, then remove the flag from the remaining arguments.
- `--draft` -> set `DRAFT_MODE=true` and remove the flag from the remaining arguments.
- `--linear-issue <ISSUE-ID>` -> validate the value against `[A-Za-z0-9]+-[0-9]+`, normalize it to uppercase, store it as `LINEAR_ISSUE_OVERRIDE`, and remove the flag and value. Reject a missing or invalid value before pre-validation. This caller-supplied identifier is authoritative and takes precedence over branch-name extraction.
- `--require-generated-description` -> set `REQUIRE_GENERATED_DESCRIPTION=true` and remove the flag. This orchestration-only safety mode forbids placeholder fallback when `kramme:pr:generate-description` returns no usable output.
- `--authorize-history-rewrite` -> set `AUTHORIZE_HISTORY_REWRITE=true` and remove the flag. This explicit capability lets a non-auto invocation skip the nested, backup-protected local reset confirmation for the validated feature branch. `--auto` implies the same capability because narrative history recreation is an intrinsic part of this workflow. Neither mode relaxes branch, backup, clean-tree, existing-PR, remote-absence, or force-with-lease checks.

Defaults: `AUTO_MODE=false`, `DRAFT_MODE=false`, `REQUIRE_GENERATED_DESCRIPTION=false`, `AUTHORIZE_HISTORY_REWRITE=false`. Flag order is not significant.

`--auto` means:

- use the recommended commit structure (`Narrative`)
- invoke downstream skills in non-interactive mode
- include all uncommitted changes by selecting **Commit and include**
- require a usable generated title and description; never publish placeholder fallback content
- authorize the nested, backup-protected local history rewrite after the existing-PR and remote-absence checks pass
- skip the final PR confirmation
- choose the recommended branch-handling path from the shared reference instructions
- stop only on hard blockers

`--auto` is fully non-interactive: while `AUTO_MODE=true`, never ask the user a question, wait for free-form user input, or allow Git/GitHub credential prompts. Choose a documented deterministic fallback when one exists; otherwise report the hard blocker, execute Step 10 when state preservation has already started, and stop. It still stops on failed validation, missing dependencies or required context, an existing Pull Request or remote branch, backup creation failure, lease mismatch, or any other hard blocker.

`--draft` means:

- create the PR as a draft (`gh pr create --draft`).

Without `--draft`, the PR is created ready for review.

---

## Step 1: Pre-Validation

Read the pre-validation checks from `references/pre-validation-checks.md`. Run all checks (GitHub CLI install/authentication, git repo, merge conflicts, rebase/merge in progress, remote configuration) and abort on any failure.

---

## Steps 2-3: Branch Handling

Read the branch and base selection instructions from `references/branch-and-platform-handling.md`. Capture `{entry-branch}` / `{entry-commit}`, resolve one validated remote `{base-source-ref}`, pin its full commit OID as immutable `{base-ref}`, retain `{base-branch}` as metadata, and select a validated `{feature-branch}` without creating, deleting, or switching branches. Keep these values for the entire invocation.

---

## Step 3.5: Reject an Existing Pull Request

After branch handling selects `{feature-branch}`, revalidate it before state capture, history rewriting, or any shell command in this file that interpolates it. The branch reference already requires the same boundary before its own commands; this is defense in depth.

Inspect the agent-tracked value directly. Require the whole string to match `[A-Za-z0-9][A-Za-z0-9._/-]*`; reject a leading `-`, whitespace, shell metacharacters, or any other character outside that allowlist.

Only after that check passes, run `git check-ref-format --branch "{feature-branch}"` and require it to succeed. This intentionally conservative boundary may reject an unusual Git-valid branch rather than execute an untrusted branch value.

With the validated value, query GitHub:

```bash
env GH_PROMPT_DISABLED=1 gh pr list --head "{feature-branch}" --state open --limit 100 --json number,url,state,headRefName
```

Require this command to succeed. Authentication, network, repository, rate-limit, and API errors are blockers, not evidence that no Pull Request exists. Continue only when the successful response is an empty list. If an open Pull Request exists, stop and report its URL; update it directly or use `kramme:pr:fix-ci --no-consolidate` instead of running the creation workflow.

---

## Step 4: Changes Detection

### 4.1 Check for Uncommitted Changes

```bash
git status --porcelain
```

### 4.2 Check for Commits Ahead of Base

```bash
git rev-list --count "{base-ref}..HEAD"
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

Read `references/state-and-rollback.md` and execute Step 5. It repeats the authoritative remote-absence check before mutation, creates the validated feature branch directly from `{entry-commit}` only when `{branch-action}=create-from-entry-head`, captures `{original-branch}` / `{original-commit}` as the pre-rewrite feature state, handles uncommitted-work inclusion or exclusion, and derives retry-safe `{recreate-backup-ref}` from the resulting input tip. Keep all entry, feature, and rollback values as agent-tracked state.

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

**IMPORTANT:** Use the Skill tool to invoke `recreate-commits`. Always pass `--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push` so the nested rewrite retains branch metadata, uses the same pinned base commit, and gets a retry-safe recovery ref while this orchestrator remains the sole remote-mutation owner. Also pass `--auto` when `AUTO_MODE=true`, and pass `--authorize-history-rewrite` whenever `AUTHORIZE_HISTORY_REWRITE=true`. Because Step 0 sets that authorization in auto mode, every auto invocation must include all those flags plus `--auto --authorize-history-rewrite` and must not pause at the nested reset confirmation.

Examples:

```yaml
skill: "kramme:git:recreate-commits", args: "--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push"
skill: "kramme:git:recreate-commits", args: "--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push --authorize-history-rewrite"
skill: "kramme:git:recreate-commits", args: "--auto --base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --no-push --authorize-history-rewrite"
```

This skill will:

- Analyze all changes against immutable `{base-ref}`
- Plan a logical commit sequence
- Create narrative-quality commits
- Leave the remote absent so Step 8 can perform one absence-leased publication after description generation succeeds
- **NEVER include AI attribution** (no "Generated with Claude Code" or Co-Authored-By)

When it returns, continue to Step 7. See the "Workflow rule" near the top of this skill.

### 6.3 Handle Skill Failure

**If the skill fails or encounters an error:**

```
Error: The recreate-commits skill encountered an issue.

Local rollback baseline:
  - Branch: {original-branch}
  - Commit: {original-commit}

What happened:
  {skill error message}

Recovery:
  1. Rollback restored the local branch and any included or excluded uncommitted work
  2. Check the Step 10 remote-state result; `--no-push` should leave the baseline unchanged, and any unexpected divergence is reported
  3. Check git status to confirm
  4. Try again with /kramme:pr:create
```

**Action:** Execute Step 10 (rollback via `references/state-and-rollback.md`), then abort.

---

## Step 7: Invoke pr-description-generator Skill

### 7.1 Invoke the Skill

Invoke `kramme:pr:generate-description` via the Skill tool. Always pass `--auto --no-update --base {base-source-ref} --base-commit {base-ref}` because this orchestrator owns the review/edit gate, the sub-skill must use the same pinned base commit while retaining branch metadata, and it must neither prompt mid-flow nor mutate an existing PR before Step 8 confirmation. When `{linear-issue-id}` is set, also pass `--linear-issue {linear-issue-id}` so the generator uses the validated identifier instead of re-extracting it from the branch.

The skill will:

- Analyze git diff and commit history
- Check for Linear issue references in branch name
- Generate a conventional commit-style **title** (`<type>(<scope>): <description>`)
- Generate a comprehensive description

When it returns, continue to Step 8. See the "Workflow rule" near the top of this skill.

### 7.2 Capture the Title and Description

Capture the generated title, the full description for Step 8, and any uppercase output markers from the generator.

Before preview or publication, require a usable title and body:

- Title is one line, at most 72 characters, and matches `^(feat|fix|refactor|docs|test|build|ci|chore|perf|style|revert)(\([a-z0-9][a-z0-9-]*\))?!?: .+$`.
- Body is non-empty and contains none of the literal fallback placeholders `[Brief description of changes]`, `[Implementation approach]`, or an unresolved `MISSING REQUIREMENT:`.

If either check fails, treat the generator output as unusable. In auto mode, execute Step 10 and stop. In interactive mode, require corrected content before Step 8.

If `{linear-issue-id}` is captured from branch handling, normalize the generated description before preview:

- Default to `Closes {linear-issue-id}` for the Linear auto-close line.
- If the generator used `Fixes {linear-issue-id}` or `Resolves {linear-issue-id}`, replace that line with `Closes {linear-issue-id}`.
- If the generator already linked `{linear-issue-id}` with a non-closing keyword (`Related to`, `Refs`, or `References`), preserve that link and do not add a separate `Closes {linear-issue-id}` line.
- If the description has no auto-close line for `{linear-issue-id}`, add `Closes {linear-issue-id}` in the issue-linking location used by the generated body, or append it at the end if no better location exists.
- Do not override an explicit user instruction to use a different keyword (`Fixes`, `Resolves`, `Refs`, `Related to`, etc.).

If the generator emits a `MISSING REQUIREMENT:` marker, do **not** proceed to Step 8 or create the PR from the incomplete description unless it is the exact documented non-blocking "no Linear ID" advisory. Every other `MISSING REQUIREMENT:` marker is blocking, including database-migration rationale/rollback-plan gaps, feature-flag rollout-context gaps, breaking-contract SemVer/migration gaps, ambiguous selectable-template gaps, and any future requirement the generator marks as missing. This classification is marker-based so the caller cannot drift behind the generator's blocking-condition list.

- If `AUTO_MODE=true`, route to Step 10 rollback and surface the marker as the reason.
- Otherwise, stop before Step 8 and ask the user for the missing context. After the user supplies it, revise `{description}` to include the context before previewing; if the user chooses not to supply it, route to Step 10 rollback.

The non-blocking "no Linear ID" marker may be surfaced in the run output without blocking PR creation.

### 7.3 Handle Skill Failure

If the skill returns no usable output and either `AUTO_MODE=true` or `REQUIRE_GENERATED_DESCRIPTION=true`, emit `MISSING REQUIREMENT: generated PR title/body unavailable; placeholder publication is forbidden`, execute Step 10 rollback, and stop before Step 8.

Otherwise, use `AskUserQuestion` to offer **Retry generation**, **Provide title and body**, or **Abort**. Validate manually supplied content with the same title/body checks above and apply the `{linear-issue-id}` normalization from Step 7.2. Never create a Pull Request containing placeholder fallback text.

---

## Step 8: Confirmation and Creation

Read `references/confirmation-and-creation.md` and execute Step 8 from that file. It contains the preview format, confirmation prompt, the "Edit description first" loop, draft-mode substitutions, absence-leased push command, `gh pr create` invocation, and failure handling. Substitute `{base-branch}`, `{base-source-ref}`, `{base-ref}`, `{original-branch}`, `{rollback-origin-ref}`, the validated title, and the generated description when emitting commands. Carry `{linear-issue-id}` into Step 8 if captured so edited descriptions still follow the Linear closing-keyword policy.

---

## Step 9: Success Output

Before printing the final success message, execute Step 9.0 from `references/state-and-rollback.md` so any excluded uncommitted changes are restored or explicitly reported. Then use Step 9 in `references/confirmation-and-creation.md` for the final success message. Preserve the draft-specific wording when `DRAFT_MODE=true`.

---

## Step 10: Abort and Rollback Handling

Triggered by an "Abort" choice in Step 8 or a critical failure in Steps 6–8, including a failed push. Execute Step 10 from `references/state-and-rollback.md`, which restores the pre-rewrite feature state and uncommitted work, returns to the invocation entry branch when this run created the feature branch, and reports observed remote state without mutating it.

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
