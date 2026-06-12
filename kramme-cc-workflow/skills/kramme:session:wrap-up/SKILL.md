---
name: kramme:session:wrap-up
description: End-of-session checklist to capture progress, ensure quality, and document next steps. Writes a session summary to SESSION_NOTES.md at the repo root (creating or appending), or appends to siw/LOG.md when an SIW project exists.
argument-hint: [quick]
disable-model-invocation: true
user-invocable: true
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

Search for TODOs added during this session.

Uncommitted changes:

```bash
git diff --unified=0 | grep -E "^\+.*TODO"
```

Recent commits — prefer the session's actual start point when determinable (the merge-base with the base branch); otherwise fall back to the last 5 commits:

```bash
default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')
base=""
if [ -n "$default" ]; then
  base=$(git merge-base HEAD "$default" 2>/dev/null || true)
  [ "$base" = "$(git rev-parse HEAD)" ] && base=""  # on the base branch itself; no branch scope
fi
scope="this session"
if [ -z "$base" ]; then
  base=$(git rev-parse --verify --quiet HEAD~5 || git rev-list --max-parents=0 HEAD | head -1)
  scope="last 5 commits"
fi
git diff "$base" --unified=0 | grep -E "^\+.*TODO"
```

Report any TODOs found with file locations. When the `HEAD~5` fallback was used, label the findings "last 5 commits" (from `$scope`) instead of "this session" — the window is a proxy, not the actual session start.

### WIP Detection

Scan recent changes for explicit markers, reusing `$base` and `$scope` from TODO detection:

```bash
git diff "$base" --unified=0 | grep -E "^\+.*(WIP|FIXME|XXX)"
```

Then spot-check modified files by judgment for commented-out code blocks and empty or placeholder function bodies. Report anything found.

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

If user selects "Yes", invoke `/kramme:verify:run` and report results.

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

Build the session block, using the current date for the heading:

```markdown
## Session: [current date]

**Accomplished:** [user's summary]

**Next steps:** [user's next steps]

**Blockers:** [if any, else "None"]
```

Append it to the active context log so the summary survives the session:

- If SIW is active (`siw/LOG.md` exists), append to `siw/LOG.md`.
- Otherwise, append to `SESSION_NOTES.md` at the repository root, creating the file if it does not exist.

Remember the path written so Phase 5 can report it.

## Phase 5: Final Report

Present a summary:

```
## Session Wrap-Up Complete

### Changes Status
- Uncommitted files: N
- Untracked files: N
- Stashes: N
- TODOs found: N
- Quality checks: PASS/FAIL/SKIPPED

### Documentation
- Session notes: Saved to [path] / Not saved

### Reminders
[List any uncommitted work, failing tests, or blockers]
```

## Quick Mode

If user runs `/kramme:session:wrap-up quick`, skip the quality-check prompt (Phase 2) and run Phases 1, 3, 4, and 5 (audit, summary, context preservation, report).
