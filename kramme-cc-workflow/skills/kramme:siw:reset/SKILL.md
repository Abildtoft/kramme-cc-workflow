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

Read siw/LOG.md and extract content that may be worth preserving in the spec:

### 2.1 Extract Decision Log Entries

Look for the `## Decision Log` section and extract all decisions:

- Decision number and title
- Problem statement
- Decision made
- Rationale
- Impact/files affected

### 2.2 Extract Completed Tasks

From `## Current Progress` section:

- Tasks marked as completed
- Implementation details worth preserving
- Any notes about how things were implemented

### 2.3 Extract Guiding Principles

If `## Guiding Principles` section exists:

- Principles that emerged during implementation
- Constraints discovered

### 2.4 Extract Rejected Alternatives

From `## Rejected Alternatives Summary`:

- Important alternatives that were considered
- Reasons for rejection (valuable for future reference)

---

## Step 3: Present Migration Candidates

If any content was found, present it to the user:

```
siw/LOG.md Analysis Complete

Found the following content that could be migrated to the spec:

Decisions (X found):
- Decision #1: {title} - {brief summary}
- Decision #2: {title} - {brief summary}
...

Completed Tasks (X found):
- Task 1.1: {title}
- Task 1.2: {title}
...

Guiding Principles (X found):
- {principle 1}
- {principle 2}
...

Rejected Alternatives (X found):
- {alternative 1} for {purpose}
...
```

Use AskUserQuestion:

```yaml
header: "Migrate Content to Spec"
question: "Which content should be migrated to the specification file before resetting?"
multiSelect: true
options:
  - label: "All decisions"
    description: "Add all Decision Log entries to spec's Design Decisions section"
  - label: "Completed tasks summary"
    description: "Add summary of completed work to spec"
  - label: "Guiding principles"
    description: "Add discovered principles to spec"
  - label: "Rejected alternatives"
    description: "Add rejected alternatives for future reference"
```

If the user selects nothing, treat that as "skip migration" and proceed to Step 4 — log content will be lost on the LOG.md reset if the user confirms.

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

### 4.1 Migrate Decisions

Add to or create `## Design Decisions` section in spec:

```markdown
## Design Decisions

### Decision #1: {title}

**Date:** {date} | **Category:** {category}

**Problem:** {problem}

**Decision:** {decision}

**Rationale:** {rationale}

**Alternatives Rejected:** {alternatives}
```

### 4.2 Migrate Completed Tasks Summary

Add to `## Implementation Notes` or `## Completed Work` section:

```markdown
## Implementation Notes

### Completed ({date range})

- {task 1}: {brief description of what was done}
- {task 2}: {brief description}
```

### 4.3 Migrate Guiding Principles

Add to `## Guiding Principles` or `## Constraints` section:

```markdown
## Guiding Principles

1. {principle 1}
2. {principle 2}
```

### 4.4 Migrate Rejected Alternatives

Add to `## Design Decisions` or `## Rejected Approaches` section:

```markdown
## Rejected Approaches

| Approach     | Purpose   | Why Rejected |
| ------------ | --------- | ------------ |
| {approach 1} | {purpose} | {reason}     |
```

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

Replace content with empty table:

```markdown
# Open Issues Overview

## General

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Mode | Related |
| --- | --- | --- | --- | --- | --- | --- |
| _None_ | _Use `/kramme:siw:issue-define` to create first issue (G-001)_ |  |  |  |  |  |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

---

## Step 6: Reset siw/LOG.md

Replace siw/LOG.md with fresh initial state:

```markdown
# LOG.md

## Current Progress

**Last Updated:** {current date} **Quick Summary:** Workflow reset. Ready for new issues.

### Project Status

- **Status:** Planning | **Current Phase:** Reset | **Overall Progress:** Fresh start

### Last Completed

- Workflow reset on {date}
- {If migration happened: "Migrated X decisions, X tasks to spec"}

### Next Steps

1. Define new issues with `/kramme:siw:issue-define`
2. Begin implementation with `/kramme:siw:issue-implement`
3. **Blockers:** None

---

## Decision Log

_Previous decisions migrated to {spec_filename}. New decisions will be documented here._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
| ----------- | --- | ------------ | ---------- |
| _None yet_  |     |              |            |

---

## Guiding Principles

{If migrated: "See {spec_filename} for established principles."} {If not migrated: "1. {To be defined during implementation}"}

## References

- Spec: `{spec_filename}`
- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
```

---

## Step 7: Report Results

```
SIW Workflow Reset Complete

Migrated to {spec_filename}:
{- X decisions}
{- X completed tasks}
{- X guiding principles}
{- X rejected alternatives}
{Or: "No content migrated"}

Cleared:
- {count(deleted_issue_paths)} issue files deleted
- siw/OPEN_ISSUES_OVERVIEW.md reset to empty
- siw/LOG.md reset to initial state
{If any failed_delete_paths: "- Failed to delete: {each failed path with error}"}

Preserved:
- {spec_filename} (with migrated content)

Next Steps:
- Run /kramme:siw:issue-define to create new issues
- Previous decisions are preserved in the spec for reference
```

---

## Edge Cases

### No content to migrate

If siw/LOG.md is empty or minimal:

```
siw/LOG.md has no significant content to migrate.
Confirming reset before deleting or overwriting workflow files...
```

Then run Step 4 before Step 5. Do not proceed directly to deletion from this edge case.

### Multiple spec files

If multiple spec files found:

```yaml
header: "Multiple Spec Files Found"
question: "Which specification file should receive the migrated content?"
options:
  - label: "{spec_file_1}"
  - label: "{spec_file_2}"
  - label: "Don't migrate (reset only)"
```
