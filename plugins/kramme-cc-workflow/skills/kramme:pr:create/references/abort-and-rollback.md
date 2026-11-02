# Abort and Rollback

Use this reference for `$kramme:pr:create` Step 10 only. It applies when `FRESH_REMOTE_MODE=true` or `REMOTE_APPEND_MODE=true` and uses the agent-tracked state defined in `state-and-rollback.md` and captured in Step 5. Clean exact-tip and fast-forward modes never execute it.

## Step 10: Abort and Rollback

Execute when the user aborts at any confirmation, or when a critical failure path in Steps 6–8 routes here. All commands below use the captured agent-tracked state — substitute literal values when emitting.

### 10.0 Refuse Rollback After Local Drift

When `REMOTE_APPEND_MODE=true`, derive `{rollback-expected-tip}` before any checkout, reset, cherry-pick, or stash operation:

- If `{publication-commit}` was captured as a valid full commit OID, use it. This covers failures after successful commit recreation.
- Otherwise require `{recreate-input-tip}` to be a valid full commit OID that still exists locally and use it. This permits safe recovery when `recreate-commits` failed before changing the prepared input tip.
- If neither value is valid, refuse automatic rollback and preserve the current state for manual recovery.

After validating `{original-branch}` and `{original-commit}` exactly as described in Step 10.1, prove that rollback would touch only the prepared state owned by this invocation. Run the final guard and reset in one bounded shell invocation so another tool call cannot separate the ownership proof from the destructive transition:

```bash
ROLLBACK_CURRENT_BRANCH=$(git branch --show-current) || exit 1
ROLLBACK_CURRENT_TIP=$(git rev-parse HEAD) || exit 1
if ! "{pr-create-skill-dir}/scripts/verify-clean-worktree.sh" \
  || [ "$ROLLBACK_CURRENT_BRANCH" != "{feature-branch}" ] \
  || [ "$ROLLBACK_CURRENT_TIP" != "{rollback-expected-tip}" ]; then
  echo "Prepared append state drifted; refusing automatic rollback." >&2
  exit 1
fi
git reset --keep "{original-commit}"
```

If `{rollback-expected-tip}` is unavailable, any guard fails, or `git reset --keep` refuses because the worktree changed, do not execute the remainder of Step 10. Preserve the current checkout, `{include-commit}`, and `{recreate-backup-ref}`, and report that the incomplete or unexpected local state must be recovered manually. This permits rollback from the unchanged pre-recreation input or the validated completed recreation while preventing partial rewrites, edits, commits, resets, or checkout changes from being erased. Never substitute `git reset --hard` in remote-append mode.

### 10.1 Return to Original State

Before checkout/reset, validate `{original-branch}` and `{original-commit}` exactly as the captured Step 5 values. `{original-branch}` must pass `git check-ref-format --branch`, contain no whitespace or shell metacharacters, and must not begin with `-`. `{original-commit}` must be a full 40-character lowercase hex commit ID that exists locally. If either value fails validation, stop and surface the captured values for manual recovery instead of running checkout or reset.

In `REMOTE_APPEND_MODE`, Step 10.0 already required the current feature branch and restored it with the guarded `git reset --keep`; do not run another checkout or reset here.

In `FRESH_REMOTE_MODE`, after validation, switch back to the validated feature branch and restore its tip, worktree, and index to the validated original commit. Use quoted, already-validated arguments only; do not interpolate unvalidated captured values into a shell command string.

Use the explicit commands below after validation only in fresh mode:

```bash
git checkout "{original-branch}"
git reset --hard "{original-commit}"
```

`recreate-commits` rewrites history on the feature branch in place, so the mode-specific reset to `{original-commit}` restores the pre-rewrite commit graph. Do not delete `{recreate-backup-ref}` automatically; its input-tip suffix prevents a restored retry with a new temporary include commit from colliding with it, while an identical retry reuses it.

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

Query `{rollback-origin-ref}` again with the shell tool's bounded timeout and the same strict one-line parser used during classification. Disable terminal and credential-manager prompting in both modes:

```bash
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads origin "{rollback-origin-ref}"
```

Use that form in fresh mode. In remote-append mode, insert the unchanged serialized assignment first and query only through its shell variable:

```bash
{origin-push-url-assignment}
NONINTERACTIVE_GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_SSH_COMMAND="$NONINTERACTIVE_GIT_SSH_COMMAND" \
  git ls-remote --heads -- "$ORIGIN_PUSH_URL" "{rollback-origin-ref}"
```

Compare the strictly parsed observed OID (or `<absent>`) with `{rollback-origin-oid}`. A command failure, malformed response, or prompt requirement classifies the result as `unverified`. This is a read-only proof: never force-push, delete, or recreate the remote ref during automatic rollback.

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
