# State Preservation and Rollback

Use this reference for `/kramme:pr:create` Step 5 (before invoking destructive sub-skills) and Step 10 (abort path).

## Agent-tracked state

The values below are **agent state, not shell variables**. Each Bash invocation runs in its own shell, so set-then-reuse across calls (`X=...` then `$X` later) will not work. Capture each value once, then substitute the literal value into every later command emitted by the skill.

Track these throughout the workflow:

- `{entry-branch}` / `{entry-commit}` — immutable invocation entry state captured in Step 2; `{entry-branch}` may be `<detached>`.
- `{feature-branch}` — selected and validated in Step 3 without mutation.
- `{feature-branch-created}` — `true` only when Step 5 creates `{feature-branch}` from `{entry-commit}`.
- `{original-branch}` — the validated feature branch immediately before history rewriting.
- `{original-commit}` — the feature-branch tip immediately before the temporary include commit and history rewriting.
- `{rollback-origin-ref}` — `refs/heads/{original-branch}`, captured before history rewriting.
- `{rollback-origin-oid}` — always `<absent>` for a run that may continue; an existing remote ref is a blocker before history rewriting.
- `{base-source-ref}` / `{base-ref}` / `{base-branch}` — validated source ref, pinned 40-character base commit, and branch metadata captured in Step 2.
- `{uncommitted-disposition}` — `none`, `committed-for-inclusion`, or `excluded-and-stashed`.
- `{include-commit}` — temporary commit created from uncommitted work when the user chooses to include it; otherwise `<none>`.
- `{stash-created}` — `true` only when Step 5.2 temporarily stashed excluded uncommitted changes, otherwise `false`.
- `{stash-message}` — unique stash message used for excluded uncommitted changes; otherwise `<none>`.
- `{recreate-input-tip}` — validated full `HEAD` OID after the include/exclude decision and immediately before Step 6.
- `{recreate-backup-ref}` — conservative input-tip-specific recovery branch name passed to `recreate-commits`.

## Step 5: State Preservation

### 5.1 Prove Remote Absence and Prepare the Feature Branch

`{feature-branch}`, `{entry-branch}`, and `{entry-commit}` already passed the trust boundary in the branch-selection reference. Revalidate them directly before mutation. Set `{rollback-origin-ref}` to `refs/heads/{feature-branch}`, then query the authoritative remote state before creating or switching any branch:

```bash
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads origin "{rollback-origin-ref}"
```

Require the query to succeed and continue only when it returns no matching ref. Capture `<absent>` as `{rollback-origin-oid}`. A network, authentication, repository, or malformed-output failure is a blocker and must leave the invocation on its entry checkout.

If the successful query returns a full OID, stop before branch creation or `kramme:git:recreate-commits`. Never check out or adopt that remote branch.

If `{branch-action}=create-from-entry-head`, create the branch from the immutable entry commit:

```bash
git checkout -b "{feature-branch}" "{entry-commit}"
```

Require success, verify the current branch is exactly `{feature-branch}`, and set `{feature-branch-created}=true`. If branch creation returns non-zero, verify the entry checkout is still intact and stop without deleting any ref. This invocation has no ownership proof for a same-name ref after a failed creation, even when it points at `{entry-commit}`.

If the entry checkout was already `{feature-branch}`, do not switch and keep `{feature-branch-created}=false`.

Now capture and validate the pre-rewrite feature state:

```bash
git branch --show-current # -> {original-branch}
git rev-parse HEAD        # -> {original-commit}
```

Require `{original-branch}` to equal `{feature-branch}` and `{original-commit}` to be a full 40-character lowercase commit ID. A Git ref lease can protect a branch OID, but it cannot atomically prevent another actor from opening a Pull Request between a GitHub PR check and a force-push. Neither `--auto` nor `--authorize-history-rewrite` may bypass the remote-absence requirement.

Initialize state after recording the branch and commit:

- `{uncommitted-disposition}` = `none`
- `{include-commit}` = `<none>`
- `{stash-created}` = `false`
- `{stash-message}` = `<none>`

### 5.2 Decide Uncommitted Changes

If `git status --porcelain` (from Step 4.1) reported no output, continue with the initialized state above.

If uncommitted changes are present and `AUTO_MODE=true`, do not prompt. Select **Commit and include** and execute that path below. Auto mode treats all current tracked, untracked, and unignored working-tree changes as work to include in the PR; the temporary commit makes them available to `kramme:git:recreate-commits`.

If uncommitted changes are present and `AUTO_MODE=false`, do **not** silently stash, commit, or ignore them. Show the current status, then ask:

```yaml
header: "Uncommitted work"
question: "Include uncommitted changes in this PR?"
options:
  - label: "Commit and include"
    description: "Create a temporary commit so recreate-commits can reorganize the work into the PR"
  - label: "Exclude from PR"
    description: "Temporarily stash these changes, create the PR from committed work only, then restore them locally"
  - label: "Abort"
    description: "Leave the working tree unchanged and stop"
multiSelect: false
```

#### If "Commit and include"

Run:

```bash
INDEX_PATH=$(git rev-parse --git-path index)
if ! INDEX_BACKUP=$(mktemp "${INDEX_PATH}.create-pr.XXXXXX"); then
  echo "Error: Failed to create a backup path for the original Git index." >&2
  exit 1
fi
if ! cp -p "$INDEX_PATH" "$INDEX_BACKUP"; then
  rm -f "$INDEX_BACKUP"
  echo "Error: Failed to back up the original Git index." >&2
  exit 1
fi

if git add -A && git commit -m "Include uncommitted changes for PR creation"; then
  rm -f "$INDEX_BACKUP"
else
  INCLUDE_STATUS=$?
  if ! mv -f "$INDEX_BACKUP" "$INDEX_PATH"; then
    echo "Error: Failed to restore the original Git index. Backup remains at $INDEX_BACKUP." >&2
    exit 1
  fi
  echo "Error: Failed to create temporary include commit; restored the original Git index." >&2
  exit "$INCLUDE_STATUS"
fi
git rev-parse HEAD
```

Capture the new commit hash as `{include-commit}` and set `{uncommitted-disposition}` = `committed-for-inclusion`. Before staging, the command block copies the real Git index with its metadata. If either `git add -A` or the temporary commit fails, it restores that exact index file so the original staged/unstaged split and index permissions are preserved; if restoration itself fails, it surfaces the backup path for manual recovery. The block exits before printing a hash on any failure. This temporary commit is intentionally plain-English; `kramme:git:recreate-commits` will replace it with the final narrative commits.

If index-backup creation, staging, or the commit fails and the original index was restored successfully, execute Step 5.3 when `{feature-branch-created}=true`, then stop and surface the error. If index restoration itself fails, retain the current branch and backup path for manual recovery. Do not continue into `recreate-commits` with a dirty working tree.

#### If "Exclude from PR"

Run:

```bash
STASH_MESSAGE="create-pr-excluded-$(date +%s)-$$"
if ! git stash push --include-untracked -m "$STASH_MESSAGE"; then
  echo "Error: Failed to stash excluded uncommitted changes." >&2
  exit 1
fi
printf 'STASH_MESSAGE=%s\n' "$STASH_MESSAGE"
printf 'POST_STASH_COMMIT_COUNT=%s\n' "$(git rev-list --count "{base-ref}..HEAD")"
```

Capture the value after `STASH_MESSAGE=` as `{stash-message}` and the value after `POST_STASH_COMMIT_COUNT=` as the post-stash commit count. Do not infer either value from unlabeled `git stash push` output. Set `{stash-created}` = `true` and `{uncommitted-disposition}` = `excluded-and-stashed` only after the labeled output is captured.

If `git stash push` fails, search the stash list for the exact unique message before any cleanup. If a matching stash exists, retain the current feature branch and surface the stash ref for manual recovery because the mutation outcome is ambiguous. If no matching stash exists, the original worktree remains present; execute Step 5.3 when `{feature-branch-created}=true`, then stop.

If the post-stash commit count is `0`, immediately restore the stash using the Step 9.0 command block. After a successful restore, execute Step 5.3 when `{feature-branch-created}=true`, then abort. If restore fails, retain the current feature branch and use early-abort wording rather than saying PR creation succeeded.

```
Error: No PR changes remain after excluding uncommitted work.

The only detected changes were uncommitted, and you chose to exclude them from this PR. Those changes were restored locally and were not shipped.
```

For all later previews and success output, do not count excluded uncommitted files as "changes to ship"; list them as local work excluded from the PR instead.

#### If "Abort"

If Step 5 created the feature branch but has not created an include commit or stash, execute the early branch cleanup below. Otherwise abort immediately without further mutation.

Before leaving Step 5 on any continuing path, capture the current full 40-character `HEAD` OID as `{recreate-input-tip}`. Construct `{recreate-backup-ref}` as `{feature-branch}-recreate-backup-{recreate-input-tip}` using the entire OID, apply the same conservative branch-name validator, and record it for Step 6. A retry with an identical input tip reuses the exact-tip backup; a retry with a newly created temporary include commit gets a different recovery ref and cannot be blocked by the older backup.

### 5.3 Early Branch Cleanup

Use this only when Step 5 created `{feature-branch}` and no temporary include commit or stash needs restoration—for example, the user aborted at the uncommitted-work question, the include commit failed after restoring the original index, or an exclusion stash was restored because no committed changes remained.

1. Verify the current feature branch still points exactly to `{original-commit}`.
2. Return to `{entry-branch}` with `git checkout "{entry-branch}"`, or to detached `{entry-commit}` with `git checkout --detach "{entry-commit}"`.
3. Delete `{feature-branch}` only after verifying it was created by this invocation and still points to `{original-commit}`. Use `git branch -d "{feature-branch}"`; if Git refuses, retain it and report the branch instead of forcing deletion.

Never use this cleanup after an include commit, stash, or history rewrite; use Step 10 for those states.

## Step 9.0: Restore Excluded Uncommitted Changes

Execute before Step 9 success output and before any post-push PR creation failure output. If `{stash-created}` is `false`, no action is required.

If `{stash-created}` is `true`, find the current stash ref by `{stash-message}` and pop it:

```bash
STASH_REF=$(git stash list --format='%gd %s' | grep -F "{stash-message}" | head -1 | awk '{print $1}')
if [ -z "$STASH_REF" ]; then
  echo "Warning: Excluded uncommitted changes stash '{stash-message}' was not found."
else
  git stash pop "$STASH_REF"
fi
```

After a successful pop, verify no stash entry with `{stash-message}` remains:

```bash
if git stash list --format='%s' | grep -F "{stash-message}" > /dev/null; then
  echo "Warning: Excluded uncommitted changes were restored, but stash '{stash-message}' still exists. Inspect with: git stash list"
fi
```

If pop fails with conflicts, do not resolve silently. Report whether PR creation had already succeeded:

```
Warning: Excluded uncommitted changes could not be restored cleanly.

{If PR creation already succeeded: "PR creation succeeded, but local excluded work needs manual restoration."}

Your excluded local changes are still safe in the stash. Inspect with:
  git stash list
  git stash show -p <matching-stash-ref>

Resolve manually when ready.
```

## Step 10: Abort and Rollback

Execute when the user aborts at any confirmation, or when a critical failure path in Steps 6–8 routes here. All commands below use the captured agent-tracked state — substitute literal values when emitting.

### 10.1 Return to Original State

Before checkout/reset, validate `{original-branch}` and `{original-commit}` exactly as the captured Step 5 values. `{original-branch}` must pass `git check-ref-format --branch`, contain no whitespace or shell metacharacters, and must not begin with `-`. `{original-commit}` must be a full 40-character lowercase hex commit ID that exists locally. If either value fails validation, stop and surface the captured values for manual recovery instead of running checkout or reset.

After validation, switch back to the validated feature branch and restore its tip, worktree, and index to the validated original commit. Use quoted, already-validated arguments only; do not interpolate unvalidated captured values into a shell command string.

Use the explicit commands below after validation:

```bash
git checkout "{original-branch}"
git reset --hard "{original-commit}"
```

`recreate-commits` rewrites history on the feature branch in place, so resetting to `{original-commit}` restores the pre-rewrite commit graph. Do not delete `{recreate-backup-ref}` automatically; its input-tip suffix prevents a restored retry with a new temporary include commit from colliding with it, while an identical retry reuses it.

### 10.2 Restore Stashed Changes

If `{uncommitted-disposition}` is `committed-for-inclusion`, first require `{include-commit}` to be a full 40-character lowercase commit ID that exists locally. Restore the uncommitted work from that validated commit after the reset:

```bash
if git cherry-pick --no-commit "{include-commit}"; then
  git reset
else
  CHERRY_PICK_STATUS=$?
  echo "CHERRY_PICK_STATUS=$CHERRY_PICK_STATUS" >&2
  exit "$CHERRY_PICK_STATUS"
fi
```

If the cherry-pick fails, surface the commit hash instead of resolving silently:

```
Warning: Restored to {original-branch} at {original-commit}, but the temporary include commit could not be reapplied cleanly.

Your changes are still safe in commit {include-commit}. Inspect with:
  git show {include-commit}
  git cherry-pick --no-commit {include-commit}

Resolve manually when ready.
```

Only if `{stash-created}` is `true`, restore the excluded uncommitted changes using the same stash lookup as Step 9.0:

```bash
STASH_REF=$(git stash list --format='%gd %s' | grep -F "{stash-message}" | head -1 | awk '{print $1}')
if [ -z "$STASH_REF" ]; then
  echo "Warning: Stash '{stash-message}' was not found."
else
  git stash pop "$STASH_REF"
fi
```

If pop fails (merge conflict against the now-reset working tree), surface the stash ref to the user instead of resolving silently:

```
Warning: Restored to {original-branch} at {original-commit}, but `git stash pop` reported a conflict.

Your changes are still safe in the stash. Inspect with:
  git stash list
  git stash show -p <matching-stash-ref>

Resolve manually when ready.
```

### 10.3 Return to the Invocation Entry Checkout

After local feature restoration succeeds:

- If `{feature-branch-created}=false`, `{entry-branch}` and `{original-branch}` are the same; remain on the restored feature branch.
- If `{feature-branch-created}=true`, return to validated `{entry-branch}`, or use detached `{entry-commit}` when the invocation began detached.
- After returning successfully, verify the created feature branch still points exactly to `{original-commit}` and delete it with `git branch -d "{feature-branch}"`. If verification fails or Git refuses deletion, retain the branch and report it; never force-delete an uncertain branch.

### 10.4 Confirm Rollback

Query `{rollback-origin-ref}` again with the same `git ls-remote --heads origin "{rollback-origin-ref}"` procedure. Compare the observed OID (or `<absent>`) with `{rollback-origin-oid}`. This is a read-only proof: never force-push, delete, or recreate the remote ref during automatic rollback.

Classify the result as:

- `unchanged` — the observed OID or absence exactly matches the captured baseline.
- `diverged` — the observed OID or absence differs from the captured baseline. Report both values and state that automatic rollback restored only the local branch; coordinate before changing the remote.
- `unverified` — the final remote query failed or returned malformed output. Report the error and do not imply anything about remote restoration.

Use the matching remote-state line in the result instead of claiming that all pre-skill state was restored:

```
Operation Aborted

Restored local state:
  - Feature branch: {original-branch} restored to {original-commit}
  - Entry checkout: {entry-branch at entry-commit | detached at entry-commit}
  - Invocation-created feature branch: {not applicable | deleted after verified restoration | retained for manual inspection}
  - Uncommitted changes: {restored from temporary include commit | restored from excluded-work stash | none to restore}

Remote state: {unchanged at captured OID/absence | diverged — expected {rollback-origin-oid}, observed {observed-origin-oid}; not modified automatically | unverified — {remote-query-error}}

The local feature state and invocation entry checkout have been restored as reported above. Remote restoration is claimed only when the read-only comparison reports `unchanged`.
```

Pick the `Uncommitted changes:` line based on `{uncommitted-disposition}`. If uncommitted work was restored from `{include-commit}`, staging may need to be redone, but the file contents are preserved.
