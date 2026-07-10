# Local Storage and Backend Rules

Wayfinder v1 uses local Markdown artifacts only. It does not require or mutate Linear, GitHub Issues, Jira, or another external tracker.

## Resolve the Canonical Root

Choose in this order:

1. Reuse the canonical directory containing an explicitly supplied existing `MAP.md`.
2. For a new map inside a Git worktree, use `<worktree-root>/.context/wayfinder/<map-slug>/`.
3. Without a Git worktree, use `<current-directory>/.context/wayfinder/<map-slug>/` only after confirming the location with the user.

Derive `<map-slug>` from the initiative name: lowercase it, replace runs of non-alphanumeric characters with one hyphen, trim hyphens, and keep it short enough to scan. If the target exists, read its `MAP.md` when present and offer resume, an explicit different slug, or abort. Never merge maps or overwrite a directory silently.

Before creating a repository-local `.context`, verify it is ignored with `git check-ignore`. If it is not ignored, stop and ask for a safe ignored location or explicit permission to update ignore rules. Do not let active Wayfinder artifacts appear in a commit by accident.

## Directory Layout

Use:

```text
.context/wayfinder/<map-slug>/
├── MAP.md
├── tickets/
│   ├── WF-001-<ticket-slug>.md
│   └── WF-002-<ticket-slug>.md
├── evidence/       # optional research summaries or linked planning evidence
└── handoffs/       # optional temporary cross-workspace resolution packets
```

Keep the runtime layout independent from `siw/`. Wayfinder artifacts are temporary decision-navigation state; SIW specs and issues are a later tracked workflow.

## Shared Paths and Conductor

Do not assume separate worktrees have the same `.context` directory. When the user explicitly wants several Conductor workspaces to work one map, choose one canonical shared root before charting:

- Prefer a user-approved path under `$CONDUCTOR_ROOT_PATH/.context/wayfinder/` when that environment variable is available, the path is writable, and it is ignored.
- Otherwise keep the map in a coordinator workspace and exchange explicit ticket snapshots and resolution handoffs.

A shared root outside the active worktree changes the write boundary. Show the resolved path and obtain confirmation before creating or modifying it. Never infer permission merely from the presence of `CONDUCTOR_ROOT_PATH`.

## Backend Gate

Treat an external tracker URL as context only unless the user asks to make that tracker canonical. If they do, stop with `UNSUPPORTED BACKEND` before any API or MCP call. Report that local Markdown is the supported backend and that native tracker children, assignments, blocking edges, and frontier queries remain a future extension.

## Safe Writes and Handoff

- Resolve every path before writing and refuse an unexpected path outside the approved root.
- Reuse files only for the same stable map or ticket identity.
- Write each candidate canonical file to a sibling named `.<canonical-name>.wayfinder-tmp-<workspace-or-session-id>`. Validate it against the map or ticket contract, then atomically rename it over the canonical path and re-read the canonical file before continuing.
- A temporary file is never authoritative. On restart, publish it only after the map owner verifies its identity and it passes the full contract; otherwise preserve it for inspection. Remove only the current session's temporary file after a verified rename. Do not delete another session's temporary file without owner or user confirmation.
- Before trusting an existing map, require valid map metadata and every required section, then verify every index row links to a valid ticket with matching identity and state.
- Before trusting an existing ticket, require its stable ID and map link plus valid type, mode, status, blockers, and claim metadata. A `RESOLVED` ticket must also satisfy the resolution contract. Treat a missing or malformed required field as corrupted state and stop for owner-guided recovery rather than repeating the investigation.
- If a map directory contains ticket files but no `MAP.md`, treat it as an interrupted chart before publication. Do not resolve tickets or create a second map in that directory. Read only enough ticket metadata to verify that every ticket points to the same intended map identity and canonical path; if they match, reconstruct a `DRAFT` map from the ticket metadata, validate the index against the tickets, then promote it through the normal `DRAFT` recovery path. If identity cannot be proven, stop for owner-guided recovery and preserve the directory unchanged.
- Write ticket detail first and the map's derived index second so interrupted runs can reconcile safely.
- Link large evidence artifacts rather than copying their contents into tickets.
- Before retiring the directory, synthesize durable decisions into the destination spec, issue, plan, or other chosen record. Downstream durable docs must not depend on a temporary `.context` path.
