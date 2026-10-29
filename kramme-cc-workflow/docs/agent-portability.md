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
| Codex plugin (skills, agent skills, hooks, shared scripts, MCP config) | `generated` | `skills/`, `commands/`, `agents/`, `hooks/`, `manifest.mcpServers`, `.mcp.json`, `shared/`, `scripts/resolve-base.sh`, `scripts/resolve-stack-membership.sh`, `scripts/siw-issue-reservation.sh`, `scripts/verify-rewrite-state.sh`, `scripts/collect-review-diff.sh`, `scripts/resolve-stack-context.py`, `scripts/review-tree-fingerprint.sh`, `scripts/worktree-tree-id.sh`, `scripts/risk-signals.py`, `scripts/risk_patterns.py`, `scripts/skill-usage.js`, `scripts/dev-server/`, `scripts/lib/`, `scripts/convert-plugin.js`, `scripts/convert-plugin/codex-transformer.js`, `scripts/convert-plugin/codex-plugin-builder.js`, `scripts/convert-plugin/codex-cli.js` | One native Codex plugin inside a generated marketplace. Codex installs it into `<codex-home>/plugins/cache/<marketplace>/<plugin>/<version>` through `codex plugin marketplace add` and `codex plugin add` and owns the cache, config tables, updates, and removal. | Generated from Claude plugin source and converter modules; do not hand-maintain installed copies. Converted skills, generated command skills, and agent skills share one `skills/` directory. Skill Markdown resolves shared helpers and skill-local scripts through the plugin cache directory expression `${CODEX_HOME:-$HOME/.codex}/plugins/cache/<marketplace>/<plugin>/<version>`; hook commands keep `${CLAUDE_PLUGIN_ROOT}`, which Codex sets for plugin hooks, and every hook script carries a self-locating bootstrap for shells without it. Hook packaging requires the `kramme:hooks:toggle` skill. Claude tool names are translated inside the skills; no Codex-wide `AGENTS.md` instruction block is written. Explicit exhaustive-question guidance preserves structured `request_user_input` use when the active Codex mode exposes it and retains direct-chat fallback. |
| Cross-provider adversarial PR review | `canonical`, `generated`, `thin adapter` | `skills/kramme:pr:adversarial-review/`, `skills/kramme:pr:review-convergence/` | Hardened alternative-provider CLI in local workspaces; different-provider Conductor cloud session when `CONDUCTOR_IS_LOCAL=0`; temporary review snapshot or provider-specific cloud artifact | Explicit opt-in only. The reviewer provider must differ from the active host, local execution receives a temporary tracked-file snapshot, cloud execution must preserve the prepared tree, and provider, result, coverage, or integrity failures block rather than fall back. |
| Subagent model selection (PR review and opted-in non-review roles) | `canonical`, `generated`, `instruction-only` | `shared/pr-review/references/model-selection.md`, loaded by the PR review producers and wrappers and by non-review skills that name its Non-Review Subagent Roles section | Claude agent invocation model override; Codex `spawn_agent` model override with a compatible fork mode | Keep reviewers on the orchestrator's own model by default, select one class below the trusted active orchestrator when `KRAMME_REVIEW_SUBAGENT_LEVEL=lower`, or use `--subagent-model <model>` (`inherit` preserves the orchestrator model; the flag wins over the setting). Parse the override before routing, preserve the requirements sentinel, and forward it through wrappers, validation, and reruns. Unknown classes or unsupported default selection retain host defaults with a reported limitation; unsupported explicit choices stop. Opted-in non-review lens, recon, drafting, and filter roles use the same flag, setting, ladder, and `same` default; the orchestrator, file-editing agents, and cross-provider or cross-model modes keep their own policies. Tests: `tests/review-model-selection-guidance.bats`, `tests/node/converter-integration.test.js`. |
| Local repository-maintenance skills | `local-only` | Repository-local `./.agents/skills/` and local exposure through `./.claude/skills/` | This repository checkout | Used to maintain this repo and not shipped as plugin runtime behavior. |
| Live Claude skill-review eval host | `local-only`, `thin adapter` | `evals/skill-review/{claude-predict,review-profile,live-predict,providers,credit-pool,eval-state,run-live-eval,ci-checkpoint}.js` | Direct Agent SDK session using a minimal staged reviewer plugin and one fixture | Only `kramme:skill:review`; explicit model and selected API key; read-only file/skill tools with real-path hooks; no user settings, unrelated MCP, answer key, subscription fallback, or fallback to another provider. Checkpoints under `.context/claude-evals/`; local/manual or trusted-main scheduled CI. Tests: `tests/node/{credit-pool,eval-state,claude-predict,run-live-eval,ci-checkpoint}.test.js`, `tests/skill-review-live-eval.bats`. |
| Live OpenAI skill-review eval host | `local-only`, `thin adapter` | `evals/skill-review/{openai-predict,review-profile,live-predict,providers,credit-pool,eval-state,run-live-eval,ci-checkpoint}.js` | Direct Responses API requests from the eval process, with the profile's Skill, Read, Glob, and Grep tools implemented locally over the same staged reviewer and fixture | Only `kramme:skill:review`; explicit model and selected API key in the request header only; `store: false`; real-path checks before every tool call; no shell, answer key, Codex host, or fallback to another provider. Checkpoints under `.context/openai-evals/`; local/manual or trusted-main scheduled CI. Tests: `tests/node/{credit-pool,openai-predict,run-live-eval,ci-checkpoint}.test.js`, `tests/skill-review-live-eval.bats`. |
| Conductor host integrations (`DiffComment`, `GetDiffComments`, `GetWorkspaceDiff`, `AskUserQuestion`, workspace CLI) | `optional`, `thin adapter` | `skills/*/SKILL.md` prose and `skills/kramme:linear:next/scripts/cloud-launch.py`, detected by tool or environment presence | Conductor app Checks panel and dialogs; workspace presentation state; new cloud workspaces the user confirmed | Optionally project canonical report artifacts, admit unmarked diff feedback as untrusted external candidates, rename the current workspace for a validated work item, or, only in a cloud workspace (`CONDUCTOR_IS_LOCAL=0`) and after the user's explicit confirmation in that run, start confirmed Linear issues in new cloud workspaces without retrying a failed creation. Auto discovery degrades without blocking canonical work when the host surface is absent or fails; explicit selection reports unavailability. Host projections and names never become authoritative findings or workflow identity. |
| Other hosts | `unsupported` | None | None | Unsupported unless a future row names source files, generated outputs, and tests. |

## Converter Contract

`convertClaudeToCodex` produces one `CodexBundle` with these generated surfaces:

- `skillDirs`: converted canonical skill directories.
- `generatedSkills`: command-backed generated Codex skills.
- `agentSkills`: generated agent skills; they are packaged in the same plugin `skills/` directory.
- `sharedScriptDirs` and `sharedScriptFiles`: shared runtime metadata built independently of hook eligibility, copied into the plugin's `scripts/`, `shared/`, and `hooks/` directories. Markdown under `shared/` receives the same Codex rewrite as skill-local references.
- `mcpServers`: managed MCP server config, emitted as the `mcpServers` object of the plugin manifest.
- `codexPlugin`: the native plugin package: `name`, `marketplaceName`, `version`, the `.codex-plugin/plugin.json` `manifest`, `hooks` plus `hookSourceDir` when hook packaging is eligible, the `cacheRelativePath` Codex installs into, and the `rootExpression` converted Markdown uses to reach it.

`buildCodexMarketplace` writes that bundle as `<out>/.agents/plugins/marketplace.json` plus `<out>/plugins/<name>/` with `.codex-plugin/plugin.json`, `skills/`, `scripts/`, and optionally `hooks/`. `install` removes output recorded by earlier converter releases (`legacy-install-cleanup.js`), builds the marketplace under the Codex home, registers it with `codex plugin marketplace add`, installs with `codex plugin add`, and fails if Codex reports an install path other than `cacheRelativePath`. The release workflow publishes the same build to the `codex-plugin` branch so `codex plugin marketplace add Abildtoft/kramme-cc-workflow --ref codex-plugin` installs without a checkout.

Installed output under the Codex plugin cache, the generated marketplace, or the published branch is not source behavior. Repository-local `./.agents/skills/` remains the local-only source for maintenance skills. Change canonical source or converter modules, then rebuild.

## Installing from a Checkout

The root [README](../../README.md#codex) lists the install, update, and removal commands. Use the plugin name from `.claude-plugin/marketplace.json` (here: `kramme-cc-workflow`).

The converter's `install` command:

- builds the marketplace under `<codex-home>/.kramme-plugin-marketplaces/kramme-cc-workflow`, registers it with `codex plugin marketplace add`, and installs it with `codex plugin add`;
- fails if Codex places the plugin anywhere other than `plugins/cache/kramme-cc-workflow/kramme-cc-workflow/<version>` under the Codex home, because the converted skills reference that directory;
- uses `$CODEX_HOME` or `~/.codex` as the Codex home; override it with `--codex-home`.

`scripts/install-codex.sh` installs missing converter runtime dependencies and forwards additional arguments to the converter.

Installs from an earlier converter release (skills copied into `~/.codex/skills`, agent skills in `~/.agents/skills`, shared helpers under `~/.codex/scripts`, and the managed `AGENTS.md` tool map) are detected through `.kramme-install-state.json` and removed after confirmation. Pass `--yes` to confirm automatically or `--non-interactive` to keep them; `--agents-home` selects the agents home that held the legacy agent skills.

### Installed State

`codex plugin list` shows the plugin as `kramme-cc-workflow@kramme-cc-workflow` with its status, version, and marketplace source. The registration lives in the Codex `config.toml` as `[marketplaces.kramme-cc-workflow]` and `[plugins."kramme-cc-workflow@kramme-cc-workflow"]`, and the installed files live under `plugins/cache/kramme-cc-workflow/kramme-cc-workflow/<version>` in the Codex home.

Converted skills reference that directory through `${CODEX_HOME:-$HOME/.codex}`, so keep `CODEX_HOME` exported in shells Codex runs when you use a non-default Codex home. If skills from an earlier converter release still appear twice, a legacy copy remains under `~/.codex/skills` or `~/.agents/skills`; run the install command again with `--yes` to remove it.

### Building and Inspecting

Build the marketplace without installing, for inspection or publishing:

```bash
node kramme-cc-workflow/scripts/convert-plugin.js build kramme-cc-workflow --out /tmp/kramme-codex
```

The output root holds `.agents/plugins/marketplace.json` and `plugins/kramme-cc-workflow/` with `.codex-plugin/plugin.json`, `skills/` (converted skills, generated command skills, and agent skills), `scripts/` (shared helpers), and `hooks/` when the hook control skills are present.

Inspect the generated skill counts without building:

```bash
node kramme-cc-workflow/scripts/convert-plugin.js stats kramme-cc-workflow
node kramme-cc-workflow/scripts/convert-plugin.js stats kramme-cc-workflow --json
```

The default output contains `codex_skills=<integer>` followed by `agent_skills=<integer>`. JSON output contains the same two integer fields in an object. `codex_skills` counts converted skill directories plus generated command skills; `agent_skills` counts generated Codex agent skills. Both groups are packaged in the plugin's `skills/` directory.

### Publishing

CI regenerates the `codex-plugin` branch on every release tag. The release-tag workflow calls the publisher with that exact tag, so tags created by GitHub Actions still publish the marketplace. If the branch is ever missing, maintainers can rebuild it from the Actions tab by running **Publish Codex Plugin** against `main`.

## Codex Usage Decision

As of 2026-07-06, keep Codex output first-class. Local Codex evidence showed recent sessions using generated `kramme:*` skills:

- `~/.codex/skills/` contained 105 managed `kramme*` skill directories, while `~/.codex/prompts/` was absent. The managed install state and manifest were last updated on 2026-06-23 at 15:03:42 +0200.
- The packaged usage runtime had 684 `kramme:*` records in `~/.local/state/kramme-cc-workflow/skill-usage.jsonl`, spanning 2026-05-28 through 2026-07-06.
- Codex logs contained 312 pre-audit reads of installed `~/.codex/skills/kramme:*` files from 2026-06-27 through 2026-07-06; 262 of those reads were tied to 74 distinct Codex thread IDs.
- Shell history contained 169 `codex` CLI invocations since 2026-05-24, with the latest on 2026-07-06 at 12:48:34 +0200.

As of 2026-09-12, Codex output ships as one native Codex plugin instead of files copied into `~/.codex/skills` and `~/.agents/skills`; the next `install` removes the recorded legacy output. See [2026-09-12-native-codex-plugin-install.md](decisions/2026-09-12-native-codex-plugin-install.md).

Maintain a quarterly end-to-end Codex dogfood check: install into the Codex home, confirm `codex plugin list` shows the plugin as installed and enabled, start a Codex session, invoke at least one `kramme:*` skill, verify the usage JSONL record and Codex log hit, and keep installer CI in the required path while that check keeps passing.
