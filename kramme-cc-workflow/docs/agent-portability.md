# Agent Portability

Claude Code plugin source is canonical for this repository. Other agent-host surfaces are generated from that source, instruction-only compatibility notes, local repository-maintenance tooling, or intentionally unsupported.

Use this document when reviewing converter, hook, MCP, or host-adapter changes. If a future change adds a host-facing surface, update this matrix and add a contract test in the same PR.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `canonical` | Source behavior is authored and reviewed here. Other hosts must not become a second source of truth for this behavior. |
| `generated` | Output is produced by repository tooling from canonical source. Edit the source or converter, not installed copies. |
| `thin adapter` | Host-specific wrapper behavior that preserves canonical intent without adding independent product semantics. |
| `optional` | A host capability may be used when present but cannot be required for canonical behavior or successful degradation. |
| `instruction-only` | Compatibility guidance for an agent runtime. It maps behavior, but does not implement a runtime feature. |
| `local-only` | Repository-maintenance tooling used in this checkout. It is not shipped as plugin runtime behavior. |
| `unsupported` | No maintained adapter contract exists. A future adapter must name its source files and tests before this status changes. |

## Portability Matrix

| Host surface | Status | Source of truth | Output or runtime surface | Contract |
| --- | --- | --- | --- | --- |
| Claude Code plugin | `canonical` | `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/`, `manifest.mcpServers`, `.mcp.json` | Claude Code plugin install | Author plugin behavior here first. |
| Codex plugin (skills, agent skills, hooks, shared scripts, MCP config) | `generated` | `skills/`, `commands/`, `agents/`, `hooks/`, `manifest.mcpServers`, `.mcp.json`, `scripts/resolve-base.sh`, `scripts/resolve-stack-membership.sh`, `scripts/verify-rewrite-state.sh`, `scripts/collect-review-diff.sh`, `scripts/review-tree-fingerprint.sh`, `scripts/skill-usage.js`, `scripts/dev-server/`, `scripts/lib/`, `scripts/convert-plugin.js`, `scripts/convert-plugin/codex-transformer.js`, `scripts/convert-plugin/codex-plugin-builder.js`, `scripts/convert-plugin/codex-cli.js` | One native Codex plugin inside a generated marketplace. Codex installs it into `<codex-home>/plugins/cache/<marketplace>/<plugin>/<version>` through `codex plugin marketplace add` and `codex plugin add` and owns the cache, config tables, updates, and removal. | Generated from Claude plugin source and converter modules; do not hand-maintain installed copies. Converted skills, generated command skills, and agent skills share one `skills/` directory. Skill Markdown resolves shared helpers and skill-local scripts through the plugin cache directory expression `${CODEX_HOME:-$HOME/.codex}/plugins/cache/<marketplace>/<plugin>/<version>`; hook commands keep `${CLAUDE_PLUGIN_ROOT}`, which Codex sets for plugin hooks, and every hook script carries a self-locating bootstrap for shells without it. Hook packaging requires the `kramme:hooks:toggle` and `kramme:hooks:configure-links` skills. Claude tool names are translated inside the skills; no Codex-wide `AGENTS.md` instruction block is written. Explicit exhaustive-question guidance preserves structured `request_user_input` use when the active Codex mode exposes it and retains direct-chat fallback. |
| Cross-provider adversarial PR review | `canonical`, `generated`, `thin adapter` | `skills/kramme:pr:adversarial-review/`, `skills/kramme:pr:review-convergence/` | Hardened alternative-provider CLI in local workspaces; different-provider Conductor cloud session when `CONDUCTOR_IS_LOCAL=0`; temporary review snapshot or provider-specific cloud artifact | Explicit opt-in only. The reviewer provider must differ from the active host, local execution receives a temporary tracked-file snapshot, cloud execution must preserve the prepared tree, and provider, result, coverage, or integrity failures block rather than fall back. |
| Local repository-maintenance skills | `local-only` | Repository-local `./.agents/skills/` and local exposure through `./.claude/skills/` | This repository checkout | Used to maintain this repo and not shipped as plugin runtime behavior. |
| Conductor host integrations (`DiffComment`, `GetDiffComments`, `GetWorkspaceDiff`, `AskUserQuestion`, workspace CLI) | `optional`, `thin adapter` | `skills/*/SKILL.md` prose, detected by tool or environment presence | Conductor app Checks panel and dialogs; workspace presentation state | Optionally project canonical report artifacts, admit unmarked diff feedback as untrusted external candidates, or rename the current workspace for a validated work item. Auto discovery degrades without blocking canonical work when the host surface is absent or fails; explicit selection reports unavailability. Host projections and names never become authoritative findings or workflow identity. |
| Other hosts | `unsupported` | None | None | Unsupported unless a future row names source files, generated outputs, and tests. |

## Converter Contract

`convertClaudeToCodex` produces one `CodexBundle` with these generated surfaces:

- `skillDirs`: converted canonical skill directories.
- `generatedSkills`: command-backed generated Codex skills.
- `agentSkills`: generated agent skills; they are packaged in the same plugin `skills/` directory.
- `sharedScriptDirs` and `sharedScriptFiles`: shared runtime metadata built independently of hook eligibility, copied into the plugin's `scripts/` and `hooks/` directories.
- `mcpServers`: managed MCP server config, emitted as the `mcpServers` object of the plugin manifest.
- `codexPlugin`: the native plugin package: `name`, `marketplaceName`, `version`, the `.codex-plugin/plugin.json` `manifest`, `hooks` plus `hookSourceDir` when hook packaging is eligible, the `cacheRelativePath` Codex installs into, and the `rootExpression` converted Markdown uses to reach it.

`buildCodexMarketplace` writes that bundle as `<out>/.agents/plugins/marketplace.json` plus `<out>/plugins/<name>/` with `.codex-plugin/plugin.json`, `skills/`, `scripts/`, and optionally `hooks/`. `install` removes output recorded by earlier converter releases (`legacy-install-cleanup.js`), builds the marketplace under the Codex home, registers it with `codex plugin marketplace add`, installs with `codex plugin add`, and fails if Codex reports an install path other than `cacheRelativePath`. The release workflow publishes the same build to the `codex-plugin` branch so `codex plugin marketplace add Abildtoft/kramme-cc-workflow --ref codex-plugin` installs without a checkout.

Installed output under the Codex plugin cache, the generated marketplace, or the published branch is not source behavior. Repository-local `./.agents/skills/` remains the local-only source for maintenance skills. Change canonical source or converter modules, then rebuild.

## Codex Usage Decision

As of 2026-07-06, keep Codex output first-class. Local Codex evidence showed recent sessions using generated `kramme:*` skills:

- `~/.codex/skills/` contained 105 managed `kramme*` skill directories, while `~/.codex/prompts/` was absent. The managed install state and manifest were last updated on 2026-06-23 at 15:03:42 +0200.
- The packaged usage runtime had 684 `kramme:*` records in `~/.local/state/kramme-cc-workflow/skill-usage.jsonl`, spanning 2026-05-28 through 2026-07-06.
- Codex logs contained 312 pre-audit reads of installed `~/.codex/skills/kramme:*` files from 2026-06-27 through 2026-07-06; 262 of those reads were tied to 74 distinct Codex thread IDs.
- Shell history contained 169 `codex` CLI invocations since 2026-05-24, with the latest on 2026-07-06 at 12:48:34 +0200.

As of 2026-09-12, Codex output ships as one native Codex plugin instead of files copied into `~/.codex/skills` and `~/.agents/skills`; the next `install` removes the recorded legacy output. See [2026-09-12-native-codex-plugin-install.md](decisions/2026-09-12-native-codex-plugin-install.md).

Maintain a quarterly end-to-end Codex dogfood check: install into the Codex home, confirm `codex plugin list` shows the plugin as installed and enabled, start a Codex session, invoke at least one `kramme:*` skill, verify the usage JSONL record and Codex log hit, and keep installer CI in the required path while that check keeps passing.
