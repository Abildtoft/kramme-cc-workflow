---
name: kramme:list-learnings
description: List all learnings, optionally filtered by category or project
argument-hint: "[--category CAT] [--project PRJ] [--limit N] [--categories]"
disable-model-invocation: false
user-invocable: true
---

# List Learnings

List learnings from the persistent database, with optional filtering.

$ARGUMENTS

## Database Check

```bash
DB_FILE="$HOME/.kramme-cc-workflow/learnings.db"
if [ ! -f "$DB_FILE" ]; then
    echo "No learnings database found. Use /kramme:learn to add your first learning."
    exit 1
fi
```

## Parse Arguments

- `--category` or `-c`: filter by category
- `--project` or `-p`: filter by project
- `--limit` or `-l`: max results (default: 20)
- `--categories`: show category summary instead of learnings
- `--stats`: show database statistics

## Sanitize Inputs

Validate numeric inputs and escape single quotes for SQL strings:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/learnings-sql.sh"

LIMIT=${LIMIT:-20}
require_numeric "limit" "$LIMIT"
require_optional_numeric "ID" "$ID"

CATEGORY_SAFE=$(sql_escape "$CATEGORY")
PROJECT_SAFE=$(sql_escape "$PROJECT")
```

## Show Category Summary

If `--categories` flag is provided:

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    category,
    COUNT(*) as count,
    SUM(times_applied) as total_applied
FROM learnings
GROUP BY category
ORDER BY count DESC;
SQL
```

Output:
```
## Learnings by Category

| Category     | Count | Times Applied |
|--------------|-------|---------------|
| Testing      | 15    | 42            |
| Git          | 12    | 28            |
| Quality      | 8     | 15            |
...
```

## Show Statistics

If `--stats` flag is provided:

```bash
sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    COUNT(*) as total_learnings,
    COUNT(DISTINCT category) as categories,
    COUNT(DISTINCT project) as projects,
    SUM(times_applied) as total_applications,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM learnings;
SQL
```

## List All Learnings

Default query (most recent first):

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    id,
    category,
    substr(rule, 1, 60) || CASE WHEN length(rule) > 60 THEN '...' ELSE '' END as rule,
    times_applied,
    date(created_at) as added
FROM learnings
ORDER BY created_at DESC
LIMIT $LIMIT;
SQL
```

## With Category Filter

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    id,
    category,
    rule,
    mistake,
    times_applied,
    date(created_at) as added
FROM learnings
WHERE category = '$CATEGORY_SAFE'
ORDER BY times_applied DESC, created_at DESC
LIMIT $LIMIT;
SQL
```

## With Project Filter

Add `WHERE project = '$PROJECT_SAFE'` or `AND project = '$PROJECT_SAFE'`.

## Output Format

```
## Learnings Database

Showing N learnings (of M total)

| ID | Category | Rule | Applied | Added |
|----|----------|------|---------|-------|
| 42 | Testing  | Always run unit tests before... | 5 | 2025-01-15 |
| 38 | Git      | Use fixup commits for small... | 3 | 2025-01-14 |
...

Use `/kramme:search-learnings <query>` to search.
Use `/kramme:learn` to add new learnings.
```

## View Single Learning

If user provides an ID (e.g., `/kramme:list-learnings 42`), show full details:

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT * FROM learnings WHERE id = $ID;
SQL
```

Output:
```
## Learning #42

**Category:** Testing
**Rule:** Always run unit tests before integration tests
**Mistake:** Integration tests failed due to missing mocks that unit tests would have caught
**Correction:** Added unit test run to pre-commit hook
**Project:** my-app
**Times Applied:** 5
**Added:** 2025-01-15 14:32:00
```
