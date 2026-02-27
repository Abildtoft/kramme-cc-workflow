---
name: kramme:nx:setup-portless
description: Set up portless in an Nx workspace for stable HTTPS localhost URLs. Use when adding portless, wiring up dev:local/dev:full targets, or configuring the HTTPS proxy.
disable-model-invocation: true
user-invocable: true
---

# Set Up Portless in an Nx Workspace

Add portless to an Nx workspace so apps get stable `https://<name>.localhost` URLs instead of port numbers. Portless runs a single HTTPS proxy daemon on port 443 that routes subdomains to individual dev servers.

> Experimental: This skill is early and may change as we refine the Nx + portless workflow.

## When to Use

- Setting up a new Nx workspace that needs local HTTPS with custom domains
- Adding a new app to an existing workspace that already has portless
- Wiring up a `dev:local` / `dev:full` target for an Nx project

## Architecture

```
Browser
  │
  ├─ https://my-app.localhost ──┐
  ├─ https://other-app.localhost ──┐
  │                                │
  ▼                                ▼
  ┌─────────────────────────────────┐
  │  Portless Proxy (port 443)      │  ← single daemon, started once per session
  │  sudo, HTTPS, routes by subdomain│
  └──────┬──────────────┬───────────┘
         │              │
         ▼              ▼
    localhost:4xxx  localhost:4yyy      ← auto-assigned ports per app
```

- One proxy serves all apps simultaneously — start it once, not per app.
- `sudo` is required because port 443 is privileged.
- Each app registers itself by name when launched via `portless <name> <command>`.

## Workspace-Level Setup (One-Time)

### 1. Install portless

```bash
# Using the workspace package manager
yarn add -D portless
# or: npm install -D portless / pnpm add -D portless
```

### 2. Add proxy targets to a project

Add these targets to one project's `project.json` (typically the primary app). The proxy is workspace-wide — these targets only need to exist once.

```jsonc
// packages/<app>/project.json
{
  "targets": {
    "proxy:trust": {
      "command": "sudo portless trust",
      "options": { "cwd": "packages/<app>" },
    },
    "proxy:start": {
      "command": "sudo PORTLESS_STATE_DIR=$HOME/.portless portless proxy start --https -p 443",
      "options": { "cwd": "packages/<app>" },
    },
    "proxy:stop": {
      "command": "sudo PORTLESS_STATE_DIR=$HOME/.portless portless proxy stop",
      "options": { "cwd": "packages/<app>" },
    },
  },
}
```

**Why `PORTLESS_STATE_DIR=$HOME/.portless`?** — Under `sudo`, the home directory changes to `/root`. This env var ensures the proxy daemon writes state to the user's home directory so `proxy:stop` can find and stop it later.

### 3. Trust the CA certificate (once per machine)

```bash
yarn nx run <app>:proxy:trust
```

This installs the portless CA certificate so browsers accept the self-signed HTTPS certificates without warnings.

## Per-App Setup

### 1. Add a `dev:local` target

```jsonc
// packages/<app>/project.json
{
  "targets": {
    "dev:local": {
      "command": "portless <app-name> <dev-command>",
      "options": { "cwd": "packages/<app>" },
    },
  },
}
```

Replace:

- `<app-name>` — the subdomain name (e.g., `my-app` → `https://my-app.localhost`)
- `<dev-command>` — the framework dev command (e.g., `next dev`, `vite dev`, `ng serve`)

**Example for Next.js:**

```jsonc
"dev:local": {
  "command": "portless keep-calm-and-quiz-on next dev",
  "options": { "cwd": "packages/app" }
}
```

### 2. Add a `dev:full` target (optional)

If the app has companion services (e.g., Convex backend), create a composite target:

```jsonc
"dev:full": {
  "dependsOn": [],
  "command": "yarn nx run-many -t dev:local convex-dev -p <app> --parallel=2"
}
```

Adjust the target list and parallelism for the services the app needs.

## Running

```bash
# Start the proxy (once per session)
yarn nx run <app>:proxy:start

# Start the app (in another terminal)
yarn nx run <app>:dev:local
# or with all services:
yarn nx run <app>:dev:full

# Open https://<app-name>.localhost

# Stop the proxy when done
yarn nx run <app>:proxy:stop
```

## Multiple Apps

Multiple apps run simultaneously through the same proxy — no extra setup needed:

```bash
# Terminal 1 (proxy already running)
yarn nx run app-one:dev:local    # → https://app-one.localhost

# Terminal 2
yarn nx run app-two:dev:local    # → https://app-two.localhost
```

## Naming Conventions

- Use kebab-case for app names: `my-cool-app` → `https://my-cool-app.localhost`
- Subdomains are supported: `portless api.my-app next dev` → `https://api.my-app.localhost`
- Keep names short and descriptive

## Troubleshooting

| Problem                           | Fix                                                                        |
| --------------------------------- | -------------------------------------------------------------------------- |
| `EACCES` on proxy start/stop      | Ensure commands use `sudo`                                                 |
| Proxy won't stop                  | Run `sudo PORTLESS_STATE_DIR=$HOME/.portless portless proxy stop` directly |
| Browser shows certificate warning | Run `proxy:trust` again and restart the browser                            |
| App not reachable after starting  | Confirm the proxy is running (`proxy:start`) before launching the app      |
