---
name: kramme:pr:fix-ci
description: Iterate on a PR until CI passes. Use when you need to fix CI failures, address review feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-push-wait cycle.
disable-model-invocation: true
user-invocable: true
---

# Iterate on PR Until CI Passes

Continuously iterate on the current branch until all CI checks pass and review feedback is addressed.

**Requires**: GitHub CLI (`gh`) authenticated and available.

## Why this loop exists

> "A bug caught in linting costs minutes; the same bug caught in production costs hours."

> "Smaller batches and more frequent releases reduce risk, not increase it."

The fix-CI loop is the **CI Failure Feedback Loop** pattern: read the failure, make a minimal fix, push, wait, repeat. This skill automates that loop so failures are surfaced and corrected in minutes instead of accumulating across a days-long review cycle.

## Options

**Flags:**

- `--fixup` - Use fixup commits to amend existing branch commits instead of creating new commits. Requires force push. Orphan files (not touched by any branch commit, including files last modified on the base branch) are committed as new.
- `--no-consolidate` - Skip the consolidation prompt after CI passes. Use for scripting or when you want to keep `[FIX PIPELINE]` commits separate.

---

## Flow

### Step 1: Identify the PR

```bash
gh pr view --json number,url,headRefName,baseRefName
PR_NUMBER=$(gh pr view --json number --jq .number)
```

If no PR exists for the current branch, stop and inform the user. Keep `PR_NUMBER` for Step 4.

### Step 2: Confirm the branch is in sync with the base

A stale branch will produce CI failures unrelated to the PR, wasting iteration cycles. Catch this before iterating.

```bash
BASE=$(gh pr view --json baseRefName --jq .baseRefName)
git fetch origin "$BASE"
git rev-list --left-right --count "origin/$BASE"...HEAD
```

If the left count is non-zero (the base has commits not in the branch), stop and ask the user to rebase before proceeding.

### Step 3: Check CI status first

```bash
gh pr checks --json name,state,bucket,link,workflow
```

The `bucket` field categorizes state into: `pass`, `fail`, `pending`, `skipping`, or `cancel`.

**Important:** If any of these checks are still `pending`, wait before proceeding:

- `sentry` / `sentry-io`
- `codecov`
- `cursor` / `bugbot` / `seer`
- Any linter or code analysis checks

These bots may post additional feedback comments once their checks complete. Waiting avoids duplicate work.

### Step 4: Gather review feedback

`gh api` auto-expands `{owner}` and `{repo}` from the current repo context. Substitute `$PR_NUMBER` (captured in Step 1) where the PR number is needed.

**Review comments and status:**

```bash
gh pr view --json reviews,comments,reviewDecision
```

**Inline code review comments:**

```bash
gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments"
```

**PR conversation comments (includes bot comments):**

```bash
gh api "repos/{owner}/{repo}/issues/$PR_NUMBER/comments"
```

### Step 5: Investigate failures

```bash
# List recent runs for this branch
gh run list --branch "$(git branch --show-current)" --limit 5 --json databaseId,name,status,conclusion

# View failed logs for a specific run (substitute the databaseId from above)
gh run view "$RUN_ID" --log-failed
```

Do NOT assume what failed based on the check name alone. Always read the actual logs.

### Step 6: Validate feedback

For each piece of feedback (CI failure or review comment):

1. **Read the relevant code** - Understand the context before making changes
2. **Verify the issue is real** - Not all feedback is correct; reviewers and bots can be wrong
3. **Check if already addressed** - The issue may have been fixed in a subsequent commit
4. **Skip invalid feedback** - If the concern is not legitimate, move on

### Step 7: Address valid issues

Make minimal, targeted code changes. Only fix what is actually broken.

### Step 8: Commit and push

**If `--fixup` mode is enabled:** See Step 8b below.

**Default (no flag):**

```bash
git add -A
git commit -m "[FIX PIPELINE] <descriptive message of what was fixed>"
git push origin "$(git branch --show-current)"
```

The `[FIX PIPELINE]` prefix marks commits as iteration fixes from CI or review feedback, making them easy to identify and consolidate later (see Step 11).

### Step 8b: Fixup commit flow (when `--fixup` is enabled)

Read and follow the fixup commit flow from `references/fixup-flow.md`. This covers base branch detection, file-to-commit mapping, fixup commit creation, autosquash rebase, and force push with lease. Shared branches still require explicit collaborator coordination before any history rewrite or force push.

### Step 9: Wait for CI

```bash
gh pr checks --watch --interval 30
```

This waits until all checks complete. Exit code 0 means all passed, exit code 1 means failures.

If the watch hangs well past expected runtimes (rule of thumb: >30 minutes for a typical PR pipeline), a check is likely stuck pending — runner outage, missing webhook, or an external bot that never reported back. Cancel the watch, name the stuck check, and surface `CONFUSION` so the user can decide whether to retry, ignore, or escalate.

### Step 10: Repeat

Return to Step 3 if:

- Any CI checks failed
- New review feedback appeared

Continue until all checks pass and no unaddressed feedback remains.

### Step 11: Consolidation phase (default mode only)

**Skip this step if:** `--fixup` mode was used, or `--no-consolidate` flag is set.

Read and follow the consolidation flow from `references/consolidation-flow.md`. This covers detecting `[FIX PIPELINE]` commits, prompting the user for consolidation options (automated, interactive, or keep separate), mapping commits to targets, executing rebase, and force pushing. On shared branches, consolidation requires explicit coordination before any history rewrite.

---

## Quality gate discipline

> "No gate can be skipped. If lint fails, fix lint — don't disable the rule."

A failing gate is signalling a real problem until proven otherwise. The fix is to fix the gate, not to silence it.

Do not silently:

- Skip a hook with `--no-verify` or equivalent flags.
- Add `eslint-disable`, `# noqa`, `@ts-ignore`, or a similar suppression comment to silence the specific failure.
- Delete, comment out, or mark-as-skipped a failing test.
- Lower a gate's threshold (coverage, complexity, bundle size) to make it pass.
- Remove the gate from the pipeline.

If disablement is genuinely warranted — a confirmed false positive, a test that asserts old behavior the PR intentionally changes, a rule the team agrees to retire — stop and surface a `MISSING REQUIREMENT` marker with the rationale. Get explicit user approval before committing the disablement. The user may approve, redirect, or provide a different fix. Silent disablement is never the answer.

---

## Exit Conditions

**Success:**

- All CI checks are green
- No unaddressed human review feedback
- (Default mode) Consolidation completed or user chose to keep separate commits

**Ask for Help:**

- Same failure persists after 3 attempts (likely a flaky test or deeper issue)
- Review feedback requires clarification or decision from the user
- CI failure is unrelated to branch changes (infrastructure issue)
- Consolidation rebase failed due to conflicts (user must resolve manually)

**Stop Immediately:**

- No PR exists for the current branch
- Branch is out of sync and needs rebase (inform user)

---

## Tips

**GitHub:**

- Use `gh pr checks --required` to focus only on required checks
- Use `gh run view <run-id> --verbose` to see all job steps, not just failures
- If a check is from an external service, the `link` field provides the URL

**Choosing a mode:**

- **Default**: Working with others, want visible iteration history, prefer to consolidate at the end
- **`--fixup`**: Working alone, want clean history throughout, comfortable with force push

---

## Output markers

Use these markers so the user (and downstream tooling) can skim status at a glance. They are a **plugin-wide convention** for Addy-ported skills. Use them verbatim (uppercase, no decoration), one marker per line.

- **UNVERIFIED** — a claim not directly confirmed against the logs or code. `UNVERIFIED: log output was truncated at 500 lines; couldn't confirm the full failure trace`.
- **NOTICED BUT NOT TOUCHING** — a pre-existing failure or unrelated issue surfaced while investigating. `NOTICED BUT NOT TOUCHING: the flaky integration test on macOS has been red on main for a week, but it's outside this PR`.
- **CONFUSION** — can't decide whether a failure is real or infrastructure. `CONFUSION: the job timed out after 10 minutes; is this a test regression or a runner issue?`
- **MISSING REQUIREMENT** — a decision is needed before proceeding. `MISSING REQUIREMENT: the lint rule looks like a false positive, but disabling it requires your approval — proceed or redirect?`

---

## Common rationalizations

Watch for these excuses — they signal the loop is slipping into damage.

| Excuse | Reality |
| --- | --- |
| "Just disable the lint rule to unblock the PR." | Silently disabling a gate is how quality erodes across PRs. Fix the root cause or surface `MISSING REQUIREMENT`. |
| "The check is flaky, I'll retry it." | Retry once. If it fails again, treat it as real until you've read the logs and can name the infrastructure cause. |
| "The failure is unrelated to my PR." | Maybe. Confirm with log evidence — git-blame the failing assertion, check main's CI history — not with assumption. |
| "The reviewer bot is wrong." | Reviewers and bots can be wrong, but verify by reading the relevant code first. A dismissal without evidence is hand-waving. |
| "I'll fix it in a follow-up." | Follow-ups are negotiable. A red CI blocking the merge is not. Land the fix or mark the failure `NOTICED BUT NOT TOUCHING` with a real reason. |
| "`--no-verify` just this once." | "Just this once" is how precedents form. Ask instead. |

---

## Red Flags — STOP

Pause and escalate if any of these are true:

- The same failure persists after 3 attempts — you are guessing, not reading.
- About to commit `--no-verify`, `eslint-disable`, `# noqa`, `@ts-ignore`, or a skip-marker without explicit user approval.
- About to force-push to a shared branch without explicit collaborator coordination, whether in `--fixup` mode or after consolidation.
- Attempting to fix a failure whose logs you haven't read in full.
- Consolidation rebase is about to drop or rewrite a non-`[FIX PIPELINE]` commit.
- CI is green but review feedback is unaddressed — green is necessary, not sufficient.

---

## Verification

Before handing off, confirm:

- [ ] All required checks pass (not "most").
- [ ] Every `[FIX PIPELINE]` commit references a concrete issue you verified: either a CI failure whose logs you read or a review finding you validated against the code.
- [ ] No gate was silently disabled. Any disablement is accompanied by an explicit user approval.
- [ ] No lingering `UNVERIFIED`, `CONFUSION`, or `MISSING REQUIREMENT` markers are unresolved.
- [ ] Consolidation (if run) preserved every non-`[FIX PIPELINE]` commit.
- [ ] If a force-push happened, it was via `--force-with-lease` and the branch either is not shared, or shared collaborators were coordinated with.
- [ ] Human review feedback is addressed or explicitly deferred with a `NOTICED BUT NOT TOUCHING` rationale.
