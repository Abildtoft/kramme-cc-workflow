---
name: kramme:siw:remove
description: Delete SIW workflow files from the current directory. Destructive; use kramme:siw:close first if you want to preserve documentation.
disable-model-invocation: true
user-invocable: true
---

# Remove Structured Implementation Workflow Files

Delete SIW-related files from the `siw/` folder in the current working directory. This is the destructive cleanup path for SIW workflow documents after implementation is complete.

If you want to preserve accumulated knowledge as permanent documentation, use `/kramme:siw:close` instead. If you want to start a fresh iteration on the same project, use `/kramme:siw:reset`.

## Target Files

**Temporary (always candidates for deletion):**

- `siw/LOG.md` — Session progress and decisions
- `siw/OPEN_ISSUES_OVERVIEW.md` — Issue tracking table
- `siw/AUDIT_IMPLEMENTATION_REPORT.md` — Spec compliance audit report
- `siw/AUDIT_SPEC_REPORT.md` — Spec quality audit report
- `siw/SPEC_STRENGTHENING_PLAN.md` — Refinement discovery output (this command deletes it, unlike `/kramme:siw:close`)
- `siw/DISCOVERY_BRIEF.md` — Greenfield discovery output
- `siw/issues/` — Individual issue files
- `siw/qa-intake/` — QA intake parent summaries

**Permanent (optional, requires explicit confirmation):**

- Specification files in `siw/` matching `*SPEC*.md`, `*SPECIFICATION*.md`, `*PLAN*.md`, or `*DESIGN*.md`, excluding `SPEC_STRENGTHENING_PLAN.md` and `DISCOVERY_BRIEF.md`
- `siw/supporting-specs/` — Numbered supporting specs

Only files discovered in Step 1 are deleted, listed in the confirmation prompt, or reported as deleted. Items in the lists above that do not exist on disk are ignored.

## Workflow

### Step 1: Scan for SIW Files

Discover what exists. Record two lists from the output:

- `found_temporary` — temp files and directories
- `found_permanent` — spec/permanent files plus `siw/supporting-specs/` if present

```bash
ls -d siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/AUDIT_IMPLEMENTATION_REPORT.md siw/AUDIT_SPEC_REPORT.md siw/SPEC_STRENGTHENING_PLAN.md siw/DISCOVERY_BRIEF.md siw/issues siw/qa-intake 2> /dev/null
find siw -maxdepth 1 -type f \( -name "*SPEC*.md" -o -name "*SPECIFICATION*.md" -o -name "*PLAN*.md" -o -name "*DESIGN*.md" \) \
  ! -name "SPEC_STRENGTHENING_PLAN.md" \
  ! -name "DISCOVERY_BRIEF.md" \
  2> /dev/null
ls -d siw/supporting-specs 2> /dev/null
```

**If both lists are empty:**

```
No SIW workflow files found in this directory.
```

Stop.

### Step 2: Check for Uncommitted Changes

```bash
git status --porcelain -- siw/ 2> /dev/null
```

If any output exists, warn the user before proceeding to confirmation:

```
Warning: There are uncommitted changes to SIW files:
{paths from porcelain output, one per line}

If `trash` is available, these will be recoverable from the system Trash. Otherwise they will be permanently lost.
```

If the working tree is clean or not a git repo, skip the warning. Continue to Step 3 either way.

### Step 3: Confirm Deletion

Use AskUserQuestion. Build option descriptions from the actual contents of `found_temporary` and `found_permanent` — do not list files that were not found in Step 1.

```yaml
header: "Delete SIW Files"
question: "Found {len(found_temporary)} temporary item(s){, plus {len(found_permanent)} permanent item(s) if non-empty}. Which should I delete?"
options:
  - label: "Temporary files only"
    description: "Delete: {comma-separated paths in found_temporary}. Keep permanent files."
  - label: "All SIW files"
    description: "Delete the temporary items plus: {comma-separated paths in found_permanent}."
  - label: "Abort"
    description: "Cancel and keep all files"
```

If `found_permanent` is empty, omit the "All SIW files" option.

### Step 4: Delete Files

Determine the deletion set from the user's selection:

- "Temporary files only" → `delete_set = found_temporary`
- "All SIW files" → `delete_set = found_temporary + found_permanent`

Prefer `trash` for recoverability. Use `trash -r` for directories.

```bash
# Files
trash <each file path in delete_set> 2> /dev/null
# Directories
trash -r <each directory path in delete_set> 2> /dev/null
```

**If `trash` is not installed,** warn and fall back to `rm`:

```
Warning: 'trash' command not found. Files will be permanently deleted.
Install with `brew install trash` (macOS) or your distro's `trash-cli` package (Linux).
```

```bash
rm -f <each file path in delete_set>
rm -rf <each directory path in delete_set>
```

### Step 5: Clean Up Empty `siw/`

After deletion, remove leftover `.gitkeep` placeholders and any directories that are now empty. `rmdir` only succeeds on empty directories, so it is safe to call unconditionally.

```bash
rm -f siw/.gitkeep siw/issues/.gitkeep siw/qa-intake/.gitkeep siw/supporting-specs/.gitkeep 2> /dev/null
rmdir siw/issues siw/qa-intake siw/supporting-specs siw 2> /dev/null
```

Record whether `siw/` itself was removed for the report.

### Step 6: Report Results

Report only paths that were actually in `delete_set`:

```
SIW Cleanup Complete

Deleted:
{each path in delete_set, one per line}

{If using trash: Files moved to Trash and can be restored if needed.}
{If siw/ was removed: siw/ directory removed.}
```

## Important Notes

1. **`trash` keeps deletions recoverable** — prefer it over `rm` whenever it is installed.
2. **Permanent files default to kept** — the "All SIW files" option must be explicitly selected to delete spec files and `siw/supporting-specs/`.
3. **Works with `/kramme:siw:init`** — the workflow can be re-initialized after cleanup.
