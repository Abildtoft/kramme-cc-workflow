# Dev Server Detection

Auto-detect a running development server for live inspection. This skill uses the shared plugin contract in `${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/README.md`; do not duplicate the port cascade here.

## Command

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto
```

The detector does not start a server. It resolves an already running local app by using explicit caller values when present, `.claude/launch.json`, framework config, Procfile/Docker/package metadata, env `PORT=`, framework defaults, and finally a common-port listener scan.

## Output Handling

- `http://...` or `https://...` -> use that as `TARGET_URL`.
- `__MULTIPLE_URLS__` followed by candidates -> ask the user to choose a URL; if the runtime is non-interactive, stop and print the candidate list.
- `__NO_RUNNING_SERVER__` -> stop and tell the user to start the dev server.
- `ERROR: ...` on stderr -> stop and show the diagnostic.

After a URL is selected, still run the normal curl health check from the parent skill. That preserves the explicit 4xx warning and 5xx hard-stop behavior.
