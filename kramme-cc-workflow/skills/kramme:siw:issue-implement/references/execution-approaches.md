# Execution Approaches (Step 7 detail)

After the user selects an approach in Step 6, run **only** the workflow that matches their selection. Each workflow ends by handing control to Step 8 in the main skill (verify status update completed).

The phrase "Run the Status Update Procedure" refers to the procedure declared at the top of `SKILL.md` — update all three tracking files (issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/LOG.md`) atomically.

---

## Step 8 Status Update Verification

After any workflow below transitions the issue to "In Progress", verify all three tracking files:

- [ ] `siw/issues/ISSUE-{prefix}-{number}-*.md` — Status line reads `**Status:** In Progress ...` and preserves any existing `**Size:**` / `**Parallelization:**` metadata instead of deleting it.
- [ ] `siw/OPEN_ISSUES_OVERVIEW.md` — Issue row shows "In Progress".
- [ ] `siw/LOG.md` — Current Progress section identifies the active issue and preserves any more specific progress already recorded:
  ```markdown
  ## Current Progress

  **Last Updated:** {date}
  **Quick Summary:** {one-line summary mentioning {prefix}-{number}}

  ### Project Status
  - **Status:** In Progress | **Current Issue:** {prefix}-{number} | ...

  ### Last Completed
  - {started implementation of {prefix}-{number}, or the latest completed task}

  ### Next Steps
  1. {next unfinished task from plan}
  ```

If any file was not updated during the selected workflow, run the Status Update Procedure again before returning to Step 9 in `SKILL.md`. When re-running it, update only missing or stale status fields and preserve accurate `Last Completed` / `Next Steps` details already written by the selected workflow.

---

## 7.1 Guided Implementation (Option 1)

**Goal:** Implement with user verification at each step.

1. **Create Todo List**
   - Break requirements into discrete tasks
   - Identify dependencies

2. **Set Status to "In Progress"** — Run the Status Update Procedure (all 3 files).

3. **Begin Implementation**
   - Work through tasks one at a time
   - **ALWAYS** ask user to review after each task
   - Update siw/LOG.md as tasks complete

---

## 7.2 Context Setup Only (Option 2)

**Goal:** Prepare everything, let user drive.

1. **Create Todo List from Acceptance Criteria**

2. **Set Status to "In Progress"** — Run the Status Update Procedure (all 3 files).

3. **Provide Starting Points**
   ```
   Context set up. Here's where to start:

   Issue: {prefix}-{number}
   Branch: {current_branch}

   Likely affected areas:
   - {file/module 1} - {why}
   - {file/module 2} - {why}

   Similar implementations to reference:
   - {existing feature} - {relevance}

   Todo list created. Ready when you want to begin.
   ```

---

## 7.3 Autonomous Implementation (Option 3)

**Goal:** Complete with minimal interaction.

1. **Deep Analysis**
   - Search for related files
   - Read similar implementations
   - Understand testing patterns

2. **Create Comprehensive Plan**
   - Detailed task breakdown

3. **Set Status to "In Progress"** — Run the Status Update Procedure (all 3 files).

4. **Implement Iteratively**
   - Work through all tasks
   - Follow existing patterns
   - Run tests after changes
   - Document decisions

5. **Verification Phase**
   - Invoke `kramme:verify:run` skill
   - Fix any issues
   - Ensure all criteria met

6. **Sync Decisions to Spec**
   - Review siw/LOG.md for decisions made during implementation
   - Update spec with any decisions not already reflected
   - Ensure spec matches actual implementation

7. **Present Results**
   ```
   Implementation Complete

   Issue: {prefix}-{number}
   Branch: {branch}

   Changes Made:
   - {summary}

   Files Modified:
   - {list}

   Verification Results:
   - Tests: {status}
   - Build: {status}

   Acceptance Criteria:
   - [x] {criterion 1}
   - [x] {criterion 2}

   Ready for review. Run /kramme:pr:create when ready.
   ```
