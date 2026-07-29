# Shipping Contract

Apply this contract only after the caller supplied `--ship`, every applicable gate completed in regular-review/convention-review/refactor order, the selected review mode's completion rule passed, and final verification passed. Standard mode permits reported advisory and refactor observations but requires zero accepted unresolved Critical or Important findings and no genuine manual blocker. Strict mode requires every emitted finding to have a disposition and likewise permits only explicitly deferred optional findings to remain.

## Authorization Boundary

`--ship` authorizes these actions for the current Linear issue branch only:

- Retire current-project disposable workflow artifacts using the safe automatic cleanup path.
- Let `kramme:pr:create --auto` reorganize the branch into narrative commits, including its backup-protected local reset without a nested prompt.
- Create the previously absent remote issue branch once with an exact absence lease, then self-assign and create a ready-for-review Pull Request.
- Let `kramme:pr:fix-ci --no-consolidate` push targeted fixes for validated CI failures and review feedback until the Pull Request is green.

These actions remain bounded to the current issue branch. Pull Request creation continues only when the branch is absent on `origin` and has no Pull Request, never bypasses backup creation, remote-absence proof, or lease checks, and expires with this invocation. The no-consolidation mode retains `[FIX PIPELINE]` commits instead of rewriting the open Pull Request's history. This contract does not authorize rewriting an existing remote branch, force-pushing an already-open Pull Request, changing unrelated branches, merging, deleting durable specifications, or performing post-merge rollout.

## Step 1: Detect an Existing Pull Request

Query the current branch with `gh pr view --json number,url,state,headRefName,headRefOid` before cleanup or history rewriting. Require the command to succeed or return the recognized no-Pull-Request result. Authentication, network, repository, rate-limit, and API errors are blockers; never interpret them as absence.

- If no Pull Request exists, continue.
- If an open Pull Request exists, stop and report its URL and the local/remote head state. This check runs before the invocation calls `kramme:pr:create`, so the workflow has no creation provenance for the Pull Request and must not adopt or mutate it even when its head matches local `HEAD`. Route a later session to `kramme:pr:fix-ci --no-consolidate` as the existing-Pull-Request workflow.
- If a closed or merged Pull Request already uses the branch, stop and ask for a new issue branch rather than rewriting it.

## Step 2: Retire Workflow Artifacts

When the PR-refactor gate is active, it writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md`; a delegated resolver may also create a convention or broad-review overview. The quality loop moves these reports under `.context/linear-issue-to-pr/` before later scope collection. Invoke `kramme:workflow-artifacts:cleanup --auto` before Pull Request creation so the registered archive and any root-level disposable reports are retired.

`--ship` authorizes the cleanup skill's auto-selected current-project disposable set. Preserve permanent specifications and shared diagrams exactly as that skill requires. Never fall back to permanent deletion when safe automatic cleanup refuses to run.

If cleanup reports a missing `trash` dependency, dirty tracked artifact, unexpected directory contents, or failed deletion, stop before history rewriting or push.

## Step 3: Require a Clean Shipping Tree

Run `git status --porcelain` after cleanup.

- Continue only when it is empty.
- If dirty files are clearly workflow-produced implementation or remediation changes, return to the quality policy's remediation commit boundary, verify and commit only those classified paths, then rerun review and final verification.
- If any dirty path may predate this workflow or fall outside the Linear issue, stop and ask whether it belongs in the Pull Request. Do not let `kramme:pr:create --auto` make this ownership decision.

Confirm the current branch is still the Linear issue branch selected during implementation. Do not ship from the repository's base branch or a different feature branch.

## Step 4: Record the Verified Tree

With a clean worktree, record:

```bash
git rev-parse 'HEAD^{tree}'
```

Store the result as `{verified-tree}`. This is the exact source tree covered by final verification; commit hashes may change during narrative history rewriting, but this tree identity must not.

## Step 5: Create the Pull Request

Invoke `kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description` using the platform's skill mechanism. The explicit issue identifier is authoritative; do not re-extract it from the branch name. `--require-generated-description` makes unusable generator output a rollback-triggering blocker instead of allowing a placeholder fallback body. `--auto` carries the invocation through the backup-protected local reset without prompting; the delegated workflow separately requires the remote issue ref to be absent and creates it with an exact absence lease.

The delegated skill owns pre-validation, base-branch detection, state preservation, narrative commit recreation, description generation, the sole pre-PR remote push, self-assignment, Pull Request creation, and rollback on failure. Capture its validated `{base-branch}` as `{expected-base-branch}`; if that value is unavailable, stop because the workflow cannot prove that the created Pull Request targets the intended base. Its recreate-commits delegate runs with `--no-push`, so description failure cannot publish rewritten history. Continue after it returns; do not stop at an intermediate sub-skill summary.

If `kramme:pr:create` asks about uncommitted work, the Step 3 clean-tree invariant was violated. Abort Pull Request creation and return to Step 3 instead of choosing include or exclude.

## Step 6: Prove the Initial Shipped Result

After Pull Request creation succeeds:

1. Capture the Pull Request number, URL, state, base branch, head branch, and remote head OID with `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid`. Require this query to succeed.
2. Require the Pull Request to be open, its `baseRefName` to equal `{expected-base-branch}`, and its head branch to match the current branch.
3. Run `git status --porcelain` and require a clean worktree.
4. Record local `HEAD` as `{initial-shipped-head}` and require the Pull Request's `headRefOid` to equal it exactly. A missing or different remote OID means the Pull Request is not the locally shipped result.
5. Record the shipped tree with `git rev-parse 'HEAD^{tree}'` as `{initial-shipped-tree}`.
6. Compare `{initial-shipped-tree}` with `{verified-tree}` exactly.

If the remote head equals local `HEAD` and the tree identities match, the pre-rewrite verification evidence applies to the shipped result at the captured remote head.

If the base, head, or tree comparison differs, report the expected and observed base branch, remote head OID, local head OID, both tree identities, and the Pull Request URL/state. Do not claim the Pull Request is verified, do not merge it, and do not silently rewrite or force-push another result.

## Step 7: Stabilize CI and Review Feedback

After the initial shipped result is proven, invoke `kramme:pr:fix-ci --no-consolidate`.

The delegated skill owns CI-status inspection, failed-log analysis, review-feedback validation, targeted fixes, scoped commits and pushes, waiting for checks, and its bounded stop conditions. The `--no-consolidate` flag is required: keep `[FIX PIPELINE]` commits visible rather than force-pushing an already-open Pull Request. Do not combine it with `--auto`.

Continue only when the delegated skill reports all checks green, no unaddressed human review feedback, and no unresolved `UNVERIFIED`, `CONFUSION`, or `MISSING REQUIREMENT` marker. If it stops because the branch needs rebasing, the same failure persisted three times, feedback needs a decision, infrastructure failed, or any other exit condition was not satisfied, preserve its evidence and stop this workflow with the Pull Request URL.

## Step 8: Prove the Final Pull Request State

After `kramme:pr:fix-ci` succeeds:

1. Capture the Pull Request number, URL, state, base branch, head branch, and remote head OID again with `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid`. Require the Pull Request to remain open, its `baseRefName` to equal `{expected-base-branch}`, and its head branch to match the current branch.
2. Capture current check state with `gh pr checks --json name,state,bucket,link,workflow`. Exit status is not a query result here: this command exits `1` when a check failed, `8` while checks are pending, and `1` with a `no checks reported` message when the Pull Request has no checks at all. Always evaluate the `bucket` field whenever the command emits a well-formed JSON array, the same way `kramme:pr:fix-ci` reads it. Treat only unparseable output, or an authentication, network, repository, rate-limit, or API error, as a blocker.
   - Require every non-skipped check to be in the `pass` bucket. A `fail`, `pending`, or `cancel` bucket means the stabilization result is not complete; report the named checks and their links, and stop.
   - A `no checks reported` result or an empty array means the Pull Request has no configured CI. Record `Checks: none configured` and continue: there was no CI signal for `kramme:pr:fix-ci` to stabilize, and an absent pipeline must not become a permanent shipping blocker. Say `none configured` in the final report rather than claiming checks passed.
3. Run `git status --porcelain` and require a clean worktree.
4. Record local `HEAD` as `{final-head}` and require the Pull Request's `headRefOid` to equal it exactly.
5. Record `git rev-parse 'HEAD^{tree}'` as `{final-tree}`.
6. If `{final-tree}` differs from `{verified-tree}`, run exactly one validation-only final quality round before verification. Reuse the applicability evaluation and artifact-isolation rules in `review-convergence.md`, then run every applicable gate in regular-review -> convention-review -> refactor order:
   - Regular review: the read-only `kramme:pr:code-review --parallel --inline` gate.
   - Convention review: `kramme:pr:convention-review --inline`.
   - Refactor discovery: `kramme:code:refactor-opportunities pr`, with its report consumed and isolated under `.context/linear-issue-to-pr/` before continuing.

   Do not edit code, re-enter `kramme:pr:fix-ci`, or start another quality round from this validation-only pass. Apply the selected review mode's existing completion rule to its findings. If an accepted required finding, genuine manual blocker, or unexpected source change remains, stop with the Pull Request URL, finding evidence, and the smallest follow-up needed; do not claim the final tree is reviewed.

7. If `{final-tree}` differs, after the validation-only quality round passes, invoke `kramme:verify:run` for a fresh project-configured verification pass over the CI-remediated tree. Require every applicable check to pass and require no source change after verification.
8. Refresh review feedback after all final quality and verification work:
   - Run `gh pr view --json reviewDecision`.
   - Run `gh api --paginate "repos/{owner}/{repo}/pulls/{pr-number}/reviews"` for every submitted review and its state.
   - Run `gh api --paginate "repos/{owner}/{repo}/pulls/{pr-number}/comments"` for every inline review comment.
   - Run `gh api --paginate "repos/{owner}/{repo}/issues/{pr-number}/comments"` for every Pull Request conversation comment, including post-hoc bot feedback.
   - Collect every review thread and its resolution state with a paginated GraphQL query. The query must accept `$endCursor`, request `reviewThreads(first: 100, after: $endCursor)`, include each thread's `id` and `isResolved`, and request `pageInfo { hasNextPage endCursor }`; use `gh api graphql --paginate` or repeat pages until `hasNextPage` is false.
   - For each collected thread, paginate its `comments(first: 100, after: $endCursor)` connection until `hasNextPage` is false, collecting each comment's node `id`, author, body, URL, and creation time. Join those GraphQL comment IDs to REST inline comments' `node_id` values so every inline comment has a known thread and `isResolved` state.

   Require the rollup query, every REST page, every review-thread page, and every per-thread comment page to succeed. Treat a missing page, malformed response, duplicate or unmatched inline comment, unavailable `isResolved`, or any other unknown thread-resolution state as a blocker rather than feedback-clear evidence. Apply the same actionable-feedback classification used by `kramme:pr:fix-ci`: no `CHANGES_REQUESTED`, no unaddressed human feedback, no unresolved inline request, and no actionable bot feedback may remain. If new feedback appeared after stabilization, stop with the Pull Request URL and the exact feedback; direct the next invocation to `kramme:pr:fix-ci --no-consolidate` instead of reporting success.

9. After feedback collection, take the final publication snapshot: re-run `git status --porcelain`, record local `HEAD` again, query `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid`, and query `gh pr checks --json name,state,bucket,link,workflow` again. Require both GitHub queries to succeed, reading the check query under the exit-status rules in item 2 rather than its exit code. Require the worktree to remain clean, local `HEAD` to remain `{final-head}`, the Pull Request to remain open with `baseRefName` equal to `{expected-base-branch}`, its head on the current branch with a matching `headRefOid`, and the check result to remain what item 2 recorded — every non-skipped check in the `pass` bucket, or the same `none configured` result. If any value changed while feedback was collected, stop instead of reporting stale success.

When `{final-tree}` equals `{verified-tree}`, the original quality-gate and verification evidence still applies. When it differs, report both identities plus the final validation-only quality evidence and fresh final-tree verification evidence; do not claim that the CI-remediated tree is identical to the pre-PR verified tree. In either case, report success only when the final remote OID equals `{final-head}`, the worktree is clean, and the checks and review-feedback obligations are clear.

## Failure and Resume Behavior

- **Cleanup failure** — no history rewrite or push has started; fix the cleanup blocker and resume at Step 2.
- **PR creation rollback** — preserve and display the recovery state supplied by `kramme:pr:create`; resume only after confirming the branch and worktree match that recovery state.
- **Push succeeded but PR creation failed** — report the pushed branch and use the delegated skill's retry guidance; do not recreate commits again unless its rollback contract says the original state was restored.
- **Description generation failed** — preserve the delegated rollback result and stop; never publish or recommend a body containing unresolved fallback placeholders.
- **Pull Request already exists** — stop as an existing-Pull-Request workflow regardless of whether its head matches local `HEAD`; this pre-creation check has no invocation-owned creation provenance. Never force-push under this skill.
- **CI or review-feedback loop stops** — preserve the Pull Request and the delegated skill's exact blocker, then end this top-level invocation. After the blocker is resolved in a later session, invoke `kramme:pr:fix-ci --no-consolidate` directly as the existing-PR workflow; do not rerun `kramme:linear:issue-to-pr` or claim a cross-session Step 7 resume.
- **Final Pull Request proof fails** — report the expected and observed base branch, remote and local head OIDs, check buckets, worktree state, and both tree identities. Do not claim CI-green verified completion.
