---
name: kramme:siw:issue-to-pr
description: Implements one local SIW issue end to end on a deterministic unpublished branch, preserves atomic SIW tracker/spec updates, runs applicable code-review, convention, and PR-refactor gates to bounded convergence, verifies, and optionally opens the Pull Request and iterates on CI and review feedback until green. Use for one implementation-ready SIW issue. Not for Linear, team-mode batches, existing PRs, stacked PRs, or post-merge rollout.
argument-hint: "<issue-id> [--strict] [--ship]"
disable-model-invocation: true
user-invocable: true
---

# Take an SIW Issue to a Pull Request

Orchestrate SIW issue implementation and the shared Pull Request completion pipeline without deleting or bypassing SIW's versioned tracker and specification state.

## Workflow Contract

- Invoke every delegated skill through the platform's skill mechanism. If direct invocation is unavailable, locate and read that skill's installed `SKILL.md` and follow it with the same arguments.
- Continue between delegated skills without pausing for progress summaries.
- Pause only for a hard blocker or an issue decision that the SIW files, repository conventions, and code cannot determine safely.
- Never broaden the issue, delete SIW workflow state, or add AI attribution.
- Do not create, edit, pause, resume, or clear a Codex goal.

## Step 1: Parse Arguments

1. Remove `--strict` and set `STRICT_REVIEW=true`.
2. Remove `--ship` and set `SHIP_MODE=true`.
3. Reject unknown flags.
4. Require exactly one remaining SIW identifier. Accept `ISSUE-G-001`, `G-001`, `ISSUE-P1-001`, or `P1-001`; normalize it to `{prefix}-{three-digit-number}` and store it as `{issue-id}`.
5. Reject `--team`; this workflow owns exactly one Pull Request branch.

Defaults: `STRICT_REVIEW=false`, `SHIP_MODE=false`.

If validation fails:

```text
Usage: $kramme:siw:issue-to-pr <issue-id> [--strict] [--ship]
Example: $kramme:siw:issue-to-pr P1-001 --strict --ship
```

## Step 2: Resolve the Issue and Branch

Before mutation:

1. Require `git status --porcelain` to be empty. SIW status updates are versioned work; pre-existing changes make ownership ambiguous. Capture the current commit and branch as `{intake-head}` and `{intake-branch}`.
2. Find exactly one non-symlink regular issue file matching `siw/issues/ISSUE-{issue-id}-*.md`. Read it fully and store its repository-relative path as `{issue-path}`.
3. Require the issue to contain scope, acceptance criteria, and an explicit `Mode`. Treat `READY` or `IN PROGRESS` as an implementation candidate. Treat `DONE` or `IN REVIEW` as a completion-resume candidate only when a `## Resolution` section exists; the existing local issue branch must still pass the full provenance checks below before implementation can be skipped. Stop on every other status, missing `Mode`, contradictory requirements, or an unresolved dependency. For `Mode: HITL`, surface the reason and let the delegated implementation skill require explicit confirmation that its human prerequisite is resolved before autonomous work.
4. Derive `{issue-branch}` as `siw/{issue-id-lowercase}-{title-slug}`. Build the slug from the issue title using lowercase ASCII letters and digits, hyphens for other runs, collapsed/trimmed hyphens, and at most 48 slug characters.
5. Validate `{issue-branch}` directly against `[A-Za-z0-9][A-Za-z0-9._/-]*`, reject a leading `-`, then require `git check-ref-format --branch "{issue-branch}"`.
6. Resolve `{base-branch}` from `refs/remotes/origin/HEAD`, falling back to a verified `main` and then `master`. Fetch `origin/{base-branch}`.
7. Require `gh pr list --head "{issue-branch}" --state all --limit 100 --json number,url,state,headRefName,headRefOid` to succeed with an empty list.
8. Require `git ls-remote --heads origin "refs/heads/{issue-branch}"` to succeed with a well-formed zero-line absent result.
9. Preserve the SIW intake tree across branch selection:
   - If `{issue-branch}` does not exist locally, require the intake issue status to be `READY` or `IN PROGRESS` and require `git diff --quiet "{intake-head}" "origin/{base-branch}" -- siw/` before creating it from `origin/{base-branch}`. This workflow requires all committed SIW planning state to be landed on the fetched base before the first run; it never silently drops or cherry-picks local-only planning commits. Set `EXECUTION_MODE=implement`.
   - If `{issue-branch}` exists locally, switch to it and require a clean worktree. Resolve `{branch-base}` with `git merge-base "origin/{base-branch}" HEAD`, require it to be one full commit OID and an ancestor of both tips, and collect every committed path in `{branch-base}..HEAD`. Re-resolve the issue and classify every path against the issue's explicit scope plus the exact allowed workflow-owned additions: applicable tests, permanent SIW specifications, `{issue-path}`, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`. Stop on any unrelated or ambiguous committed path; matching only the SIW subtree is insufficient because `complete-work` reviews and ships the full branch diff.
     - When branch `HEAD` equals the fetched base tip and the SIW tree matches `{intake-head}`, require branch issue status `READY` or `IN PROGRESS` and set `EXECUTION_MODE=implement`.
     - When the branch issue is `READY` or `IN PROGRESS`, has no completed `## Resolution`, at least one committed path exists, and every committed path passed classification, set `EXECUTION_MODE=implement` to resume implementation on the validated branch. An untouched branch whose tip merely lags the fetched base is not a resumable implementation branch.
     - When the branch issue is `DONE` or `IN REVIEW`, has a `## Resolution`, all three SIW tracker views agree, and every committed path passed classification, set `EXECUTION_MODE=complete-resume`.
     - Stop on every other branch/intake combination. Report `{intake-branch}`, the intake and branch issue statuses, branch/base/head identities, and first mismatched or out-of-scope path rather than choosing an authoritative state silently.
10. Require the current branch to equal `{issue-branch}`. Re-resolve `{issue-path}` and require it to remain a non-symlink regular file. When `EXECUTION_MODE=implement`, require the current issue to be `READY` or `IN PROGRESS`; when this is a fresh base-tip branch, also require its content to match the issue read from `{intake-head}`. When `EXECUTION_MODE=complete-resume`, require the validated `DONE`/`IN REVIEW` status, Resolution section, and synchronized tracker state to remain unchanged before invoking completion.

An existing Pull Request or remote branch is a hard new-PR-boundary failure. Do not adopt or rewrite it. Authentication, network, repository, or API errors are blockers rather than evidence of absence.

## Step 3: Implement the SIW Issue

When `EXECUTION_MODE=complete-resume`, do not invoke `kramme:siw:issue-implement` again and do not create another implementation commit. The existing branch already contains the scope-classified implementation, Resolution, and atomic SIW closeout; continue directly to Step 4 so review, verification, or pre-publication completion can resume.

Otherwise invoke `kramme:siw:issue-implement` with `{issue-id} --auto`.

The delegated skill owns issue intake, exploration, conservative ambiguity handling, autonomous implementation, verification, decision-to-spec sync, resolution recording, and atomic updates to the issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`.

Continue only when:

- autonomous implementation completed rather than context-only or guided setup;
- every acceptance criterion is satisfied or a required manual criterion is explicitly represented by `IN REVIEW`;
- the issue has a `## Resolution` section and status `DONE` or `IN REVIEW`;
- all three SIW tracker views agree on status;
- no implementation or spec-sync blocker remains; and
- the current branch is still `{issue-branch}`.

### Implementation Commit Boundary

For `EXECUTION_MODE=implement`, before quality review:

1. Inspect `git status --porcelain` and classify every path.
2. Continue only when every path is an in-scope implementation, test, permanent spec, or atomic SIW tracker update produced by this invocation. Stop on unrelated or ambiguous paths.
3. Run the smallest focused verification that covers remaining changes.
4. Stage only classified paths with `git add -- <path>...`; never use `git add -A`.
5. Commit with a plain-English message containing `{issue-id}`.
6. Require a clean worktree. If hooks change content, rerun focused verification.

## Step 4: Complete the Pull Request Workflow

Build delegated arguments:

```text
--work-id {issue-id} --archive-key siw-issue-to-pr
```

Append `--strict` when `STRICT_REVIEW=true` and `--ship` when `SHIP_MODE=true`. Invoke `kramme:pr:complete-work` once with those arguments and continue until it returns a final result or blocker.

The shared completion skill owns the ordered quality loop, bounded remediation, final verification, optional narrative history rewrite, Pull Request creation, CI/review stabilization, and final local/remote tree proof.

## Step 5: Report

Include the shared completion result plus:

```text
SIW issue: {issue-id}
SIW status: {DONE|IN REVIEW}; issue, overview, and log synchronized
SIW state: preserved on the Pull Request branch; permanent spec changes included when applicable
Branch: {issue-branch}
```

Do not invoke `kramme:workflow-artifacts:cleanup --auto`: it treats active SIW tracker files as disposable project artifacts and could remove other issues. Review artifacts stay isolated under `.context/siw-issue-to-pr/reviews/`.

## Error Handling

- Dirty worktree: ask the user to commit or stash, then rerun.
- Issue missing or not implementation-ready: route to `kramme:siw:issue-define`.
- Local-only or conflicting SIW planning state: land the intended `siw/` tree on the base branch before a first run, or switch to the authoritative existing issue branch before a rerun.
- Completion-stage retry: reuse only the exact clean local issue branch whose full committed path set is issue-scoped and whose `DONE`/`IN REVIEW` Resolution and three tracker views agree; skip implementation and return through `kramme:pr:complete-work`.
- HITL or missing-mode issue: stop for the exact human input; `--strict` and `--ship` do not authorize guessing.
- Existing Pull Request or remote branch: stop before switching or implementing.
- Partial SIW status update: repair only stale tracker fields before review.
- Implementation, review, verification, or shipping failure: preserve delegated recovery evidence and stop.
