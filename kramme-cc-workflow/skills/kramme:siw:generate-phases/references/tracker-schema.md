# Tracker Schema

Use this schema when updating `siw/OPEN_ISSUES_OVERVIEW.md` in Phase 6.2.

Update `siw/OPEN_ISSUES_OVERVIEW.md` with all new issues, grouped by phase. Modern sections keep one group-level `**Parallelization:**` summary line; exact per-issue guidance lives in the issue files. Legacy sections that predate that metadata keep their existing format unless the user is explicitly migrating the tracker schema.

If you add any non-DONE issues to a phase section currently marked ` (DONE)`, remove the marker (or ask the user) so the header stays accurate.

**Append-mode compatibility rules:**

- Inspect each existing section before appending rows.
- If a section already uses the **7-column** schema `| # | Title | Status | Size | Priority | Mode | Related |`, keep that schema and emit Mode for new rows.
- If a section already uses the **6-column** schema `| # | Title | Status | Size | Priority | Related |` (pre-Mode), preserve it for compatibility. Only migrate to the 7-column schema when the user explicitly requests a schema migration.
- If a section already uses the legacy **5-column** `| # | Title | Status | Priority | Related |`, preserve that schema and do not inject Size or Mode columns into that section.
- If you're creating a brand-new section while appending into a tracker whose existing sections are legacy 5- or pre-Mode 6-column tables, match the existing dominant schema for the new section instead of mixing layouts mid-file.
- Preserve any existing section-level `**Parallelization:**` line exactly as written. If a legacy section predates that metadata, do not add the line unless the user is explicitly migrating the tracker schema.

The `Mode` cell is `AUTO` or `HITL` (no inline reason in the table; the reason lives in the issue file's frontmatter).

```markdown
# Open Issues Overview

## General

**Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination}

| #     | Title   | Status | Size   | Priority   | Mode | Related |
| ----- | ------- | ------ | ------ | ---------- | ---- | ------- |
| G-001 | {Title} | READY  | {Size} | {Priority} | AUTO |         |
| G-002 | {Title} | READY  | {Size} | {Priority} | HITL |         |

## Phase 1: {Goal}

**Parallelization:** {Safe to parallelize after P1-001 | Must be sequential | Needs coordination}

| #      | Title   | Status | Size   | Priority | Mode | Related |
| ------ | ------- | ------ | ------ | -------- | ---- | ------- |
| P1-001 | {Title} | READY  | {Size} | High     | AUTO |         |
| P1-002 | {Title} | READY  | {Size} | Medium   | AUTO | P1-001  |

## Phase 2: {Goal}

**Parallelization:** {Safe to parallelize | Must be sequential after Phase 1 | Needs coordination}

| #      | Title   | Status | Size   | Priority | Mode | Related |
| ------ | ------- | ------ | ------ | -------- | ---- | ------- |
| P2-001 | {Title} | READY  | {Size} | High     | HITL | Phase 1 |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

Legacy compatibility example when appending to an older 5-column tracker:

```markdown
## Phase 1: {Goal}

| #      | Title   | Status | Priority | Related |
| ------ | ------- | ------ | -------- | ------- |
| P1-001 | {Title} | READY  | High     |         |
| P1-002 | {Title} | READY  | Medium   | P1-001  |
```

When reading existing tracker rows in append mode, accept legacy title-case `Ready` and `In Progress` as `READY` and `IN PROGRESS`. Emit uppercase statuses for all new or updated rows.
