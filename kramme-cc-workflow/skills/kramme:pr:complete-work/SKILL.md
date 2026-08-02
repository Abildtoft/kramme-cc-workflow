---
name: kramme:pr:complete-work
description: Internal post-implementation orchestrator for kramme:siw:issue-to-pr and kramme:code:plan-to-pr. Rechecks the new-PR boundary and caller scope, runs applicable code-review, convention, and PR-refactor gates to bounded convergence, verifies the prepared branch, and optionally opens the Pull Request and iterates on CI and review feedback until green. Not a standalone implementation workflow.
argument-hint: "--work-id <id> --archive-key <siw-issue-to-pr|code-plan-to-pr> [--scope-plan <archived-plan>] [--strict] [--ship]"
disable-model-invocation: true
user-invocable: false
---

# Complete Prepared Work as a Pull Request

Finish a caller-prepared implementation branch without changing the caller's source-of-truth workflow. The caller owns issue or plan intake, branch selection, implementation, and the initial implementation commit boundary. This skill owns quality convergence, final verification, and optional Pull Request shipping.

## Workflow Contract

- Invoke every delegated skill through the platform's skill mechanism. If direct invocation is unavailable, locate and read that skill's installed `SKILL.md` and follow it with the same arguments. This rule covers every delegation below and in both references.
- Continue between delegated skills without pausing for progress summaries.
- Pause only for a hard blocker or a decision the work item, repository conventions, and code cannot determine safely.
- Treat a delegated skill failure as a workflow failure. Preserve its recovery information and do not skip ahead.
- Keep every edit within the prepared work item's scope.
- Never add AI attribution to code, commits, or the Pull Request.
- Do not create, edit, pause, resume, or clear a Codex goal.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` before repository work.

1. `--strict` sets `STRICT_REVIEW=true`.
2. `--ship` sets `SHIP_MODE=true`.
3. Require `--work-id <id>` exactly once. Validate the value against `[A-Za-z0-9][A-Za-z0-9._:-]*`; reject whitespace, a leading `-`, shell metacharacters, and every other character outside that allowlist. Store it as `{work-id}`.
4. Require `--archive-key <key>` exactly once. Accept only `siw-issue-to-pr` or `code-plan-to-pr`; store it as `{archive-key}`. This allowlist prevents caller-controlled path construction.
5. Parse `--scope-plan <path>` at most once. Require it exactly once when `{archive-key}` is `code-plan-to-pr`, and reject it for `siw-issue-to-pr`. Store the value as `{scope-plan-input}` without using it in a command until Step 2 validates the complete path.
6. Reject unknown flags, duplicate valued flags, missing values, and positional arguments.

Defaults:

- `STRICT_REVIEW=false`
- `SHIP_MODE=false`

`--strict` changes finding disposition, not product authority. `--ship` authorizes the shipping contract's backup-protected narrative rewrite, first publication of the previously absent branch, Pull Request creation, and subsequent scoped CI/review fixes. It never authorizes rewriting an existing remote branch or Pull Request, merging, deployment, or post-merge rollout.

If validation fails, report:

```text
Internal usage: $kramme:pr:complete-work --work-id <id> --archive-key <siw-issue-to-pr|code-plan-to-pr> [--scope-plan <archived-plan>] [--strict] [--ship]
Invoke kramme:siw:issue-to-pr or kramme:code:plan-to-pr instead.
```

## Step 2: Recheck the Prepared Branch

The caller must have established a clean committed implementation boundary.

1. Require `git status --porcelain` to be empty.
2. Resolve the default base from `refs/remotes/origin/HEAD`, falling back to a verified `main` and then `master`. Store it as `{base-branch}`.
3. Fetch `origin/{base-branch}` and require the fetch to succeed.
4. Capture the current branch as `{work-branch}`. Require it to differ from `{base-branch}` and validate the agent-tracked value against `[A-Za-z0-9][A-Za-z0-9._/-]*`, a non-leading `-`, and `git check-ref-format --branch`.
5. Require at least one commit in `origin/{base-branch}..HEAD`.
6. When `{archive-key}` is `code-plan-to-pr`, validate the caller's scope handoff before any review or edit:
   - Resolve `{scope-plan-input}` without following a final symlink. Require every parent below `.context/code-plan-to-pr/` to be a real non-symlink directory and require the canonical input to be a non-symlink regular file at `.context/code-plan-to-pr/{plan-set-id}/plans/PR_PLAN_[A-Z][0-9][0-9][A-Z]_[A-Z0-9_]+.md`. Require `{plan-set-id}` to match `ps-` plus one full lowercase hexadecimal object ID for the repository's object format. The broader first label character permits a normalized standalone attachment; the caller still restricts repository-root generated sets to `W##L`.
   - Read the plan fully. Parse and normalize literal backticked paths only from `### In Scope` using the plan caller's rules: reject absolute paths, a leading `-`, `..` segments, NUL/control characters, duplicate normalized paths, and any path whose canonical resolution escapes the repository. Store the exact normalized list as `VALIDATED_SCOPE_PATHS`, pass it only through quoted array expansion, and never render a plan value into shell command text.
   - Read `references/standalone-scope-handoff.md` completely and follow its archive classification, immutable-source proof, and scope policy. It sets `PLAN_SCOPE_MODE=exact-files` for normalized standalone attachments and `PLAN_SCOPE_MODE=containment` for generated plan sets.
   - Require a complete `## Workflow State` block with `Stage: IMPLEMENTED` or `Stage: QUALITY_BLOCKED`. Require its plan set, plan basename, branch, base branch, base commit, checkpoint head/tree, and normalized scope list to match the validated archive, `{work-branch}`, `{base-branch}`, the live plan, and `VALIDATED_SCOPE_PATHS`.
   - Require the base/checkpoint values to be full lowercase hexadecimal object IDs for the repository's object format. Require the base commit to resolve and be an ancestor of the checkpoint, the checkpoint to equal current `HEAD`, and its tree to equal the recorded checkpoint tree. For every committed path in `{base-commit}..HEAD`, require exact equality with one `VALIDATED_SCOPE_PATHS` entry when `PLAN_SCOPE_MODE=exact-files`; otherwise allow exact path or directory containment. Store the base as `{scope-base-commit}`.
   - Set `PLAN_SCOPE_ACTIVE=true`. For `siw-issue-to-pr`, set `PLAN_SCOPE_ACTIVE=false`; its caller retains the SIW-specific scope and tracker contract.
7. Query all Pull Requests for the exact branch:

   ```bash
   gh pr list --head "{work-branch}" --state all --limit 100 --json number,url,state,headRefName,headRefOid
   ```

   Require success and an empty list. An API, authentication, network, rate-limit, or repository error is a blocker, not evidence of absence.

8. Query `git ls-remote --heads origin "refs/heads/{work-branch}"`. Require success and a well-formed zero-line absent result. An existing or malformed ref is a blocker.
9. Create `.context/{archive-key}/reviews/` and require `git check-ignore -q -- .context/{archive-key}/reviews/` to succeed. Stop if the caller-selected fixed archive is not ignored.

If the branch already has any Pull Request, route a later session to `kramme:pr:fix-ci --no-consolidate`. If only the remote branch exists, require coordination or a fresh branch; this new-PR workflow never adopts it.

## Step 3: Run the Quality Loop

Read `references/review-convergence.md` and follow it completely with `{work-id}` and `{archive-key}`.

During normal remediation rounds, evaluate applicability and run active gates in this order:

1. `kramme:pr:code-review --parallel --inline`
2. `kramme:pr:convention-review --inline`
3. `kramme:code:refactor-opportunities pr`

The parent owns finding triage, edits, the shared remediation-cycle ledger, focused verification, remediation commits, and reruns. When `PLAN_SCOPE_ACTIVE=true`, every proposed edit, dirty path, staged path, and committed remediation path must satisfy `PLAN_SCOPE_MODE`: exact equality for `exact-files`, otherwise exact path or directory containment. An otherwise valid finding that requires a path outside that list is a scope blocker, not permission to widen the plan. Move file-backed review output into `.context/{archive-key}/reviews/` before collecting another unified scope.

## Step 4: Run Final Verification

Invoke `kramme:verify:run` for a fresh project-configured pass.

- Require every applicable check to pass.
- Report missing tools and skipped destructive integration/E2E checks instead of claiming they ran.
- If an in-scope defect appears and remediation budget remains, consume one cycle, fix it, cross the remediation commit boundary, return through Step 3, and rerun verification.
- If verification exposes a defect after the budget is exhausted or the loop stopped at diminishing returns, do not edit again or ship without explicit user authorization to resume. A clean final verification may still ship with explicitly deferred optional findings.
- Stop on missing dependencies, external services, or required user decisions.

Capture the successful verification evidence. No source change may occur between this point and Pull Request creation except through the shipping contract.

Before returning success or entering the shipping contract, require the worktree clean and the current branch still equal to `{work-branch}`. When `PLAN_SCOPE_ACTIVE=true`, rerun `RECHECK_STANDALONE_SCOPE` if `PLAN_SCOPE_MODE=exact-files`, then collect every committed path in `{scope-base-commit}..HEAD` and enforce the mode's exact-or-containment membership rule. Capture the resulting full head/tree as the verified scoped completion checkpoint. Stop before publication on the first out-of-scope path. Treat the first newly ineligible standalone path as the same blocker.

## Step 5: Stop or Ship

If `SHIP_MODE=false`, stop without invoking `kramme:pr:create`. Report:

```text
Completion disposition: success
Pre-publication quality and verification: passed
Publication state: absent
Work branch: {work-branch}
Local head/tree: {head} {tree}
Remote head: absent
Work item: {work-id}
Implementation: complete
Quality gates: complete ({standard|strict}; {active gates})
Skipped gates: {gate + evidence-based reason | none}
Remediation: {cycles used}/{cycle budget}; stop={converged|diminishing returns}
Findings: 0 blocking unresolved; fixed={count}, rejected={count}, deferred optional={count}, blocked=0
Verification: passed
Pull Request: not created (--ship was not supplied)
Blocker: none
Recovery: none
Next: $kramme:pr:create --auto --require-generated-description
Then: $kramme:pr:fix-ci --no-consolidate
```

If `SHIP_MODE=true`, read `references/shipping-contract.md` and follow it completely.

## Step 6: Report a Shipped Result

Report:

```text
Completion disposition: success
Pre-publication quality and verification: passed
Publication state: open Pull Request
Work branch: {work-branch}
Local head/tree: {final-head} {final-tree}
Remote head: {final-head}
Work item: {work-id}
Implementation: complete
Quality gates: complete ({standard|strict}; {active gates})
Skipped gates: {gate + evidence-based reason | none}
Remediation: {cycles used}/{cycle budget}; stop={converged|diminishing returns}
Findings: 0 blocking unresolved; fixed={count}, rejected={count}, deferred optional={count}, blocked=0
Verification: initial tree {verified-tree} passed; final tree {final-tree} {unchanged|passed fresh verification}
CI: {green|none configured}; review feedback addressed; final tree {final-tree}
Pull Request: {url}
Blocker: none
Recovery: none
History: narrative rewrite completed before PR creation; CI fix commits retained separately; final remote head matches the clean local tree
```

Replace success wording with the exact limitation when coverage is degraded, a check is skipped, or the workflow stops.

## Caller Return Contract

Always return enough structured state for the source workflow to distinguish a resumable pre-publication blocker from a published handoff:

```text
Completion disposition: success | prepublication_blocked | published_blocked
Pre-publication quality and verification: passed | incomplete
Publication state: absent | remote branch only | open Pull Request
Work branch: {work-branch}
Local head/tree: {head} {tree}
Remote head: {oid | absent | unverified}
Pull Request: {url | absent | unverified}
Blocker: {exact blocker | none}
Recovery: {exact next invocation | none}
```

- `success` means the requested non-ship or ship workflow completed.
- `prepublication_blocked` means no remote branch or Pull Request exists. Return the exact clean local checkpoint so a caller with its own provenance rules can resume completion without rerunning implementation.
- `published_blocked` means the exact branch was published or its Pull Request was created after quality convergence and final verification, but creation, CI/review stabilization, or final proof stopped. Return the shipping-contract handoff. A caller may persist implementation completion and publication provenance, but must preserve the blocker and must not call the overall result successful.
- Never return `prepublication_blocked` over a dirty tree, an unverified branch/head/tree, or unknown remote state. Report the raw blocker instead.

## Artifact Lifecycle

- Review reports are produced by active quality gates, consumed during triage, and moved to `.context/{archive-key}/reviews/`. They remain gitignored and never enter the Pull Request.
- Implementation and remediation commits are consumed by `kramme:pr:create`, then refreshed only by accepted CI/review fixes.
- The Pull Request is created only after review and verification pass. It is retired by merge or close.

## Error Handling

- Dirty or base branch: return to the caller's implementation commit boundary.
- Existing Pull Request: stop; use `kramme:pr:fix-ci --no-consolidate` in a later session.
- Existing remote branch without a Pull Request: stop; coordinate or choose a fresh source-workflow branch.
- Quality coverage degraded: identify the failed dimensions and do not call the result clean.
- Diminishing returns with a required finding: stop before final verification and shipping.
- Verification failure: fix through the bounded quality loop or stop with evidence.
- Shipping failure: return the structured `published_blocked` handoff when publication occurred; otherwise preserve the delegated rollback and return a proven `prepublication_blocked` checkpoint only when the remote remains absent.
