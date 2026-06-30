# Decision Index

This index records settled repository decisions and points to their source of
truth. It is not a full ADR archive yet; add a dated ADR when a future decision
needs tradeoffs, rejected alternatives, or migration steps.

| Decision | Current rule | Source |
| --- | --- | --- |
| Root README is canonical public documentation. | Keep install, usage, component listings, testing, and release links in the root `README.md`. | `README.md`, `CLAUDE.md` |
| Skills must be self-contained at runtime. | Skill `SKILL.md` files and skill resources must not require repository-level docs after installation. Runtime policy belongs inside the skill directory. | `CLAUDE.md`, `tests/skill-resource-references.bats` |
| PR titles use Conventional Commits; branch commits do not have to. | Use plain-English branch commit messages. Use Conventional Commits for PR titles because they become merge commits and feed changelog generation. | `README.md#contributing`, `CLAUDE.md` |
| Every hook supports toggling. | Hook scripts source `hooks/lib/check-enabled.sh` and call `exit_if_hook_disabled`, using JSON mode for hooks that must emit `{}`. | `CLAUDE.md`, `docs/hooks.md`, `tests/check-enabled.bats` |
| Codex support is generated from the Claude plugin. | Maintain the Claude plugin source as canonical and use `scripts/convert-plugin.js` to install converted Codex skills, agent skills, hooks, MCP config, and shared scripts. | `README.md#codex`, `scripts/convert-plugin.js` |
| Dev-server detection resolves running servers only. | Browser workflows may auto-detect a reachable local URL, but the detector does not start a server. | `scripts/dev-server/README.md`, `tests/dev-server-scripts.bats` |
| Skill security scanning is part of meaningful skill changes. | Run changed-skill SkillSpector scans for new or materially changed skills; high and critical enforceable findings should block merge unless explicitly accepted. | `README.md#skill-security-scans`, `scripts/run-skillspector.sh` |
| SkillOpt remains a constrained pilot. | Only `kramme:skill:review` is in the SkillOpt loop until another skill has deterministic splits, a candidate gate, and manual acceptance. | `README.md#skillopt-adoption`, `evals/skillopt/README.md` |
| Local maintenance skills are not shipped. | `.agents/skills/` supports maintaining this repo and is exposed locally through `.claude/skills`; it is separate from plugin skills under `kramme-cc-workflow/skills/`. | `README.md#local-repository-maintenance` |

## Adding Decisions

For a small settled convention, add a row here with a source link. For a
decision that changes architecture, runtime behavior, or contribution policy,
add a dated ADR file in this directory and link it from the table.
