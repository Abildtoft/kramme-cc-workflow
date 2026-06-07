---
name: kramme:git:worktree
description: Safely list, create, and remove git worktrees with checks for existing paths, checked-out branches, and Conductor workspace directories. Use for manual worktree operations during PR splitting or local parallel development. Not for branch cleanup, deleting gone branches, renaming branches, or bypassing Conductor workspace archival.
argument-hint: "<list|create|remove> [options]"
disable-model-invocation: true
user-invocable: true
---

# Worktree Helper

Guide manual git worktree operations with conservative checks.

## Workflow

1. Parse `$ARGUMENTS`.
   - `list`: show worktrees and label likely Conductor paths.
   - `create --path <path> --branch <branch> [--base <ref>]`: create a new worktree and branch from the base ref. If the branch already exists, attach it only when it is not checked out elsewhere.
   - `remove --path <path> --yes [--force] [--allow-conductor]`: remove a worktree after explicit confirmation.

2. Resolve `SKILL_DIR` to the directory containing this `SKILL.md`, then run the helper from the user's current workspace:

   ```bash
   "$SKILL_DIR/scripts/worktree-helper.sh" list
   ```

   Do not `cd` into the skill directory; the helper intentionally inspects the current git repository. For create/remove, pass only arguments the user explicitly requested.

3. Before `create`, verify:
   - The target path is intentional and not already populated.
   - The branch name is not the current branch unless the user is only listing.
   - The base ref resolves to a commit when provided.
   - The operation does not rename any existing branch.

4. Before `remove`, verify:
   - The user has reviewed `list` output.
   - The path is exactly the worktree to remove.
   - `--yes` is present only after explicit confirmation.
   - `--allow-conductor` is present only after the user confirms the Conductor workspace should be removed outside Conductor's archive flow.
   - `--force` is present only after the user accepts that uncommitted files in the worktree may be discarded.

5. Report the exact command outcome and any skipped safety check.

## Safety Rules

- Do not rename the current branch.
- Do not remove Conductor workspace paths by default.
- Do not remove dirty worktrees without `--force` and explicit confirmation.
- Prefer Conductor's archive workflow for Conductor-created workspaces.
- Prefer `/kramme:git:clean-gone-branches` for stale local branch cleanup.
