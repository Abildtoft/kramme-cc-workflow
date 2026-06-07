# Shared Dev-server Detection

These scripts provide one detection contract for browser-facing workflows. They are used when a skill receives `auto` or a visual-capture mode needs to discover a running local app. Explicit user-provided URLs and ports always win.

## Scripts

- `detect-url.sh` resolves a reachable URL or emits a sentinel.
- `detect-project-type.sh` detects `rails`, `next`, `vite`, `nuxt`, `astro`, `remix`, `sveltekit`, `procfile`, `multiple`, or `unknown`.
- `resolve-package-manager.sh` detects the JS package manager from lockfiles and emits the dev command tail.
- `read-launch-json.sh` reads `.claude/launch.json` and emits a selected config as JSON.
- `resolve-port.sh` resolves the intended dev-server port.

## URL Detection Contract

Run the wrapper from the plugin root:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --url http://localhost:3000
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --port 5173
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --launch-config web
```

Stdout is one of:

- `http://localhost:<port>` or an explicit reachable URL.
- `__NO_RUNNING_SERVER__` when nothing responds.
- `__MULTIPLE_URLS__` followed by one URL per line when discovery is ambiguous.

Diagnostics and operational errors are printed to stderr.

## Precedence

Port resolution uses this order:

1. Explicit URL or `--port`.
2. `.claude/launch.json` `port` from the selected configuration. If multiple launch configs exist and no `--launch-config` is provided, only configured launch ports are considered so discovery does not fall through to unrelated local servers.
3. Framework config files such as `next.config.*`, `vite.config.*`, `nuxt.config.*`, and `astro.config.*`.
4. Rails `config/puma.rb`.
5. `Procfile.dev` web command.
6. `docker-compose.yml` port mappings.
7. `package.json` `dev` or `start` script flags.
8. `.env.local`, `.env.development`, then `.env` `PORT=`.
9. Framework defaults.
10. Common-port listener scan as a final running-server fallback.

Do not scan prose files such as `AGENTS.md`, `CLAUDE.md`, READMEs, or issue text for ports. Those files often contain examples and stale troubleshooting notes.

## Source

`detect-project-type.sh`, `resolve-package-manager.sh`, `read-launch-json.sh`, and `resolve-port.sh` are adapted from `ce-polish` in EveryInc's `compound-engineering-plugin`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`. Upstream license: MIT.
