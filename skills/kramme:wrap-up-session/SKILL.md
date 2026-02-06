---
name: kramme:wrap-up-session
description: End-of-session checklist to capture progress, ensure quality, and document next steps
disable-model-invocation: true
---

# Wrap Up Session

A structured end-of-session ritual that ensures nothing is forgotten and captures context for future sessions.

## Phase 1: Changes Audit

### Git Status

Run `git status` and report:
- **Uncommitted changes**: List modified/staged files
- **Untracked files**: List new files not yet added
- **Stash**: Check `git stash list` for forgotten stashes

### TODO Detection

Search for TODOs added during this session:
```bash
git diff HEAD~5 --unified=0 | grep -E "^\+.*TODO"
```

If uncommitted changes exist:
```bash
git diff --unified=0 | grep -E "^\+.*TODO"
```

Report any TODOs found with file locations.

### WIP Detection

Flag potential incomplete work:
- Files with "WIP", "FIXME", or "XXX" in recent changes
- Commented-out code blocks in modified files
- Empty function bodies or placeholder implementations

## Phase 2: Quality Check

If there are uncommitted changes, offer to run quality checks:

```yaml
question: "Run quality checks on uncommitted changes?"
options:
  - label: "Yes, run checks"
    description: "Run lint, typecheck, and tests on affected code"
  - label: "Skip"
    description: "Skip quality checks"
```

If user selects "Yes", invoke `/kramme:verify` and report results.

## Phase 3: Session Summary

Prompt the user for session documentation:

### Accomplishments

```yaml
question: "What was accomplished this session?"
freeform: true
placeholder: "Brief summary of completed work..."
```

### Next Steps

```yaml
question: "What are the logical next steps?"
freeform: true
placeholder: "What should be done next session..."
```

### Blockers (Optional)

```yaml
question: "Any blockers or open questions?"
freeform: true
placeholder: "Leave empty if none..."
optional: true
```

## Phase 4: Context Preservation

If SIW is active (`siw/LOG.md` exists), update it with:

```markdown
## Session: [date]

**Accomplished:** [user's summary]

**Next steps:** [user's next steps]

**Blockers:** [if any]
```

If no SIW is active, skip this phase.

## Phase 5: Optional Learning Extraction

If corrections were made during the session:

```yaml
question: "Extract learnings from this session?"
options:
  - label: "Yes, run /kramme:extract-learnings"
    description: "Review and save non-obvious discoveries to AGENTS.md"
  - label: "No, skip"
```

If selected, invoke `/kramme:extract-learnings`.

## Phase 6: Final Report

Present a summary:

```
## Session Wrap-Up Complete

### Changes Status
- Uncommitted files: N
- Untracked files: N
- TODOs found: N
- Quality checks: PASS/FAIL/SKIPPED

### Documentation
- Session notes: Saved to [location] / Not saved
- Learnings: Extracted / Skipped

### Reminders
[List any uncommitted work, failing tests, or blockers]
```

## Quick Mode

If user runs `/kramme:wrap-up-session quick`:
- Skip quality checks
- Skip learning extraction
- Only run Phases 1, 3, and 6 (audit, summary, report)
