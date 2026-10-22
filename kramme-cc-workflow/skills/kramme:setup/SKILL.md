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
   - `Context`: repository and local configuration signals, plus Conductor mode, workspace name/path, root path, default branch, allocated port range, and `.conductor/settings.toml` presence. `Conductor mode: cloud` means browser MCP tooling and `CONDUCTOR_PORT` are unavailable. When `Root path` differs from `Workspace path`, `.context/` and other untracked scratch are visible only in the current workspace. `.context ignored` says whether git ignores that scratch directory and which rule does it. `Codex legacy records` and `Codex tool map block` report leftovers from earlier Codex converter releases, which copied skills into the Codex home and wrote a managed tool map into its `AGENTS.md`. `Codex plugin` reports whether native plugin versions are cached in the Codex home. `Claude plugin cache` lists cached Claude Code versions and, when `jq` can read `installed_plugins.json`, the cached versions registered for this plugin across all scopes and projects. Registrations do not identify the active version or whether the plugin is enabled in this session. The probe honors `CLAUDE_CODE_PLUGIN_CACHE_DIR` before falling back to `CLAUDE_CONFIG_DIR/plugins` or `~/.claude/plugins`. `Plugin copy` names the directory and manifest version of the plugin copy running the checker.

4. If a tool is missing, provide the install command from the report as guidance only. Install hints assume macOS/Homebrew with Linux (apt) alternates where they exist; adapt to the user's platform and package manager. Do not run installs unless the user explicitly asks in a separate follow-up.

5. Turn context gaps into guidance only; never edit files to fix them:
   - `.context ignored: no`: suggest adding `.context/` to the clone's exclude file, at the path `git rev-parse --git-path info/exclude` prints (this clone only; in a worktree `.git` is a file, so `.git/info/exclude` fails), or `.gitignore` (shared), because session-search skeletons and other scratch land there.
   - `Codex legacy records: present`: tell the user to run the plugin's Codex converter `install` command again (from a checkout or through npx). It finds those records and asks before removing what they list, including a complete tool-map block when no other plugin shares the records.
   - `Codex tool map block` is `incomplete`, or `present` with no legacy records: the converter will not touch it. Tell the user to delete the marked block from that `AGENTS.md` themselves; for `incomplete`, only the start marker was found, so they must find where the old block ends.
   - `codex` row `ok` and `Codex plugin: not installed`: explain that Codex has no native plugin installation. Give `codex plugin marketplace add Abildtoft/kramme-cc-workflow --ref codex-plugin`, then `codex plugin add kramme-cc-workflow@kramme-cc-workflow` as guidance only. The checkout alternative is `npm install`, then `node kramme-cc-workflow/scripts/convert-plugin.js install kramme-cc-workflow` from the repository root. Never run these commands during the check.
   - `codex` row `ok` and `Codex plugin: installed`: enablement and hook trust are not inspected. Suggest `codex plugin list` for the user to check status themselves.
   - More than one Claude cache version: explain that cached or registered copies can belong to different scopes or projects; their presence alone does not mean this session loaded a superseded copy. In Claude Code, suggest `/plugin` to check this session's status and restart sessions after updating. In Codex, when `codex` is available, recommend installing the native plugin. Do not delete cache directories.
   - When `codex` is missing, say nothing about the Codex plugin.

6. For integrations that are not reliably inspectable from the shell, report them as `manual-check` instead of inventing a status. This includes authenticated app connectors such as Linear and Figma, plus Conductor MCP tool availability, unless their local configuration is directly visible.

7. End with a short readiness summary:
   - `Ready`: required tools are present.
   - `Ready with optional gaps`: required tools are present, but recommended or optional tools are missing.
   - `Blocked`: at least one required tool is missing, below its documented minimum version, or unable to complete its runtime probe.
   - List any step 5 findings after the status as cleanup notes. They never change the status.

## Safety Rules

- Keep the default path read-only.
- Do not auto-install missing tools.
- Never run `codex plugin` or `claude plugin` commands during the check.
- Never read Codex `config.toml` or modify either host's plugin caches or `installed_plugins.json`.
- Do not modify `.conductor/settings.toml`, `conductor.json`, `.worktreeinclude`, hook config, shell profiles, MCP settings, `.gitignore` or `.git/info/exclude`, the Codex `AGENTS.md`, or legacy install records.
- Treat missing optional integrations as guidance, not failure.
