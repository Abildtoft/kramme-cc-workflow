# Shipping Contract

Apply this contract only after the caller supplied `--ship`, the quality policy completed, final verification passed, and the branch/worktree still satisfy the new-PR boundary.

## Authorization Boundary

`--ship` authorizes, for the current prepared branch only:

- a backup-protected local narrative rewrite by `kramme:pr:create --auto --authorize-history-rewrite`;
- first publication of the previously absent remote branch with an exact absence lease;
- self-assignment and ready-for-review Pull Request creation; and
- targeted `{fix-ci-invocation}` commits and pushes until checks and review feedback are clear, where plan-scoped callers persist their validated archive path.

It does not authorize rewriting an existing remote branch or Pull Request, merging, deleting source-workflow state, deployment, or post-merge rollout.

## Step 1: Recheck Pull Request and Branch Absence

Run `gh pr view --json number,url,state,headRefName,headRefOid` for the current branch before history rewriting. Require success or the recognized no-Pull-Request result. API, authentication, network, repository, and rate-limit errors are blockers.

- Existing open Pull Request: stop and route a later session to `kramme:pr:fix-ci --no-consolidate`.
- Closed/merged Pull Request on this branch: require a fresh branch.

Re-query the exact current remote ref with `git ls-remote --heads origin "refs/heads/{work-branch}"` and require a well-formed absent result.

## Step 2: Require the Clean Verified Branch

1. Require `git status --porcelain` to be empty. Gitignored source-workflow archives may remain.
2. Require the current branch to equal the prepared `{work-branch}` and differ from `{base-branch}`.
3. When `PLAN_SCOPE_ACTIVE=true`, run `RECHECK_STANDALONE_SCOPE` for `PLAN_SCOPE_MODE=exact-files`, then collect every committed path in `{scope-base-commit}..HEAD`. Require exact equality with one `VALIDATED_SCOPE_PATHS` entry for `exact-files`, and otherwise allow exact path or directory containment. Stop before history rewriting or publication on the first mismatch or newly ineligible standalone path.
4. Record:

   ```bash
   git rev-parse 'HEAD^{tree}'
   ```

   as `{verified-tree}`.

If dirty files are workflow-owned implementation/remediation changes, return through the quality policy's commit, review, and verification sequence. Stop on unrelated or ambiguous paths.

## Step 3: Create the Pull Request

Invoke:

```text
kramme:pr:create --auto --require-generated-description --authorize-history-rewrite
```

The delegated skill owns validation, base resolution, state preservation, narrative commit recreation with `--no-push`, description generation, the sole pre-PR push, self-assignment, Pull Request creation, and rollback.

Capture its validated `{base-branch}` as `{expected-base-branch}`. If unavailable, stop because the created Pull Request target cannot be proven. If it asks about uncommitted work, abort because Step 2's clean-tree invariant failed.

## Step 4: Prove the Initial Shipped Result

After creation:

1. Query `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid`.
2. Require an open Pull Request whose base equals `{expected-base-branch}` and head branch equals the current branch.
3. Require a clean worktree.
4. Record local `HEAD` as `{initial-shipped-head}` and require exact equality with `headRefOid`.
5. Record `git rev-parse 'HEAD^{tree}'` as `{initial-shipped-tree}` and require equality with `{verified-tree}`.
6. When `PLAN_SCOPE_ACTIVE=true`, update only the archived workflow-state checkpoint head/tree to `{initial-shipped-head}` and `{initial-shipped-tree}` while preserving its stage, plan set, plan, branch, base, and scope. Re-read the archive and rerun its provenance and committed-path proofs. This binds the archive to the narrative rewrite before delegated CI fixes begin; stop before stabilization if the refresh fails.

History may change commit IDs, but the verified tree must not change. On mismatch, report expected and observed base, head OIDs, tree IDs, and Pull Request URL; do not start stabilization or claim verified completion.

## Step 5: Stabilize CI and Review Feedback

Set `{fix-ci-invocation}` to `$kramme:pr:fix-ci --no-consolidate`. Synced scoped recovery payload contract (keep aligned across plan recovery): `$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}`. When `PLAN_SCOPE_ACTIVE=true`, set `{fix-ci-invocation}` to that exact scoped value. Invoke it through the platform skill mechanism. Do not combine it with `--auto`.

When `PLAN_SCOPE_ACTIVE=true`, the delegated skill must reconstruct `PLAN_SCOPE_MODE`, `VALIDATED_SCOPE_PATHS`, `{scope-base-commit}`, and `RECHECK_STANDALONE_SCOPE` from `{validated-scope-plan}` under its scoped-plan mutation contract. These remain authoritative throughout `fix-ci`; its normal staging and push behavior does not widen the prepared work item's scope. Before every fix commit or push, require all of the following:

1. Every proposed, dirty, and staged fix path satisfies the active exact-or-containment membership rule.
2. For `PLAN_SCOPE_MODE=exact-files`, run `RECHECK_STANDALONE_SCOPE` immediately before staging.
3. Collect every committed path in `{scope-base-commit}..HEAD` and enforce the same membership rule before push.

If valid CI or review feedback needs an out-of-scope path, stop before editing, staging, committing, or pushing that fix and return `published_blocked` with the first required path. Do not let the delegated workflow publish a change that the final scope proof would reject.

Continue only when it reports:

- every configured check green;
- no unaddressed human review feedback; and
- no unresolved `UNVERIFIED`, `CONFUSION`, or `MISSING REQUIREMENT` marker.

If it stops, preserve the Pull Request URL, exact blocker, and `{fix-ci-invocation}`. A later session resumes with that exact invocation, never with an unscoped substitute and never by rerunning implementation.

Before returning a blocked handoff, when `PLAN_SCOPE_ACTIVE=true`, rerun `RECHECK_STANDALONE_SCOPE` for `PLAN_SCOPE_MODE=exact-files`, collect every committed path in `{scope-base-commit}..HEAD`, and enforce the active membership rule. Preserve the first failed eligibility or membership proof as the blocker; never claim the handoff is safe for source-workflow finalization when this recheck fails.

Return a structured caller handoff before stopping:

```text
Completion disposition: published_blocked
Pre-publication quality and verification: passed
Publication state: open Pull Request
Work branch: {work-branch}
Pull Request: {url}
Local head/tree: {head} {tree}
Remote head: {headRefOid}
Blocker: {exact delegated blocker}
Recovery: ${fix-ci-invocation}
```

This is a blocking overall result, not success, but callers must persist their implementation-complete source state and Pull Request provenance before returning it to the user.

## Step 6: Prove the Final Pull Request State

1. Query `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid` again. Require it to remain open with expected base and current head branch.
2. Query:

   ```bash
   gh pr checks --json name,state,bucket,link,workflow
   ```

   Exit status is not itself the result: `gh` may exit `1` for failed checks, `8` for pending checks, or `1` with `no checks reported`. Evaluate a well-formed JSON array by `bucket`.
   - Require every non-skipped check in `pass`.
   - Treat `fail`, `pending`, or `cancel` as incomplete.
   - Treat an empty array or recognized `no checks reported` response as `Checks: none configured`.
   - Treat malformed output and API/auth/network/repository errors as blockers.

3. Require a clean worktree.
4. Record local `HEAD` as `{final-head}` and require equality with `headRefOid`.
5. Record `git rev-parse 'HEAD^{tree}'` as `{final-tree}`.
6. When `PLAN_SCOPE_ACTIVE=true`, rerun `RECHECK_STANDALONE_SCOPE` for `PLAN_SCOPE_MODE=exact-files`, then collect every committed path in `{scope-base-commit}..HEAD` again and enforce the mode's exact-or-containment rule. If any path falls outside `VALIDATED_SCOPE_PATHS` or a standalone path is newly ineligible, return `published_blocked` with the first mismatch and do not claim plan-scoped completion.
7. If `{final-tree}` differs from `{verified-tree}`, run exactly one validation-only final quality round using the applicability and archive rules from `review-convergence.md`, with active gates in regular-review, convention-review, refactor order. Do not edit, re-enter CI fixing, or start another quality round.
8. If that validation-only round passes, invoke `kramme:verify:run` once on the CI-remediated tree and require every applicable check to pass without further source changes.

## Step 7: Refresh Review Feedback and Publication State

After final quality/verification:

1. Query `gh pr view --json reviewDecision`.
2. Fetch every submitted review with `gh api --paginate "repos/{owner}/{repo}/pulls/{pr-number}/reviews"`, every inline review comment with `gh api --paginate "repos/{owner}/{repo}/pulls/{pr-number}/comments"`, and every conversation comment with `gh api --paginate "repos/{owner}/{repo}/issues/{pr-number}/comments"`.
3. Fetch every review thread with a paginated GraphQL query using `reviewThreads(first: 100, after: $endCursor)`, each thread's `id` and `isResolved`, and `pageInfo { hasNextPage endCursor }`.
4. For each thread, paginate `comments(first: 100, after: $endCursor)` with its own `pageInfo { hasNextPage endCursor }`, then join GraphQL comment IDs to REST `node_id` values.
5. Require every page and join to succeed. Unknown or unmatched thread state is a blocker.
6. Require no `CHANGES_REQUESTED`, unaddressed human feedback, unresolved inline request, or actionable bot feedback.

Then take a final snapshot:

- `git status --porcelain`
- local `HEAD`
- `gh pr view --json number,url,state,baseRefName,headRefName,headRefOid`
- `gh pr checks --json name,state,bucket,link,workflow`

Require the worktree clean, local head unchanged, Pull Request open with expected base/head and matching OID, and checks still all passing or the same none-configured result. Stop if state changed while feedback was collected.

## Failure and Resume Behavior

- PR creation rollback: preserve the delegated recovery state.
- Push succeeded but PR creation failed: return `Completion disposition: published_blocked`, `Pre-publication quality and verification: passed`, `Publication state: remote branch only`, `Work branch: {work-branch}`, the validated local head/tree and matching remote head, `Pull Request: absent`, the exact `Blocker`, and the delegated manual Pull Request creation `Recovery`. Callers may persist implementation completion, but must not claim a Pull Request exists. Do not recreate commits unless rollback restored the original state.
- Description generation failed: preserve rollback; never publish placeholder content.
- Existing Pull Request: never adopt or force-push it under this workflow.
- CI/review loop stopped: preserve the URL and resume later with the exact recorded `{fix-ci-invocation}`.
- Final proof failed: report expected/observed base, heads, checks, worktree state, and tree identities. Do not claim a green verified Pull Request.
