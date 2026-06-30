# Repository Architecture

This repo packages a personal workflow plugin for Claude Code and includes a
Codex conversion path. The root [README.md](../../README.md) is the canonical
user-facing documentation; this file is a short map for maintainers and agents.

## Top-Level Shape

- `kramme-cc-workflow/` is the plugin source. Its `.claude-plugin/plugin.json`
  is the installable plugin manifest.
- `.claude-plugin/marketplace.json` is the root marketplace entry that points at
  `kramme-cc-workflow/`.
- `README.md` documents install, usage, skills, agents, hooks, testing, and
  releases.
- `CLAUDE.md` records local contribution conventions.
- `.agents/skills/` contains repository-maintenance skills that are not shipped
  as part of the public plugin.

## Plugin Subsystems

| Subsystem | Main files | Responsibility |
| --- | --- | --- |
| Skills | `skills/*/SKILL.md`, `skills/*/references/`, `skills/*/assets/`, `skills/*/scripts/` | User-invocable and background workflows. Skills must carry their runtime policy inside their own directory. |
| Agents | `agents/*.md` | Specialized Claude Code subagents used by skills and PR review workflows. |
| Hooks | `hooks/hooks.json`, `hooks/*.sh`, `hooks/lib/` | Claude Code lifecycle hooks for command safety, formatting, context links, review confirmation, and usage stats. |
| Shared scripts | `scripts/*.sh`, `scripts/*.py`, `scripts/*.js`, `scripts/dev-server/` | Helpers shared by skills, hooks, release workflows, and browser-facing workflows. |
| Codex converter | `scripts/convert-plugin.js`, `scripts/convert-plugin/` | Loads the Claude plugin, transforms components for Codex, and writes managed output under a Codex home. |
| Evals | `evals/skill-review/`, `evals/skillopt/` | Deterministic fixture evals and the local SkillOpt adapter for the `kramme:skill:review` pilot. |
| Tests | `tests/*.bats`, `tests/test_helper/` | Bats coverage for shell hooks, scripts, converter behavior, eval harnesses, and skill guidance contracts. |

## Runtime Flow

Claude Code installs the plugin from `kramme-cc-workflow/`. Skills and agents
are loaded from their directories, and hook events are wired through
`hooks/hooks.json`. Hook scripts source `hooks/lib/check-enabled.sh` so every
hook can be disabled by the toggle system without editing the hook manifest.

For Codex, `scripts/convert-plugin.js` is the entry point. It loads the Claude
plugin, filters platform-specific skills, converts skills and agents, rewrites
shared script references, stages output, updates managed install state, and
writes Codex config tables when hooks or MCP servers are present.

Browser and visual workflows use the shared dev-server detector in
`scripts/dev-server/`. It resolves an already running local app; it does not
start a server.

## State and Generated Output

- Hook toggle state is stored in `hooks/hook-state.json` and is gitignored.
- Skill usage events default to
  `~/.local/state/kramme-cc-workflow/skill-usage.jsonl`.
- Codex conversion writes managed entries under the selected Codex root,
  defaulting to `~/.codex`.
- SkillOpt and other local run artifacts belong under `.context/` and must not
  be committed.

## Verification Model

The fast default check is:

```bash
make -C kramme-cc-workflow test
```

Use `make -C kramme-cc-workflow lint` for shell and Python linting, and
`make -C kramme-cc-workflow verify` before larger PRs or release candidates.
For focused source-to-test mapping, see [code-map.md](code-map.md).
