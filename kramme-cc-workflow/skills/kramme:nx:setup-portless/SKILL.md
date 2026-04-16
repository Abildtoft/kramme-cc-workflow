---
name: kramme:nx:setup-portless
description: Set up portless in an Nx workspace with dev:local/dev:full targets. Use when adding portless to an Nx project or wiring up Nx targets for local HTTPS development.
disable-model-invocation: true
user-invocable: true
---

# Set Up Portless in an Nx Workspace

Wire portless into an Nx workspace so apps get stable `https://<name>.localhost` URLs via Nx targets. The proxy auto-starts when you launch an app, and Nx targets give you a repeatable place to trust the CA, run apps, and fall back to manual proxy control when a task runner needs it.

> Experimental: This skill is early and may change as we refine the Nx + portless workflow.

## When to Use

- Setting up a new Nx workspace that needs local HTTPS with custom domains
- Adding a new app to an existing workspace that already has portless
- Wiring up `dev:local` / `dev:full` targets for an Nx project

## Operational Model

- `portless <app-name> <dev-command>` starts an app, assigns it a port, and registers it with the proxy.
- `portless run <dev-command>` does the same thing, but infers the app name from `package.json`.
- The proxy auto-starts the first time you launch an app and routes `https://<name>.localhost` to the correct dev server.
- Most frameworks read the injected `PORT` env var. Frameworks that ignore it receive matching `--port` and `--host` flags automatically.
- Non-interactive task runners cannot answer elevation prompts. In those cases, pre-start the proxy with a manual `proxy:start` target and then launch the app.

## Workspace-Level Setup (One-Time)

### 1. Install portless

```bash
# Using the workspace package manager
yarn add -D portless
# or: npm install -D portless / pnpm add -D portless
```

### 2. Add the trust target

Add this target to one project's `project.json` (typically the primary app). It only needs to exist once in the workspace.

```jsonc
// packages/<app>/project.json
{
  "targets": {
    "proxy:trust": {
      "command": "sudo portless trust",
      "options": { "cwd": "packages/<app>" },
    },
  },
}
```

### 3. Trust the CA certificate (once per machine)

```bash
yarn nx run <app>:proxy:trust
```

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

Portless auto-detects common frameworks and injects the correct `--port`/`--host` flags automatically.

**Example for Next.js:**

```jsonc
"dev:local": {
  "command": "portless keep-calm-and-quiz-on next dev",
  "options": { "cwd": "packages/app" }
}
```

Alternatively, use `portless run` to infer the app name from `package.json`:

```jsonc
"dev:local": {
  "command": "portless run next dev",
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

The proxy auto-starts when you launch an app — no manual `proxy start` needed.

```bash
# Start the app
yarn nx run <app>:dev:local
# or with all services:
yarn nx run <app>:dev:full

# Open https://<app-name>.localhost
```

## Multiple Apps

Multiple apps run simultaneously through the same proxy:

```bash
# Terminal 1
yarn nx run app-one:dev:local    # → https://app-one.localhost

# Terminal 2
yarn nx run app-two:dev:local    # → https://app-two.localhost
```

## Naming Conventions

- Use kebab-case for app names: `my-cool-app` → `https://my-cool-app.localhost`
- Subdomains are supported: `portless api.my-app next dev` → `https://api.my-app.localhost`
- Keep names short and descriptive
- **Reserved names** (cannot be used as app names): `run`, `get`, `alias`, `hosts`, `list`, `trust`, `clean`, `proxy` — use `portless run` or `portless --name <name>` instead

## Advanced: Manual Proxy Targets

If you need explicit proxy control (e.g., task runners that don't support auto-start, or custom port/TLD/LAN settings), add these targets:

```jsonc
// packages/<app>/project.json
{
  "targets": {
    "proxy:start": {
      "command": "sudo PORTLESS_STATE_DIR=$HOME/.portless portless proxy start",
      "options": { "cwd": "packages/<app>" },
    },
    "proxy:stop": {
      "command": "sudo PORTLESS_STATE_DIR=$HOME/.portless portless proxy stop",
      "options": { "cwd": "packages/<app>" },
    },
  },
}
```

**Why `PORTLESS_STATE_DIR`?** — Under `sudo`, the home directory changes to `/root`. This env var ensures the proxy daemon writes state to the user's home directory so `proxy:stop` can find and stop it later.

Common `proxy:start` additions:

- `--lan` to advertise `.local` hostnames on your LAN
- `--tld test` to use `.test` instead of `.localhost`
- `--wildcard` to let unregistered subdomains fall back to a parent app
- `-p 8080` to avoid privileged ports and `sudo`

Useful env vars when you need them:

- `PORTLESS_PORT` to override the proxy port
- `PORTLESS_HTTPS=0` to disable TLS
- `PORTLESS_LAN=1` to default to LAN mode
- `PORTLESS_TLD=test` to change the TLD
- `PORTLESS_STATE_DIR` to override the proxy state directory

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `portless` exits because there is no TTY or it cannot prompt for elevation | Pre-start the proxy with `yarn nx run <app>:proxy:start`, then launch `dev:local` |
| Permission error on port 443 | Keep `sudo`, or run the proxy on an unprivileged port such as `-p 8080` |
| Browser shows a certificate warning | Run `yarn nx run <app>:proxy:trust` again |
| Safari cannot resolve the local hostname | Run `portless hosts sync` to add host entries |
