---
name: kramme:pr:rebase
description: Rebase current branch onto latest main/master, auto-resolving bounded conflicts up to 10 rounds, then force push with --force-with-lease. Use when your PR is behind the base branch.
argument-hint: "[--auto] [--base <branch>]"
disable-model-invocation: true
user-invocable: true
---

# Rebase PR

Rebase the current branch onto the latest base branch and force push.

## Why rebase — dev branches are costs

A feature branch is a cost that compounds every day it stays open. It drifts from the base branch, it accumulates irrelevant diff when other PRs land, and it forces every reviewer to re-learn a stale context. Rebasing is how you pay down that cost: the branch stays in sync with `main`, the diff stays scoped to the change, and the reviewer's mental model of the base is still valid when they open the PR. Merge commits defer the cost — they hide drift behind a merge marker instead of resolving it — which is why this skill rebases and force-pushes rather than merging `main` in. If the rebase fights you, that is evidence the branch is already too old: finish it or split it, don't patch it with more merges.

## Options

**Flags:**

- `--auto` - Skip the final force-push confirmation and push immediately with `--force-with-lease` after a successful rebase.
- `--base <branch>` - Override auto-detected base branch (e.g., `--base develop`)

`--auto` only bypasses the final confirmation prompt when the rebase completes without machine-resolved conflicts. It does not bypass conflict handling, red-flag stops, the auto-resolved-conflict verification/confirmation gate, or the requirement to use `--force-with-lease`.

## Output markers

Use these uppercase markers when reasoning about the rebase and reporting progress. One marker per line, no decoration:

- **REBASE PREFLIGHT** — base branch, conflict method, and autostash state at the start. `REBASE PREFLIGHT: origin/main, --autostash enabled, 3 uncommitted changes stashed`.
- **UNVERIFIED** — claims about resolved conflicts that haven't been runtime-checked. `UNVERIFIED: conflict auto-resolved in handler.ts but I didn't run the tests after`.
- **NOTICED BUT NOT TOUCHING** — issues visible during rebase that are outside scope. `NOTICED BUT NOT TOUCHING: origin/main has an unrelated lint failure — not this rebase's problem`.
- **CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS** — end-of-run summary when the rebase completes.
- **CONFUSION** — ambiguous conflict evidence. `CONFUSION: both sides of the conflict add the same function but with different signatures — unclear which is authoritative`.
- **MISSING REQUIREMENT** — a decision is needed before the rebase can proceed. `MISSING REQUIREMENT: origin/main has force-pushed since last fetch — confirm the target is correct before I continue`.
- **PLAN** — announced sequence when conflicts span multiple rounds. `PLAN: resolve handler.ts first, then re-run the rebase; 2 more files likely to conflict afterward`.

## Workflow

### Step 0: Parse Arguments

If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag from remaining arguments. If `--base <branch>` is present, set `BASE_BRANCH_OVERRIDE=<branch>` and remove the flag and value from remaining arguments.

### Step 1: Validate Prerequisites

1. **Check for rebase/merge in progress:**

   ```bash
   ls -d .git/rebase-merge .git/rebase-apply .git/MERGE_HEAD 2> /dev/null
   ```

   If any exist, stop with error:

   > "A rebase or merge is already in progress. Complete or abort it first with `git rebase --abort` or `git merge --abort`."

2. **Resolve base branch:**

   Use the shared plugin script to resolve the base branch. It uses the same 3-tier strategy as the sibling review skills: explicit `--base`, PR target branch (via `gh`), then `origin/HEAD`/`origin/main`/`origin/master`. It runs in strict mode and fetches the resolved base, so fetch failures stop the workflow with the script's stderr message.

   ```bash
   RESOLVE_ARGS=(--strict)
   [ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

   RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
     echo "Base resolution failed; see the message above. Re-run with --base <branch>." >&2
     exit 1
   }
   eval "$RESOLVED"
   ```

   The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE`. Use `BASE_BRANCH` wherever `<base-branch>` appears below.

3. **Verify current branch is not the base branch:**

   ```bash
   git branch --show-current
   ```

   If current branch equals base branch, stop with error:

   > "You are on the base branch. Switch to a feature branch first."

### Step 2: Fetch Latest

The resolve script in Step 1 already fetched `origin/<base-branch>`. If meaningful time has passed since Step 1 (e.g., after a long conflict round or user pause), refresh it before rebasing:

```bash
git fetch origin <base-branch>
```

### Step 3: Rebase

Run the rebase with `--autostash` so uncommitted changes are stashed before the rebase and popped after, covering the common case of rebasing with local modifications:

```bash
git rebase --autostash origin/<base-branch>
```

**If rebase succeeds:** Proceed to Step 4.

**If rebase fails (conflicts):**

1. **Attempt automatic resolution (up to 10 conflict rounds):**

   The 10-round cap exists because each round reapplies a single commit; beyond that, conflicts almost always indicate semantic drift the auto-resolver can't handle safely — escalate to the user instead of guessing further.

   Track all conflicts and resolutions for the summary and set `CONFLICTS_AUTO_RESOLVED=true` once any conflict marker is resolved by the model. Before resolving each file, re-read the **Red Flags** section below — if any apply (migrations, generated artifacts, files you don't fully understand, deletions that drop semantics), abort instead of resolving.

   For each round:

   a. Get list of conflicting files:

   ```bash
   git diff --name-only --diff-filter=U
   ```

   b. For each conflicting file:
   - Read the file content
   - Resolve conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) by analyzing both versions and choosing the best resolution
   - **Record the conflict and resolution** (file path, what conflicted, how it was resolved)
   - Write the resolved content back
   - Stage the file: `git add <file>`

   c. Continue the rebase (`GIT_EDITOR=true` prevents `git rebase --continue` from opening an editor on commit-message prompts):

   ```bash
   GIT_EDITOR=true git rebase --continue
   ```

   d. If rebase completes, proceed to **Step 4: Conflict Summary**

   e. If new conflicts arise, repeat from (a)

2. **If resolution fails** (after 10 rounds or unresolvable conflict):

   Abort the rebase:

   ```bash
   git rebase --abort
   ```

   Inform user:

   > "Automatic conflict resolution failed after X attempts. The branch has been restored to its pre-rebase state."
   >
   > "Conflicting files that could not be resolved: `<list files>`"
   >
   > "To resolve manually, run `git rebase origin/<base-branch>`, fix conflicts, then `git rebase --continue`."

### Step 4: Conflict Summary (only if conflicts were resolved)

If the rebase completed without conflicts, skip to Step 5.

Otherwise, present a summary so the user can review what was auto-resolved before force pushing:

> **Conflicts resolved during rebase:**
>
> For each resolved conflict, show:
>
> - **File:** `<file path>`
> - **Conflict:** Brief description of what conflicted (e.g., "Both branches modified the `calculateTotal` function")
> - **Resolution:** How it was resolved (e.g., "Combined changes: kept the new parameter from base branch and the validation logic from feature branch")

### Step 5: Force Push

If `AUTO_MODE=true` and `CONFLICTS_AUTO_RESOLVED` is not true, skip the confirmation prompt and push immediately with `--force-with-lease`.

If `AUTO_MODE=true` and `CONFLICTS_AUTO_RESOLVED=true`, do not push until one of these gates is satisfied:

1. Run the project's verification battery using the `kramme:verify:run` conventions. If verification is available and passes, push with `--force-with-lease`.
2. If verification is unavailable, fails, or cannot cover the conflict resolution, present the full Conflict Summary and ask the user to confirm before pushing.

If neither gate succeeds, stop before `git push` and report:

- the full Conflict Summary
- verification command(s) attempted, if any
- why the branch was not pushed automatically

Use the `UNVERIFIED` marker for every conflict resolution that was not covered by a passing verification run.

Otherwise, before pushing, use `AskUserQuestion` to confirm:

> "Ready to force push rebased branch. This will overwrite the remote branch history. Continue?"
>
> Options:
>
> - **Yes, force push** - Push with `--force-with-lease`
> - **Do not push** - Keep local rebase but don't push

If confirmed, push the rebased branch:

```bash
git push --force-with-lease origin $(git branch --show-current)
```

**Note:** `--force-with-lease` refuses to overwrite remote commits you haven't fetched, providing safety against overwriting others' work.

### Step 6: Report Results

Show the commit log relative to base (substitute the resolved base-branch name for `<base-branch>` — no spaces around the angle brackets, or the shell will read it as redirection):

```bash
git log --oneline origin/<base-branch>..HEAD
```

Confirm success:

> "Branch rebased onto `origin/<base-branch>` and pushed."

## Common Rationalizations

Lies you'll tell yourself mid-rebase. Each has a correct response:

- _"I'll just merge `main` in instead — it's faster."_ → Faster now, harder to review later. Merges hide drift; rebases resolve it.
- _"The auto-conflict resolution looks right — I don't need to re-run tests."_ → Conflict resolution is a code change. Re-run the verify battery or surface it as `UNVERIFIED`.
- _"Force-push is fine; no one else is on this branch."_ → If the branch is pushed, assume someone has it. `--force-with-lease` is the floor, not the ceiling — still warn the user.
- _"Ten rounds of auto-resolve failed — I'll just pick one side."_ → The skill aborts after 10 rounds for a reason. Escalate to the user; don't guess.

## Red Flags — STOP

Pause and hand back to the user if any of these are true:

- `--force-with-lease` is about to run against `main`, `master`, or `develop`.
- The auto-resolver merged logic from a file it doesn't fully understand.
- The rebase touched migration files or generated artifacts; auto-resolution is unsafe there.
- The branch hadn't been fetched recently and the base has moved significantly (>20 commits).
- Any conflict was resolved by deleting a block instead of merging semantics.

## Verification

Before force-pushing, self-check:

- [ ] If conflicts were resolved, the Conflict Summary lists every resolved file with file + conflict + resolution. (No conflicts → this item is N/A.)
- [ ] If `AUTO_MODE=true` and conflicts were machine-resolved, passing verification or explicit user confirmation happened before `git push`.
- [ ] The base branch was freshly fetched (Step 2 ran).
- [ ] The user explicitly confirmed via `AskUserQuestion` (Step 5), or `AUTO_MODE=true` with every required auto-mode gate satisfied.
- [ ] `--force-with-lease` (not `--force`) is the flag being used.
- [ ] Post-push `git log --oneline origin/<base>..HEAD` shows the expected linear history.
