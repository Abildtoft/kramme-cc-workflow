# Codex installs ship one native Codex plugin

- Status: ACCEPTED
- Date: 2026-09-12
- Deciders: repository maintainer (explicit implementation request)

## Context

The converter copied transformed skills into `~/.codex/skills`, agent skills into `~/.agents/skills`, and shared helpers into `~/.codex/scripts`, rewriting every helper reference to an absolute path. It also generated a native Codex plugin for hooks only, edited `config.toml` to register it, and wrote a managed tool-map block into the Codex `AGENTS.md`. Keeping those copies consistent required a bespoke transactional install layer (locks, journals, backups, stale-owner recovery, install state, and a `doctor` command) of about 4,500 lines plus tests; ninety of the last 150 commits touched the converter.

Codex now installs plugins itself. Its manifest accepts `skills`, `hooks`, and `mcpServers` as plugin-relative paths, marketplaces can be added from a local directory or a GitHub ref, and `codex plugin add` copies the plugin into `<codex-home>/plugins/cache/<marketplace>/<plugin>/<version>`, writes the config tables, refreshes the cache on re-add, and removes it on `codex plugin remove`. Hook commands receive `PLUGIN_ROOT` and a `CLAUDE_PLUGIN_ROOT` alias. Skills receive no variable; the model is told the absolute `SKILL.md` path, and bundled OpenAI skills reference helpers relative to that path. Plugin manifests have no model-facing instruction surface, and session logs showed the managed `AGENTS.md` tool map covered only a handful of residual tool names.

## Decision

Ship Codex output as one native Codex plugin inside a generated marketplace and let Codex own installation. The converter keeps its loader, transformer, and Markdown rewriting as a pure `build` step; `install` removes output recorded by earlier releases, builds the marketplace under the Codex home, and registers and installs it through the Codex CLI. Agent skills and shared helpers live inside the plugin. Converted Markdown resolves helpers through the plugin cache directory expression `${CODEX_HOME:-$HOME/.codex}/plugins/cache/<marketplace>/<plugin>/<version>`, and `install` fails if Codex reports a different install path. Hook packaging keeps `${CLAUDE_PLUGIN_ROOT}` in commands and the self-locating bootstrap in scripts. The `AGENTS.md` tool map, the install transaction layer, install state, config editing, and `doctor` are removed; the release workflow publishes the build to the `codex-plugin` branch for checkout-free installs.

## Alternatives and consequences

Committing the generated output into `main` with a drift check would give the same native install but duplicates every skill in the repository; the published branch keeps `main` canonical. Skill-relative helper paths would avoid depending on the Codex cache layout, but shell snippets copied verbatim from a skill would then resolve against the working directory; the cache expression works in any shell and is verified at install time.

Users on the previous layout keep working until they reinstall; the next `install` removes the recorded legacy output after confirmation. The converter now depends on the Codex CLI being on `PATH` for `install` and `uninstall`; `build` and `stats` do not. Installer CI exercises the real Codex CLI against a temporary Codex home.
