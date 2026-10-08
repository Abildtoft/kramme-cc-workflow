# Permit Guarded Model-Invocable Orchestration Children

- Status: ACCEPTED
- Date: 2026-08-29
- Amended: 2026-10-08
- Deciders: repository maintainers
- First safety review: 2026-11-29

## Context

Claude Code rejects Skill-tool invocation of any skill with `disable-model-invocation: true`, even when a directly invoked parent skill supplies the call. This made `kramme:pr:create --auto` unable to invoke its required `kramme:git:recreate-commits` and `kramme:pr:generate-description` phases.

## Decision

Permit a narrow exception to the default rule that side-effecting skills are model-disabled. Apply it only to these exact parent-child relationships:

- `kramme:git:recreate-commits` is model-invocable only for direct user requests and delegation from `pr:create`. The parent always supplies `--require-unstacked`, `--no-push`, a pinned base commit, and a retry-safe backup ref. The child revalidates unstacked membership at the reset boundary, and the parent repeats that check at publication. The directly invoked parent owns the authorization represented by its `--auto` or `--authorize-history-rewrite` mode and remains the sole remote publisher. Model callers cannot invent `--force-backup`; only `pr:create` may automatically supply its exact derived `--backup-ref`.
- `kramme:pr:generate-description` is model-invocable, but every model caller must supply `--no-update`. Only a direct user invocation may omit that guard and update an existing Pull Request.
- `kramme:linear:issue-implement` is model-invocable only as the child of `kramme:linear:issue-to-pr`, which must pass `--auto` and, for a fresh run, `--set-in-progress` with its validated status handoff, or, for continuation, its validated `--resume-current-branch` handoff. The child owns the status-only Linear write, applies it before branch setup, repeats the parent's confirmation race close, and verifies the result by reading the issue back. A model caller cannot invent `--set-in-progress`, cannot pass it without the parent-owned handoff, and cannot pass it with `--resume-current-branch`; only a direct user invocation may supply it bare, and it then answers the child's own non-backlog confirmation. The child keeps all Linear, branch, planning, scope, and verification gates.
- `kramme:pr:review-convergence` is model-invocable only as a child of `kramme:linear:issue-to-pr` or `kramme:code:plan-to-pr`, which must pass their exact internal work ID, allowlisted archive key, and sentinel-last requirements handoff. Validation-only and plan-scope flags remain caller-owned and validated by the child.
- `kramme:workflow-artifacts:cleanup` is model-invocable only as the child of `kramme:linear:issue-to-pr --ship`, with `--auto`; its destructive inventory, Trash requirement, dirty-artifact checks, and permanent-specification protections remain mandatory.
- `kramme:pr:create` is model-invocable only as a child of `kramme:linear:issue-to-pr` or `kramme:code:plan-to-pr`, with the caller's `--auto` authorization and required generated-description and issue/scope flags. It remains the sole owner of Pull Request publication and its existing backup and lease gates.
- `kramme:pr:fix-ci` is model-invocable only as a child of `kramme:linear:issue-to-pr`, `kramme:code:plan-to-pr`, or `kramme:pr:rebase`, with the parent's bounded `--no-consolidate`/scope or explicit rebase-mode arguments. It retains all CI, review-feedback, retry, and publication checks.
- `kramme:pr:rebase` is model-invocable only as a child of `kramme:pr:fix-ci`, which must pass the exact `--force-push` argument and must not invent `--auto`, `--fix-ci`, or a base override. It retains all branch, stack, conflict, red-flag, verification, lease, and publication gates and remains the sole owner of the validated rebase push.
- `kramme:pr:convention-review` and `kramme:pr:overengineering-review` are model-invocable only as read-only gates of `kramme:pr:review-convergence`, with that parent's inline, requirements, and report-lifecycle arguments. They never edit source or choose dispositions.

Each child must narrowly route model use, document its least-side-effect model contract, and retain its existing confirmation and validation gates. Focused tests must pin the parent arguments.

## Consequences

- `kramme:pr:create --auto` can use the existing child skills through Claude Code's Skill tool without duplicating their workflows.
- The user-invoked, model-disabled `kramme:pr:verify-description --fix` delegates only output-only generation; after its own y/N confirmation, the verifier validates and publishes the returned content itself. This does not grant the child mutation authority or add another exception.
- One skill owns the started-state transition mechanics. `kramme:linear:issue-to-pr` keeps the authorization, status resolution, and confirmation gate, and the parent's Conductor rename now runs after that gate rather than after a verified write.
- The children become visible to the model, and their routing and argument contracts are advisory rather than a platform-enforced authorization check.
- Additional side-effecting children remain model-disabled unless an accepted ADR names the exact parent-child exception.

## Alternatives Considered

### Duplicate the child workflows inside `pr:create`

Rejected because parallel workflow text would drift and make ownership unclear.
