# Phase 3: Execution

## As You Work on Each Task

### 1. Reference [YOUR_SPEC].md → Read ONLY the current task section

**Don't read the entire spec for each task.** Task sections are self-contained.

**Find and read just the current task:**

```bash
# Find the task location (replace X.Y with your task number)
grep -n "### Task X.Y\|#### Task X.Y" YOUR_SPEC.md
```

Then read from that line with `limit: 30` lines.

**What to check in the task section:**
- Task details and acceptance criteria
- Success criteria
- Requirements and constraints
- Suggested execution order

**Read the full spec only during:**
- Initial planning (Phase 1)
- Final review (Phase 4)

### 2. Track Progress and Keep Spec Current

- Check off completed items in verification checklist
- Update task descriptions if execution differs from plan
- Update spec with actual details of what was done
- **CRITICAL:** Update "Current Progress" in LOG.md after completing numbered tasks/subtasks, before ending sessions, or after resolving blockers
- Update "Last Completed" and "Next Steps" sections
- **CRITICAL:** Keep [YOUR_SPEC].md as the single source of truth

**ALWAYS:** Ask user to review completed work unless they've explicitly opted out.

### 3. Don't Reference Temporary Documents in Deliverables

- **NEVER** reference [YOUR_SPEC].md, OPEN_ISSUES_OVERVIEW.md, issues/*.md, or LOG.md in final deliverables
- **NEVER** add references like "See [YOUR_SPEC].md for details"
- **For code:** No references in comments, XML docs, JSDoc, error messages, or logs
- **For documentation:** No references in published content or final documents
- **ALWAYS** make deliverables self-contained
- **NOTE:** These temporary documents won't exist after project completion

### 4. Handle New Issues

- Create `issues/ISSUE-XXX-*.md` when blocked
- Add row to `OPEN_ISSUES_OVERVIEW.md`
- Investigate using the template structure
- Once resolved, delete issue file and remove from overview
- Document resolution as a decision in LOG.md
- Update "Current Progress" section with any blockers

### 5. Document Execution Decisions

- Add to LOG.md's Decision Log section (Execution Phase)
- Explain choices made during work
- Document why certain approaches were taken
- Note impact on final deliverable
