---
name: kramme:search-learnings
description: Search learnings database using full-text search (BM25)
argument-hint: <query> [--category CAT] [--project PRJ] [--limit N]
disable-model-invocation: false
user-invocable: true
---

# Search Learnings Database

Search the persistent learnings database using BM25 full-text search.

$ARGUMENTS

## Database Check

First, check if the database exists:

```bash
DB_FILE="$HOME/.kramme-cc-workflow/learnings.db"
if [ ! -f "$DB_FILE" ]; then
    echo "No learnings database found. Use /kramme:learn to add your first learning."
    exit 1
fi
```

## Parse Arguments

- First non-flag argument(s) form the search query
- `--category` or `-c`: filter by category
- `--project` or `-p`: filter by project
- `--limit` or `-l`: max results (default: 10)

## Sanitize Inputs

Validate numeric inputs and escape single quotes for SQL strings:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/learnings-sql.sh"

LIMIT=${LIMIT:-10}
require_numeric "limit" "$LIMIT"

QUERY_SAFE=$(sql_escape "$QUERY")
CATEGORY_SAFE=$(sql_escape "$CATEGORY")
PROJECT_SAFE=$(sql_escape "$PROJECT")
```

## Search Query Construction

### Full-Text Search (default)

Use FTS5 MATCH for keyword search:

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    l.id,
    l.category,
    l.rule,
    l.mistake,
    l.times_applied
FROM learnings l
JOIN learnings_fts fts ON l.id = fts.rowid
WHERE fts MATCH '$QUERY_SAFE'
ORDER BY bm25(fts)
LIMIT $LIMIT;
SQL
```

### With Category Filter

```bash
sqlite3 -header -column "$HOME/.kramme-cc-workflow/learnings.db" <<SQL
SELECT
    l.id,
    l.category,
    l.rule,
    l.mistake,
    l.times_applied
FROM learnings l
JOIN learnings_fts fts ON l.id = fts.rowid
WHERE fts MATCH '$QUERY_SAFE'
  AND l.category = '$CATEGORY_SAFE'
ORDER BY bm25(fts)
LIMIT $LIMIT;
SQL
```

### With Project Filter

Add `AND l.project = '$PROJECT_SAFE'` to the WHERE clause.

## Search Syntax Tips

- Simple keywords: `testing` matches "testing", "tests", "test"
- Prefix matching: `test*` matches anything starting with "test"
- Phrases: `"file paths"` matches exact phrase
- Multiple terms: `git rebase` matches either "git" OR "rebase"
- AND logic: `git AND rebase` requires both terms
- Exclude: `git NOT merge` excludes "merge" results

## Output Format

Present results in a readable format:

```
## Search Results for "$QUERY"

Found N learnings:

### #1 (ID: 42) [Testing]
**Rule:** Always run unit tests before integration tests
**Mistake:** Integration tests failed due to missing mocks
**Applied:** 3 times

### #2 (ID: 17) [Testing]
**Rule:** Use test fixtures for database state
**Applied:** 1 time

---
Use `/kramme:learn` to add new learnings.
```

## No Results

If no results found:

```
No learnings found for "$QUERY".

Tips:
- Try broader search terms
- Use prefix matching: test*
- Remove category/project filters
- Check available categories with /kramme:list-learnings --categories
```

## Increment Usage Counter

When a learning is particularly helpful and the user acts on it, you can increment its usage counter:

```bash
require_numeric "ID" "$ID"

sqlite3 "$HOME/.kramme-cc-workflow/learnings.db" \
  "UPDATE learnings SET times_applied = times_applied + 1 WHERE id = $ID"
```
