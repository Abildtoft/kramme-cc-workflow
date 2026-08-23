# Decision Index

This index records repository decisions and points to their source of truth. Add
a dated ADR when a future decision needs tradeoffs, rejected alternatives, or
migration steps.

## Settled Decisions

| Decision | Current rule | Source |
| --- | --- | --- |
| Audience model for kramme-cc-workflow. | Treat the repository as a practice arena / showcase; release, security, CI, portability, and documentation machinery are deliberate exercises, not adoption-justified product taxes. | [0001-audience-model.md](0001-audience-model.md) |
| Root README is canonical public documentation. | Keep install, usage, component listings, testing, and release links in the root `README.md`. | `README.md`, `AGENTS.md` |
| Skills must be self-contained at runtime. | Skill `SKILL.md` files and skill resources must not require repository-level docs after installation. Runtime policy belongs inside the skill directory. | `AGENTS.md`, `tests/skill-resource-references.bats` |
| PR titles use Conventional Commits; branch commits do not have to. | Use plain-English branch commit messages. Use Conventional Commits for PR titles because they become merge commits and feed changelog generation. | `README.md#contributing`, `AGENTS.md` |
| Every hook supports toggling. | Hook scripts source `hooks/lib/check-enabled.sh` and call `exit_if_hook_disabled`, using JSON mode for hooks that must emit `{}`. | `AGENTS.md`, `docs/hooks.md`, `tests/check-enabled.bats` |
| Codex support is generated from the Claude plugin. | Maintain the Claude plugin source as canonical and use `scripts/convert-plugin.js` to install converted Codex skills, agent skills, hooks, MCP config, and shared scripts. | `README.md#codex`, `scripts/convert-plugin.js` |
| Host adapters remain thin and documented. | Use the portability matrix as the operational contract for canonical, generated, instruction-only, local-only, and unsupported host surfaces. | `docs/agent-portability.md`, `tests/node/converter-*.test.js` |
| Dev-server detection resolves running servers only. | Browser workflows may auto-detect a reachable local URL, but the detector does not start a server. | `scripts/dev-server/README.md`, `tests/dev-server-scripts.bats` |
| Skill security scanning is part of meaningful skill changes. | Run changed-skill SkillSpector scans for new or materially changed skills; high and critical enforceable findings should block merge unless explicitly accepted. | `docs/development.md#skill-security-scans`, `scripts/run-skillspector.sh` |
| Skill quality uses dogfooding-first QA with a capped SkillOpt pilot. | Keep committed behavior eval investment at the `kramme:skill:review` pilot, and run a lightweight top-five smoke ritual after model-generation upgrades. | `2026-07-06-skill-quality-regime.md`, `docs/development.md#skillopt-adoption`, `evals/skillopt/README.md` |
| Skill library growth and pruning should be usage-informed. | Consult the 30-day and 90-day skill usage reports before adding new skills or pruning existing ones; use quarterly reviews to separate core, emerging, observe, and sunset candidates. | `docs/decisions/2026-07-06-skill-usage-portrait.md` |
| Skill catalog shape preserves distinct, evidence-backed entry points. | Permit singleton domains only when they add durable routing information, merge adjacent skills when only a mode separates them, and use `kramme:<domain>:<skill-name>` unless an accepted decision grants an exception. | [2026-07-29-skill-catalog-shape.md](2026-07-29-skill-catalog-shape.md) |
| Detached plan self-updates preserve immutable provenance. | After approval, refresh a preimplementation detached plan into a new content-derived archive; keep the original source, identity, and archive unchanged. | [2026-08-21-detached-plan-self-updates.md](2026-08-21-detached-plan-self-updates.md) |
| Prepared PR review convergence is a shared workflow phase. | Expose `kramme:pr:review-convergence` for direct prepared-branch use and delegate Linear, SIW, and archived-plan callers to the same primitive; direct use may freeze requirements from conversation, one explicit Linear issue, or a supplied block, while internal callers keep their frozen handoff authoritative. | [2026-08-21-pr-review-convergence-extraction.md](2026-08-21-pr-review-convergence-extraction.md), [2026-08-21-review-convergence-requirement-sources.md](2026-08-21-review-convergence-requirement-sources.md) |
| Local maintenance skills are not shipped. | `.agents/skills/` supports maintaining this repo and is exposed locally through `.claude/skills`; it is separate from plugin skills under `kramme-cc-workflow/skills/`. | `README.md#local-repository-maintenance` |

## Proposed

Nothing here changes a rule in the table above.

| Decision under consideration | Record |
| --- | --- |
| Whether to expand the committed eval cap to `kramme:pr:resolve-review`. Tests the revisit condition in `2026-07-06-skill-quality-regime.md` against a prototype and recommends reaffirming the cap. | [2026-08-08-eval-scope-review.md](2026-08-08-eval-scope-review.md) |

## Adding Decisions

For a small settled convention, add a row to the Settled Decisions table with a
source link. For a decision that changes architecture, runtime behavior, or
contribution policy, add a dated ADR file in this directory and link it from
that table. While an ADR is still PROPOSED, list it under Proposed instead; fold
it into Settled Decisions in the same change that flips its status to ACCEPTED —
as a new row, or as an amendment to the Source cell of the row it revises.
