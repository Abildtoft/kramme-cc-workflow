# State Preservation and Rollback

Use this reference for `/kramme:pr:create` Step 5 (before invoking destructive sub-skills) and Step 10 (abort path).

## Agent-tracked state

The values below are **agent state, not shell variables**. Each Bash invocation runs in its own shell, so set-then-reuse across calls (`X=...` then `$X` later) will not work. Capture each value once, then substitute the literal value into every later command emitted by the skill.

Track these throughout the workflow:

- `{original-branch}` — branch the workflow started on.
- `{original-commit}` — commit `HEAD` pointed at when the workflow started.
- `{base-branch}` — detected default branch from Step 2 (`main`, `master`, or whatever `git symbolic-ref refs/remotes/origin/HEAD` resolves to).
- `{uncommitted-disposition}` — `none`, `committed-for-inclusion`, or `excluded-and-stashed`.
- `{include-commit}` — temporary commit created from uncommitted work when the user chooses to include it; otherwise `<none>`.
- `{stash-created}` — `true` only when Step 5.2 temporarily stashed excluded uncommitted changes, otherwise `false`.
- `{stash-message}` — unique stash message used for excluded uncommitted changes; otherwise `<none>`.

## Step 5: State Preservation

### 5.1 Record Original State

Run each command and capture the output as the named template value:

```bash
git branch --show-current # -> {original-branch}
git rev-parse HEAD        # -> {original-commit}
```

Initialize state after recording the branch and commit:

- `{uncommitted-disposition}` = `none`
- `{include-commit}` = `<none>`
- `{stash-created}` = `false`
- `{stash-message}` = `<none>`

### 5.2 Decide Uncommitted Changes

If `git status --porcelain` (from Step 4.1) reported no output, continue with the initialized state above.

If uncommitted changes are present, do **not** silently stash, commit, or ignore them. Even when `AUTO_MODE=true`, this is a required user decision because only committed history is rebuilt by `kramme:git:recreate-commits`.

Show the current status, then ask:

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
if ! cp "$INDEX_PATH" "$INDEX_BACKUP"; then
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

Capture the new commit hash as `{include-commit}` and set `{uncommitted-disposition}` = `committed-for-inclusion`. Before staging, the command block copies the real Git index. If either `git add -A` or the temporary commit fails, it restores that exact index file so the original staged/unstaged split is preserved; if restoration itself fails, it surfaces the backup path for manual recovery. The block exits before printing a hash on any failure. This temporary commit is intentionally plain-English; `kramme:git:recreate-commits` will replace it with the final narrative commits.

If staging or the commit fails, stop and surface the error. Do not continue into `recreate-commits` with a dirty working tree.

#### If "Exclude from PR"

Run:

```bash
STASH_MESSAGE="create-pr-excluded-$(date +%s)"
if ! git stash push --include-untracked -m "$STASH_MESSAGE"; then
  echo "Error: Failed to stash excluded uncommitted changes." >&2
  exit 1
fi
printf 'STASH_MESSAGE=%s\n' "$STASH_MESSAGE"
printf 'POST_STASH_COMMIT_COUNT=%s\n' "$(git rev-list --count origin/{base-branch}..HEAD)"
```

Capture the value after `STASH_MESSAGE=` as `{stash-message}` and the value after `POST_STASH_COMMIT_COUNT=` as the post-stash commit count. Do not infer either value from unlabeled `git stash push` output. The command block exits before printing either labeled value if the stash fails. Set `{stash-created}` = `true` and `{uncommitted-disposition}` = `excluded-and-stashed`.

If the post-stash commit count is `0`, immediately restore the stash using the Step 9.0 command block, then abort. If restore fails, use early-abort wording rather than saying PR creation succeeded.

```
Error: No PR changes remain after excluding uncommitted work.

The only detected changes were uncommitted, and you chose to exclude them from this PR. Those changes were restored locally and were not shipped.
```

For all later previews and success output, do not count excluded uncommitted files as "changes to ship"; list them as local work excluded from the PR instead.

#### If "Abort"

Abort immediately without running any git mutation.

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

After validation, switch back to the validated original branch and restore the branch tip, worktree, and index to the validated original commit. Use quoted, already-validated arguments only; do not interpolate captured branch or commit values into a shell command string.

`recreate-commits` rewrites history on the current branch in place, so resetting to `{original-commit}` is what restores the pre-skill commit graph. Do **not** delete any branches here — this skill does not create temporary branches.

### 10.2 Restore Stashed Changes

If `{uncommitted-disposition}` is `committed-for-inclusion`, restore the uncommitted work from `{include-commit}` after the reset:

```bash
if git cherry-pick --no-commit {include-commit}; then
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

### 10.3 Confirm Rollback

```
Operation Aborted

Restored state:
  - Branch: {original-branch}
  - Commit: {original-commit}
  - Uncommitted changes: {restored from temporary include commit | restored from excluded-work stash | none to restore}

Your work has been restored to the pre-skill branch state.
```

Pick the `Uncommitted changes:` line based on `{uncommitted-disposition}`. If uncommitted work was restored from `{include-commit}`, staging may need to be redone, but the file contents are preserved.
