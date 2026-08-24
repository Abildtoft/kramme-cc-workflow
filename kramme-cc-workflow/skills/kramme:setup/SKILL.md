---
name: kramme:setup
description: Run a read-only environment health check for this plugin's local workflow tools, repo context, optional CLIs, and detectable Conductor/worktree state. Use after installing the plugin, when a skill fails because a dependency may be missing, or before running a workflow in a new workspace. Not for installing tools, changing config, or repairing broken environments automatically.
argument-hint: "[--json|--help]"
disable-model-invocation: false
user-invocable: true
---

# Setup Health Check

Run a non-mutating environment check and report what is ready, missing, or only partially detectable.

## Workflow

1. Parse `$ARGUMENTS`.
   - No arguments: run the default human-readable report.
   - `--json`: request machine-readable output from the script.
   - `--help`: show script usage.
   - Unknown arguments: stop and show usage.

2. Run the bundled checker by resolving the script path relative to this skill directory while keeping the current workspace as the command working directory:

   ```bash
   "$SKILL_DIR/scripts/check-environment.sh"
   ```

   `SKILL_DIR` is the directory containing this `SKILL.md`. Add `--json` when requested. Do not `cd` into the skill directory before running it; the `Context` section intentionally reports the workspace where the skill was invoked. The checker must not install packages, edit config, fetch remotes, delete files, or write repo-local state.

3. Read the report in four groups:
   - `Required`: Bash, Git, `jq`, Python 3.10+, and Node.js 18+, which the plugin assumes for the full default experience.
   - `Recommended`: tools used by common PR, verification, and conversion workflows.
   - `Optional`: tools used only by specific skills or local maintenance paths.
   - `Context`: repository and local configuration signals, plus Conductor mode, workspace name/path, root path, default branch, allocated port range, and `.conductor/settings.toml` presence. `Conductor mode: cloud` means browser MCP tooling and `CONDUCTOR_PORT` are unavailable. When `Root path` differs from `Workspace path`, `.context/` and other untracked scratch are visible only in the current workspace.

4. If a tool is missing, provide the install command from the report as guidance only. Install hints assume macOS/Homebrew with Linux (apt) alternates where they exist; adapt to the user's platform and package manager. Do not run installs unless the user explicitly asks in a separate follow-up.

5. For integrations that are not reliably inspectable from the shell, report them as `manual-check` instead of inventing a status. This includes authenticated app connectors such as Linear and Figma, plus Conductor MCP tool availability, unless their local configuration is directly visible.

6. End with a short readiness summary:
   - `Ready`: required tools are present.
   - `Ready with optional gaps`: required tools are present, but recommended or optional tools are missing.
   - `Blocked`: at least one required tool is missing, below its documented minimum version, or unable to complete its runtime probe.

## Safety Rules

- Keep the default path read-only.
- Do not auto-install missing tools.
- Do not modify `.conductor/settings.toml`, `conductor.json`, `.worktreeinclude`, hook config, shell profiles, or MCP settings.
- Treat missing optional integrations as guidance, not failure.
