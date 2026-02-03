---
name: kramme:siw:remove
description: Remove all Structured Implementation Workflow (SIW) files from current directory
---

# Remove Structured Implementation Workflow Files

Delete all SIW-related files from the `siw/` folder in the current working directory. This command cleans up the temporary workflow documents after implementation is complete.

## Target Files

**Temporary files (always deleted):**
- `siw/LOG.md` - Session progress and decisions
- `siw/OPEN_ISSUES_OVERVIEW.md` - Issue tracking table
- `siw/issues/` - Directory containing individual issue files

**Permanent files (optional, requires confirmation):**
- Specification files in `siw/` (`siw/*SPEC*.md`, `siw/*SPECIFICATION*.md`, `siw/*PLAN*.md`, `siw/*DESIGN*.md`)

## Workflow

### Step 1: Scan for SIW Files

Check which SIW files exist:

```bash
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/issues/ 2>/dev/null
ls siw/*SPEC*.md siw/*SPECIFICATION*.md siw/*PLAN*.md siw/*DESIGN*.md 2>/dev/null
```

**If no SIW files found:**
```
No SIW workflow files found in this directory.

Expected files:
- siw/LOG.md
- siw/OPEN_ISSUES_OVERVIEW.md
- siw/issues/ directory
- Specification files in siw/ (e.g., siw/FEATURE_SPECIFICATION.md)
```
**Action:** Stop.

### Step 2: Present Found Files

List what will be deleted:

```
SIW Workflow Files Found:

Temporary (will be deleted):
- siw/LOG.md
- siw/OPEN_ISSUES_OVERVIEW.md
- siw/issues/ ({count} issue files)

Permanent (optional):
- siw/{spec_filename}
```

### Step 3: Confirm Deletion

Use AskUserQuestion:

```yaml
header: "Delete SIW Files"
question: "Which files should I delete?"
options:
  - label: "Temporary files only"
    description: "Delete siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, and siw/issues/ directory. Keep spec file."
  - label: "All SIW files"
    description: "Delete everything including the specification file"
  - label: "Abort"
    description: "Cancel and keep all files"
```

### Step 4: Delete Files

Use `trash` command to move files to system Trash (recoverable):

```bash
# Temporary files
trash siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md 2>/dev/null
trash -r siw/issues/ 2>/dev/null

# If "All SIW files" selected
trash siw/{spec_filename} 2>/dev/null
```

**If `trash` is not available**, fall back to `rm` with warning:

```
Warning: 'trash' command not found. Files will be permanently deleted.
Consider installing: brew install trash
```

```bash
rm -f siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md
rm -rf siw/issues/
# If all files: rm -f siw/{spec_filename}
```

### Step 5: Report Results

```
SIW Cleanup Complete

Deleted:
- siw/LOG.md
- siw/OPEN_ISSUES_OVERVIEW.md
- siw/issues/ ({count} files)
{- siw/{spec_filename} (if selected)}

{If using trash: Files moved to Trash and can be restored if needed.}
```

## Important Notes

1. **Use `trash` when available** - Allows recovery from system Trash
2. **Spec files are permanent** - Default is to keep them; only delete with explicit confirmation
3. **Check for uncommitted changes** - If any deleted files had uncommitted changes, warn the user
4. **Works with `/kramme:siw:init`** - Can re-initialize workflow after cleanup
