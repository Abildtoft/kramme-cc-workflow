# Repository Architecture

This repo packages a personal workflow plugin for Claude Code and includes a Codex conversion path. The root [README.md](../../README.md) is the canonical user-facing documentation; this file is a short map for maintainers and agents.

## Top-Level Shape

- `kramme-cc-workflow/` is the plugin source. Its `.claude-plugin/plugin.json` is the installable plugin manifest.
- `.claude-plugin/marketplace.json` is the root marketplace entry that points at `kramme-cc-workflow/`.
- `README.md` documents install, usage, skills, agents, hooks, testing, and releases.
- `AGENTS.md` records local contribution conventions; `CLAUDE.md` imports it for Claude Code.
- `.agents/skills/` contains repository-maintenance skills that are not shipped as part of the public plugin.

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

Claude Code installs the plugin from `kramme-cc-workflow/`. Skills and agents are loaded from their directories, and hook events are wired through `hooks/hooks.json`. Hook scripts source `hooks/lib/check-enabled.sh` so every hook can be disabled by the toggle system without editing the hook manifest.

Command-safety hooks share a fail-closed parser boundary: the shell wrappers in `hooks/` validate input and parser output through `hooks/lib/safety-hook-parser.sh`, while `hooks/lib/command_safety/` owns syntax analysis and policy modes. The `rm-rf` mode analyzes supported destructive shapes through depth 5 and blocks with its generic deletion reason when deeper analysis would be required. See the [hook helper library](../hooks/lib/README.md#git-command-parser-mode-contracts) for mode contracts and focused verification.

For Codex, `scripts/convert-plugin.js` is the entry point. It loads the Claude plugin, filters platform-specific skills, converts skills and agents, rewrites shared script references, stages output, updates managed install state, and writes Codex config tables when hooks or MCP servers are present. Installation mutations flow from staging through `install-transaction.js`, which owns locks, journals, backups, commit/rollback, and recovery. The `doctor` path is separate and read-only: `diagnostics.js` uses the transaction inspector for a bounded advisory snapshot without acquiring locks or repairing artifacts. See the [converter module map](../scripts/convert-plugin/README.md#module-map) for ownership and focused verification; the root [README](../../README.md#codex) remains the public command reference.

Browser and visual workflows use the shared dev-server detector in `scripts/dev-server/`. The detector only resolves an already running local app. A caller may own a separately documented startup lifecycle; delegated PR demo capture permits one tightly bounded local-development startup attempt and owns cleanup of the process it launched.

How much independence skills and agents take at runtime is described in [agent-autonomy.md](agent-autonomy.md).

## State and Generated Output

- Hook toggle state defaults to `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json`.
- Skill usage events default to `~/.local/state/kramme-cc-workflow/skill-usage.jsonl`.
- Codex conversion writes managed entries under the selected Codex root, defaulting to `~/.codex`.
- SkillOpt and other local run artifacts belong under `.context/` and must not be committed.

## Verification Model

The fast default check is:

```bash
make -C kramme-cc-workflow test
```

Use `make -C kramme-cc-workflow lint` for shell and Python linting, and `make -C kramme-cc-workflow verify` before larger PRs or release candidates. For focused source-to-test mapping, see [code-map.md](code-map.md).
