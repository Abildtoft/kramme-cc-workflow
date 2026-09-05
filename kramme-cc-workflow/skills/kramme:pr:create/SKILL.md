---
name: kramme:pr:create
description: Create a PR from the current branch with a generated description and attach useful screenshot/video evidence when observable behavior can be captured. Rewrites unpublished work into narrative commits, recovers an exact-tip remote, or safely appends committed and auto-included local work when the existing remote is at or behind local HEAD.
argument-hint: "[--auto] [--draft] [--linear-issue <ISSUE-ID>] [--require-generated-description] [--authorize-history-rewrite]"
disable-model-invocation: true
user-invocable: true
---

# Create Pull Request

Orchestrate the creation of a clean, well-documented PR by validating git state, preparing unpublished commits when applicable, generating a description, safely publishing or reusing the remote branch, and creating the PR via `gh`.

## When NOT to use this skill

- Branch already has an open PR — update it directly (or use `kramme:pr:generate-description` to refresh the description) instead of running the full creation flow.
- The feature branch exists on `origin` and contains commits absent locally, has genuinely diverged, or is not the current branch. Existing-remote modes never merge, switch branches, or rewrite published history; coordinate and use a fresh branch when the remote cannot be safely reused or fast-forwarded. Dirty existing branches are accepted only in `--auto` mode, which explicitly includes all local work.
- Hotfix / cherry-pick that must preserve exact commit boundaries — `recreate-commits` will reorganize history. Push and `gh pr create` manually.
- Working in a stacked-PR setup where the base is another feature branch — this skill assumes the repo default branch (resolved via `origin/HEAD`) as the PR base. Use `kramme:pr:stack` instead: it creates and submits the whole chain with correct base branches via the gh-stack CLI.
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
Step 4  Changes detection + remote mode ... fresh rewrite; exact recovery; safe fast-forward
    |
Step 4.5 Reject stacked branches
    |
    +-- Fresh remote: Steps 5–6 preserve state + recreate commits
    |
    +-- Existing exact tip, clean: skip rewrite and preserve existing commits
    |
    +-- Existing ancestor tip, clean: skip rewrite and preserve/publish local commits
    |
    +-- Existing safe tip, dirty + --auto: preserve published commits,
                                         recreate only the unpublished tail
    |
Step 7  Generate description + best-effort demo evidence
    |
Step 8  Preview + confirmation
        - Abort        --> Step 10 rollback only when rewrite state exists
        - Edit         --> loop until user confirms
        - Create       --> publish/reuse branch + gh pr create
    |
Step 9  Success output
```

## Workflow rule — do not stop mid-flow

The fresh-remote and remote-append paths invoke Steps 6 and 7 via the Skill tool. Exact-tip recovery and clean remote fast-forward mode skip Step 6 and invoke only Step 7 because both preserve the existing local commit history. After a sub-skill returns, **continue to the next step in this skill**. Do not summarize and wait for user input between sub-skills. The only stop points are: the Step 5 uncommitted-work decision when `AUTO_MODE=false`, a confirmation prompt that explicitly requires input, a `--auto`-suppressed prompt that hits a hard blocker, or a routed-to Step 10 abort.

## References

- `references/pre-validation-checks.md` — Step 1: repository safety checks.
- `references/branch-and-platform-handling.md` — Steps 2–3: entry-state capture, immutable-base resolution, ref validation, mutation-free feature-branch selection, and authoritative remote-tip classification.
- `references/state-and-rollback.md` — Steps 5 and 10: state capture, stash handling, abort/rollback.
- `references/confirmation-and-creation.md` — Steps 8–9: preview, confirmation, edit loop, absence- or OID-leased publication, exact-tip reuse, repeatable `gh pr create --attach` flags, draft mode, and success output.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for optional flags before starting:

- `--auto` -> set `AUTO_MODE=true` and `REQUIRE_GENERATED_DESCRIPTION=true`, then remove the flag from the remaining arguments. Auto mode authorizes the nested unstacked rewrite but does not synthesize the separate stack-wide authorization capability.
- `--draft` -> set `DRAFT_MODE=true` and remove the flag from the remaining arguments.
- `--linear-issue <ISSUE-ID>` -> validate the value against `[A-Za-z0-9]+-[0-9]+`, normalize it to uppercase, store it as `LINEAR_ISSUE_OVERRIDE`, and remove the flag and value. Reject a missing or invalid value before pre-validation. This caller-supplied identifier is authoritative and takes precedence over branch-name extraction.
- `--require-generated-description` -> set `REQUIRE_GENERATED_DESCRIPTION=true` and remove the flag. This orchestration-only safety mode forbids placeholder fallback when `kramme:pr:generate-description` returns no usable output.
- `--authorize-history-rewrite` -> set `AUTHORIZE_HISTORY_REWRITE=true` and remove the flag. This explicit capability lets a non-auto invocation skip the nested, backup-protected unstacked reset confirmation. Stacked branches are rejected before state preservation and must use `kramme:pr:stack`; this flag never widens `pr:create` into a stacked-PR workflow. Auto mode does not set this variable. Neither mode relaxes branch, existing-PR, or path-specific remote-state checks. Backup and remote absence apply to the fresh-remote rewrite path; exact-tip recovery never pushes; clean remote fast-forward mode preserves local history; remote append rewrites only the unpublished tail after its captured remote OID. Every existing-remote publication uses a lease tied to that OID.

Defaults: `AUTO_MODE=false`, `DRAFT_MODE=false`, `REQUIRE_GENERATED_DESCRIPTION=false`, `AUTHORIZE_HISTORY_REWRITE=false`. Flag order is not significant.

`--auto` means:

- use the recommended commit structure (`Narrative`)
- invoke downstream skills in non-interactive mode
- include all uncommitted changes by selecting **Commit and include**, including on a safely reusable existing remote
- require a usable generated title and description; never publish placeholder fallback content
- authorize the nested, backup-protected unstacked history rewrite on the fresh-remote path or the unpublished tail of a safe existing remote; published commits are never rewritten
- skip the final PR confirmation
- choose the recommended branch-handling path from the shared reference instructions
- stop only on hard blockers

`--auto` is fully non-interactive: while `AUTO_MODE=true`, never ask the user a question, wait for free-form user input, or allow Git/GitHub credential prompts. Choose a documented deterministic fallback when one exists; otherwise report the hard blocker, execute Step 10 when state preservation has started and no publication was attempted, and stop. After any push attempt, use only the mode-specific outcome handling in Step 8; never infer that a non-zero command result makes destructive local rollback safe. It still stops on failed validation, missing dependencies or required context, an existing Pull Request, remote-only work, genuine divergence, an unsafe or changing existing-remote boundary, backup creation failure, lease mismatch, or any other hard blocker.

`--draft` means:

- create the PR as a draft (`gh pr create --draft`).

Without `--draft`, the PR is created ready for review.

---

## Step 1: Pre-Validation

Read the pre-validation checks from `references/pre-validation-checks.md`. Run all checks (GitHub CLI install/authentication, git repo, merge conflicts, rebase/merge in progress, remote configuration) and abort on any failure.

---

## Steps 2-3: Branch Handling

Read the branch and base selection instructions from `references/branch-and-platform-handling.md`. Capture `{entry-branch}` / `{entry-commit}`, resolve one validated remote `{base-source-ref}`, pin its full commit OID as immutable `{base-ref}`, retain `{base-branch}` as metadata, select a validated `{feature-branch}`, capture `{observed-origin-oid}`, and record `{branch-action}` without creating, deleting, or switching branches. Keep these values for the entire invocation.

### Conductor workspaces

Synced Conductor workspace boundary contract (keep aligned across git-mutating workflow skills): when `CONDUCTOR_WORKSPACE_PATH` is set: stay on the current branch absent explicit approval; use another Conductor workspace—not raw worktrees or throwaway branches—for isolation. Never remove, reset, or re-point a Conductor workspace path; archive workspaces through Conductor. Conductor changes defaults, not permissions or safety gates.

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
if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
  echo "Could not inspect the working tree; stop before preparing the Pull Request." >&2
  exit 1
fi
printf '%s\n' "$WORKTREE_STATUS"
```

Capture the exact output as `{worktree-status}`. The explicit `--untracked-files=all` overrides a local `status.showUntrackedFiles=no` setting, and a failed inspection is a blocker rather than empty output.

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

## Step 4.4: Finalize the Remote Mode

Initialize `FRESH_REMOTE_MODE=false`. Initialize `REMOTE_RECOVERY_MODE=false`. Initialize `REMOTE_FAST_FORWARD_MODE=false`. Initialize `REMOTE_APPEND_MODE=false`.

If `{branch-action}` is `use-current` or `create-from-entry-head`, require `{observed-origin-oid}=<absent>` and set `FRESH_REMOTE_MODE=true`.

If `{branch-action}=reuse-existing-exact-tip`, first require all of these stable-current-branch conditions:

- `{entry-branch}` and `{feature-branch}` are the same validated current branch.
- `{observed-origin-oid}` and `{entry-commit}` are the same full commit OID.
- A fresh `git branch --show-current` still returns `{feature-branch}`.
- A fresh `git rev-parse HEAD` still returns `{entry-commit}`.

When `{worktree-status}` from Step 4.1 is empty, resolve `{pr-create-skill-dir}` as the directory containing this skill's `SKILL.md`, run `"{pr-create-skill-dir}/scripts/verify-clean-worktree.sh"`, require success, and set `REMOTE_RECOVERY_MODE=true`. This final clean-tree proof forces full untracked-file visibility, detects modified assume-unchanged tracked content, and fails closed when Git cannot inspect either state.

This path exists for an already-published branch that has no open Pull Request, including recovery after an earlier run pushed successfully but `gh pr create` failed. It preserves the existing commit history, performs no state-preservation mutation, and never invokes `kramme:git:recreate-commits`. A matching OID is proof that the remote already contains the exact committed tree selected for the Pull Request; it is not authorization to rewrite that ref.

If `{branch-action}=fast-forward-existing-remote`, require the same current-branch and unchanged-`HEAD` checks. Also require `{origin-push-url-assignment}` to be the single frozen, shell-quoted endpoint assignment resolved during classification, require `{observed-origin-oid}` to differ from `{entry-commit}`, and rerun `git merge-base --is-ancestor "{observed-origin-oid}" "{entry-commit}"`; any failure or execution error is a blocker. When `{worktree-status}` is empty, run the clean-worktree helper, require success, set `{publication-commit}={entry-commit}`, and set `REMOTE_FAST_FORWARD_MODE=true`.

The clean fast-forward path preserves the local commits exactly as authored and never invokes `kramme:git:recreate-commits`. Step 8 must revalidate the local tip, frozen push endpoint, remote OID, clean tree, and strict-ancestor relationship, then update that endpoint with immutable `{publication-commit}` and a lease tied to `{observed-origin-oid}`. A changed remote tip must fail even when it remains an ancestor of local `HEAD`.

When either existing-remote branch action has non-empty `{worktree-status}`, require `AUTO_MODE=true`; a non-auto invocation stops without mutating the worktree because it has no explicit include decision. When `AUTO_MODE=true`, route dirty existing-remote work to `REMOTE_APPEND_MODE` only after all of these checks succeed:

- Revalidate the same current branch and unchanged `{entry-commit}` requirements used by the clean mode.
- Resolve and freeze `{origin-push-url-assignment}` with `scripts/resolve-origin-push-url.sh` when exact-tip classification did not already do so. The helper must reject inline credentials, other credential-bearing URL syntax, executable remote-helper forms, and unsupported transports before returning an assignment. Preserve its shell-quoted assignment bytes; never carry the decoded URL as agent state or substitute it directly into later shell source.
- Query that frozen endpoint with the strict `git ls-remote` boundary from branch classification. Require the frozen endpoint to remain at `{observed-origin-oid}`.
- Require `git merge-base --is-ancestor "{observed-origin-oid}" "{entry-commit}"` to succeed. Equality is valid here; remote append will create unpublished commits from the dirty work.

Set `REMOTE_APPEND_MODE=true` only after these checks. This mode preserves all commits through `{observed-origin-oid}`, executes Step 5 to include the dirty work, and invokes `kramme:git:recreate-commits --after {observed-origin-oid}` so it rewrites only the unpublished tail after the observed remote tip. Published history is outside the reset boundary.

Require exactly one of `FRESH_REMOTE_MODE`, `REMOTE_RECOVERY_MODE`, `REMOTE_FAST_FORWARD_MODE`, and `REMOTE_APPEND_MODE` to be `true` before continuing.

---

## Step 4.5: Reject Stacked Branches

Resolve stack membership before state preservation or history rewriting:

```bash
STACK_RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-stack-membership.sh") || {
  echo "Stack membership could not be determined; stop before preparing the Pull Request." >&2
  exit 1
}
eval "$STACK_RESOLVED"
if [ "$STACK_MEMBERSHIP" != "none" ]; then
  echo "kramme:pr:create does not publish stacked branches; use kramme:pr:stack instead." >&2
  exit 1
fi
```

Both locally tracked and server-side stacks stop here. Do not pass stack authorization through to the nested rewrite: this workflow publishes at most one lease-protected branch and creates one default-base Pull Request, so it cannot safely own restacking, whole-stack publication, or per-branch Pull Request bases.

---

## Step 5: State Preservation

If `REMOTE_RECOVERY_MODE=true` or `REMOTE_FAST_FORWARD_MODE=true`, skip Steps 5 and 6 and continue directly to Step 7. No rollback state is needed because neither mode has mutated the checkout or remote yet.

Otherwise, require either `FRESH_REMOTE_MODE=true` with `{observed-origin-oid}=<absent>` or `REMOTE_APPEND_MODE=true` with `AUTO_MODE=true`, then read `references/state-and-rollback.md` and execute Step 5. Fresh mode repeats the authoritative remote-absence check, may create the validated feature branch, and follows the existing include/exclude decision for uncommitted work. Remote append instead revalidates the captured existing-remote boundary and always includes its dirty work. Both capture `{original-branch}` / `{original-commit}` as the pre-rewrite feature state and derive retry-safe `{recreate-backup-ref}` from the resulting input tip. Keep all entry, feature, and rollback values as agent-tracked state.

---

## Step 6: Invoke recreate-commits Skill

This step applies when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`. Clean existing-remote modes already skipped here from Step 5 and preserve the existing local commit history.

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

**IMPORTANT:** Use the Skill tool to invoke `recreate-commits`. Always pass `--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --require-unstacked --no-push` so the nested rewrite retains branch metadata, uses the same pinned base commit, gets a retry-safe recovery ref, and enforces this workflow's unstacked-only authorization while this orchestrator remains the sole remote-mutation owner. When `REMOTE_APPEND_MODE=true`, also pass `--after {observed-origin-oid}` so the published prefix cannot be rewritten. Also pass `--auto` when `AUTO_MODE=true`, and pass `--authorize-history-rewrite` only when the user supplied that flag and `AUTHORIZE_HISTORY_REWRITE=true`. Step 4.5 already proved the branch is unstacked; any later stack detection is state drift and `--require-unstacked` must stop the nested skill before reset. When both variables are explicitly true, pass both flags.

Examples:

```yaml
skill: "kramme:git:recreate-commits", args: "--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --require-unstacked --no-push"
skill: "kramme:git:recreate-commits", args: "--base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --require-unstacked --no-push --authorize-history-rewrite"
skill: "kramme:git:recreate-commits", args: "--auto --base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --require-unstacked --no-push"
skill: "kramme:git:recreate-commits", args: "--auto --base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --require-unstacked --no-push --authorize-history-rewrite"
skill: "kramme:git:recreate-commits", args: "--auto --base {base-source-ref} --base-commit {base-ref} --backup-ref {recreate-backup-ref} --after {observed-origin-oid} --require-unstacked --no-push"
```

The final example is the only remote-append invocation. After it returns, capture the rewritten local `HEAD` as `{publication-commit}`. Require a full 40-character lowercase commit OID, require it to differ from `{observed-origin-oid}`, and require `git merge-base --is-ancestor "{observed-origin-oid}" "{publication-commit}"` to succeed before Step 7. On any postcondition failure, execute Step 10 and stop.

This skill will:

- Analyze all changes against immutable `{base-ref}`
- Plan a logical commit sequence
- Create narrative-quality commits
- Leave the remote unchanged so Step 8 can perform one absence- or OID-leased publication after description generation succeeds
- **NEVER include AI attribution** (no "Generated with Claude Code" or Co-Authored-By)

When it returns, continue to Step 7. See the "Workflow rule" near the top of this skill.

### 6.3 Handle Skill Failure

**If the skill fails or encounters an error:**

Execute Step 10 first and capture whether local rollback completed or was refused, plus its remote-state classification. Then report:

```
Error: The recreate-commits skill encountered an issue.

Local rollback baseline:
  - Branch: {original-branch}
  - Commit: {original-commit}

What happened:
  {skill error message}

Recovery:
  1. Local recovery: {restored the local branch and included or excluded work | refused automatic rollback because the prepared state drifted; inspect the retained checkout and recovery refs}
  2. Check the Step 10 remote-state result; `--no-push` should leave the baseline unchanged, and any unexpected divergence is reported
  3. Check git status to confirm
  4. Try again with /kramme:pr:create
```

**Action:** Abort after reporting the captured Step 10 outcome.

---

## Step 7: Invoke pr-description-generator Skill

### 7.1 Invoke the Skill

Before invoking the generator, run `env GH_PROMPT_DISABLED=1 gh pr create --help` and inspect its successful output for the exact `--attach file` flag. This proves only that the installed CLI accepts attachment syntax; repository permissions, authentication type, and GitHub host support are rechecked by `gh` at the Step 8.4 creation boundary. Set `ATTACHMENTS_SUPPORTED=true` only when both the help command and flag check succeed; otherwise set it to `false`, record that the installed GitHub CLI lacks usable attachment support, and continue without visual capture.

Invoke `kramme:pr:generate-description` via the Skill tool. Always pass `--auto --no-update --base {base-source-ref} --base-commit {base-ref}` because this orchestrator owns the review/edit gate, the sub-skill must use the same pinned base commit while retaining branch metadata, and it must neither prompt mid-flow nor mutate an existing PR before Step 8 confirmation; also pass `--visual --for-pr-create` when `ATTACHMENTS_SUPPORTED=true`, so the generator can decide from the pinned diff whether observable behavior warrants capture and knows this exact parent owns the manifest handoff. When `{linear-issue-id}` is set, also pass `--linear-issue {linear-issue-id}` so the generator uses the validated identifier instead of re-extracting it from the branch.

The skill will:

- Analyze git diff and commit history
- Check for Linear issue references in branch name
- Generate a conventional commit-style **title** (`<type>(<scope>): <description>`)
- Generate a comprehensive description
- When supported and applicable, delegate local screenshot/video capture and return `DEMO_EVIDENCE_MANIFEST` outside the PR body

When it returns, continue to Step 8. See the "Workflow rule" near the top of this skill.

### 7.2 Capture the Title and Description

Capture the generated title, the full description for Step 8, and any uppercase output markers from the generator. `DEMO_EVIDENCE_MANIFEST:` is a local orchestration handoff, not body content; never include that marker or its path in `{description}`.

Before preview or publication, require a usable title and body:

- Title is one line, at most 72 characters, and matches `^(feat|fix|refactor|docs|test|build|ci|chore|perf|style|revert)(\([a-z0-9][a-z0-9-]*\))?!?: .+$`.
- Body is non-empty and contains none of the literal fallback placeholders `[Brief description of changes]`, `[Implementation approach]`, or an unresolved `MISSING REQUIREMENT:`.

If either check fails, treat the generator output as unusable. In auto mode, execute Step 10 when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`; in a clean existing-remote mode, stop without rollback because no mutation occurred. In interactive mode, require corrected content before Step 8.

If `{linear-issue-id}` is captured from branch handling, normalize the generated description before preview:

- Default to `Closes {linear-issue-id}` for the Linear auto-close line.
- If the generator used `Fixes {linear-issue-id}` or `Resolves {linear-issue-id}`, replace that line with `Closes {linear-issue-id}`.
- If the generator already linked `{linear-issue-id}` with a non-closing keyword (`Related to`, `Refs`, or `References`), preserve that link and do not add a separate `Closes {linear-issue-id}` line.
- If the description has no auto-close line for `{linear-issue-id}`, add `Closes {linear-issue-id}` in the issue-linking location used by the generated body, or append it at the end if no better location exists.
- Do not override an explicit user instruction to use a different keyword (`Fixes`, `Resolves`, `Refs`, `Related to`, etc.).

If the generator emits a `MISSING REQUIREMENT:` marker, do **not** proceed to Step 8 or create the PR from the incomplete description unless it is the exact documented non-blocking "no Linear ID" advisory. Every other `MISSING REQUIREMENT:` marker is blocking, including database-migration rationale/rollback-plan gaps, feature-flag rollout-context gaps, breaking-contract SemVer/migration gaps, ambiguous selectable-template gaps, and any future requirement the generator marks as missing. This classification is marker-based so the caller cannot drift behind the generator's blocking-condition list.

- If `AUTO_MODE=true`, route to Step 10 rollback when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`; in a clean existing-remote mode, stop without rollback. Surface the marker as the reason.
- Otherwise, stop before Step 8 and ask the user for the missing context. After the user supplies it, revise `{description}` to include the context before previewing. If the user chooses not to supply it, route to Step 10 when `FRESH_REMOTE_MODE=true`, or stop without rollback in either clean existing-remote mode. Remote append is auto-only, so it cannot enter this interactive branch.

The non-blocking "no Linear ID" marker may be surfaced in the run output without blocking PR creation.

### 7.3 Handle Skill Failure

If the skill returns no usable output and either `AUTO_MODE=true` or `REQUIRE_GENERATED_DESCRIPTION=true`, emit `MISSING REQUIREMENT: generated PR title/body unavailable; placeholder publication is forbidden`. Execute Step 10 rollback when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true`; in a clean existing-remote mode, stop without rollback. Stop before Step 8 in every mode.

Otherwise, use `AskUserQuestion` to offer **Retry generation**, **Provide title and body**, or **Abort**. Validate manually supplied content with the same title/body checks above and apply the `{linear-issue-id}` normalization from Step 7.2. Never create a Pull Request containing placeholder fallback text.

### 7.4 Prepare Demo Evidence Attachments

Initialize `ATTACH_ARGS` as an empty shell array, `DEMO_ATTACHMENT_COUNT=0`, and `{demo-evidence-status}` to the Step 7.1 capability result.

When `ATTACHMENTS_SUPPORTED=true` and the generator returned exactly one `DEMO_EVIDENCE_MANIFEST: <path>` marker, require the whole path to match `^/[A-Za-z0-9._/: -]+/manifest\.json$` before putting it in a shell command. Resolve `{pr-create-skill-dir}` to the directory containing this `SKILL.md` and run:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) || exit 1
python3 "{pr-create-skill-dir}/scripts/prepare-demo-attachments.py" \
  --repo-root "$REPO_ROOT" \
  --manifest "{demo-evidence-manifest}"
```

Capture stdout as JSON. Never `eval`, source, or render it as shell code. Require `schema_version: 1`, a recognized non-skipped tier, a one-line description, and one through 50 attachments. The helper enforces the `.context/demo-reels/` containment boundary, direct regular files, supported GitHub image/video extensions and size limits, matching media kinds, unique paths, one-line alt descriptions, and no symlink traversal.

Retain the validated manifest path rather than rendering attachment values into shell source. At the creation boundary, the helper will emit NUL-delimited `flag_value` records that are read directly into `ATTACH_ARGS`. Image values include `#<alt text>`; video values do not because GitHub renders video as a player without alt text. Never construct a command string, use `eval`, or interpolate attachment values as shell syntax. Set `DEMO_ATTACHMENT_COUNT` from the validated array and `{demo-evidence-status}` to `{tier}: {description}`.

If the marker is missing, duplicated, malformed, or the helper rejects it, keep `ATTACH_ARGS` empty, record the reason in `{demo-evidence-status}`, and continue. Demo capture and attachment preparation are best-effort and must not block an otherwise valid PR. Never put a local evidence path in `{description}`. Let `gh` append successfully uploaded evidence inline at the end of the body; do not invent local Markdown references or reorder a repository PR template to position the media.

---

## Step 8: Confirmation and Creation

Read `references/confirmation-and-creation.md` and execute Step 8 from that file. It contains the preview format, confirmation prompt, edit loop, fresh-branch absence-leased push, exact-tip reuse, existing-branch OID-leased publication, repeatable `gh pr create --attach` arguments, and failure handling. Substitute `{base-branch}`, `{base-source-ref}`, `{base-ref}`, `{entry-commit}`, `{publication-commit}`, `{observed-origin-oid}`, the shell-quoted `{origin-push-url-assignment}` for an existing-remote publication, `{original-branch}`, `{rollback-origin-ref}`, the validated title, generated description, `ATTACH_ARGS`, `DEMO_ATTACHMENT_COUNT`, and `{demo-evidence-status}` when emitting commands. Never substitute a decoded push URL into shell source. Carry `{linear-issue-id}` into Step 8 if captured so edited descriptions still follow the Linear closing-keyword policy.

---

## Step 9: Success Output

Before printing the final success message, execute Step 9.0 from `references/state-and-rollback.md` only when `FRESH_REMOTE_MODE=true` so any excluded uncommitted changes are restored or explicitly reported. Existing-remote modes skip Step 9.0; clean modes created no stash, and remote append committed all dirty work for inclusion. Then use Step 9 in `references/confirmation-and-creation.md` for the final success message. Preserve the draft-specific wording when `DRAFT_MODE=true`.

---

## Step 10: Abort and Rollback Handling

Triggered by an "Abort" choice in Step 8 when `FRESH_REMOTE_MODE=true`, by a critical failure in Steps 6–8 on the fresh path, or by a critical failure before any remote-append push attempt when `REMOTE_APPEND_MODE=true`. Execute Step 10 from `references/state-and-rollback.md`, which first refuses destructive rollback if the prepared append checkout drifted, otherwise restores the pre-rewrite feature state and uncommitted work, returns to the invocation entry branch when this run created the feature branch, and reports observed remote state without mutating it. Clean existing-remote modes never execute Step 10 because they do not rewrite local history or create rollback state. After any remote-append push attempt, preserve the prepared local state and use Step 8's read-only outcome classification instead of Step 10.

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

### Complete Every Applicable Step

For a fresh remote branch, invoke both sub-skills:

1. `kramme:git:recreate-commits` for clean commit history
2. `kramme:pr:generate-description` for a comprehensive description and best-effort reviewer evidence when `gh pr create --attach` is available

This keeps PRs consistent across the workflow.

For exact-tip recovery and clean remote fast-forward mode, invoke only `kramme:pr:generate-description`. Skipping `kramme:git:recreate-commits` preserves the current local commit history; fast-forward mode publishes those same commits without replacing remote-only work. Remote append invokes recreation with `--after {observed-origin-oid}`, preserving published history while turning all local dirty work into the narrative-quality unpublished commits that Step 8 publishes.
