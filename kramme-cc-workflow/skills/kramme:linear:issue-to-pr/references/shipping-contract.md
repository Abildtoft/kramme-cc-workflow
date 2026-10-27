# Linear Shipping Hooks

This reference binds every hook in `{pr-shipping-contract}` for the Linear issue workflow. Read it first, then follow `{pr-shipping-contract}` completely with these bindings.

Ship only after every applicable gate completed in regular-review/convention-review/overengineering-review/refactor order, the selected review mode's completion rule passed, and final verification passed. Standard mode permits reported Judgment Call, advisory, and refactor observations but requires zero accepted unresolved Critical, Important, or `OVERDONE` findings and no genuine manual blocker. Strict mode requires every emitted finding to have a disposition and likewise permits only explicitly deferred optional findings to remain.

## Additional Authorization

Every shared grant applies to the current Linear issue branch only. `--ship` additionally authorizes retiring current-project disposable workflow artifacts using the safe automatic cleanup path, bounded the same way.

## Hook Bindings

- `{work-id}`: `{issue-id}`.
- `{archive-key}`: `linear-issue-to-pr`.
- `{work-requirements}`: `{issue-requirements}`, the frozen sentinel-last block passed to the pre-publication convergence call.
- `{work-branch}`: `{issue-branch}`, the Linear issue branch validated in this skill's Step 2 and selected during implementation.
- `{pre-publication-hook}`: retire workflow artifacts.

  When the overengineering gate is active, it writes or refreshes `OVERENGINEERING_REVIEW_OVERVIEW.md`, and the PR-refactor gate writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md`; a delegated resolver may also create a convention or broad-review overview. `kramme:pr:review-convergence` moves these reports under `.context/linear-issue-to-pr/reviews/` before later scope collection. Invoke `kramme:workflow:cleanup-artifacts --auto` before Pull Request creation so every registered archived or root-level disposable report is retired.

  `--ship` authorizes the cleanup skill's auto-selected current-project disposable set. Preserve permanent specifications and shared diagrams exactly as that skill requires. Never fall back to permanent deletion when safe automatic cleanup refuses to run.

  If cleanup reports a missing `trash` dependency, dirty tracked artifact, unexpected directory contents, or failed deletion, stop before history rewriting or push.

- `{scope-proof}`: classify dirty paths by ownership.
  - If dirty files are clearly workflow-produced implementation or remediation changes, return to the quality policy's remediation commit boundary, verify and commit only those classified paths, then rerun review and final verification.
  - If any dirty path may predate this workflow or fall outside the Linear issue, stop and ask whether it belongs in the Pull Request.

  The Linear workflow has no committed-path scope beyond the issue branch itself, so the committed-path proof and its final recheck reduce to confirming the current branch is still the Linear issue branch.

- `{create-invocation}`: `kramme:pr:create --auto --linear-issue {issue-id} --require-generated-description`. The explicit issue identifier is authoritative; do not re-extract it from the branch name.
- `{post-create-hook}`: none.
- `{fix-ci-invocation}`: `kramme:pr:fix-ci --no-consolidate`.
- `{fix-ci-guard}`: none.
- `{validation-extra-args}`: none.
- `{blocked-handoff}`: stop with the Pull Request URL, or the pushed branch when no Pull Request exists, and the delegated skill's exact blocker, then end this top-level invocation. After the blocker is resolved in a later session, invoke `kramme:pr:fix-ci --no-consolidate` directly as the existing-PR workflow; do not rerun `kramme:linear:issue-to-pr` or claim a cross-session Step 7 resume.

## Linear Failure Notes

- **Cleanup failure** — no history rewrite or push has started; fix the cleanup blocker and resume at the shared contract's Step 2.
- **CI or review-feedback loop stops** — preserve the Pull Request and the delegated skill's exact blocker under `{blocked-handoff}`; the later-session recovery is `kramme:pr:fix-ci --no-consolidate`, never a rerun of this workflow.
