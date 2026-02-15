#!/bin/bash
# Initialize the learnings database for kramme-cc-workflow
# Location: ~/.kramme-cc-workflow/learnings.db

set -e

DB_DIR="$HOME/.kramme-cc-workflow"
DB_FILE="$DB_DIR/learnings.db"

# Create directory if it doesn't exist
mkdir -p "$DB_DIR"

# Check if database already exists
if [ -f "$DB_FILE" ]; then
    echo "Database already exists at $DB_FILE"
    exit 0
fi

# Create database with schema
sqlite3 "$DB_FILE" <<'SQL'
-- Main learnings table
CREATE TABLE IF NOT EXISTS learnings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT DEFAULT (datetime('now')),
    project TEXT,
    category TEXT NOT NULL,
    rule TEXT NOT NULL,
    mistake TEXT,
    correction TEXT,
    times_applied INTEGER DEFAULT 0
);

-- Full-text search virtual table using FTS5 with BM25 ranking
CREATE VIRTUAL TABLE IF NOT EXISTS learnings_fts USING fts5(
    category, rule, mistake, correction,
    content='learnings',
    content_rowid='id'
);

-- Trigger: sync FTS on insert
CREATE TRIGGER IF NOT EXISTS learnings_ai AFTER INSERT ON learnings BEGIN
    INSERT INTO learnings_fts(rowid, category, rule, mistake, correction)
    VALUES (new.id, new.category, new.rule, new.mistake, new.correction);
END;

-- Trigger: sync FTS on delete
CREATE TRIGGER IF NOT EXISTS learnings_ad AFTER DELETE ON learnings BEGIN
    INSERT INTO learnings_fts(learnings_fts, rowid, category, rule, mistake, correction)
    VALUES ('delete', old.id, old.category, old.rule, old.mistake, old.correction);
END;

-- Trigger: sync FTS on update
CREATE TRIGGER IF NOT EXISTS learnings_au AFTER UPDATE ON learnings BEGIN
    INSERT INTO learnings_fts(learnings_fts, rowid, category, rule, mistake, correction)
    VALUES ('delete', old.id, old.category, old.rule, old.mistake, old.correction);
    INSERT INTO learnings_fts(rowid, category, rule, mistake, correction)
    VALUES (new.id, new.category, new.rule, new.mistake, new.correction);
END;

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_learnings_category ON learnings(category);
CREATE INDEX IF NOT EXISTS idx_learnings_project ON learnings(project);
CREATE INDEX IF NOT EXISTS idx_learnings_created_at ON learnings(created_at);
SQL

echo "Database initialized at $DB_FILE"
