# Batch Mode (`--all-open`)

Rebase every open Pull Request of the current user whose head branch is checked out in a clean local worktree of this repository and is behind its base. The plan inventories all open PR heads so a branch stacked on another author's PR is skipped, while only the current user's PRs are eligible for mutation. As in the single-branch flow, a branch that already contains its base but carries merge commits above it is rebased to linearize them. Batch mode is direct-user-only: a model caller never passes `--all-open`.

`{batch-script}` and `{stack-resolver}` are the resolved paths the skill passes in. Run every command from the current repository.

## Rules

- Batch mode never resolves conflicts. A conflicting rebase is aborted and its branch is left at its pre-rebase head.
- Batch mode never stashes; the Git stash stack is shared across worktrees. Dirty worktrees are skipped and rebases run with `--no-autostash`.
- Batch mode never switches, creates, removes, resets, or re-points a worktree. It only rebases the branch a clean worktree already has checked out.
- A branch is eligible only when its local head equals its `origin` head. Each push uses `--force-with-lease` pinned to that head with an explicit refspec, so no unpushed local work is published and no remote-only commit is overwritten.
- The open-PR inventory is capped at 1,000 rows; if `gh` reaches that cap, planning stops with an explicit error instead of silently omitting PRs.
- Stacked branches, fork heads, protected branches, agent isolation worktrees, and branches not checked out locally are reported as skipped.

## Procedure

1. **Plan.** Write the plan to a temporary file. Exit 1 means nothing was planned; report the error and stop.

   ```bash
   PLAN_FILE=$(mktemp "${TMPDIR:-/tmp}/pr-rebase-batch.XXXXXX") || exit 1
   echo "PLAN_FILE=$PLAN_FILE"
   "{batch-script}" plan --stack-resolver "{stack-resolver}" > "$PLAN_FILE" || {
     rm -f "$PLAN_FILE"
     exit 1
   }
   cat "$PLAN_FILE"
   ```

   Preserve the script's `#push-url` metadata line verbatim; it binds apply to the same validated publication endpoint used during planning.

   Shell state does not persist between tool calls, so carry the printed `PLAN_FILE` path into the later steps.

2. **Show the plan.** Print `BATCH PLAN` on its own line, then one Markdown table with PR, branch, base, worktree, action, and reason for every row. If no row has action `rebase`, report that nothing needs rebasing, remove the plan file, and stop.

3. **Confirm once.** Unless `FORCE_PUSH_MODE=true`, use `AskUserQuestion` once:

   > "Rebase and force-push N branches?"
   >
   > - **Rebase and push** - rebase each listed branch onto its base and force-push it with a pinned lease
   > - **Cancel** - change nothing

   List every branch to rebase and force-push with its worktree path in the question, and warn that agent sessions active in those workspaces should be idle first. On **Cancel**, remove the plan file and stop; nothing changed.

4. **Apply.**

   ```bash
   "{batch-script}" apply --plan "$PLAN_FILE" --stack-resolver "{stack-resolver}"
   ```

   The script revalidates each row immediately before rebasing it: the Pull Request is still open with the planned head and base in the same repository, the same branch is still checked out at the planned head, the worktree is clean with no operation in progress, the branch is still unstacked, and `origin` still holds the planned head. Any change skips that row. Exit 1 means the plan file was rejected before anything changed. Exit 2 means an aborted rebase did not restore its worktree; later rows were not processed.

5. **Report.** Render one result table with PR, branch, worktree, result, old head -> new head (short OIDs), and detail. Then remove the plan file with `rm -f "$PLAN_FILE"`.
   - `pushed`: rebased and published.
   - `conflict`: the rebase was aborted and the branch is unchanged.
   - `push-rejected`: the local branch is rebased but the lease rejected the push; the detail names the pre-rebase head for manual recovery. Batch mode never resets it.
   - `error`: name the worktree prominently; it needs manual inspection before anything else runs there.
   - `skipped`: the reason explains why the row was left alone, including a rebase that failed before starting.

   Tell the user that each `conflict`, `push-rejected`, or `error` branch needs a single-branch `/kramme:pr:rebase` in its own workspace. Batch mode does not run CI stabilization; run `/kramme:pr:fix-ci` per Pull Request if needed.
