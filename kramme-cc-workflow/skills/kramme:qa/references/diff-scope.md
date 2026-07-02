# Diff Scope Resolution

Use this during `diff-aware` mode before filtering for UI-relevant files.

Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills): use the shared resolve-base.sh script for base refs; use the shared collect-review-diff.sh script for unified changed-file scope; canonical base priority is explicit --base, PR target branch, then origin/HEAD, origin/main, or origin/master, and canonical diff scope is committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths.

## Base And Changed Files

If `--base <branch>` was provided, set `BASE_BRANCH_OVERRIDE` before running the shared script. Otherwise let the script resolve the PR target branch, then the remote default branch fallback chain. Do not duplicate the fallback logic in this skill.

```bash
COLLECT_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above. Re-run with --base <branch> if the target branch is ambiguous." >&2
  exit 1
}
eval "$RESOLVED"
```

The script exports:

- `BASE_REF`: remote tracking ref for the resolved base.
- `BASE_BRANCH`: normalized base branch name.
- `MERGE_BASE`: merge base between the resolved base and `HEAD`.
- `CHANGED_FILES`: newline-delimited committed PR diff, staged changes, unstaged changes, and untracked files.

Use `CHANGED_FILES` for UI-relevant filtering below. Use `MERGE_BASE` or `BASE_REF` for any later diff commands instead of local branch names.
