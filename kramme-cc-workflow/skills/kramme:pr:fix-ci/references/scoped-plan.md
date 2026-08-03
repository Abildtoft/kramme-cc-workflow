# Scoped Plan Mutation Contract

Apply this contract only when `kramme:pr:fix-ci` receives `--scope-plan`. It makes a plan-to-PR scope boundary durable across the initial CI loop and later recovery sessions instead of relying on caller memory.

## Validate the Archive

1. Canonicalize the repository root and resolve the supplied path without following a final symlink. Require `.context`, `.context/code-plan-to-pr`, and every later parent to be real non-symlink directories below the canonical repository root. Require a non-symlink regular input at `.context/code-plan-to-pr/{plan-set-id}/plans/PR_PLAN_[A-Z][0-9][0-9][A-Z]_[A-Z0-9_]+.md`, where `{plan-set-id}` is `ps-` plus one full lowercase object ID. Store the repository-relative path as `{validated-scope-plan}` and never render its raw argument into command text.
2. Read the selected plan and sibling index completely. Parse literal backticked paths only from `### In Scope`; reject absolute paths, a leading `-`, `..` segments, control characters, duplicates, resolution outside the repository, and an empty list. Store exact normalized values in `VALIDATED_SCOPE_PATHS` and quoted literal Git pathspecs separately.
3. Classify the archive before trusting lifecycle text. A non-`W##L` basename, an exact `**Input mode:** standalone attachment` marker in the index or rejection record, or an `ATTACHMENT_SOURCE.md` sibling is standalone evidence. Reject standalone evidence with a `W##L` basename. With evidence, require a non-`W` basename, exactly one plan and index row, independent dependency metadata, the rejection marker, and a source snapshot whose object ID matches the index. Rebuild the `standalone-attachment` NUL-delimited manifest from the basename and source object ID and require its hash to equal `{plan-set-id}`. Normalize the opening status in the mutable plan and source snapshot, remove exactly one allowed workflow-state/result pair, and require every other byte to match. Set `PLAN_SCOPE_MODE=exact-files`. With no evidence, require a generated `W##L` basename and set `PLAN_SCOPE_MODE=containment`.
4. Require plan/index status agreement and exactly one complete workflow-state block. Accept either:
   - `SCOPED_PLAN_LIFECYCLE=initial`: status `TODO` or `READY`, stage `IMPLEMENTED` or `QUALITY_BLOCKED`, and no execution result; or
   - `SCOPED_PLAN_LIFECYCLE=recovery`: status `DONE`, stage `PUBLISHED_BLOCKED`, one execution result, and recovery exactly `$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}`.
5. Require the state plan set, basename, branch, base branch, full base/checkpoint OIDs, checkpoint tree, and normalized scope list to match the archive and current branch. Fetch the recorded base, require the base commit to equal `git merge-base "{checkpoint-head}" "origin/{base-branch}"`, and require it to be an ancestor of the checkpoint. Require local `HEAD`, its tree, the remote branch, and the open same-repository Pull Request head to equal the checkpoint. Revalidate every committed path in `{base-commit}..HEAD` against the active membership rule and store the base as `{scope-base-commit}`.
6. In recovery mode, tolerate only an interrupted prior scoped push: when the recorded checkpoint differs from the matching local/remote/Pull Request head, require the old checkpoint to be its ancestor, require every intervening committed path and the full base-to-head set to remain in scope, rerun standalone eligibility when applicable, and refresh the archive checkpoint before any new edit. Reject divergence, force-push evidence, or an out-of-scope intervening path.

## Preserve Scope

For `exact-files`, reject existing directories, the repository's Git administrative path, ignored untracked or missing paths, and every dirty, staged, committed, or proposed path that is not exactly one `VALIDATED_SCOPE_PATHS` entry. Run the visibility check in one NUL-delimited `git check-ignore --index -z --stdin` batch, capture NUL output in a temporary file, preserve the first matching path as the blocker, and remove the temporary file on every path. Define this file-level, Git-admin, and visibility proof as `RECHECK_STANDALONE_SCOPE`.

For `containment`, require each path to equal one validated path or remain below a validated directory. Never use Git glob semantics to decide membership.

Before each edit, validate every intended path. Before staging, require every dirty and staged path to pass membership, run `RECHECK_STANDALONE_SCOPE` for exact-file mode, and stage only the validated changed-path array. Before every push, revalidate all committed paths in `{scope-base-commit}..HEAD`; after every push, require local, remote, and Pull Request heads to match.

## Persist Recovery State

The exact recovery payload is `$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}`.

In initial lifecycle mode, do not mutate the archive. Return the final head/tree, blocker or success, and exact recovery payload so `kramme:pr:complete-work` remains the sole source-state writer.

In recovery lifecycle mode, immediately after every proven push replace the archived checkpoint head/tree and execution-result completion commit with the new local head/tree while preserving the proven base and scope. If the loop remains blocked, retain `PUBLISHED_BLOCKED`, record the exact current blocker and recovery payload, and re-read the archive before returning. On success, remove the stale blocker and recovery, set the workflow stage to `COMPLETE`, keep plan/index status `DONE`, record the final open Pull Request identity, and re-read the archive. A failed archive write or revalidation is a blocker even when the push succeeded; the interrupted-push rule above is the only supported reconciliation path.
