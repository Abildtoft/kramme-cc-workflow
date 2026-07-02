---
name: kramme:hooks:toggle
description: Enable, disable, list, or reset hook toggles for the kramme-cc-workflow plugin. Use when a hook is firing unwantedly, when a new hook needs to be switched on, or when the user asks about current hook state.
argument-hint: "<status|reset|hook-name> [enable|disable]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Toggle Hook

Enable or disable hooks in the kramme-cc-workflow plugin.

## Usage

- `/kramme:hooks:toggle status` - List all hooks and their current state
- `/kramme:hooks:toggle <hook-name>` - Toggle the hook (enable if disabled, disable if enabled)
- `/kramme:hooks:toggle <hook-name> enable` - Enable the hook
- `/kramme:hooks:toggle <hook-name> disable` - Disable the hook
- `/kramme:hooks:toggle reset` - Enable all hooks (clear disabled list)

## Available Hooks

| Hook Name | Event | Description |
| --- | --- | --- |
| `block-rm-rf` | PreToolUse | Blocks destructive file deletion (rm -rf, shred, etc.) |
| `confirm-review-responses` | PreToolUse | Confirms before committing configured review artifact files (see `hooks/confirm-review-artifacts.txt`) |
| `noninteractive-git` | PreToolUse | Forces non-interactive git commands |
| `skill-usage-stats` | UserPromptSubmit, PreToolUse | Records local skill usage statistics for slash invocations and Skill tool calls |
| `auto-format` | PostToolUse | Auto-formats code after Write/Edit operations |
| `context-links` | Stop | Shows PR and Linear issue links at session end |

The canonical hook list is the set of names each script passes to `exit_if_hook_disabled` (grep `hooks/*.sh` for `exit_if_hook_disabled`). Treat that set as the source of truth: if a hook script registers a name not in this table, the table is stale — update it (and surface the discrepancy to the user) rather than rejecting the name.

`block-rm-rf`, `confirm-review-responses`, and `noninteractive-git` are safety guardrails.

## Implementation

Resolve the state file the same way `hooks/lib/check-enabled.sh` does, and use that resolved path for every read and write:

1. If `KRAMME_HOOK_STATE_FILE` is set, use that path.
2. Otherwise use `${XDG_STATE_HOME:-$HOME/.local/state}/kramme-cc-workflow/hook-state.json` when it exists, or when the legacy file does not exist.
3. Fall back to `${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json` only when the XDG state file is absent and that legacy file exists.

The preferred default state file lives outside the installed plugin tree, so toggles survive plugin updates and reinstalls. `status` and `reset` are reserved subcommands and take precedence over a hook of the same name.

In Codex installs, do not write state under the copied skill directory. Use the XDG/default state path unless `KRAMME_HOOK_STATE_FILE` is set or an existing legacy hook-state file is explicitly resolved from the installed hook plugin root.

Whenever you read the state file: a missing file means all hooks are enabled (proceed as if `{"disabled": []}`). If the file exists but is not valid JSON, do not guess — report it and offer `reset` to restore a clean state.

### For `status` command:

1. Read the resolved state file (missing file = all enabled)
2. List all hooks with their enabled/disabled state
3. Format as a table

### For toggle/enable/disable:

1. Read the resolved state file (missing file = all enabled)
2. Parse the argument to get hook name and optional action. If the action is present and is not `enable` or `disable`, stop and show the valid forms.
3. Validate the hook name against the available hooks list. If it is unknown, stop and list the valid hook names.
4. If the change disables a safety guardrail (`block-rm-rf`, `confirm-review-responses`, `noninteractive-git`), warn the user which protection is being removed and confirm before writing.
5. Update the `disabled` array:
   - If action is "enable": remove hook from disabled array
   - If action is "disable": add hook to disabled array only if not already present (no duplicates)
   - If no action (toggle): toggle the current state
6. Write updated JSON back to file
7. Confirm the change to user

### For `reset` command:

1. Write `{"disabled": []}` to the resolved state file
2. Confirm all hooks are now enabled

### State File Format

```json
{
  "disabled": ["auto-format", "context-links"]
}
```

Empty `disabled` array or missing file means all hooks are enabled.
