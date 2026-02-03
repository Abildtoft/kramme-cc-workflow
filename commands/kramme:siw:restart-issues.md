---
name: kramme:siw:restart-issues
description: Remove all DONE issues and renumber remaining issues from 001
---

# Restart Issues

Remove all DONE issues and renumber remaining issues starting from 001. This command:
1. Identifies all issues with status DONE
2. Deletes DONE issue files
3. Renumbers remaining issues sequentially from 001
4. Updates siw/OPEN_ISSUES_OVERVIEW.md with new numbers

Use this when you want to clean up completed issues and have a fresh numbering sequence.

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
[Identify remaining issues] -> Calculate new numbers
    |
    v
[Confirm with user] -> Show what will happen
    |
    v
[Delete DONE issue files]
    |
    v
[Rename remaining issue files] -> ISSUE-XXX -> ISSUE-00Y
    |
    v
[Update siw/OPEN_ISSUES_OVERVIEW.md] -> New numbers, remove DONE rows
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
- Issue number (###)
- Title
- Status (READY, IN PROGRESS, IN REVIEW, DONE)
- Priority
- Related tasks

Categorize issues:
- **DONE issues:** Will be deleted
- **Active issues:** Will be renumbered (READY, IN PROGRESS, IN REVIEW)

---

## Step 3: Confirm with User

Present the plan to the user:

```
Issues Restart Plan

DONE issues to delete (X):
- ISSUE-002: {title}
- ISSUE-005: {title}
...

Active issues to renumber (Y):
- ISSUE-001 -> ISSUE-001 (no change)
- ISSUE-003 -> ISSUE-002
- ISSUE-004 -> ISSUE-003
- ISSUE-006 -> ISSUE-004
...

Proceed with restart?
```

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
    trash siw/issues/ISSUE-XXX-*.md
else
    rm -f siw/issues/ISSUE-XXX-*.md
fi
```

---

## Step 5: Rename Remaining Issue Files

For each active issue that needs renumbering:

1. Read the issue file content
2. Update the issue number in the file header (e.g., `# ISSUE-003:` -> `# ISSUE-002:`)
3. Update the `**Status:**` line if it references the issue number
4. Write to new filename
5. Delete old file

**Example:**
```bash
# ISSUE-003-api-design.md -> ISSUE-002-api-design.md
# Update content: "# ISSUE-003:" -> "# ISSUE-002:"
mv siw/issues/ISSUE-003-api-design.md siw/issues/ISSUE-002-api-design.md
```

**Important:** Process in reverse order (highest number first) to avoid conflicts when renaming.

---

## Step 6: Update siw/OPEN_ISSUES_OVERVIEW.md

Rebuild the issues table:

1. Remove all DONE rows
2. Update issue numbers for remaining rows
3. Keep all other columns (Title, Status, Priority, Related) unchanged

**Before:**
```markdown
| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| 001 | Feature A | DONE | High | Task 1.0 |
| 002 | Feature B | IN PROGRESS | High | Task 2.0 |
| 003 | Bug Fix | READY | Medium | Task 3.0 |
| 004 | Feature C | DONE | Low | Task 4.0 |
| 005 | Refactor | IN REVIEW | High | Task 5.0 |
```

**After:**
```markdown
| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| 001 | Feature B | IN PROGRESS | High | Task 2.0 |
| 002 | Bug Fix | READY | Medium | Task 3.0 |
| 003 | Refactor | IN REVIEW | High | Task 5.0 |
```

---

## Step 7: Report Results

```
Issues Restart Complete

Deleted (X DONE issues):
- ISSUE-002: {title}
- ISSUE-005: {title}

Renumbered (Y active issues):
- ISSUE-003 -> ISSUE-002: {title}
- ISSUE-004 -> ISSUE-003: {title}
...

Updated:
- siw/OPEN_ISSUES_OVERVIEW.md

Next Steps:
- Continue working on active issues
- Use /kramme:siw:define-issue to add new issues (will start at ISSUE-00{next})
```

---

## Edge Cases

### No DONE issues
```
No DONE issues found. Nothing to delete.

Active issues (X):
- ISSUE-001: {title}
- ISSUE-002: {title}

No renumbering needed since there are no gaps.
```
**Action:** Report and exit (no changes needed).

### All issues are DONE
```
All issues are DONE. This will clear all issues.

After restart, use /kramme:siw:define-issue to create new issues starting from ISSUE-001.
```
Use AskUserQuestion to confirm clearing all issues.

### No gaps in numbering
If DONE issues are at the end of the sequence, only deletion is needed (no renumbering):
```
DONE issues to delete:
- ISSUE-004: {title}
- ISSUE-005: {title}

Active issues (no renumbering needed):
- ISSUE-001: {title}
- ISSUE-002: {title}
- ISSUE-003: {title}
```

### Issue file missing
If an issue is in the overview but the file doesn't exist:
```
Warning: ISSUE-003 listed in overview but file not found.
Will remove from overview table.
```

### References in siw/LOG.md
After renumbering, warn about potential stale references:
```
Note: If siw/LOG.md references old issue numbers, those references are now stale.
Consider updating any ISSUE-XXX references in siw/LOG.md manually.
```
