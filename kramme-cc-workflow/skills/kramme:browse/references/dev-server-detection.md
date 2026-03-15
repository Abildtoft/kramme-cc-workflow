# Dev Server Detection

Auto-detect a running development server for live inspection.

## Step 1: Scan for Listening Ports

Check common dev server ports for active listeners:
```bash
lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -E ':(3000|3001|4200|4201|5173|5174|5000|8000|8080|8888|9000) '
```

## Step 2: Check Framework Config (if ambiguous)

If multiple ports are listening or none found on common ports:
- `angular.json` -> look for `"port"` in `serve.options`
- `vite.config.ts` / `vite.config.js` -> `server.port`
- `next.config.js` / `next.config.mjs` -> dev defaults to 3000
- `package.json` -> parse `"dev"` or `"start"` scripts for `--port` flags
- `.env` / `.env.local` -> `PORT=` variable

## Step 3: Resolve URL

- If exactly one dev server found -> use it (e.g., `http://localhost:4200`)
- If multiple found -> pick the one matching the project's primary framework, or ask the user to confirm
- If none found:
  ```
  Warning: No running dev server detected on common ports (3000, 4200, 5173, 8080, ...).

  Start your dev server first, then re-run the command.
  ```
  Stop — a running app is required.

## Step 4: Verify URL

Make a quick HTTP request to confirm the server responds:
```bash
curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL"
```
- If 2xx or 3xx -> proceed
- If connection refused or timeout -> stop with diagnostic
