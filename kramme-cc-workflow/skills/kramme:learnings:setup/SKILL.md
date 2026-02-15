---
name: kramme:learnings:setup
description: Initialize or verify the learnings database (and optionally rebuild FTS)
argument-hint: "[--check] [--rebuild-fts] [--force]"
disable-model-invocation: true
user-invocable: true
---

# Setup Learnings Database

Initialize or verify the learnings database at `~/.kramme-cc-workflow/learnings.db`.

$ARGUMENTS

## Parse Arguments

- `--check`: run health check and exit
- `--rebuild-fts`: rebuild the FTS index
- `--force`: back up and recreate the database

## Prerequisites

```bash
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required. Install it and retry."
  exit 1
fi
```

## Paths

```bash
DB_DIR="$HOME/.kramme-cc-workflow"
DB_FILE="$DB_DIR/learnings.db"
```

## Health Check

```bash
if [ -f "$DB_FILE" ]; then
  sqlite3 "$DB_FILE" <<'SQL'
  SELECT name, type FROM sqlite_master
  WHERE name IN ('learnings','learnings_fts','learnings_ai','learnings_ad','learnings_au')
  ORDER BY type, name;
SQL
else
  echo "Database not found at $DB_FILE"
fi
```

If `--check` is provided, stop after health check and report total learnings:

```bash
if [ -f "$DB_FILE" ]; then
  sqlite3 "$DB_FILE" "SELECT COUNT(*) AS total_learnings FROM learnings;"
  exit 0
fi
exit 1
```

## Initialize if Missing

```bash
if [ ! -f "$DB_FILE" ]; then
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-learnings-db.sh"
fi
```

## Force Recreate (Optional)

If `--force` is provided and the database exists, confirm before proceeding:

```yaml
header: "Recreate Learnings Database"
question: "This will replace the existing learnings database. Proceed?"
options:
  - label: "Backup and recreate"
    description: "Copy DB to .bak.<timestamp> then reinitialize"
  - label: "Cancel"
```

If confirmed:

```bash
TS=$(date +"%Y%m%d%H%M%S")
cp "$DB_FILE" "${DB_FILE}.bak.${TS}"
rm "$DB_FILE"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-learnings-db.sh"
```

## Rebuild FTS (Optional)

If `--rebuild-fts` is provided:

```bash
sqlite3 "$DB_FILE" "INSERT INTO learnings_fts(learnings_fts) VALUES('rebuild');"
```

## Final Status

```bash
sqlite3 "$DB_FILE" "SELECT COUNT(*) AS total_learnings FROM learnings;"
```
