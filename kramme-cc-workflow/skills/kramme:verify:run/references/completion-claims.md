# Completion Claims

Read this before claiming that a regression test protects a fix, that a delegated agent finished its task, or that requirements are met. The Evidence Before Claims section in `SKILL.md` owns the general rule.

## What each claim needs

- **A test suite passes**: that suite's output on the current tree with zero failures; an earlier or unknown tree is not evidence.
- **Lint, format, or type checks are clean**: the tool's own output with zero errors, not another tool or a partial file list.
- **The build succeeds**: the build command exiting 0; a passing linter says nothing about compilation.
- **A bug is fixed**: the original reproduction, run again, now behaving correctly.
- **A regression test protects the fix**: the red-green check below.
- **A delegated agent finished**: its claimed changes present in the diff and checked like your own work; its report is a claim, not evidence.
- **Requirements are met**: each requirement compared with the change one at a time, with gaps reported.

## Red-green check for a regression test

A regression test earns trust only if it fails without the fix. Take the fix out with a uniquely tagged stash entry and restore it by commit ID. Every worktree of a repository shares one stash list, including parallel Conductor workspaces and other agent sessions, so never run a bare `git stash pop` or assume the entry is still `stash@{0}`.

```bash
RG_TAG="kramme-red-green-$(date +%s)-$$"
git stash push --include-untracked --message "$RG_TAG" -- <files changed by the fix>
RG_SHA=$(git stash list --format='%H %gs' | awk -v tag="$RG_TAG" 'index($0, tag) { print $1; exit }')
[ -n "$RG_SHA" ] || { echo "No red-green stash entry was created; stop and inspect git stash list." >&2; exit 1; }
```

1. Run the regression test. It must fail; if it passes, it does not protect the fix, so report that.
2. Restore the fix with `git stash apply "$RG_SHA"`. On a conflict, stop: the entry stays listed under `$RG_TAG` and `$RG_SHA` still names the fix. Tell the user instead of resolving it blindly.
3. Run the test again. It must pass.
4. Keep the stash entry and report its tag and commit ID so the user can identify it later. Do not automatically drop it: a concurrent push or drop can change a positional stash ref between lookup and deletion.

```bash
printf 'Retained red-green stash: %s (commit %s)\n' "$RG_TAG" "$RG_SHA"
```

Limit the stash to the files the fix changed so the new test and unrelated work stay in place.
