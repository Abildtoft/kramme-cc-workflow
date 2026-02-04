---
name: kramme:siw:restart-issues
description: Remove all DONE issues and renumber remaining issues within each prefix group
---

# Restart Issues

Remove all DONE issues and renumber remaining issues **within each prefix group**. This command:
1. Identifies all issues with status DONE
2. Deletes DONE issue files
3. Renumbers remaining issues sequentially **within each prefix group** (G-, P1-, P2-, etc.)
4. Updates siw/OPEN_ISSUES_OVERVIEW.md with new numbers
5. Updates siw/LOG.md issue references to match new numbers

Use this when you want to clean up completed issues and have fresh numbering sequences within each group.

**Important:** Issues are renumbered within their own prefix group. Phase groupings remain intact.

## Workflow

```
/kramme:siw:restart-issues
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
ls siw/OPEN_ISSUES_OVERVIEW.md siw/issues/ 2>/dev/null
```

**If siw/OPEN_ISSUES_OVERVIEW.md doesn't exist:**
```
No siw/OPEN_ISSUES_OVERVIEW.md found. Nothing to restart.

To initialize a new SIW workflow, run /kramme:siw:init
```
**Action:** Abort.

**If siw/issues/ directory doesn't exist or is empty:**
```
No issues found. Nothing to restart.

To create issues, run /kramme:siw:define-issue
```
**Action:** Abort.

---

## Step 2: Parse Issues Overview

Read siw/OPEN_ISSUES_OVERVIEW.md and extract all issues from the table:

For each row, extract:
- Issue prefix and number (e.g., `G-001`, `P1-002`)
- Title
- Status (READY, IN PROGRESS, IN REVIEW, DONE)
- Priority
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
header: "Restart Scope"
question: "Phase issues detected. Which issues should be included in the restart?"
options:
  - label: "All issues"
    description: "Reset both general (G-) and phase (P1-, P2-, etc.) issues"
  - label: "General issues only"
    description: "Reset only general (G-) issues, leave phase issues unchanged"
  - label: "Cancel"
    description: "Abort the restart"
```

**If "Cancel":** Abort.

**If "General issues only":** Filter the plan to only include G- prefixed issues. Skip all P1-, P2-, etc. issues.

**If "All issues":** Continue with the full plan.

**If no phase issues exist:** Skip this question and proceed directly to confirmation.

### 3.2 Present the Plan

Present the plan to the user (filtered by scope if applicable):

```
Issues Restart Plan

DONE issues to delete (X):
- G-002: {title}
- P1-003: {title}  # Only shown if "All issues" selected
...

Active issues to renumber (by prefix group):

General (G-):
- G-001 -> G-001 (no change)
- G-003 -> G-002

# Phase sections only shown if "All issues" selected:
Phase 1 (P1-):
- P1-001 -> P1-001 (no change)
- P1-002 -> P1-002 (no change)
- P1-004 -> P1-003

Phase 2 (P2-):
- P2-001 -> P2-001 (no change)

Proceed with restart?
```

### 3.3 Confirm

Use AskUserQuestion:

```yaml
header: "Confirm Issues Restart"
question: "This will delete DONE issues and renumber remaining issues. Proceed?"
options:
  - label: "Yes, restart issues"
    description: "Delete DONE issues and renumber remaining from 001"
  - label: "No, cancel"
    description: "Keep current state"
```

---

## Step 4: Delete DONE Issue Files

For each DONE issue:

```bash
# Delete using trash if available
if command -v trash &> /dev/null; then
    trash siw/issues/ISSUE-{prefix}-{number}-*.md
else
    rm -f siw/issues/ISSUE-{prefix}-{number}-*.md
fi
```

---

## Step 5: Rename Remaining Issue Files

For each active issue that needs renumbering **within its prefix group**:

1. Read the issue file content
2. Update the issue number in the file header (e.g., `# ISSUE-G-003:` -> `# ISSUE-G-002:`)
3. Update the `**Status:**` line if it references the issue number
4. Write to new filename
5. Delete old file

**Example:**
```bash
# ISSUE-G-003-api-design.md -> ISSUE-G-002-api-design.md
# Update content: "# ISSUE-G-003:" -> "# ISSUE-G-002:"
mv siw/issues/ISSUE-G-003-api-design.md siw/issues/ISSUE-G-002-api-design.md
```

**Important:**
- Process each prefix group separately
- Process in reverse order within each group (highest number first) to avoid conflicts when renaming
- Do NOT merge issues between prefix groups

---

## Step 6: Update siw/OPEN_ISSUES_OVERVIEW.md

Rebuild the issues table **maintaining section groupings**:

1. Remove all DONE rows from each section
2. Update issue numbers for remaining rows within each prefix group
3. Keep all other columns (Title, Status, Priority, Related) unchanged
4. Preserve section headers (General, Phase 1, Phase 2, etc.) exactly as written (including any ` (DONE)` marker on phase headers)

**Before:**
```markdown
## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| G-001 | Setup | DONE | High | |
| G-002 | Docs | READY | Low | |
| G-003 | Config | READY | Medium | |

## Phase 1: Foundation

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P1-001 | Feature A | IN PROGRESS | High | Task 1.0 |
| P1-002 | Feature B | DONE | High | Task 2.0 |
| P1-003 | Bug Fix | READY | Medium | Task 3.0 |
```

**After:**
```markdown
## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| G-001 | Docs | READY | Low | |
| G-002 | Config | READY | Medium | |

## Phase 1: Foundation

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P1-001 | Feature A | IN PROGRESS | High | Task 1.0 |
| P1-002 | Bug Fix | READY | Medium | Task 3.0 |
```

---

## Step 7: Update siw/LOG.md

If `siw/LOG.md` exists, update issue number references to match the new numbering.

**Process:**

1. **Read siw/LOG.md content** - Skip this step if file doesn't exist

2. **Use the issue number mapping** from Step 5:
   - Map old numbers to new numbers within each prefix group (e.g., `G-003` → `G-002`, `P1-004` → `P1-002`)

3. **Update issue references:**
   - Patterns to match (both forms):
     - Short form: `{prefix}-(\d{3})` (e.g., `G-002`, `P1-003`)
     - Full form: `ISSUE-{prefix}-(\d{3})` (e.g., `ISSUE-G-002`, `ISSUE-P1-003`)
   - Where prefix is `G`, `P1`, `P2`, etc.
   - For renumbered issues: Replace with new number, preserving the form used
   - For deleted (DONE) issue references: Leave unchanged - they're valid historical references

4. **Write updated LOG.md**

**Example mapping:**
```
Renumber mapping:
- G-002 -> G-001
- G-003 -> G-002
- P1-003 -> P1-002

Deleted (no replacement):
- G-001
- P1-002
```

**Example LOG.md updates:**
```markdown
# Before:
- **Task:** G-002 - Feature B
- **Task:** P1-003 - Bug Fix
- **Impact:** Updated ISSUE-G-003 validation

# After:
- **Task:** G-001 - Feature B
- **Task:** P1-002 - Bug Fix
- **Impact:** Updated ISSUE-G-002 validation
```

**Important:**
- Do NOT change Decision numbers (#1, #2, etc.) - these are permanent
- Do NOT change references to deleted (DONE) issues - they're historical and valid

---

## Step 8: Report Results

```
Issues Restart Complete

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
- Use /kramme:siw:define-issue to add new general issues (will start at G-00{next})
- Phase issues maintain their numbering within their group
```

**LOG.md reporting variations:**
- If LOG.md was updated: `siw/LOG.md (N issue references updated)`
- If LOG.md exists but no references found: `siw/LOG.md (no issue references)`
- If LOG.md doesn't exist: Omit from the list

---

## Edge Cases

### No DONE issues
```
No DONE issues found. Nothing to delete.

Active issues:
- G-001: {title}
- G-002: {title}
- P1-001: {title}

No renumbering needed since there are no gaps in any group.
```
**Action:** Report and exit (no changes needed).

### All issues are DONE
```
All issues are DONE. This will clear all issues.

After restart, use /kramme:siw:define-issue to create new issues starting from G-001.
```
Use AskUserQuestion to confirm clearing all issues.

### No gaps in numbering
If DONE issues are at the end of each sequence, only deletion is needed (no renumbering):
```
DONE issues to delete:
- G-003: {title}
- P1-004: {title}

Active issues (no renumbering needed):
- G-001: {title}
- G-002: {title}
- P1-001: {title}
- P1-002: {title}
- P1-003: {title}
```

### Issue file missing
If an issue is in the overview but the file doesn't exist:
```
Warning: G-002 listed in overview but file not found.
Will remove from overview table.
```

### LOG.md not found
If siw/LOG.md doesn't exist, skip the update step silently. Do not report an error.

### No issue references in LOG.md
If LOG.md exists but contains no issue reference patterns:
```
siw/LOG.md: No issue references found
```

### Mixed prefix groups
Each prefix group is handled independently. Issues never move between groups:
```
G-001 (DONE), G-002 (READY), G-003 (READY)  →  G-001, G-002 (renumbered within G-)
P1-001 (READY), P1-002 (DONE), P1-003 (READY)  →  P1-001, P1-002 (renumbered within P1-)
```

### References to deleted issues in LOG.md
Leave references to DONE (deleted) issues unchanged - they are valid historical references to completed work. Only update references to issues that were renumbered.

### General issues only (scope selection)
When user selects "General issues only":
- Only process G- prefixed issues
- Leave all P1-, P2-, etc. issues completely unchanged
- LOG.md updates only apply to G- references
- Report shows only general issues in results

```
Issues Restart Complete (General Issues Only)

Deleted (X DONE general issues):
- G-001: {title}

Renumbered (Y active general issues):
- G-002 -> G-001: {title}
- G-003 -> G-002: {title}

Unchanged (phase issues not included):
- P1-001, P1-002, P1-003
- P2-001, P2-002

Updated files:
- siw/OPEN_ISSUES_OVERVIEW.md (general section only)
- siw/LOG.md (N general issue references updated)
```
