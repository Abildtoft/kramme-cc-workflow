# Permit Guarded Model-Invocable Orchestration Children

- Status: ACCEPTED
- Date: 2026-08-29
- Deciders: repository maintainers
- First safety review: 2026-11-29

## Context

Claude Code rejects Skill-tool invocation of any skill with `disable-model-invocation: true`, even when a directly invoked parent skill supplies the call. This made `kramme:pr:create --auto` unable to invoke its required `kramme:git:recreate-commits` and `kramme:pr:generate-description` phases.

## Decision

Permit a narrow exception to the default rule that side-effecting skills are model-disabled. Apply it only to these children of `kramme:pr:create`:

- `kramme:git:recreate-commits` is model-invocable only for direct user requests and delegation from `pr:create`. The parent always supplies `--require-unstacked`, `--no-push`, a pinned base commit, and a retry-safe backup ref. The directly invoked parent owns the authorization represented by its `--auto` or `--authorize-history-rewrite` mode, preserves its unstacked-only boundary across delegation, and remains the sole remote publisher.
- `kramme:pr:generate-description` is model-invocable, but every model caller must supply `--no-update`. Only a direct user invocation may omit that guard and update an existing Pull Request.

Each child must narrowly route model use, document its least-side-effect model contract, and retain its existing confirmation and validation gates. Focused tests must pin the parent arguments.

## Consequences

- `kramme:pr:create --auto` can use the existing child skills through Claude Code's Skill tool without duplicating their workflows.
- The children become visible to the model, and their routing and argument contracts are advisory rather than a platform-enforced authorization check.
- Additional side-effecting children remain model-disabled unless an accepted ADR names the exact parent-child exception.

## Alternatives Considered

### Duplicate the child workflows inside `pr:create`

Rejected because parallel workflow text would drift and make ownership unclear.
