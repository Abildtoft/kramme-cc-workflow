# Phase 0: Starting or Resuming Work

**This is where AI agents should ALWAYS begin.**

## If Files Don't Exist Yet

You're starting fresh. Proceed directly to **Phase 1** (read `phase-1-planning.md`).

## If Files Already Exist

You're resuming work. Follow this reading order:

### 1. siw/LOG.md → Read ONLY "Current Progress" (first ~50 lines)

**Don't read the entire siw/LOG.md.** The Current Progress section is designed to be self-contained and sufficient for resuming.

**Use targeted reading:**
- Read tool with `limit: 50` (Current Progress is always at the top)
- The section contains everything you need: status, last completed, next steps

**Only read Decision Log when:**
- The current task explicitly references a decision (e.g., "per Decision #5")
- You're making a related decision and want to check precedent
- Use Grep to find specific decisions: `grep -n "Decision.*keyword" siw/LOG.md`

**What's in Current Progress:**
- **Project Status**: Status, current phase, overall progress
- **Last Completed**: Task name, what was done, files modified
- **Next Steps**: Immediate task, subsequent tasks, any blockers

### 2. siw/OPEN_ISSUES_OVERVIEW.md → Read overview only

**Don't read individual issue files yet.** The overview table shows all active issues at a glance.

- READY (not started)
- IN PROGRESS (being worked on)
- IN REVIEW (awaiting review/approval)
- DONE (completed)

**Only read individual issue files** (`siw/issues/ISSUE-{prefix}-XXX-*.md`) when you're about to work on that specific issue.

### 3. siw/[YOUR_SPEC].md → Read ONLY the relevant task section

**Don't read the entire spec.** Find and read just the task mentioned in "Next Steps":

```bash
# Find the task location (replace X.Y with task number from Next Steps)
grep -n "### Task X.Y\|#### Task X.Y" siw/YOUR_SPEC.md
```

Then read from that line with `limit: 30` lines. Task sections are self-contained.

**What to look for in the task section:**
- Task details and acceptance criteria
- Verification checklist
- Prerequisites and dependencies

### 3.5. Check for Supporting Specs (if folder exists)

```bash
ls siw/supporting-specs/ 2>/dev/null
```

**If supporting specs exist:**
- Check if the current task references a supporting spec (e.g., "See `siw/supporting-specs/02-api-specification.md`")
- Read only the relevant section of the referenced supporting spec:
  ```bash
  grep -n "## Section Name" siw/supporting-specs/02-api-specification.md
  ```
- Read from that line with `limit: 50`

**Don't read all supporting specs** - only read the one referenced by your current task.

### 4. Determine Your Phase

| State | Next Phase |
|-------|------------|
| Has blockers in siw/OPEN_ISSUES_OVERVIEW.md | Phase 2 (Investigation) - read `phase-2-investigation.md` |
| No blockers, tasks remain | Phase 3 (Execution) - read `phase-3-execution.md` |
| All tasks complete | Phase 4 (Review) - read `phase-4-completion.md` |

## Session Guidelines

**Session** = Continuous work period by one AI agent.

**Before ending your session:**
- **ALWAYS** update "Current Progress" in siw/LOG.md
- Update "Last Completed" with what you accomplished
- Update "Next Steps" with immediate next task and any blockers
