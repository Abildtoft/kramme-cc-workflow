# Phase 2: Investigation & Discovery

**Goal:** Document issue → Investigate → Make decision → Record in LOG → Update [YOUR_SPEC].md → Remove issue

## When You Encounter Blockers or Need to Make Decisions

### 1. Create Issue File

If no issues exist yet, read `templates/issues-template.md` for templates.

**If this is the first issue:**
1. Create `issues/` directory
2. Create `OPEN_ISSUES_OVERVIEW.md` (see template)
3. Create `issues/ISSUE-001-short-title.md`

**If issues already exist:**
1. Find next issue number from `OPEN_ISSUES_OVERVIEW.md`
2. Create `issues/ISSUE-XXX-short-title.md`
3. Add row to `OPEN_ISSUES_OVERVIEW.md` table

**In the issue file:**
- Mark as 🔴 Blocked (cannot proceed) or 🟡 Investigating (actively researching)
- Document problem statement and context
- List options being considered with pros/cons
- Note questions requiring answers

### 2. Investigate and Research

- Search existing work for relevant patterns
- Review existing implementations
- Consider alternatives and trade-offs
- Update the issue with findings
- Mark as 🟢 Ready if decision requires team input or approval; otherwise proceed to step 3

**When checking past decisions (don't read entire LOG.md):**

```bash
# Find decisions related to your topic
grep -n "Decision.*EntityName\|Decision.*pattern" LOG.md
```

Then read only that specific decision section (~10 lines per decision) using Read with `offset` at the line number found.

### 3. Make Decision

- Choose the best approach
- Fill in "Decision" section in the issue file
- Delete the issue file: `issues/ISSUE-XXX-*.md`
- Remove row from `OPEN_ISSUES_OVERVIEW.md`
- Prepare to document in LOG.md

### 4. Record in LOG.md

- Create new decision entry in the Decision Log section
- Document **WHY** the decision was made
- Include the investigation from the issue
- List alternatives considered and why rejected
- Note impact on implementation
- Add code/doc references
- Reference the original issue number if helpful

### 5. Update [YOUR_SPEC].md

- Modify affected tasks based on decision
- Update implementation details with final approach chosen
- Incorporate relevant context from the investigation
- Adjust estimates if needed
- **CRITICAL:** Keep spec self-contained (never reference OPEN_ISSUES.md or LOG.md)

**ALWAYS:** Ask user to review decision and spec updates unless they've explicitly opted out.
