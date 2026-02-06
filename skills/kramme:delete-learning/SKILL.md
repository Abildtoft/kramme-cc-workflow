---
name: kramme:delete-learning
description: Delete a learning from the database by ID
argument-hint: <id>
disable-model-invocation: true
---

# Delete Learning

Delete a learning from the persistent database by ID.

$ARGUMENTS

## Database Check

```bash
DB_FILE="$HOME/.kramme-cc-workflow/learnings.db"
if [ ! -f "$DB_FILE" ]; then
    echo "No learnings database found."
    exit 1
fi
```

## Parse Arguments

The argument should be a numeric ID. If not provided, ask:

```yaml
question: "Which learning do you want to delete? Enter the ID number."
type: text
```

## Validate Inputs

Ensure IDs are numeric and escape strings used in bulk deletes:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/learnings-sql.sh"

require_numeric "ID" "$ID"

CATEGORY_SAFE=$(sql_escape "$CATEGORY")
PROJECT_SAFE=$(sql_escape "$PROJECT")
```

## Fetch Learning Details

Before deleting, show what will be deleted:

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" \
  "SELECT id, category, rule, created_at FROM learnings WHERE id = $ID"
```

If no learning found:
```
Learning #$ID not found. Use /kramme:list-learnings to see available IDs.
```

## Confirm Deletion

Ask for confirmation:

```yaml
header: "Confirm Deletion"
question: "Delete this learning?"
options:
  - label: "Yes, delete it"
    description: "Permanently remove learning #$ID"
  - label: "No, cancel"
    description: "Keep the learning"
```

## Delete Learning

If confirmed:

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "DELETE FROM learnings WHERE id = $ID"
```

## Confirm Success

Verify deletion:

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "SELECT COUNT(*) FROM learnings WHERE id = $ID"
```

If count is 0:
```
Learning #$ID deleted successfully.
```

## Bulk Delete (Optional)

If user wants to delete multiple learnings:

```yaml
question: "Delete multiple learnings?"
options:
  - label: "By category"
    description: "Delete all learnings in a category"
  - label: "By project"
    description: "Delete all learnings for a project"
  - label: "By age"
    description: "Delete learnings older than N days"
  - label: "Cancel"
```

### Delete by Category

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "DELETE FROM learnings WHERE category = '$CATEGORY_SAFE'"
```

### Delete by Project

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "DELETE FROM learnings WHERE project = '$PROJECT_SAFE'"
```

### Delete by Age

```bash
require_numeric "age (days)" "$DAYS"

sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "DELETE FROM learnings WHERE created_at < datetime('now', '-$DAYS days')"
```

Always show count of affected rows and confirm before executing bulk deletes.
