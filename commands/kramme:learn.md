---
name: kramme:learn
description: Add a learning to the persistent database. Proposes adding to AGENTS.md if project-relevant.
argument-hint: [rule] [--category CAT] [--project PRJ] [--mistake MSG]
---

# Add Learning

Add a learning to the persistent SQLite database at `~/.kramme-cc-workflow/learnings.db`.

$ARGUMENTS

## Database Setup

First, ensure the database exists:

```bash
DB_FILE="$HOME/.kramme-cc-workflow/learnings.db"
if [ ! -f "$DB_FILE" ]; then
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-learnings-db.sh"
fi
```

## Categories

| Category | Use for |
|----------|---------|
| Navigation | Finding files, codebase exploration |
| Editing | Code modification patterns |
| Testing | Test writing and running |
| Git | Version control workflows |
| Quality | Code quality, reviews |
| Context | Managing conversation context |
| Architecture | Design patterns, structure |
| Performance | Optimization techniques |
| Prompting | Effective communication with Claude |
| Tooling | IDE, CLI, MCP tool insights |

## Collect Learning

### Quick Mode (arguments provided)

Parse arguments:
- First non-flag argument is the rule
- `--category` or `-c`: category name
- `--project` or `-p`: project name (defaults to current git repo name)
- `--mistake` or `-m`: what went wrong

Example: `/kramme:learn "Always check for null" --category Quality`

### Interactive Mode (no arguments)

Ask the user:

1. "What did you learn? (the rule or insight)"
2. "Which category?" (show options)
3. "What mistake led to this?" (optional)

## Insert Learning

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "INSERT INTO learnings (category, rule, mistake, project)
   VALUES ('$CATEGORY', '$RULE', '$MISTAKE', '$PROJECT')"
```

Escape single quotes by doubling them (`'` → `''`).

Confirm:
```
Learning added to database (ID: N)
Category: $CATEGORY
```

## Propose AGENTS.md Addition

After saving to the database, evaluate if this learning is **project-specific** (not a general best practice):

**Add to AGENTS.md if:**
- References specific files, directories, or modules in this project
- Describes project-specific quirks or conventions
- Documents hidden dependencies or relationships in this codebase
- Explains non-obvious build/test commands for this project

**Skip AGENTS.md if:**
- General programming best practice
- Language/framework knowledge applicable anywhere
- Personal workflow preference

If project-relevant, propose:

```yaml
question: "This learning seems specific to this project. Add to AGENTS.md?"
options:
  - label: "Yes, add to AGENTS.md"
    description: "Make this available in project context"
  - label: "No, database only"
    description: "Keep it searchable but not in project files"
```

## Formatting for AGENTS.md

If user accepts, format the learning for AGENTS.md:

**Guidelines:**
- Use short bullet points (1-2 lines)
- Be direct and factual, no explanations
- Use imperative mood ("Run X before Y", not "You should run X")
- Include file paths or commands if relevant

**Transform the learning:**

| Database format | AGENTS.md format |
|-----------------|------------------|
| "Always run unit tests before integration tests because integration tests are slow" | `- Run unit tests before integration tests` |
| "The config loader reads from ~/.config first, then falls back to /etc" | `- Config precedence: ~/.config → /etc` |
| "FeatureFlags.ts must be updated whenever adding a new feature" | `- Update FeatureFlags.ts when adding features` |

**Determine placement:**
1. Check if AGENTS.md exists in project root
2. If yes, read it and find the appropriate section
3. If no, create it with a simple format

Present the proposed addition:

```
**Proposed addition to AGENTS.md:**

```markdown
- [the formatted learning]
```

**Placement:** [End of file | After "## Build" section | etc.]
```

Ask for confirmation, then apply with Edit tool.

## Summary

```
Learning saved:
- Database: ✓ (ID: N, searchable via /kramme:search-learnings)
- AGENTS.md: ✓ Added | ✗ Skipped (not project-specific)
```
