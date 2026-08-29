# Convert Plugin Module

This directory contains the implementation behind `scripts/convert-plugin.js`. The boundary is conversion and installation of the Claude plugin into Codex-compatible output; it should not become a second plugin source of truth. This implements the "Codex support is generated from the Claude plugin" and "host adapters remain thin and documented" decisions; see [docs/decisions/README.md](../../docs/decisions/README.md) and the [agent portability matrix](../../docs/agent-portability.md).

## Module Map

| File | Responsibility |
| --- | --- |
| `../convert-plugin.js` | CLI entry point; owns parsing and help for `install` and the read-only `stats` and `doctor` inspection commands. |
| `loader.js` | Resolves plugin input, reads manifests, loads agents, skills, legacy commands, hooks, and MCP servers. |
| `codex-transformer.js` | Converts Claude skills, invocable commands, agents, hooks, and instruction text into a Codex bundle. |
| `ask-user-question-parser.js` | Parses and rewrites structured `AskUserQuestion` prompt blocks into direct-chat instructions. |
| `codex-writer.js` | Coordinates converted bundle output, managed install state, and AGENTS.md tool-map updates. |
| `codex-bundle-output.js` | Stages and finalizes prompts, skills, agent skills, shared scripts, config, and hook plugin output. |
| `codex-config.js` | Upserts and removes managed TOML tables for MCP servers and converted hook plugin config. |
| `codex-hook-plugin-writer.js` | Builds converted Codex hook plugin trees, marketplaces, plugin cache entries, and hook bootstrap scripts. |
| `codex-markdown-resources.js` | Rewrites copied Markdown resource files with Codex instruction and shared-script references. |
| `codex-shared-scripts.js` | Builds and applies shared-script path rewrites for installed Codex output. |
| `diagnostics.js` | Collects the resolved plugin, install-state, and bounded transaction-health record used by `doctor`; it does not install or repair. |
| `install-transaction.js` | Owns install locking, journaling, stale-owner recovery, mutation preparation, transaction-aware publication, commit, rollback, and read-only transaction inspection. |
| `install-staging.js` | Orchestrates staged installs, preflight conflict checks, stale managed-file pruning, and cleanup through the transaction API. |
| `install-state.js` | Reads, sanitizes, rebuilds, and writes install state and per-plugin manifests. |
| `filesystem.js` | Shared safe filesystem helpers for path containment, JSON/text I/O, copies, and directory listing. |
| `contracts.d.ts` | Shared converter input/output declarations used by loader, transformer, and writer boundaries. |
| `frontmatter.js` | Parses and renders frontmatter, normalizes names, and sanitizes descriptions. |
| `confirm.js` | Handles interactive and non-interactive cleanup confirmations. |

## Invariants

- Load from the Claude plugin source; do not hand-maintain Codex copies.
- Keep path containment checks in shared filesystem helpers before writing or deleting managed children.
- Stage writes before finalizing installs so failed installs do not leave a partially updated bundle.
- Keep transaction state private to `install-transaction.js`; staging consumes
  its narrow mutation API and the transaction module must not import staging.
- Keep transaction diagnostics advisory and read-only. The inspector may report
  bounded aggregate status but must not acquire locks, claim recovery, repair or
  remove artifacts, or expose owners, tokens, paths, records, or artifact data.
- Preserve user-owned files unless they are tracked as managed entries from a previous converter run.
- Keep platform filtering in the transformer so `kramme-platforms` has one conversion meaning.

## CLI Contract

`stats <plugin-name|path>` loads and converts the plugin in memory without installing it. Its default text output is two `key=value` lines in this order:

```text
codex_skills=<integer>
agent_skills=<integer>
```

`--json` returns the same ordered fields in one JSON object. `codex_skills` counts converted skill directories plus generated command skills; `agent_skills` counts generated Codex agent skills. The command supports only the `codex` target.

`doctor` follows a separate inspection path: `diagnostics.js` resolves the
plugin and install state, then calls the transaction inspector exported by
`install-transaction.js`. It never enters `install-staging.js` or the mutation
transaction. The nested `transaction_health` result summarizes five artifact
classes: install locks, journals, recovery claims, recovery conflicts, and
backups. Collection inspection is capped at 50 entries or discovered roots,
and accepted owner/journal metadata is capped at 64 KiB. Counts, truncation,
and aggregate statuses are diagnostic evidence rather than a repair decision.
The root [README](../../../README.md#codex) owns command syntax and the public
field contract.

## Verification

Run the CLI smoke tests after changing the entry point or its public contract:

```bash
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/convert-plugin.bats
```

Run the focused converter suite after changing this module:

```bash
make -C kramme-cc-workflow test-convert
```

For transaction or doctor boundaries, start with the installer and CLI suites:

```bash
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/converter-install.test.js
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/convert-plugin.bats
```

For TOML/frontmatter/parser changes, also run the full Bats suite before shipping:

```bash
make -C kramme-cc-workflow test
```
