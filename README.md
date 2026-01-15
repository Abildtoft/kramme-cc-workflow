# kramme-cc-workflow

A Claude Code plugin providing tooling for daily workflow tasks.

## Installation

### From Git URL

```bash
claude /plugin install git+https://github.com/YOUR_USERNAME/kramme-cc-workflow.git
```

### From Local Path (development)

```bash
claude /plugin install /path/to/kramme-cc-workflow
```

## Plugin Structure

```
kramme-cc-workflow/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata
├── commands/            # Slash commands
├── agents/              # Specialized subagents
├── skills/              # Auto-triggered skills
├── hooks/               # Event handlers
│   └── hooks.json
└── README.md
```

## Adding Components

### Commands

Create markdown files in `commands/` with this format:

```markdown
---
allowed-tools:
  - Bash(git add:*)
  - Bash(git status:*)
---
# Command Name

## Context
- Current directory: $PWD

## Your Task
Describe what the command should do.
```

### Agents

Create markdown files in `agents/` with this format:

```markdown
---
model: sonnet
color: blue
tools:
  - Glob
  - Grep
  - Read
---
# Agent Name

## Mission
Describe the agent's purpose and capabilities.

## Expected Output
Describe what the agent should return.
```

### Skills

Create a subdirectory in `skills/` with a `SKILL.md` file:

```
skills/
└── my-skill/
    └── SKILL.md
```

SKILL.md format:

```markdown
---
name: my-skill
description: When to use this skill (this triggers auto-invocation)
---
# My Skill

Instructions for Claude when this skill is active.
```

### Hooks

Edit `hooks/hooks.json` to add event handlers:

```json
{
  "description": "Hook description",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/my_hook.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Session started'"
          }
        ]
      }
    ]
  }
}
```

Available hook events:
- `PreToolUse` - Before a tool is executed
- `PostToolUse` - After a tool is executed
- `SessionStart` - When Claude Code session begins
- `Stop` - When Claude attempts to stop

## Documentation

- [Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)

## License

MIT
