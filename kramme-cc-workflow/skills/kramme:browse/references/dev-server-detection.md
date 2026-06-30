# Dev Server Detection

Auto-detect a running development server for live inspection. The detector
resolves an already running local app; it does not start a server.

## Command

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
```

Optional caller inputs:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --url http://localhost:3000
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --port 5173
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh --launch-config web
```

## Detection Order

Use explicit caller values first. If no explicit URL or port is provided, the
detector resolves candidates in this order:

1. `.claude/launch.json` `port` from the selected launch configuration. If
   multiple launch configs exist and no config is selected, only configured
   launch ports are considered.
2. Framework config files such as `next.config.*`, `vite.config.*`,
   `nuxt.config.*`, and `astro.config.*`.
3. Rails `config/puma.rb`.
4. `Procfile.dev` web command.
5. `docker-compose.yml` port mappings.
6. `package.json` `dev` or `start` script flags.
7. `.env.local`, `.env.development`, then `.env` `PORT=`.
8. Framework defaults.
9. Common-port listener scan as the final running-server fallback.

Do not scan prose files such as `AGENTS.md`, `CLAUDE.md`, READMEs, or issue
text for ports. Those files often contain examples and stale troubleshooting
notes.

## Output Handling

- `http://...` or `https://...` -> use that as `TARGET_URL`.
- `__MULTIPLE_URLS__` followed by candidates -> ask the user to choose a URL; if the runtime is non-interactive, stop and print the candidate list.
- `__NO_RUNNING_SERVER__` -> stop and tell the user to start the dev server.
- `ERROR: ...` on stderr -> stop and show the diagnostic.

After a URL is selected, still run the normal curl health check from the parent skill. That preserves the explicit 4xx warning and 5xx hard-stop behavior.

## Maintenance Source

The implementation source of truth is
`${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/`. Keep this reference self-contained
for runtime use, and update it when the detector contract changes.
