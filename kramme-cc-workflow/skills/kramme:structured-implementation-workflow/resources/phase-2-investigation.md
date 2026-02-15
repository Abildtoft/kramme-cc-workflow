# Phase 2: Investigation & Discovery

**Goal:** Document issue → Investigate → Make decision → Record in siw/LOG.md → Update siw/[YOUR_SPEC].md → Close issue (mark DONE)

## When You Encounter Blockers or Need to Make Decisions

### 1. Create Issue File

If no issues exist yet, read `templates/issues-template.md` for templates.

**If this is the first issue:**
1. Create `siw/issues/` directory
2. Create `siw/OPEN_ISSUES_OVERVIEW.md` (see template)
3. Create `siw/issues/ISSUE-G-001-short-title.md`

**If issues already exist:**
1. Determine prefix (`G`, `P1`, `P2`, etc.)
2. Find next issue number from `siw/OPEN_ISSUES_OVERVIEW.md` within that prefix group
3. Create `siw/issues/ISSUE-{prefix}-XXX-short-title.md`
4. Add row to `siw/OPEN_ISSUES_OVERVIEW.md` table
5. If you added a non-DONE issue to a phase section currently marked ` (DONE)`, ask the user whether to remove the marker

**In the issue file:**
- Mark as IN PROGRESS while actively working on it
- Document problem statement and context
- List options being considered with pros/cons
- Note questions requiring answers

### 2. Investigate and Research

- Search existing work for relevant patterns
- Review existing implementations
- Consider alternatives and trade-offs
- Update the issue with findings
- Mark as IN REVIEW if decision requires team input or approval; otherwise proceed to step 3

**When checking past decisions (don't read entire siw/LOG.md):**

```bash
# Find decisions related to your topic
grep -n "Decision.*EntityName\|Decision.*pattern" siw/LOG.md
```

Then read only that specific decision section (~10 lines per decision) using Read with `offset` at the line number found.

### 3. Make Decision

- Choose the best approach
- Fill in "Decision" section in the issue file
- Mark the issue `DONE` in `siw/OPEN_ISSUES_OVERVIEW.md` (keep the row for history)
- If this was a phase issue (`P1-*`, `P2-*`, etc.) and it was the last open issue in that phase, ask the user whether to mark the phase as DONE by appending ` (DONE)` to the phase section header
- After recording the decision, optionally delete the issue file: `siw/issues/ISSUE-{prefix}-XXX-*.md`
- Prepare to document in siw/LOG.md

### 4. Record in siw/LOG.md

- Create new decision entry in the Decision Log section
- Document **WHY** the decision was made
- Include the investigation from the issue
- List alternatives considered and why rejected
- Note impact on implementation
- Add code/doc references
- Reference the original issue number if helpful

**Use standard categories:** Architecture | Data Model | API | UI/UX | Testing | Performance | Security | Infrastructure

### 5. Update siw/[YOUR_SPEC].md

- Modify affected tasks based on decision
- Update implementation details with final approach chosen
- Incorporate relevant context from the investigation
- Adjust estimates if needed
- **CRITICAL:** Keep spec self-contained (never reference siw/OPEN_ISSUES_OVERVIEW.md or siw/LOG.md)

**ALWAYS:** Ask user to review decision and spec updates unless they've explicitly opted out.
