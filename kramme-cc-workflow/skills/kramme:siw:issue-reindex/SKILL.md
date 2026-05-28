---
name: kramme:siw:issue-reindex
description: Remove all DONE issues and renumber remaining issues within each prefix group. Not for editing live issue content, archiving still-open issues, or moving issues between prefix groups.
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Reindex Issues

Remove all DONE issues and renumber remaining issues **within each prefix group**. This command:

1. Identifies all issues with status DONE
2. Verifies DONE issue decisions and LOG.md entries are captured in specs before deletion
3. Deletes DONE issue files
4. Renumbers remaining issues sequentially **within each prefix group** (G-, P1-, P2-, etc.)
5. Updates siw/OPEN_ISSUES_OVERVIEW.md with new numbers
6. Updates siw/LOG.md issue references to match new numbers

Use this when you want to clean up completed issues and have fresh numbering sequences within each group.

**Important:** Issues are renumbered within their own prefix group. Phase groupings remain intact.

## Workflow

```
/kramme:siw:issue-reindex
    |
    v
[Find SIW files] -> Not found? -> Show error, abort
    |
    v
[Parse siw/OPEN_ISSUES_OVERVIEW.md] -> Extract all issues with statuses
    |
    v
[Identify DONE issues] -> List for deletion
    |
    v
[Identify remaining issues] -> Calculate new numbers per prefix group
    |
    v
[Confirm with user] -> Show what will happen
    |
    v
[Verify spec capture] -> Check DONE issues + LOG.md entries against specs
    |
    v
[Delete DONE issue files]
    |
    v
[Rename remaining issue files] -> Renumber within each prefix (G-003 -> G-001, P1-004 -> P1-002)
    |
    v
[Update siw/OPEN_ISSUES_OVERVIEW.md] -> New numbers, remove DONE rows
    |
    v
[Update siw/LOG.md] -> Update issue references to new numbers
    |
    v
[Report results]
```

---

## Step 1: Find and Validate SIW Files

Check for required SIW files:

```bash
ls siw/OPEN_ISSUES_OVERVIEW.md siw/issues/ 2> /dev/null
```

**If siw/OPEN_ISSUES_OVERVIEW.md doesn't exist:**

```
No siw/OPEN_ISSUES_OVERVIEW.md found. Nothing to reindex.

To initialize a new SIW workflow, run /kramme:siw:init
```

**Action:** Abort.

**If siw/issues/ directory doesn't exist or is empty:**

```
No issues found. Nothing to reindex.

To create issues, run /kramme:siw:issue-define
```

**Action:** Abort.

---

## Step 2: Parse Issues Overview

Read siw/OPEN_ISSUES_OVERVIEW.md section-by-section and extract all issues from the table.

For each section, extract:

- Section header
- Table schema (`| # | Title | Status | Size | Priority | Mode | Related |`, pre-Mode 6-column, or the legacy 5-column form)
- Any section-level metadata line immediately above the table (for example `**Parallelization:** ...`)

For each row, extract:

- Issue prefix and number (e.g., `G-001`, `P1-002`)
- Title
- Status (READY, IN PROGRESS, IN REVIEW, DONE)
- Size when present in the 6- or 7-column schema
- Priority
- Mode when present in the 7-column schema (`AUTO` or `HITL`)
- Related tasks

Categorize issues **by prefix group**:

- **DONE issues per group:** Will be deleted
- **Active issues per group:** Will be renumbered within their prefix (READY, IN PROGRESS, IN REVIEW)

**Example grouping:**

- G-001 (DONE), G-002 (READY), G-003 (READY) → Delete G-001, renumber G-002→G-001, G-003→G-002
- P1-001 (READY), P1-002 (DONE) → Delete P1-002, P1-001 stays as P1-001

---

## Step 3: Determine Scope and Confirm

### 3.1 Ask About Scope (if phase issues exist)

**If any phase issues (P1-, P2-, etc.) exist**, ask which issues to include:

Use AskUserQuestion:

```yaml
header: "Reindex Scope"
question: "Phase issues detected. Which issues should be included in the reindex?"
options:
  - label: "All issues"
    description: "Reindex both general (G-) and phase (P1-, P2-, etc.) issues"
  - label: "General issues only"
    description: "Reindex only general (G-) issues, leave phase issues unchanged"
  - label: "Cancel"
    description: "Abort the reindex"
```

**If "Cancel":** Abort.

**If "General issues only":** Filter the plan to only include G- prefixed issues. Skip all P1-, P2-, etc. issues.

**If "All issues":** Continue with the full plan.

**If no phase issues exist:** Skip this question and proceed directly to confirmation.

### 3.2 Present the Plan

Present the plan to the user (filtered by scope if applicable). No-change rows may be omitted in large workspaces to keep the summary scannable:

```
Issues Reindex Plan

DONE issues to delete (X):
- G-002: {title}
- P1-003: {title}  # Only shown if "All issues" selected
...

Active issues to renumber (by prefix group):

General (G-):
- G-003 -> G-002

# Phase sections only shown if "All issues" selected:
Phase 1 (P1-):
- P1-004 -> P1-003

Phase 2 (P2-):
- (no renames)

Proceed with reindex?
```

### 3.3 Confirm

Use AskUserQuestion:

```yaml
header: "Confirm Issues Reindex"
question: "This will delete DONE issues and renumber remaining issues. Proceed?"
options:
  - label: "Yes, reindex issues"
    description: "Delete DONE issues and renumber remaining from 001"
  - label: "No, cancel"
    description: "Keep current state"
```

---

## Step 4: Verify Spec Capture of DONE Issues

Read and follow `references/spec-capture-check.md` before deleting any DONE issue files. It defines durable-vs-transient classification, spec-update rules, stop conditions, and the spec-capture report format.

---

## Step 5: Delete DONE Issue Files

For each DONE issue id, resolve the matching file before deletion:

1. Expand the glob `siw/issues/ISSUE-{prefix}-{number}-*.md` to its concrete matches.
2. **Exactly one match:** proceed to delete.
3. **Zero matches:** apply the missing-DONE-file rule in `references/edge-cases.md` ("Missing Files") and stop for user confirmation.
4. **Multiple matches:** apply the multiple-files rule in `references/edge-cases.md` ("Missing Files") and stop to ask which file is authoritative.

Delete the single confirmed file. Prefer `trash` when available; otherwise fall back to `rm -f` on that exact path:

```bash
target="siw/issues/ISSUE-G-001-some-slug.md"   # the single resolved path
if command -v trash &> /dev/null; then
  trash "$target"
else
  rm -f "$target"
fi
```

Never pass the unexpanded glob to `trash` or `rm`.

---

## Step 6: Rename Remaining Issue Files

Define maps before renaming anything:

- `renumberById`: original active issue id → new active issue id (see `references/log-update.md` for the full definition and matching rules).
- `deletedById`: original DONE issue id → deleted issue title (same reference).

Build the complete original-to-new filename map for every active issue in scope, then verify every target filename is unique and does not collide with an existing file outside the map.

For each active issue that needs renumbering **within its prefix group**:

1. Read the issue file content.
2. Update the issue number in the file header (e.g., `# ISSUE-G-003:` -> `# ISSUE-G-002:`).
3. Rewrite any short/full issue-id references inside the file body using the `renumberById` / `deletedById` maps and the collision-safe matching rules in `references/log-update.md`.
   - This includes `**Related:**`, dependency lists such as `Blocked by` / `Blocks`, `Parallelization Guidance`, and any other prose references to issue ids.
   - If a referenced issue was deleted, keep the original id and annotate it with `(deleted: "{title}")` instead of silently pointing it at a different renumbered issue.
4. Update the `**Status:**` line if it references the issue number.
5. Preserve any existing `**Size:**` / `**Parallelization:**` / `**Mode:**` metadata while updating ids.
6. Write to the new filename.
7. Delete the old file.

**Rename order to avoid collisions:**

- Compress-down (the common case after DONE deletions, e.g., `G-002 → G-001`, `G-003 → G-002`) requires processing renames in **ascending order of the new id within each prefix group**. Processing highest-first collides because the lower target still exists.
- For any case where two active files would swap or where ascending order is not obviously safe, follow `references/edge-cases.md` ("Rename Collisions") and rename through temporary filenames so order does not matter.

**Example:**

```bash
# Compress-down within G-: G-002 -> G-001, then G-003 -> G-002
mv siw/issues/ISSUE-G-002-foo.md siw/issues/ISSUE-G-001-foo.md
mv siw/issues/ISSUE-G-003-api-design.md siw/issues/ISSUE-G-002-api-design.md
```

**Important:**

- Process each prefix group separately.
- Classify matches against the original issue-file content first; do not chain replacements.
- Do NOT merge issues between prefix groups.

---

## Step 7: Update siw/OPEN_ISSUES_OVERVIEW.md

Read and follow `references/overview-update.md` to rebuild `siw/OPEN_ISSUES_OVERVIEW.md`. It defines the section/schema preservation rules, related-column rewrites, empty-section handling, and consistency checks.

---

## Step 8: Update siw/LOG.md

Read and follow `references/log-update.md` to update issue references in `siw/LOG.md`. It defines `renumberById` / `deletedById`, the short/full id matching rules, replacement rules, and the active-issue-body rewrite rules used by Step 6.

---

## Step 9: Report Results

```
Issues Reindex Complete

Spec Capture:
- {N} items migrated
- {spec_file_1}: {n1} item(s)
- {spec_file_2}: {n2} item(s)
{Or: "All items already captured" / "Skipped by user" / "No spec file found"}

Deleted (X DONE issues):
- G-001: {title}
- P1-002: {title}

Renumbered (Y active issues):

General:
- G-002 -> G-001: {title}
- G-003 -> G-002: {title}

Phase 1:
- P1-003 -> P1-002: {title}

Updated files:
- siw/OPEN_ISSUES_OVERVIEW.md
- siw/LOG.md (N issue references updated)

Next Steps:
- Continue working on active issues
- Use /kramme:siw:issue-define to add new general issues (will start at G-00{next})
- Phase issues maintain their numbering within their group
```

**LOG.md reporting variations:**

- If LOG.md was updated: `siw/LOG.md (N issue references updated)`
- If LOG.md exists but no references found: `siw/LOG.md (no issue references)`
- If LOG.md doesn't exist: Omit from the list

---

## Edge Cases

Read and follow `references/edge-cases.md` when any edge case condition applies.
