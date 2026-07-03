# Agent Portability

Claude Code plugin source is canonical for this repository. Other agent-host
surfaces are generated from that source, instruction-only compatibility notes,
local repository-maintenance tooling, or intentionally unsupported.

Use this document when reviewing converter, hook, MCP, or host-adapter changes.
If a future change adds a host-facing surface, update this matrix and add a
contract test in the same PR.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `canonical` | Source behavior is authored and reviewed here. Other hosts must not become a second source of truth for this behavior. |
| `generated` | Output is produced by repository tooling from canonical source. Edit the source or converter, not installed copies. |
| `thin adapter` | Host-specific wrapper behavior that preserves canonical intent without adding independent product semantics. |
| `instruction-only` | Compatibility guidance for an agent runtime. It maps behavior, but does not implement a runtime feature. |
| `local-only` | Repository-maintenance tooling used in this checkout. It is not shipped as plugin runtime behavior. |
| `unsupported` | No maintained adapter contract exists. A future adapter must name its source files and tests before this status changes. |

## Portability Matrix

| Host surface | Status | Source of truth | Output or runtime surface | Contract |
| --- | --- | --- | --- | --- |
| Claude Code plugin | `canonical` | `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/`, `manifest.mcpServers`, `.mcp.json` | Claude Code plugin install | Author plugin behavior here first. |
| Codex skills, prompts, and MCP config | `generated` | `skills/`, `commands/`, `manifest.mcpServers`, `.mcp.json`, `scripts/convert-plugin.js`, `scripts/convert-plugin/codex-transformer.js`, `scripts/convert-plugin/codex-bundle-output.js`, `scripts/convert-plugin/codex-config.js` | `~/.codex/skills/`, `~/.codex/prompts/`, managed Codex config tables | Generated from Claude plugin source and converter modules. |
| Codex agent skills | `generated` | `agents/`, `scripts/convert-plugin/codex-transformer.js`, `scripts/convert-plugin/codex-bundle-output.js` | `.agents/skills/` under the selected agents home | Generated from Claude agents. Do not hand-maintain installed agent skill copies. |
| Codex hook plugin and shared scripts | `generated`, `thin adapter` | `hooks/`, `scripts/resolve-base.sh`, `scripts/collect-review-diff.sh`, `scripts/skill-usage.js`, `scripts/dev-server/`, `scripts/convert-plugin/codex-hook-plugin-writer.js`, `scripts/convert-plugin/codex-shared-scripts.js` | Managed Codex plugin marketplace/cache entries and hook config | Converts Claude hook behavior into Codex plugin packaging without expanding hook support promises. |
| Codex `AGENTS.md` tool map | `instruction-only` | `scripts/convert-plugin/codex-writer.js` | Managed block in `~/.codex/AGENTS.md` | Maps Claude-oriented tool names to Codex behavior for agent instructions only. |
| Local repository-maintenance skills | `local-only` | Repository-local `./.agents/skills/` and local exposure through `./.claude/skills/` | This repository checkout | Used to maintain this repo and not shipped as plugin runtime behavior. |
| Other hosts | `unsupported` | None | None | Unsupported unless a future row names source files, generated outputs, and tests. |

## Converter Contract

The Codex converter exposes generated surfaces through these bundle
responsibilities:

- `prompts`: generated Codex prompt files.
- `skillDirs`: converted canonical skill directories.
- `generatedSkills`: command-backed generated Codex skills.
- `agentSkills`: generated agent skills for the selected agents home's `skills/`
  directory.
- `mcpServers`: managed Codex MCP config input.
- `codexPlugin`: generated Codex hook plugin packaging when hook control skills
  are available.

Installed output under `~/.codex`, the selected agents home's `skills/`
directory, plugin caches, or generated hook marketplaces is not source behavior.
Repository-local `./.agents/skills/` remains the local-only source for
maintenance skills. Change canonical source or converter modules, then
regenerate.
