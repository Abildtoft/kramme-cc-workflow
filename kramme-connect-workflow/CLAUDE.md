# CLAUDE.md

This is a Claude Code plugin providing workflow automation for the Connect monorepo.

## Project Structure

```
.claude-plugin/plugin.json   # Plugin manifest (name, version, author)
skills/                      # Skills (subdirectories with SKILL.md)
```

## Conventions

- Use kebab-case for file and directory names
- Components are markdown files with YAML frontmatter
- Keep instructions concise and actionable
- Use "Pull Request" (PR) terminology, not "Merge Request" (MR)
- **Explicit skill frontmatter** - Every skill SKILL.md must declare all frontmatter fields explicitly (`name`, `description`, `disable-model-invocation`, `user-invocable`). Never rely on defaults.

## Development

Install locally for testing:
```bash
claude /plugin install /path/to/kramme-connect-workflow
```
