---
name: kramme:git:clean-gone-branches
description: Find local git branches whose upstream remote branch is gone, list associated worktrees, label Conductor workspace paths, and delete only after explicit confirmation. Use for local branch hygiene after remote branches are merged or deleted. Not for deleting the current branch, deleting active worktrees, pruning without review, or rewriting history.
argument-hint: "[--prune] [--delete --yes <branch>...] [--force]"
disable-model-invocation: true
user-invocable: true
---

# Clean Gone Branches

List local branches whose upstream is marked `[gone]`, then optionally delete safe candidates after confirmation.

## Workflow

1. Parse `$ARGUMENTS`.
   - Default: discovery only.
   - `--prune`: run `git fetch --prune` before discovery. This updates remote-tracking refs but does not delete local branches.
   - `--delete`: request local branch deletion. Delete mode requires the exact confirmed branch names as positional arguments.
   - `--yes`: required with `--delete`; only pass it after the user explicitly confirms the displayed plan.
   - `--force`: use `git branch -D` instead of `git branch -d`. Ask for separate explicit confirmation before using this.

2. Resolve `SKILL_DIR` to the directory containing this `SKILL.md`, then run discovery from the user's current workspace:

   ```bash
   "$SKILL_DIR/scripts/clean-gone-branches.sh"
   ```

   Do not `cd` into the skill directory; the script intentionally inspects the current git repository. Pass `--prune` only when the user asked for a fresh remote-pruned view.

3. Review the output:
   - Branches marked `current` must not be deleted.
   - Branches marked `checked-out` are attached to a worktree and must be skipped by this skill.
   - Branches marked `conductor-workspace` point at a Conductor workspace path and require the user to review or archive that workspace before removal.

4. If no deletion was requested, stop after the report.

5. If deletion was requested:
   - Show the candidate list to the user.
   - Capture the exact branch names from that displayed candidate list. This is the confirmed delete set.
   - Confirm they want to delete the unblocked local branches in that exact set.
   - If `--force` is present, separately confirm that unmerged local work may be discarded from those branch refs.
   - Run:

     ```bash
     CONFIRMED_BRANCHES=(branch-a branch-b)
     "$SKILL_DIR/scripts/clean-gone-branches.sh" --delete --yes "${CONFIRMED_BRANCHES[@]}"
     ```

     Add `--force` only when already confirmed. Do not pass `--prune` in delete mode; if the remote-pruned view needs refreshing, rerun discovery with `--prune`, show the new candidate list, and confirm that new exact set before deleting.

6. Report deleted, skipped, and failed branches. If a branch is skipped because a worktree exists, suggest `git worktree list` or `/kramme:git:worktree list` for inspection rather than deleting the worktree automatically.

## Safety Rules

- Never delete the current branch.
- Never delete a branch that is checked out in any worktree.
- Never remove worktree directories from this skill.
- Never pass `--yes` before the user has confirmed the exact deletion plan.
- Never run delete mode without passing the exact confirmed branch names.
- Never pass `--prune` in delete mode; pruning belongs to discovery before confirmation.
- Prefer `git branch -d`; use `--force` only after explicit confirmation.
