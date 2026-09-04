# Append Dirty Auto-Mode Work to Safe Existing PR Branches

- Status: ACCEPTED
- Date: 2026-09-04
- Deciders: repository maintainers
- First safety review: 2026-12-04

## Context

`kramme:pr:create --auto` promises to include all current uncommitted work, but previously stopped whenever the selected feature branch already existed remotely. This made an exact-tip remote—often left by a successful push followed by failed Pull Request creation—a recurring manual-commit blocker even though no remote-only or divergent work existed.

The workflow already supports an exact-OID lease for fast-forwarding an existing remote and `kramme:git:recreate-commits` already supports `--after <commit>`, which keeps the named commit and all earlier history intact.

## Decision

When `--auto` runs on the current feature branch with uncommitted work, permit existing-remote append only when the observed remote tip is equal to or an ancestor of the captured local `HEAD`.

Before any local mutation, the workflow must:

- freeze exactly one origin push endpoint;
- reject credential-bearing endpoint syntax before the endpoint can enter agent-visible state, and reject executable remote helpers or unsupported transports before passing an endpoint to Git;
- require that endpoint to remain at the observed remote OID;
- reject remote-only work, divergence, an open Pull Request, stack membership, or local branch/tip drift; and
- reject modified tracked content hidden by `assume-unchanged` or `skip-worktree`; and
- capture the original local tip, prepared recreation input tip, working-tree state, and remote OID as the rollback baseline.

The workflow then commits all uncommitted work for inclusion and delegates commit recreation with `--after <observed-remote-oid>`. This allows the child to reorganize unpublished local work while making the published prefix an immutable reset boundary. The parent captures the resulting local tip and publishes it with one explicit refspec and an exact OID lease against the observed remote OID.

If preparation or description generation fails before publication, restore the original local tip and uncommitted work without mutating the remote, but only while the checkout still matches either the prepared recreation input or the validated recreated tip. Any partial recreation or later drift preserves the current state for manual recovery. After any non-zero push result, preserve the prepared local state: an immediate old-OID observation cannot prove that an in-flight remote update will not land after the query. Re-query the remote only to classify and report the observed outcome.

Non-auto invocations with dirty existing branches remain blocked until a future interaction design explicitly owns the include/exclude decision.

## Consequences

- `kramme:pr:create --auto` now matches its documented promise to include local work when the existing branch is safely reusable.
- Published commits are never rewritten by this path; only the unpublished tail after the captured remote OID may be recreated.
- Concurrent remote changes remain hard blockers through frozen-endpoint checks and the exact lease.
- The workflow gains rollback state in one existing-remote mode, so pre-publication failures must distinguish remote append from clean recovery and clean fast-forward modes, while every ambiguous publication attempt retains its prepared local recovery state.

## Alternatives Considered

### Require users to commit before retrying

Rejected because it exposes an orchestration detail and contradicts auto mode's promise to include uncommitted work.

### Add one generic commit without recreation

Rejected because it would bypass the workflow's narrative-commit quality contract and leave a temporary orchestration message in published history.

### Rewrite the complete feature branch

Rejected because an existing remote OID proves publication, not permission to replace published history.
