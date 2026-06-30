# Convert Plugin Module

This directory contains the implementation behind
`scripts/convert-plugin.js`. The boundary is conversion and installation of the
Claude plugin into Codex-compatible output; it should not become a second plugin
source of truth.

## Module Map

| File | Responsibility |
| --- | --- |
| `../convert-plugin.js` | CLI entry point for `install` and `stats`; resolves target and root options. |
| `loader.js` | Resolves plugin input, reads manifests, loads agents, skills, legacy commands, hooks, and MCP servers. |
| `codex-transformer.js` | Converts Claude skills, invocable commands, agents, hooks, and shared script references into a Codex bundle. |
| `codex-writer.js` | Writes the converted bundle, stages output, rewrites installed shared-script paths, updates managed state, and finalizes files. |
| `codex-config.js` | Upserts and removes managed TOML tables for MCP servers and converted hook plugin config. |
| `install-staging.js` | Provides staged install, preflight conflict checks, stale managed-file pruning, and cleanup. |
| `install-state.js` | Reads, sanitizes, rebuilds, and writes install state and per-plugin manifests. |
| `filesystem.js` | Shared safe filesystem helpers for path containment, JSON/text I/O, copies, and directory listing. |
| `frontmatter.js` | Parses and renders frontmatter, normalizes names, and sanitizes descriptions. |
| `confirm.js` | Handles interactive and non-interactive cleanup confirmations. |

## Invariants

- Load from the Claude plugin source; do not hand-maintain Codex copies.
- Keep path containment checks in shared filesystem helpers before writing or
  deleting managed children.
- Stage writes before finalizing installs so failed installs do not leave a
  partially updated bundle.
- Preserve user-owned files unless they are tracked as managed entries from a
  previous converter run.
- Keep platform filtering in the transformer so `kramme-platforms` has one
  conversion meaning.

## Verification

Run the focused converter suite after changing this module:

```bash
make -C kramme-cc-workflow test-convert
```

For TOML/frontmatter/parser changes, also run the full Bats suite before
shipping:

```bash
make -C kramme-cc-workflow test
```
