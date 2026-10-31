# Run Shipping Skills Unattended by Default

- Status: ACCEPTED
- Date: 2026-10-31
- Deciders: repository maintainers

## Context

`kramme:git:recreate-commits`, `kramme:pr:create`, `kramme:pr:fix-ci`, `kramme:pr:generate-description`, and `kramme:pr:rebase` each paired an interactive default with an opt-in `--auto`. The maintainer wants the `--auto` behavior on about 99% of direct runs, so the flag was typed on nearly every invocation and the default served only the exception.

The interactive default was also a safety property: a caller that forgot a flag got prompts rather than a history rewrite or a force-push. All five skills are model-invocable under [guarded exceptions](2026-08-29-model-invocable-orchestration-children.md) whose contracts are advisory rather than platform-enforced, so the flip has to keep that omission safe for model callers.

## Decision

- All five skills default to auto mode, the behavior `--auto` used to select, and take `--manual` to restore what the no-flag invocation used to do. `--auto` leaves their interfaces. A leftover `--auto` is ignored so saved prompts keep working.
- Auto mode belongs to a direct user invocation, meaning a typed slash command or `$` mention or a request in the session that names the skill, and to the parent delegations each skill names. A saved PR-creation prompt that names `kramme:pr:create` therefore gets auto mode. Every other invocation runs as `--manual`, whether or not it passes that flag, including one where the model picks the skill for a request that does not name it. `kramme:pr:generate-description` instead treats such a call as `--no-update`, because its generated text has no side effect until it edits a Pull Request.
- `kramme:pr:rebase` takes its former `--auto` behavior in full, including continuing past red flags and pushing without verification. The maintainer chose this knowingly.
- `--force-push` now overrides that default instead of losing to it, so `kramme:pr:fix-ci` and `kramme:pr:create --rebase`, which both pass it, keep every rebase gate.
- `--no-consolidate` turns off auto mode in `kramme:pr:fix-ci`. Otherwise `kramme:linear:issue-to-pr --ship` and `kramme:code:plan-to-pr --ship` would inherit an unattended rebase decision and break their promise not to rewrite an open Pull Request. Their invocations stay byte-identical.
- Modes with their own gates do not inherit the default: `kramme:pr:generate-description --check`, `kramme:pr:rebase --all-open`, and `kramme:pr:fix-ci --scope-plan`.
- Every other skill's `--auto` stays opt-in.

## Consequences

- A typed command that used to prompt now acts. `/kramme:pr:create` commits all uncommitted work and publishes, `/kramme:pr:generate-description` edits an open Pull Request, and `/kramme:pr:rebase` force-pushes after any completed rebase. Saved prompts that relied on the prompts must add `--manual`.
- A forgotten `--manual` no longer fails safe for a direct user. For `kramme:pr:rebase` this is a deliberate exception to the back-pressure principle in [agent autonomy](../agent-autonomy.md): a force-push without verification is expensive to find wrong, though the lease and the rebase's own failure handling still apply.
- The rule that separates direct from model-initiated calls is advisory, like the rest of the model-invocation contracts. Focused tests pin it and the parent arguments, but they cannot enforce it at run time. A request that does not name the skill, such as "open a PR", still prompts, because the model chose the skill.
- Stacked history rewrites stay gated: `kramme:git:recreate-commits` stops in auto mode without `--authorize-history-rewrite`, and `--manual` offers the stack-wide confirmations.
- Conflicted branches from `kramme:pr:rebase --all-open` are routed to `--manual`, because a conflict is the case where the default is least safe.
- The catalog now has two conventions for the same word: five skills are unattended unless `--manual`, and the rest are interactive unless `--auto`.

## Alternatives Considered

### Make `--force-push` the rebase default

This keeps conflict, red-flag, and verification gates while skipping only the final confirmation. Rejected because the maintainer asked for the existing `--auto` behavior on this skill, with its risk already known. `--force-push` remains available for any run that wants those gates.

### Keep `--auto` and add a setting for the default

Rejected because a per-repository or per-user setting would make the same command behave differently across hosts and would add a second configuration surface for one maintainer's preference.

### Reject a leftover `--auto`

Rejected because the flag's meaning is now the default, so a stop would cost a rerun without preventing any mistake.

### Count only typed commands as direct

Rejected because a saved prompt that names the skill, such as a host's PR-creation instructions, would then prompt on the user's most common path.

### Let model callers inherit the default

Rejected because a model call that dropped a flag would rewrite history or force-push with no human in the loop, which the guarded exceptions exist to prevent.
