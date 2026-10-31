# Plan Shipping Hooks

This reference binds every hook in `{pr-shipping-contract}` for the archived-plan workflow. Read it first, then follow `{pr-shipping-contract}` completely with these bindings. Every model-visible result, success or blocked, returns to `SKILL.md`'s completion return contract and archive finalization.

Ship only after `kramme:pr:review-convergence` passed in normal mode for the current tree, final verification passed, and `SKILL.md` preserved `{scope-base-commit}`, `VALIDATED_SCOPE_PATHS`, and `RECHECK_STANDALONE_SCOPE` from its handoff.

## Additional Authorization

Every shared grant applies to the prepared plan branch only. `--ship` additionally authorizes the gitignored archive checkpoint refresh in `{post-create-hook}` and requires `{fix-ci-invocation}` to preserve the validated archive path. It never authorizes moving or deleting the plan archive or broad workflow-artifact cleanup.

## Hook Bindings

- `{work-id}`: `{execution-label}`.
- `{archive-key}`: `code-plan-to-pr`.
- `{work-requirements}`: `{work-requirements}`, the frozen sentinel-last block passed to the pre-publication convergence call.
- `{work-branch}`: the prepared `{work-branch}`, captured before review convergence and equal to `{plan-branch}`.
- `{pre-publication-hook}`: none. This workflow never invokes broad workflow-artifact cleanup.
- `{scope-proof}`: enforce the validated plan scope.
  - Dirty paths: gitignored source-workflow archives may remain. If dirty files are workflow-owned implementation or remediation changes, return through the quality policy's commit, review, and verification sequence. Stop on unrelated or ambiguous paths.
  - Committed paths: run `RECHECK_STANDALONE_SCOPE` for `PLAN_SCOPE_MODE=exact-files`, then collect every committed path in `{scope-base-commit}..HEAD`. Require exact equality with one `VALIDATED_SCOPE_PATHS` entry for `exact-files`, and otherwise allow exact path or directory containment. Stop before history rewriting or publication on the first mismatch or newly ineligible exact-file path.
  - Final recheck: If any path falls outside `VALIDATED_SCOPE_PATHS` or an exact-file path is newly ineligible, return `published_blocked` through `{blocked-handoff}` with the first mismatch and do not claim plan-scoped completion.
- `{create-invocation}`: `kramme:pr:create --base {base-branch} --require-generated-description`, with the `{base-branch}` resolved in `SKILL.md` Step 4. Auto mode already authorizes the backup-protected unstacked rewrite, and a plan branch is never stacked.
- `{post-create-hook}`: refresh the archived checkpoint.

  Apply this persistence rule before delegated CI fixes begin. Synced atomic scoped archive update contract (keep aligned across plan recovery): write the complete updated selected plan to a non-symlink temporary sibling in its `plans/` directory, re-read and fully validate the staged bytes, then atomically rename that sibling over the selected plan; on any write, validation, or rename failure, leave the previous plan intact and treat the already-published mutation as interrupted. Use that atomic replacement to update only the archived workflow-state checkpoint head/tree to `{initial-shipped-head}` and `{initial-shipped-tree}` while preserving its stage, plan set, plan, branch, base, and scope. Re-read the published archive and rerun its provenance and committed-path proofs. This binds the archive to the narrative rewrite before delegated CI fixes begin; stop before stabilization if the refresh fails.

- `{fix-ci-invocation}`: the scoped recovery payload.

  Set `{fix-ci-invocation}` to the exact scoped value in the synced recovery contract. Synced scoped recovery payload contract (keep aligned across plan recovery): `$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}`. Invoke it through the platform skill mechanism. The same value routes a later session when a Pull Request already exists.

- `{fix-ci-guard}`: keep every fix inside the validated plan scope.

  The delegated skill must reconstruct `PLAN_SCOPE_MODE`, `VALIDATED_SCOPE_PATHS`, `{scope-base-commit}`, and `RECHECK_STANDALONE_SCOPE` from `{validated-scope-plan}` under its scoped-plan mutation contract. These remain authoritative throughout `fix-ci`; its normal staging and push behavior does not widen the prepared work item's scope. Before every fix commit or push, require all of the following:
  1. Every proposed, dirty, and staged fix path satisfies the active exact-or-containment membership rule.
  2. For `PLAN_SCOPE_MODE=exact-files`, run `RECHECK_STANDALONE_SCOPE` immediately before staging.
  3. Collect every committed path in `{scope-base-commit}..HEAD` and enforce the same membership rule before push.

  If valid CI or review feedback needs an out-of-scope path, stop before editing, staging, committing, or pushing that fix and return `published_blocked` through `{blocked-handoff}` with the first required path. Do not let the delegated workflow publish a change that the final scope proof would reject.

- `{validation-extra-args}`: the same `--scope-plan {validated-scope-plan}` passed before publication.
- `{blocked-handoff}`: return a structured `published_blocked` handoff to `SKILL.md`, then stop.

  Before returning a blocked handoff, rerun `RECHECK_STANDALONE_SCOPE` for `PLAN_SCOPE_MODE=exact-files`, collect every committed path in `{scope-base-commit}..HEAD`, and enforce the active membership rule. Preserve the first failed eligibility or membership proof as the blocker; never claim the handoff is safe for source-workflow finalization when this recheck fails.

  Preserve the Pull Request URL, exact blocker, and `{fix-ci-invocation}`. A later session resumes with that exact invocation, never with an unscoped substitute and never by rerunning implementation. When a Pull Request exists, return:

  ```text
  Completion disposition: published_blocked
  Pre-publication quality and verification: passed
  Publication state: open Pull Request
  Work branch: {work-branch}
  Pull Request: {url}
  Local head/tree: {head} {tree}
  Remote head: {headRefOid}
  Blocker: {exact delegated blocker}
  Recovery: {fix-ci-invocation}
  ```

  When the push succeeded but Pull Request creation failed, return the same fields with `Publication state: remote branch only`, the validated local head/tree and matching remote head, `Pull Request: absent`, the exact `Blocker`, and the delegated manual Pull Request creation `Recovery`. Never claim a Pull Request exists, and do not recreate commits unless rollback restored the original state.

  This is a blocking overall result, not success, but callers must persist their implementation-complete source state and Pull Request provenance before returning it to the user.

## Plan Result Notes

- Report the entry count of the validated `CI remediation JSON` on the shipped completion result's `CI remediation:` line. Keep the merged final-tree `Reviewer handoff JSON` as validation evidence; this workflow does not summarize it.
