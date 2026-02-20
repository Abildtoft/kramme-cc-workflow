# Phase 3: Execution

## As You Work on Each Task

### 1. Reference siw/[YOUR_SPEC].md → Read ONLY the current task section

**Don't read the entire spec for each task.** Task sections are self-contained.

**Find and read just the current task:**

```bash
# Find the task location (replace X.Y with your task number)
grep -n "### Task X.Y\|#### Task X.Y" siw/YOUR_SPEC.md
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

### 1.5. Check Supporting Specs (if referenced)

If the task references a supporting spec (e.g., "See `siw/supporting-specs/02-api-specification.md#endpoints`"):

1. **Find the section** in the supporting spec:
   ```bash
   grep -n "## Endpoints\|### Endpoints" siw/supporting-specs/02-api-specification.md
   ```

2. **Read just that section** with `limit: 50` lines

3. **Use supporting specs for**:
   - Detailed data model definitions
   - API endpoint contracts
   - UI component specifications
   - User story acceptance criteria

**Supporting specs are permanent** - they can be referenced in tasks and documentation.

### 2. Track Progress and Keep Spec Current

- Check off completed items in verification checklist
- Update task descriptions if execution differs from plan
- Update spec with actual details of what was done
- **CRITICAL:** Update "Current Progress" in siw/LOG.md after completing numbered tasks/subtasks, before ending sessions, or after resolving blockers
- Update "Last Completed" and "Next Steps" sections
- **CRITICAL:** Keep siw/[YOUR_SPEC].md as the single source of truth

**ALWAYS:** Ask user to review completed work unless they've explicitly opted out.

### 3. Don't Reference Temporary Documents in Deliverables

**NEVER reference these temporary documents in final deliverables:**
- siw/OPEN_ISSUES_OVERVIEW.md
- siw/issues/*.md
- siw/LOG.md

**CAN reference these permanent documents:**
- siw/[YOUR_SPEC].md (main spec)
- siw/supporting-specs/*.md (supporting specifications)

**For code:** No references to temporary docs in comments, XML docs, JSDoc, error messages, or logs
**For documentation:** No references to temporary docs in published content

**NOTE:** Temporary documents (LOG.md, issues/) are deleted after project completion; permanent documents (spec, supporting-specs) are kept.

### 4. Handle New Issues

- Create `siw/issues/ISSUE-{prefix}-XXX-*.md` when blocked
- Add row to `siw/OPEN_ISSUES_OVERVIEW.md`
  - If you added a non-DONE issue to a phase section currently marked ` (DONE)`, ask the user whether to remove the marker
- Investigate using the template structure
- Once resolved, document the resolution in the issue file's `## Resolution` section, set status to `IN REVIEW` or `DONE` based on confidence, and update the overview row
  - If this was a phase issue (`P1-*`, `P2-*`, etc.) and it was the last open issue in that phase, ask the user whether to mark the phase as DONE by appending ` (DONE)` to the phase section header
- Document resolution as a decision in siw/LOG.md
- Update "Current Progress" section with any blockers

### 5. Document Execution Decisions

- Add to siw/LOG.md's Decision Log section (Execution Phase)
- Explain choices made during work
- Document why certain approaches were taken
- Note impact on final deliverable
- Use standard categories: Architecture | Data Model | API | UI/UX | Testing | Performance | Security | Infrastructure
