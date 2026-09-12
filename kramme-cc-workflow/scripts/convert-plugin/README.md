# Convert Plugin Module

This directory contains the implementation behind `scripts/convert-plugin.js`. The boundary is conversion of the Claude plugin into one native Codex plugin and its registration through the Codex CLI; it should not become a second plugin source of truth. This implements the "Codex support is generated from the Claude plugin" and "host adapters remain thin and documented" decisions; see [docs/decisions/README.md](../../docs/decisions/README.md), [2026-09-12-native-codex-plugin-install.md](../../docs/decisions/2026-09-12-native-codex-plugin-install.md), and the [agent portability matrix](../../docs/agent-portability.md).

## Module Map

| File | Responsibility |
| --- | --- |
| `../convert-plugin.js` | CLI entry point; owns parsing, option validation, and help for `build`, `install`, `uninstall`, and the read-only `stats` command. |
| `loader.js` | Resolves plugin input, reads manifests, loads agents, skills, legacy commands, hooks, and MCP servers. |
| `codex-transformer.js` | Converts Claude skills, invocable commands, agents, and instruction text into a Codex bundle and describes the native plugin package (manifest, hook eligibility, cache path, plugin root expression). |
| `ask-user-question-parser.js` | Parses and rewrites structured `AskUserQuestion` prompt blocks into direct-chat instructions. |
| `codex-plugin-builder.js` | Writes the marketplace tree: `marketplace.json`, `.codex-plugin/plugin.json`, skills, shared runtime helpers, and bootstrapped hooks. |
| `codex-shared-scripts.js` | Builds the plugin cache root expression and rewrites `CLAUDE_PLUGIN_ROOT` references in converted Markdown. |
| `codex-markdown-resources.js` | Rewrites copied Markdown resource files with Codex instruction text and the plugin root expression. |
| `codex-cli.js` | Runs the Codex CLI to register the marketplace, install the plugin, verify the reported install path, and remove both again. |
| `legacy-install-cleanup.js` | Removes skills, agent skills, helpers, hook marketplaces, cache entries, and the AGENTS.md tool map recorded by earlier converter releases. |
| `filesystem.js` | Shared safe filesystem helpers for path containment, JSON/text I/O, copies, and directory listing. |
| `contracts.d.ts` | Shared converter input/output declarations used by loader, transformer, and builder boundaries. |
| `frontmatter.js` | Parses and renders frontmatter, normalizes names, and sanitizes descriptions. |
| `confirm.js` | Handles interactive and non-interactive confirmations for legacy cleanup. |

## Invariants

- Load from the Claude plugin source; do not hand-maintain Codex copies.
- Keep path containment checks in shared filesystem helpers before writing or deleting managed children.
- `build` only writes into an absent or empty output directory; `install` builds into a sibling temporary directory and swaps it in, and only replaces a directory holding a marketplace generated for the same name.
- Codex owns the plugin cache and `config.toml`; the converter never edits them. `install` fails if `codex plugin add` reports an install path other than `codexPlugin.cacheRelativePath`, because converted Markdown references that directory.
- Keep platform filtering in the transformer so `kramme-platforms` has one conversion meaning.
- Build shared runtime metadata independently of hook eligibility. The main `CodexBundle` owns `sharedScriptDirs` and `sharedScriptFiles`; hook packaging only adds `hooks/` when the plugin declares hooks and ships the hook control skills.
- Legacy cleanup removes only entries recorded in `.kramme-install-state.json` or the per-plugin manifest, verifies helper digests before deleting, and asks for confirmation unless `--yes` is given.

## CLI Contract

`build <plugin-name|path> --out <dir>` loads and converts the plugin and writes the marketplace to `<dir>`. `install` runs legacy cleanup, builds under `<codex-home>/.kramme-plugin-marketplaces/<plugin>` (or `--marketplace-dir`), then runs `codex plugin marketplace add` and `codex plugin add --json`. `uninstall` runs `codex plugin remove` and `codex plugin marketplace remove`, deletes the generated marketplace, and runs legacy cleanup. The Codex home defaults to `$CODEX_HOME` or `~/.codex`.

`stats <plugin-name|path>` loads and converts the plugin in memory without building it. Its default text output is two `key=value` lines in this order:

```text
codex_skills=<integer>
agent_skills=<integer>
```

`--json` returns the same ordered fields in one JSON object. `codex_skills` counts converted skill directories plus generated command skills; `agent_skills` counts generated Codex agent skills. `stats` never loads the builder, Codex CLI, or cleanup modules. The root [README](../../../README.md#codex) owns command syntax and the public field contract.

## Verification

Run the CLI smoke tests after changing the entry point or its public contract; they drive the fake `codex` in `tests/test_helper/mocks`:

```bash
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/convert-plugin.bats
```

Run the focused converter suite after changing this module:

```bash
make -C kramme-cc-workflow test-convert
```

For build layout, hook packaging, Codex CLI, or legacy cleanup changes, start with the matching Node suite:

```bash
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/converter-build.test.js
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/codex-hook-compat.test.js
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/codex-cli.test.js
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/legacy-install-cleanup.test.js
```

The installer workflow additionally installs the real Codex CLI and runs `install` against a temporary Codex home.
