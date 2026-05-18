# Issue Closeout (Step 11 detail)

Use this when `SKILL.md` reaches Step 11 after verification passes and implementation is complete.

## 11.1 Document Resolution in Issue File

Add a `## Resolution` section to the issue file with:

```markdown
## Resolution

**Date:** {date}

### Summary

{One paragraph describing what was done to resolve the issue}

### Changes Made

- {file 1} - {what changed}
- {file 2} - {what changed}

### Key Decisions

- {any decisions made during implementation, if applicable}
```

**IMPORTANT:** Do NOT delete the issue file. The issue file is preserved as a record of the work.

## 11.2 Determine Confidence and Set Status

Use AskUserQuestion:

```yaml
header: "Issue Resolution Confidence"
question: "How confident are you that this solution is correct and complete?"
options:
  - label: "Confident — mark as DONE"
    description: "Solution is verified and complete. No further review needed."
  - label: "Needs review — mark as IN REVIEW"
    description: "Solution works but would benefit from human review before considering it done."
```

**If "Confident":** Set status to `DONE`. **If "Needs review":** Set status to `IN REVIEW`.

## 11.3 Update All Tracking Files

**CRITICAL:** Run the Status Update Procedure with the chosen status (`DONE` or `IN REVIEW`). All three files:

- [ ] **Issue file** — Set `**Status:**` to the chosen status
- [ ] **Overview** (`siw/OPEN_ISSUES_OVERVIEW.md`) — Update the issue row to match
- [ ] **Log** (`siw/LOG.md`) — Move the issue into "Last Completed", set "Next Steps" to the next READY issue

Do NOT proceed to 11.4 until all three files are updated.

## 11.4 If This Was the Last Open Issue in a Phase, Confirm Phase Completion

Only applies to phase-prefixed issues (`P1-*`, `P2-*`, etc.). Skip for `G-*`.

1. Determine the phase number from the prefix (`P1` → Phase 1, `P2` → Phase 2, etc.)
2. In `siw/OPEN_ISSUES_OVERVIEW.md`, find that phase section and check whether any issues in that section are still **not** `DONE` (READY / IN PROGRESS / IN REVIEW).

**If no open issues remain in that phase:** Ask the user:

```yaml
header: "Mark Phase Complete?"
question: "All issues in Phase {N} are now DONE. Should I mark the entire phase as DONE?"
options:
  - label: "Yes, mark Phase {N} as DONE"
    description: "Update the Phase {N} section header in OPEN_ISSUES_OVERVIEW.md"
  - label: "No, leave phase unmarked"
    description: "Keep the current phase header as-is"
```

**If user selects "Yes":**

- Update the phase section header in `siw/OPEN_ISSUES_OVERVIEW.md` by appending ` (DONE)` (e.g., `## Phase 2: Core Features (DONE)`)
- Do not double-append if it is already marked

## 11.5 Post-Phase LOG.md Update (only if phase marked DONE in 11.4)

If a phase was marked DONE in 11.4, update `siw/LOG.md` to note the phase completion in the summary/last-completed entry.
