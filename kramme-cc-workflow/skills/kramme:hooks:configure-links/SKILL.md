---
name: kramme:hooks:configure-links
description: Configure the context-links hook by updating hooks/context-links.config with workspace, team key, issue regex, and GitLab remote regex overrides. Use when end users want to set up or change context-links behavior without manually editing files.
argument-hint: "[show|reset|KEY=VALUE ...]"
disable-model-invocation: true
user-invocable: true
---

# Configure Context Links

Configure the `context-links` hook using a local config file:

- File: `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config`
- Template: `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config.example`
- Git status: ignored by `.gitignore` (local-only overrides)

## Supported Keys

- `CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG`
- `CONTEXT_LINKS_LINEAR_TEAM_KEYS`
- `CONTEXT_LINKS_LINEAR_ISSUE_REGEX`
- `CONTEXT_LINKS_GITLAB_REMOTE_REGEX`

## Usage

- `/kramme:hooks:configure-links`:
  - Create config from example if missing
  - Show current values
  - Ask which values to update, then apply changes

- `/kramme:hooks:configure-links show`:
  - Show current config file content and effective values from supported keys

- `/kramme:hooks:configure-links reset`:
  - Delete `hooks/context-links.config` if present
  - Confirm fallback to built-in defaults

- `/kramme:hooks:configure-links KEY=VALUE [KEY=VALUE ...]`:
  - Upsert each supported key into `hooks/context-links.config`
  - Preserve unrelated comments/lines where practical

## Argument Rules

1. Parse `$ARGUMENTS` by spaces.
2. Recognize `show` and `reset` as exclusive commands.
3. Treat remaining tokens with `=` as `KEY=VALUE` updates.
4. Reject unknown keys with a clear message and list of supported keys.

## Update Workflow

1. Ensure `${CLAUDE_PLUGIN_ROOT}/hooks/context-links.config` exists:
   - If missing and template exists, copy from `.example`.
   - If template missing, create file with a short header comment.
2. For each `KEY=VALUE`:
   - Escape value safely for shell replacement.
   - If key exists (commented or uncommented), replace the line with `KEY="VALUE"`.
   - If key does not exist, append `KEY="VALUE"` at end of file.
3. Print final config file content.
4. Confirm changes are active immediately for the hook.

## Interactive Mode (No Arguments)

If no arguments are provided:

1. Run `show` behavior first.
2. Prompt user for 1-4 updates in `KEY=VALUE` format (or blank to cancel).
3. Apply updates with the same upsert workflow.

## Output Expectations

- Report:
  - config file path
  - keys changed
  - keys unchanged
  - keys rejected (if any)
- When `reset` is used, confirm the hook will use defaults from `hooks/context-links.sh`.

## Examples

```bash
/kramme:hooks:configure-links show
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG=acme
/kramme:hooks:configure-links CONTEXT_LINKS_LINEAR_TEAM_KEYS=ENG,OPS,PLAT
/kramme:hooks:configure-links CONTEXT_LINKS_GITLAB_REMOTE_REGEX=git\\.example\\.com
/kramme:hooks:configure-links reset
```
