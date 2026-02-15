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
[Analyze siw/LOG.md] -> Extract decisions, completed tasks, learnings
    |
    v
[Present migration candidates] -> User selects what to migrate
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
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/issues/ 2>/dev/null
ls siw/*SPEC*.md siw/*SPECIFICATION*.md siw/*PLAN*.md siw/*DESIGN*.md 2>/dev/null
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
  - label: "Skip migration"
    description: "Reset without migrating any content (content will be lost)"
```

---

## Step 4: Update Specification File

For each selected migration category, update the spec file:

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

| Approach | Purpose | Why Rejected |
|----------|---------|--------------|
| {approach 1} | {purpose} | {reason} |
```

---

## Step 5: Clear Issues

### 5.1 Delete Issue Files

```bash
# Count issues first for reporting
issue_count=$(ls siw/issues/ISSUE-*.md 2>/dev/null | wc -l)

# Delete using trash if available
if command -v trash &> /dev/null; then
    trash siw/issues/ISSUE-*.md 2>/dev/null
else
    rm -f siw/issues/ISSUE-*.md
fi
```

### 5.2 Reset siw/OPEN_ISSUES_OVERVIEW.md

Replace content with empty table:

```markdown
# Open Issues Overview

## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| _None_ | _Use `/kramme:siw:define-issue` to create first issue (G-001)_ | | | |

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

**Last Updated:** {current date}
**Quick Summary:** Workflow reset. Ready for new issues.

### Project Status

- **Status:** Planning | **Current Phase:** Reset | **Overall Progress:** Fresh start

### Last Completed

- Workflow reset on {date}
- {If migration happened: "Migrated X decisions, X tasks to spec"}

### Next Steps

1. Define new issues with `/kramme:siw:define-issue`
2. Begin implementation with `/kramme:siw:implement-issue`
3. **Blockers:** None

---

## Decision Log

_Previous decisions migrated to {spec_filename}. New decisions will be documented here._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| _None yet_ | | | |

---

## Guiding Principles

{If migrated: "See {spec_filename} for established principles."}
{If not migrated: "1. {To be defined during implementation}"}

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
- {issue_count} issue files deleted
- siw/OPEN_ISSUES_OVERVIEW.md reset to empty
- siw/LOG.md reset to initial state

Preserved:
- {spec_filename} (with migrated content)

Next Steps:
- Run /kramme:siw:define-issue to create new issues
- Previous decisions are preserved in the spec for reference
```

---

## Important Notes

1. **Always offer migration** - Don't lose valuable decisions without user consent
2. **Preserve the spec** - The spec is permanent; add to it, don't replace it
3. **Clear indication of reset** - siw/LOG.md should show when reset happened
4. **Idempotent** - Running reset multiple times is safe (nothing to migrate if already reset)

## Edge Cases

### No content to migrate
If siw/LOG.md is empty or minimal:
```
siw/LOG.md has no significant content to migrate.
Proceeding with reset...
```

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

### Uncommitted changes to workflow files
```
Warning: There are uncommitted changes to SIW workflow files.
These changes will be lost after reset.
```
Use AskUserQuestion to confirm.
