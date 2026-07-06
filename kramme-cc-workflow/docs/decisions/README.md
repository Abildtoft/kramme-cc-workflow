# Decision Index

This index records repository decisions and points to their source of truth. Add
a dated ADR when a future decision needs tradeoffs, rejected alternatives, or
migration steps.

## Settled Decisions

| Decision | Current rule | Source |
| --- | --- | --- |
| Audience model for kramme-cc-workflow. | Treat the repository as a practice arena / showcase; release, security, CI, portability, and documentation machinery are deliberate exercises, not adoption-justified product taxes. | [0001-audience-model.md](0001-audience-model.md) |
| Root README is canonical public documentation. | Keep install, usage, component listings, testing, and release links in the root `README.md`. | `README.md`, `CLAUDE.md` |
| Skills must be self-contained at runtime. | Skill `SKILL.md` files and skill resources must not require repository-level docs after installation. Runtime policy belongs inside the skill directory. | `CLAUDE.md`, `tests/skill-resource-references.bats` |
| PR titles use Conventional Commits; branch commits do not have to. | Use plain-English branch commit messages. Use Conventional Commits for PR titles because they become merge commits and feed changelog generation. | `README.md#contributing`, `CLAUDE.md` |
| Every hook supports toggling. | Hook scripts source `hooks/lib/check-enabled.sh` and call `exit_if_hook_disabled`, using JSON mode for hooks that must emit `{}`. | `CLAUDE.md`, `docs/hooks.md`, `tests/check-enabled.bats` |
| Codex support is generated from the Claude plugin. | Maintain the Claude plugin source as canonical and use `scripts/convert-plugin.js` to install converted Codex skills, agent skills, hooks, MCP config, and shared scripts. | `README.md#codex`, `scripts/convert-plugin.js` |
| Host adapters remain thin and documented. | Use the portability matrix as the operational contract for canonical, generated, instruction-only, local-only, and unsupported host surfaces. | `docs/agent-portability.md`, `tests/node/converter-contracts.test.js` |
| Dev-server detection resolves running servers only. | Browser workflows may auto-detect a reachable local URL, but the detector does not start a server. | `scripts/dev-server/README.md`, `tests/dev-server-scripts.bats` |
| Skill security scanning is part of meaningful skill changes. | Run changed-skill SkillSpector scans for new or materially changed skills; high and critical enforceable findings should block merge unless explicitly accepted. | `README.md#skill-security-scans`, `scripts/run-skillspector.sh` |
| Skill quality uses dogfooding-first QA with a capped SkillOpt pilot. | Keep committed behavior eval investment at the `kramme:skill:review` pilot, and run a lightweight top-five smoke ritual after model-generation upgrades. | `2026-07-06-skill-quality-regime.md`, `README.md#skillopt-adoption`, `evals/skillopt/README.md` |
| Local maintenance skills are not shipped. | `.agents/skills/` supports maintaining this repo and is exposed locally through `.claude/skills`; it is separate from plugin skills under `kramme-cc-workflow/skills/`. | `README.md#local-repository-maintenance` |

## Adding Decisions

For a small settled convention, add a row here with a source link. For a
decision that changes architecture, runtime behavior, or contribution policy,
add a dated ADR file in this directory and link it from the table.
