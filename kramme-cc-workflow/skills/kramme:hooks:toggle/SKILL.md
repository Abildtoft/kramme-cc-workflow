---
name: kramme:hooks:toggle
description: Enable, disable, list, or reset hook toggles for the kramme-cc-workflow plugin. Use when a hook is firing unwantedly, when a new hook needs to be switched on, or when the user asks about current hook state.
argument-hint: "<status|reset|hook-name> [enable|disable]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
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

The state file is at `${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json`. `status` and `reset` are reserved subcommands and take precedence over a hook of the same name.

Whenever you read the state file: a missing file means all hooks are enabled (proceed as if `{"disabled": []}`). If the file exists but is not valid JSON, do not guess — report it and offer `reset` to restore a clean state.

### For `status` command:

1. Read `hooks/hook-state.json` (missing file = all enabled)
2. List all hooks with their enabled/disabled state
3. Format as a table

### For toggle/enable/disable:

1. Read `hooks/hook-state.json` (missing file = all enabled)
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

1. Write `{"disabled": []}` to `hooks/hook-state.json`
2. Confirm all hooks are now enabled

### State File Format

```json
{
  "disabled": ["auto-format", "context-links"]
}
```

Empty `disabled` array or missing file means all hooks are enabled.
