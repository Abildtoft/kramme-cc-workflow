---
name: kramme:learn
description: Add a learning to the persistent database for cross-session retrieval
argument-hint: [rule] [--category CAT] [--project PRJ] [--mistake MSG] [--correction FIX]
---

# Add Learning to Database

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

Valid categories (pick the most appropriate):

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

## Modes

### Quick Mode (arguments provided)

If the user provided arguments, parse them:
- First non-flag argument is the rule
- `--category` or `-c`: category name
- `--project` or `-p`: project name
- `--mistake` or `-m`: what went wrong
- `--correction` or `-x`: how it was fixed

Example: `/kramme:learn "Always check for null" --category Quality --mistake "NullPointerException"`

### Interactive Mode (no arguments)

If no arguments provided, ask the user:

```yaml
header: "Add a Learning"
question: "What did you learn? (the rule or insight)"
type: text
```

Then ask for category:

```yaml
question: "Which category best fits this learning?"
options:
  - "Navigation"
  - "Editing"
  - "Testing"
  - "Git"
  - "Quality"
  - "Context"
  - "Architecture"
  - "Performance"
  - "Prompting"
  - "Tooling"
```

Then optionally ask:
- "What mistake led to this learning?" (optional)
- "How was it corrected?" (optional)
- "Associate with a specific project?" (optional, defaults to current project name from git or null)

## Insert Learning

Once you have the data, insert into the database:

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "INSERT INTO learnings (category, rule, mistake, correction, project)
   VALUES ('$CATEGORY', '$RULE', '$MISTAKE', '$CORRECTION', '$PROJECT')"
```

**Important:** Properly escape single quotes in values by doubling them (`'` → `''`).

## Confirmation

After inserting, query the new learning:

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" \
  "SELECT id, category, rule FROM learnings ORDER BY id DESC LIMIT 1"
```

Report success:
```
Learning #N added to database.
Category: $CATEGORY
Rule: $RULE
```

## Sync to AGENTS.md (Optional)

If the user specified `--sync-to-agents` or if the learning is project-specific and highly relevant:

Ask if they'd like to also add this to an AGENTS.md file for the current project. If yes, follow the pattern from `/kramme:extract-learnings` to determine placement and format.
