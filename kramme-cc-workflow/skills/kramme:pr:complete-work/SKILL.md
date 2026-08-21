---
name: kramme:pr:complete-work
description: Internal post-implementation orchestrator for kramme:siw:issue-to-pr and kramme:code:plan-to-pr. Rechecks the new-PR boundary, delegates caller-scoped review convergence and verification to kramme:pr:review-convergence, and optionally opens the Pull Request and iterates on CI and review feedback until green. Not a standalone implementation or review workflow.
argument-hint: "--work-id <id> --archive-key <siw-issue-to-pr|code-plan-to-pr> [--scope-plan <archived-plan>] [--strict] [--ship]"
disable-model-invocation: true
user-invocable: false
---

# Complete Prepared Work as a Pull Request

Finish a caller-prepared implementation branch without changing the caller's source-of-truth workflow. The caller owns issue or plan intake, branch selection, implementation, and the initial implementation commit boundary. This skill owns new-PR preflight, the requirements handoff, optional Pull Request shipping, and structured recovery; `kramme:pr:review-convergence` owns review and verification.

## Workflow Contract

- Invoke every delegated skill through the platform's skill mechanism. If direct invocation is unavailable, locate and read that skill's installed `SKILL.md` and follow it with the same arguments. This rule covers every delegation below and in the shipping reference.
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
6. Query all Pull Requests for the exact branch:

   ```bash
   gh pr list --head "{work-branch}" --state all --limit 100 --json number,url,state,headRefName,headRefOid
   ```

   Require success and an empty list. An API, authentication, network, rate-limit, or repository error is a blocker, not evidence of absence.

7. Query `git ls-remote --heads origin "refs/heads/{work-branch}"`. Require success and a well-formed zero-line absent result. An existing or malformed ref is a blocker.

If the branch already has any Pull Request, route a later session to `kramme:pr:fix-ci --no-consolidate`. If only the remote branch exists, require coordination or a fresh branch; this new-PR workflow never adopts it.

## Step 3: Invoke Review Convergence

Build one frozen `{work-requirements}` handoff before delegation:

- For `siw-issue-to-pr`, resolve exactly one non-symlink regular file matching `siw/issues/ISSUE-{work-id}-*.md`. Read it fully and tightly preserve its title, requested behavior, scope, acceptance criteria, constraints, non-goals, mode, and resolution evidence. Record absent requirement categories explicitly.
- For `code-plan-to-pr`, state that the validated `--scope-plan` is the authoritative prepared-work contract. Preserve its work label and require `kramme:pr:review-convergence` to validate the archive, read the complete plan, and freeze its goal, context, in-scope paths, requirements, completion criteria, verification obligations, constraints, and non-goals without inventing or thinning them.

Build delegated arguments:

```text
--work-id {work-id} --archive-key {archive-key} [--scope-plan {scope-plan-input}] [--strict] --requirements {work-requirements}
```

Include `--scope-plan` only for `code-plan-to-pr` and append `--strict` only when `STRICT_REVIEW=true`. Invoke `kramme:pr:review-convergence` once and capture its structured handoff.

Continue only when it returns `Review convergence: passed`, normal mode, the exact work ID and branch, a clean current tree matching its review tree, complete ordered-gate evidence, no required or blocked finding, and passed final verification. JSON-decode its `Requirements JSON` field and require the decoded value to equal `{work-requirements}` byte-for-byte. For plan scope, also capture and preserve its validated scope plan, mode, scope base, and normalized paths as the only state the shipping contract may use. Stop at any missing invariant; never reconstruct or restart its remediation loop inside this skill.

## Step 4: Stop or Ship

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

## Step 5: Report a Shipped Result

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

- Review reports are produced and owned by `kramme:pr:review-convergence`, consumed during triage, and moved to `.context/{archive-key}/reviews/`. They remain gitignored and never enter the Pull Request.
- Implementation and remediation commits are consumed by `kramme:pr:create`, then refreshed only by accepted CI/review fixes.
- The Pull Request is created only after review and verification pass. It is retired by merge or close.

## Error Handling

- Dirty or base branch: return to the caller's implementation commit boundary.
- Existing Pull Request: stop; use `kramme:pr:fix-ci --no-consolidate` in a later session.
- Existing remote branch without a Pull Request: stop; coordinate or choose a fresh source-workflow branch.
- Quality coverage degraded: identify the failed dimensions and do not call the result clean.
- Review convergence or verification failure: preserve the delegated cycle ledger, scope state, and exact blocker; do not recreate the loop or reset its budget locally.
- Shipping failure: return the structured `published_blocked` handoff when publication occurred; otherwise preserve the delegated rollback and return a proven `prepublication_blocked` checkpoint only when the remote remains absent.
