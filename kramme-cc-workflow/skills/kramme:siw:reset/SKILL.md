---
name: kramme:siw:reset
description: Reset SIW workflow state while preserving the spec - migrates log decisions to spec, clears issues and log
disable-model-invocation: true
user-invocable: true
---

# Reset Structured Implementation Workflow

Reset the SIW workflow state to start fresh while preserving the specification document. This command:

1. Reviews siw/LOG.md for decisions and progress that should be captured in the spec
2. Migrates relevant content to the spec file
3. Clears the issues directory and overview
4. Resets siw/LOG.md to initial state

Use this when you've completed a phase of work and want to start fresh with new issues, or when the current issues are stale and need to be replaced.

## Workflow

```
/kramme:siw:reset
    |
    v
[Find SIW files] -> Not found? -> Show error, abort
    |
    v
[Check git status of siw/] -> Dirty? -> Confirm overwrite, else abort
    |
    v
[Analyze siw/LOG.md] -> Extract decisions, completed tasks, learnings
    |
    v
[Present migration candidates] -> User selects what to migrate
    |
    v
[Confirm destructive reset] -> Abort? -> Stop before changes
    |
    v
[Update spec file] -> Add selected content
    |
    v
[Clear issues] -> Delete siw/issues/ and reset siw/OPEN_ISSUES_OVERVIEW.md
    |
    v
[Reset siw/LOG.md] -> Fresh state with reference to migration
    |
    v
[Report results] -> Summary of changes
```

---

## Step 1: Find and Validate SIW Files

Check for required SIW files:

```bash
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/issues/ 2> /dev/null
# Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
find siw -maxdepth 1 -type f \( -name "*SPEC*.md" -o -name "*SPECIFICATION*.md" -o -name "*PLAN*.md" -o -name "*DESIGN*.md" \) \
  ! -name "LOG.md" \
  ! -name "OPEN_ISSUES_OVERVIEW.md" \
  ! -name "DISCOVERY_BRIEF.md" \
  ! -name "SPEC_STRENGTHENING_PLAN.md" \
  ! -name "AUDIT_*.md" \
  ! -name "PRODUCT_AUDIT.md" \
  ! -name "SIW_*.md" \
  2> /dev/null
```

**If siw/LOG.md doesn't exist:**

```
No siw/LOG.md found. Nothing to reset.

To initialize a new SIW workflow, run /kramme:siw:init
```

**Action:** Abort.

**If no spec file found:**

```
Warning: No specification file found.

The reset will clear siw/LOG.md and siw/issues, but there's no spec to migrate content to.
```

Use AskUserQuestion to confirm proceeding without migration.

### 1.1 Check for Uncommitted SIW Changes

Step 5 deletes issue files and Step 6 overwrites siw/LOG.md, so dirty paths under `siw/` will be lost. Check before continuing:

```bash
git status --porcelain -- siw/ 2> /dev/null
```

If output is non-empty, list the dirty paths and use AskUserQuestion with options "Proceed and discard changes" / "Abort". Abort by default if the user does not pick "Proceed".

---

## Step 2: Analyze siw/LOG.md for Migration Candidates

Read `references/migration-analysis.md`, then analyze `siw/LOG.md` for decisions, completed tasks, guiding principles, and rejected alternatives that may be worth preserving in the spec.

---

## Step 3: Present Migration Candidates

Present candidates and ask which categories to migrate using `references/migration-analysis.md`. If the user selects nothing, treat that as "skip migration" and proceed to Step 4; log content will be lost on the `LOG.md` reset if the user confirms.

---

## Step 4: Confirm Destructive Reset

Before editing the spec file or running Step 5, explicitly confirm the destructive reset. This confirmation is required even when there is no content to migrate, when the working directory is not a git repository, or when Step 1.1 found no dirty SIW paths.

Summarize exactly what will be deleted or overwritten:

- `siw/issues/ISSUE-*.md` issue files
- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/LOG.md`
- any content from `siw/LOG.md` that was not selected for migration

Use AskUserQuestion:

```yaml
header: "Confirm Reset"
question: "Resetting will delete issue files and overwrite siw/OPEN_ISSUES_OVERVIEW.md and siw/LOG.md. Continue?"
options:
  - label: "Proceed with reset"
    description: "Delete issue files and reset the SIW tracking documents"
  - label: "Abort"
    description: "Keep the current SIW workflow files unchanged"
```

If "Abort", stop before editing the spec, deleting issue files, or overwriting workflow documents.

---

## Step 4.5: Update Specification File

If the user selected no migration categories in Step 3, skip this step and continue to Step 5.

For each selected migration category, update the spec file. Resolve `{date}` placeholders with today's date (`date +%Y-%m-%d`); derive `{date range}` from the earliest and latest entries in the LOG's Current Progress section.

Before appending, scan the spec for an existing heading that matches the entry you are about to add — same Decision number/title, same principle text, same rejected approach. If found, skip that entry rather than duplicating it. This keeps re-runs from accreting copies into the spec.

Use `assets/spec-migration-templates.md` for the selected migration categories.

---

## Step 5: Clear Issues

### 5.1 Delete Issue Files

```bash
issue_paths=$(find siw/issues -maxdepth 1 -type f -name 'ISSUE-*.md' 2> /dev/null)
issue_count=$(printf '%s\n' "$issue_paths" | sed '/^$/d' | wc -l)

if [ -n "$issue_paths" ]; then
  if command -v trash &> /dev/null; then
    while IFS= read -r path; do
      trash "$path"
    done << EOF
$issue_paths
EOF
  else
    echo "Warning: 'trash' command not found. Issue files will be permanently deleted."
    echo "Install with brew install trash (macOS) or your distro's trash-cli package (Linux)."
    # Ask for explicit confirmation after the permanent-deletion warning, then run:
    while IFS= read -r path; do
      rm -f "$path"
    done << EOF
$issue_paths
EOF
  fi
fi
```

Do not suppress deletion errors. Capture stderr/stdout. After deletion, verify every issue file with `[ ! -e "$path" ]`. Record only verified-absent files in `deleted_issue_paths`, and record survivors in `failed_delete_paths` with the captured error.

### 5.2 Reset siw/OPEN_ISSUES_OVERVIEW.md

Synced tracker status vocabulary: READY | IN PROGRESS | IN REVIEW | DONE.

Replace content with the empty table from `assets/reset-document-templates.md`.

---

## Step 6: Reset siw/LOG.md

Replace `siw/LOG.md` with the fresh initial state from `assets/reset-document-templates.md`.

The reset LOG template must keep these headings in this order:

## Current Progress

### Project Status

### Last Completed

### Next Steps

---

## Step 7: Report Results

Read `references/summary-and-edge-cases.md` and report results using its completion summary format.

---

## Edge Cases

Read `references/summary-and-edge-cases.md` for no-content and multiple-spec handling. Both edge cases still require Step 4 confirmation before any destructive reset action.
