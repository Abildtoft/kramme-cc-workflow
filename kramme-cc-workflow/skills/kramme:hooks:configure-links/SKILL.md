---
name: kramme:hooks:configure-links
description: Configure the context-links hook by updating its persistent config file with workspace, team key, and issue regex overrides. Use when end users want to set up or change context-links behavior without manually editing files.
argument-hint: "[show|reset|KEY=VALUE ...]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Configure Context Links

Configure the `context-links` hook using a local config file.

- **Config file:** resolve this exactly as `hooks/context-links.sh` does, then use that one resolved path as the target for every read, write, and delete below (referred to as "the config file"):
  1. If `CONTEXT_LINKS_CONFIG_FILE` is set, use that path.
  2. Otherwise use `${XDG_CONFIG_HOME:-$HOME/.config}/kramme-cc-workflow/context-links.config` when it exists, or when the legacy file does not exist.
  3. Fall back to `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config` only when the XDG config file is absent and that legacy file exists.
- **Template:** `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config.example`
- **Git status:** the preferred default config file is local-only outside the plugin tree, so its contents are not recoverable from version control once deleted.

In Codex installs, do not write config under the copied skill directory. Use the XDG/default config path unless `CONTEXT_LINKS_CONFIG_FILE` is set or an existing legacy config is explicitly resolved from the installed hook plugin root. If the template is not reachable from the installed hook plugin root, create the config file with a short header comment instead.

Do not use this skill to enable or disable the hook itself (that is the hook toggle system), or to edit any other hook.

## Supported Keys

- `CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG`
- `CONTEXT_LINKS_LINEAR_TEAM_KEYS`
- `CONTEXT_LINKS_LINEAR_ISSUE_REGEX`

## Usage

- `/kramme:hooks:configure-links`:
  - Create the config file from the template if missing
  - Show current values
  - Ask which values to update, then apply changes

- `/kramme:hooks:configure-links show`:
  - Print the config file contents
  - For each supported key, report the value set in the config file. For any key not set there, note that the hook falls back (in order) to `CONTEXT_LINKS_*` env vars, legacy `LINEAR_*` env vars, then the built-in defaults in `hooks/context-links.sh`. Do not present a config-file value as the final value when an env var may override it.

- `/kramme:hooks:configure-links reset`:
  - Print the current config file contents so the user can recover values
  - Ask the user to confirm deletion (the file is local-only and cannot be recovered afterward)
  - On confirmation, delete the config file if present
  - Resolve the config path again and report what the hook will read next: an env override, a fallback legacy config, or the built-in defaults from `hooks/context-links.sh`

- `/kramme:hooks:configure-links KEY=VALUE [KEY=VALUE ...]`:
  - Upsert each supported key into the config file
  - Preserve unrelated comments/lines

## Argument Rules

1. Parse `$ARGUMENTS` by spaces.
2. `show` and `reset` are mutually exclusive: reject if both appear, or if either appears alongside any `KEY=VALUE` token.
3. Treat remaining tokens containing `=` as `KEY=VALUE` updates.
4. Reject unknown keys, and reject any bare token that is neither `show` nor `reset` and contains no `=`, with a clear message listing the supported keys.
5. Values cannot contain spaces (spaces split arguments). For multi-value keys such as `CONTEXT_LINKS_LINEAR_TEAM_KEYS`, use commas: `ENG,OPS,PLAT`.

## Update Workflow

1. Ensure the config file exists:
   - If missing and the template exists, copy from `.example`.
   - If both are missing, create the file with a short header comment.
2. For each `KEY=VALUE`, edit by reading the file, modifying it in memory, and writing it back. Do not use `sed`: its replacement breaks on regex/metacharacter values such as `(ENG|OPS|PLAT)-[0-9]+`.
   - Write the value as `KEY="VALUE"`, wrapping it in double quotes and escaping any embedded `"` and `\`.
   - If the key already appears (commented or uncommented, possibly more than once), remove all of those lines and leave a single canonical `KEY="VALUE"`.
   - If the key does not appear, append `KEY="VALUE"` at the end of the file.
3. Print the final config file contents.
4. Note that changes take effect on the hook's next run — it reloads the config each time, so no restart is needed.

## Interactive Mode (No Arguments)

If no arguments are provided:

1. Run `show` behavior first.
2. Prompt user for 1-3 updates in `KEY=VALUE` format (or blank to cancel).
3. Apply updates with the same upsert workflow.

## Output Expectations

- Report:
  - config file path (the resolved absolute path)
  - keys changed
  - keys unchanged
  - keys rejected (if any)
- For `reset`, after deletion, report what config source the hook will use next.

## Examples

```bash
/kramme:hooks:configure-links show
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=acme
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_TEAM_KEYS=ENG,OPS,PLAT
/kramme:hooks:configure-links reset
```
