# State Preservation and Rollback

Use this reference for `/kramme:pr:create` Step 5 (before invoking destructive sub-skills) and Step 10 (abort path).

## Agent-tracked state

The values below are **agent state, not shell variables**. Each Bash invocation runs in its own shell, so set-then-reuse across calls (`X=...` then `$X` later) will not work. Capture each value once, then substitute the literal value into every later command emitted by the skill.

Track these throughout the workflow:

- `{original-branch}` — branch the workflow started on.
- `{original-commit}` — commit `HEAD` pointed at when the workflow started.
- `{base-branch}` — detected default branch from Step 2 (`main`, `master`, or whatever `git symbolic-ref refs/remotes/origin/HEAD` resolves to).
- `{stash-created}` — `true` if Step 5.2 created a stash, otherwise `false`.

## Step 5: State Preservation

### 5.1 Record Original State

Run each command and capture the output as the named template value:

```bash
git branch --show-current   # -> {original-branch}
git rev-parse HEAD          # -> {original-commit}
```

### 5.2 Stash Uncommitted Changes

If `git status --porcelain` (from Step 4.1) reported any output, stash:

```bash
git stash push -m "create-pr-backup-$(date +%s)"
```

Set `{stash-created}` = `true`. Otherwise set `{stash-created}` = `false`.

## Step 10: Abort and Rollback

Execute when the user aborts at any confirmation, or when a critical failure path in Steps 6–8 routes here. All commands below use the captured agent-tracked state — substitute literal values when emitting.

### 10.1 Return to Original State

```bash
git checkout {original-branch}
git reset --hard {original-commit}
```

`recreate-commits` rewrites history on the current branch in place, so resetting to `{original-commit}` is what restores the pre-skill commit graph. Do **not** delete any branches here — this skill does not create temporary branches.

### 10.2 Restore Stashed Changes

Only if `{stash-created}` is `true`:

```bash
git stash pop
```

If pop fails (merge conflict against the now-reset working tree), surface the stash ref to the user instead of resolving silently:

```
Warning: Restored to {original-branch} at {original-commit}, but `git stash pop` reported a conflict.

Your changes are still safe in the stash. Inspect with:
  git stash list
  git stash show -p stash@{0}

Resolve manually when ready.
```

### 10.3 Confirm Rollback

```
Operation Aborted

Restored state:
  - Branch: {original-branch}
  - Commit: {original-commit}
  - Uncommitted changes: {restored from stash | none to restore}

Your work is exactly as it was before running /kramme:pr:create.
```

Pick the `Uncommitted changes:` line based on `{stash-created}`.
