---
name: kramme:toggle-hook
description: Enable or disable a plugin hook
argument-hint: <hook-name|status> [enable|disable]
---

# Toggle Hook

Enable or disable hooks in the kramme-cc-workflow plugin.

## Usage

- `/kramme:toggle-hook status` - List all hooks and their current state
- `/kramme:toggle-hook <hook-name>` - Toggle the hook (enable if disabled, disable if enabled)
- `/kramme:toggle-hook <hook-name> enable` - Enable the hook
- `/kramme:toggle-hook <hook-name> disable` - Disable the hook
- `/kramme:toggle-hook reset` - Enable all hooks (clear disabled list)

## Available Hooks

| Hook Name | Event | Description |
|-----------|-------|-------------|
| `block-rm-rf` | PreToolUse | Blocks destructive file deletion (rm -rf, shred, etc.) |
| `confirm-review-responses` | PreToolUse | Confirms before committing REVIEW_RESPONSES.md |
| `noninteractive-git` | PreToolUse | Forces non-interactive git commands |
| `auto-format` | PostToolUse | Auto-formats code after Write/Edit operations |
| `context-links` | Stop | Shows PR/MR and Linear issue links at session end |

## Implementation

The state file is at `${CLAUDE_PLUGIN_ROOT}/hooks/hook-state.json`.

### For `status` command:
1. Read `hooks/hook-state.json`
2. List all hooks with their enabled/disabled state
3. Format as a table

### For toggle/enable/disable:
1. Read `hooks/hook-state.json`
2. Parse the argument to get hook name and optional action
3. Validate hook name against the available hooks list
4. Update the `disabled` array:
   - If action is "enable": remove hook from disabled array
   - If action is "disable": add hook to disabled array
   - If no action (toggle): toggle the current state
5. Write updated JSON back to file
6. Confirm the change to user

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
