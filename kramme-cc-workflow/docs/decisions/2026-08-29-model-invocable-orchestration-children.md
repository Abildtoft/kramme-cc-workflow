# Permit Guarded Model-Invocable Orchestration Children

- Status: ACCEPTED
- Date: 2026-08-29
- Deciders: repository maintainers
- First safety review: 2026-11-29

## Context

Claude Code rejects Skill-tool invocation of any skill with `disable-model-invocation: true`, even when a directly invoked parent skill supplies the call. This made `kramme:pr:create --auto` unable to invoke its required `kramme:git:recreate-commits` and `kramme:pr:generate-description` phases. It also prevented description generation from delegating its existing opt-in visual-evidence phase to `kramme:visual:demo-reel`.

## Decision

Permit a narrow exception to the default rule that side-effecting skills are model-disabled. Apply it only to these exact parent-child relationships:

- `kramme:git:recreate-commits` is model-invocable only for direct user requests and delegation from `pr:create`. The parent always supplies `--require-unstacked`, `--no-push`, a pinned base commit, and a retry-safe backup ref. The child revalidates unstacked membership at the reset boundary, and the parent repeats that check at publication. The directly invoked parent owns the authorization represented by its `--auto` or `--authorize-history-rewrite` mode and remains the sole remote publisher. Model callers cannot invent `--force-backup`; only `pr:create` may automatically supply its exact derived `--backup-ref`.
- `kramme:pr:generate-description` is model-invocable, but every model caller must supply `--no-update`. Only a direct user invocation may omit that guard and update an existing Pull Request.
- `kramme:visual:demo-reel` is model-invocable for direct evidence-capture requests and as a child of `kramme:pr:generate-description`. The parent must pass `--for-pr-description`, the full pinned base commit used for its diff, and an option separator before the opaque capture target. Delegated mode is non-interactive and best-effort, writes only below an ignored, non-symlink `.context/demo-reels/`, never starts a server or uploads evidence, and returns a skipped result when safe capture is unavailable. `kramme:pr:create` passes `--for-pr-create` when asking the description generator for this local evidence, but remains the sole owner of validating it and passing repeatable `gh pr create --attach` flags under its existing user-authorized publication boundary.

Each child must narrowly route model use, document its least-side-effect model contract, and retain its existing confirmation and validation gates. Focused tests must pin the parent arguments.

## Consequences

- `kramme:pr:create --auto` can use the existing child skills through Claude Code's Skill tool without duplicating their workflows.
- The user-invoked, model-disabled `kramme:pr:verify-description --fix` delegates only output-only generation; after its own y/N confirmation, the verifier validates and publishes the returned content itself. This does not grant the child mutation authority or add another exception.
- PR-producing callers can reuse one capture workflow without giving the capture child network-publishing authority. Attachment failure remains best-effort and cannot prevent an otherwise valid Pull Request from being created.
- The children become visible to the model, and their routing and argument contracts are advisory rather than a platform-enforced authorization check.
- Additional side-effecting children remain model-disabled unless an accepted ADR names the exact parent-child exception.

## Alternatives Considered

### Duplicate the child workflows inside `pr:create`

Rejected because parallel workflow text would drift and make ownership unclear.
