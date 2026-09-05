# Best-Effort Local Environment Startup

Use this procedure only after URL detection reports `__NO_RUNNING_SERVER__` and the caller supplied the validated internal `--start-if-easy` capability. It permits one bounded attempt to start a local UI environment; it does not turn evidence capture into a setup, repair, or deployment workflow.

## Qualifying Environment

Treat an environment as straightforward and safe to start only when all of these are true:

- One unambiguous local development command is available from an explicit user instruction or an established repository entrypoint such as the default applicable Conductor run script, a documented development command, or a conventional package-manager `dev`/`start` script.
- In delegated PR mode, a repository-derived command and the file that defines it exist in the pinned base commit and are unchanged by the captured diff. Never automatically execute a new or modified command supplied by the branch under review.
- Required executables, installed dependencies, local configuration, and non-sensitive demo data are already present. Starting the app needs no install, bootstrap, generation, migration, seed, reset, container or virtual-machine startup, privileged command, credential prompt, tunnel, cloud deployment, or external service mutation.
- The command is non-interactive, binds only to a local interface, can become ready within 60 seconds, and can be stopped without affecting a process that was running before this capture.

If any condition is unclear or multiple commands are equally plausible, do not guess or ask in delegated mode. Return `Tier: skipped` with the concrete reason.

## Start, Detect, and Clean Up

1. Run the secret preflight before launching anything. Never source or print environment files to discover configuration.
2. Record the current worktree status, then launch only the qualifying command through a managed shell session. Keep its exact process or session handle, redirect its output to `DEMO_REEL_DIR/environment.log`, and do not stream logs into the conversation.
3. For at most 60 seconds, rerun `${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh auto` while also checking whether the launched process exited. Use the first single reachable local URL. Do not broaden discovery to remote hosts.
4. If readiness times out, the process exits, or detection remains ambiguous, retain a concise diagnostic without copying log contents and return `Tier: skipped` unless a non-browser tier still proves the behavior.
5. After capture—or on every skipped or failure path—stop only the exact process/session started here and its children. Never kill by port, executable name, or pattern, and never stop a server that predated this run.
6. Recheck worktree status. Do not revert or delete product files automatically. Report any new tracked change as a startup side effect so the parent can surface it; ordinary ignored runtime caches do not invalidate otherwise safe evidence.

Startup and cleanup are best-effort evidence mechanics. They never authorize uploads; the publishing parent retains that boundary.
