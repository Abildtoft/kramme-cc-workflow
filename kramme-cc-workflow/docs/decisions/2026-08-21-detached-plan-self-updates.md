# Detached Plan Self-Updates Preserve Immutable Provenance

- Status: ACCEPTED
- Date: 2026-08-21
- Deciders: repository maintainers

## Context

`kramme:code:plan-to-pr` accepts detached `PR_PLAN_*.md` attachments without their source index or sibling plans. The workflow normalizes each attachment into a content-derived archive containing an immutable `ATTACHMENT_SOURCE.md` and a mutable execution copy.

Generated plan guidance now offers to update stale plans in place after explaining drift and receiving explicit approval. Asking detached-plan users to supply a replacement would contradict that handoff. Mutating the attachment or its established archive, however, would break the provenance and retry guarantees used by downstream completion and CI workflows.

## Decision

Before implementation begins, an eligible detached plan may self-update after explicit user approval. The workflow must:

1. Preserve the original attachment, source object ID, plan-set ID, and any established archive unchanged.
2. Fetch the execution base, require a clean source worktree whose `HEAD` equals that fetched tip, then refresh a temporary copy from that exact committed evidence and rerun full scope closure.
3. Require separate confirmation if the refresh changes the implementation boundary, dependencies, execution label, or canonical filename.
4. Revalidate the revised plan and derive a new source object ID and plan-set ID from its final bytes.
5. Revalidate source, status, base, and execution-boundary eligibility after approval; require ignored staging and destination paths; redact secret values from refreshed evidence; publish a new immutable snapshot and normalized archive atomically; then restart plan validation from that archive.

Self-update is available only before an execution boundary exists. Plans with workflow state, execution results, an implementation branch, a remote branch, or a Pull Request use their existing retry and reconciliation paths.

## Invariants

- No refresh rewrites, deletes, or reuses the identity of the original source or archive.
- Every normalized archive is bound to exactly one immutable source snapshot.
- A changed plan body produces a different source object ID and plan-set ID.
- Approval to refresh stale evidence does not silently authorize a wider implementation scope.
- Approval does not survive a changed source, status, base tip, local branch, remote branch, or Pull Request boundary.
- Uncommitted evidence must be committed, stashed, or removed before refresh because `Planned at` records a commit boundary.
- Refreshed evidence and `Planned at` describe the same fetched commit that seeds the implementation branch.
- Secret values never enter the temporary revision or immutable archive, and refresh artifacts remain below verified ignored paths.
- Failure before publication leaves the prior source and archive usable and unchanged.

## Alternatives Considered

### Ask the user for a replacement attachment

Rejected because it makes detached plans less capable than the generated handoff promises and transfers repository-aware refresh work back to the user.

### Mutate the attachment or established archive in place

Rejected because retries and downstream completion checks rely on an immutable comparison source and content-derived identity.

### Add mutable revision history inside one archive

Rejected because it would weaken the one-source-per-archive invariant and require every archive consumer to interpret revision state. A new archive reuses the existing provenance contract.

## Consequences

Positive:

- Detached plans can recover from planning drift without replacement input.
- Original evidence remains auditable, and downstream archive consumers keep their existing identity contract.
- Scope changes receive a distinct confirmation gate.

Negative:

- One logical plan may leave multiple immutable archives after approved refreshes.
- The workflow must validate and report both the previous and replacement identities.
