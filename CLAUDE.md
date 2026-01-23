# CLAUDE.md

This is a Claude Code plugin providing workflow automation tools for daily development tasks.

## Project Structure

```
.claude-plugin/plugin.json   # Plugin manifest (name, version, author)
commands/                    # Slash commands (markdown files)
agents/                      # Specialized subagents (markdown files)
skills/                      # Auto-triggered skills (subdirectories with SKILL.md)
hooks/hooks.json             # Event handlers configuration
```

## Adding Components

### Commands
Create `commands/<command-name>.md`:
```yaml
---
name: kramme:command-name
description: Brief description shown in command list
argument-hint: [optional-argument]
---
# Command instructions here
```

### Agents
Create `agents/<agent-name>.md`:
```yaml
---
name: kramme:agent-name
description: When and how to use this agent (shown in Task tool)
model: sonnet
color: blue
---
# Agent mission and expected output
```

### Skills
Create `skills/<skill-name>/SKILL.md`:
```yaml
---
name: skill-name
description: When to auto-trigger this skill
---
# Skill instructions
```

### Hooks
Edit `hooks/hooks.json` to add event handlers (PreToolUse, PostToolUse, SessionStart, Stop).

**Important:** All hooks must support the toggle system. Add this at the start of each hook script:
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "hook-name"        # For PreToolUse hooks
exit_if_hook_disabled "hook-name" "json" # For PostToolUse/Stop hooks
```

## Conventions

- Use kebab-case for file and directory names
- Components are markdown files with YAML frontmatter
- Keep instructions concise and actionable
- **Document all components in README.md** - Every command, skill, agent, and hook must be documented in the README with a description of what it does and when to use it
- Use "Pull Request" (PR) terminology, not "Merge Request" (MR) — even when supporting GitLab
- **Use conventional commits** - Commit messages and PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) format (`feat:`, `fix:`, `docs:`, etc.) for automatic CHANGELOG generation. PR titles are validated by CI and become merge commit messages.

## Development

Install locally for testing:
```bash
claude /plugin install /path/to/this/repo
```
