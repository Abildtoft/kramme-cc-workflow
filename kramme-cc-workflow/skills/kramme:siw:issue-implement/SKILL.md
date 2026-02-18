---
name: kramme:siw:issue-implement
description: Start implementing a defined local issue with codebase exploration and planning
argument-hint: <G-001 | P1-001 | ISSUE-G-XXX>
disable-model-invocation: true
user-invocable: true
---

# Implement Local Issue

Start implementing a local issue through an extensive planning phase before any code changes.

**IMPORTANT:** This command emphasizes thorough planning and codebase exploration to translate issue requirements into a concrete technical approach before starting implementation.

## Process Overview

```
/kramme:siw:issue-implement G-001
    |
    v
[Validate & Read Issue] -> Not found? -> Show error, abort
    |
    v
[Verify Git State] -> Warn if uncommitted changes
    |
    v
[Parse Requirements] -> Extract acceptance criteria
    |
    v
=============== PLANNING PHASE (extensive) ===============
    |
    v
[Codebase Exploration] -> ALWAYS search for patterns/implementations
    |
    v
[Technical Analysis] -> Map requirements to technical approach
    |
    v
[Upfront Questions] -> Clarify ambiguities before proceeding
    |
    v
[Create Technical Plan] -> Document approach, files, patterns
    |
    v
=================== EXECUTION PHASE ===================
    |
    v
[Approach Selection] -> AskUserQuestion with 3 options
    |
    v
[Execute Workflow] -> Guided / Context-only / Autonomous
```

---

## Step 1: Parse Arguments and Read Issue

### 1.1 Extract Issue Identifier from Arguments

`$ARGUMENTS` contains the issue identifier provided by the user.

**Accepted formats:**
- Full format: `ISSUE-G-001`, `ISSUE-P1-001`, `ISSUE-P2-001`, etc.
- Short format: `G-001`, `P1-001`, `P2-001`, etc.
- Legacy format: `ISSUE-001` or `001` (treated as `G-001`)

**Validation:**
- Extract the prefix (`G`, `P1`, `P2`, etc.) and numeric portion
- Pad number to 3 digits (1 → 001, 12 → 012)
- Default prefix is `G` if none provided (IDs like `G-001`)

**If no argument provided or invalid:**

```
Error: Please provide an issue identifier.

Usage: /kramme:siw:issue-implement <prefix-number>
Examples:
  /kramme:siw:issue-implement G-001      # General issue
  /kramme:siw:issue-implement P1-001     # Phase 1 issue
  /kramme:siw:issue-implement ISSUE-G-001

The issue can be specified as G-001, P1-001, ISSUE-G-001, etc.
```

**Action:** Abort.

### 1.2 Find and Read Issue File

Search for issue file in `siw/issues/` directory:

```bash
ls siw/issues/ISSUE-{prefix}-{padded_number}-*.md 2>/dev/null
```

**If found:**
- Read the full issue file
- Extract:
  - Title (from `# ISSUE-{prefix}-{number}:` header)
  - Status, Priority, Phase, Related tasks (from frontmatter line)
  - Problem description
  - Context (if present)
  - Scope (in/out)
  - Acceptance Criteria
  - Technical Notes (if present)

**If not found:**

```
Error: Issue {prefix}-{number} not found.

Please verify:
  - The issue exists in the siw/issues/ directory
  - You have the correct issue identifier (e.g., G-001, P1-001)

Available issues:
{list files in siw/issues/ directory}

To create a new issue, run /kramme:siw:issue-define
```

**Action:** Abort.

---

## Step 2: Verify Git State

Check current git status (works on current branch by default):

```bash
git status --porcelain
git branch --show-current
```

**If uncommitted changes exist:**

Use AskUserQuestion:

```yaml
header: "Uncommitted Changes Detected"
question: "You have uncommitted changes. How should I proceed?"
options:
  - label: "Continue anyway"
    description: "Work with current changes (recommended if changes are related)"
  - label: "Stash changes"
    description: "Save changes to stash, can be restored later"
  - label: "Abort"
    description: "Cancel and let me handle it manually"
```

**Display current branch:**

```
Working on branch: {branch_name}
```

---

## Step 3: Parse and Present Issue Context

### 3.1 Present Issue Summary

Show the user what was found:

```
Issue: {prefix}-{number}

Title: {title}

Problem:
---
{problem section}
---

Status: {status}
Priority: {priority}
Related: {related tasks}

Acceptance Criteria:
- {criterion 1}
- {criterion 2}
...

Technical Notes:
{if present, show summary}
```

---

## Step 4: Codebase Exploration (PLANNING PHASE)

**CRITICAL:** **ALWAYS** perform extensive codebase exploration to understand how to implement the feature, regardless of how detailed the issue is.

### 4.1 Why This Phase Is Essential

Issues describe:
- **What** should be accomplished
- **Why** it matters
- **Acceptance criteria** for verification

They may NOT describe:
- Which files/modules to modify
- What patterns to follow
- How existing similar features are implemented

**Your job is to bridge this gap through thorough exploration.**

### 4.2 Mandatory Exploration Steps

**ALWAYS perform these steps:**

1. **Check supporting specs (if they exist):**
   ```bash
   ls siw/supporting-specs/ 2>/dev/null
   ```
   If supporting specs exist, identify which ones are relevant:
   - Data model specs for entity-related work
   - API specs for endpoint-related work
   - UI specs for frontend-related work
   Read relevant sections for detailed requirements.

2. **Search for similar features/patterns:**
   - Use Glob and Grep to find related code
   - Look for existing implementations of similar functionality
   - Identify relevant modules, services, or components

3. **Use the Explore agent:**
   ```
   Task tool with subagent_type=Explore:
   "Find existing implementations related to {feature description from issue}.
    Identify relevant files, patterns, and conventions used in this codebase."
   ```

4. **Identify key files and patterns:**
   - List files that will likely need modification
   - Note existing patterns to follow
   - Find test patterns for similar features

### 4.3 Present Findings

```
Codebase Exploration Results:

Supporting Specs Referenced:
- siw/supporting-specs/01-data-model.md#user-entity (if applicable)
- siw/supporting-specs/02-api-specification.md#endpoints (if applicable)

Relevant Files Found:
- {file 1} - {why relevant}
- {file 2} - {why relevant}

Existing Patterns:
- {pattern description} in {location}

Similar Implementations:
- {feature} in {files} - could serve as reference

Suggested Approach:
{brief technical approach based on findings}
```

---

## Step 5: Upfront Questions (PLANNING PHASE)

**CRITICAL:** Ask questions rather than making assumptions. The goal is to fully understand before writing code.

### 5.1 Identify Ambiguities

Review the issue and exploration results to identify:

- Unclear requirements or acceptance criteria
- Multiple valid technical approaches
- Scope boundaries (what's in/out)
- Dependencies on other work
- Testing expectations

### 5.2 Ask Clarifying Questions

**ALWAYS** use AskUserQuestion for unclear aspects.

**Example questions:**

```yaml
header: "Implementation Scope"
question: "The issue mentions {feature}. Should this include {related functionality}?"
options:
  - label: "Core feature only"
    description: "Minimal implementation as described"
  - label: "Include {related functionality}"
    description: "Broader scope"
```

```yaml
header: "Technical Approach"
question: "I found two patterns. Which should we follow?"
options:
  - label: "Pattern A - {description}"
    description: "Used in {files}"
  - label: "Pattern B - {description}"
    description: "Used in {files}"
```

### 5.3 Create Technical Plan

After gathering answers, create a comprehensive plan:

```
Technical Implementation Plan for {prefix}-{number}

## Summary
{One paragraph describing what will be built}

## Requirements -> Technical Approach
| Requirement | Technical Implementation |
|-------------|-------------------------|
| {criterion 1} | {how it will be implemented} |
| {criterion 2} | {how it will be implemented} |

## Files to Modify/Create
- {file 1} - {what changes}
- {file 2} - {what changes}

## Patterns to Follow
Based on exploration of {similar feature}:
- {pattern 1}
- {pattern 2}

## Implementation Steps
1. {step 1}
2. {step 2}
3. {step 3}

## Testing Approach
- {test type}: {what to test}

## Open Questions (if any)
- {remaining uncertainties}
```

**Present plan and get confirmation before proceeding.**

---

## Step 6: Implementation Approach Selection

Use AskUserQuestion:

```yaml
header: "Implementation Approach"
question: "How would you like to proceed?"
options:
  - label: "Guided Implementation"
    description: "Step-by-step with verification at each stage. Best for complex work."
  - label: "Context Setup Only"
    description: "I'll create a todo list, but you guide implementation. Best when you know the approach."
  - label: "Autonomous Implementation"
    description: "I'll implement and verify, check in when done. Best for straightforward tasks."
```

---

## Step 7: Workflow Execution by Approach

### 7.1 Guided Implementation (Option 1)

**Goal:** Implement with user verification at each step.

1. **Create Todo List**
   - Break requirements into discrete tasks
   - Identify dependencies

2. **Update Issue Status**
   - Change status to "In Progress" in issue file
   - Update siw/OPEN_ISSUES_OVERVIEW.md

3. **Update siw/LOG.md**
   - Set Current Progress to this issue
   - Record implementation start

4. **Begin Implementation**
   - Work through tasks one at a time
   - **ALWAYS** ask user to review after each task
   - Update siw/LOG.md as tasks complete

### 7.2 Context Setup Only (Option 2)

**Goal:** Prepare everything, let user drive.

1. **Create Todo List from Acceptance Criteria**

2. **Update Issue Status to "In Progress"**

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

### 7.3 Autonomous Implementation (Option 3)

**Goal:** Complete with minimal interaction.

1. **Deep Analysis**
   - Search for related files
   - Read similar implementations
   - Understand testing patterns

2. **Create Comprehensive Plan**
   - Detailed task breakdown

3. **Update Issue Status**

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

---

## Step 8: Update Progress Tracking

### Update siw/LOG.md

After starting implementation:

```markdown
## Current Progress

**Last Updated:** {date}
**Quick Summary:** Implementing {prefix}-{number}: {title}

### Project Status
- **Status:** In Progress | **Current Issue:** {prefix}-{number}

### Last Completed
- Started implementation of {prefix}-{number}

### Next Steps
1. {next task from plan}
```

### Update Issue File

Change status line:
```markdown
**Status:** In Progress | **Priority:** {priority} | **Related:** {tasks}
```

### Update siw/OPEN_ISSUES_OVERVIEW.md

Update the issue's row status to "In Progress".

---

## Step 9: Success Output

```
Issue Implementation Started

Issue: {prefix}-{number} - {title}
Branch: {branch}
Approach: {selected approach}

{Approach-specific next steps}

Quick Commands:
- /kramme:verify:run - Run verification checks
- /kramme:pr:create - Create PR when ready
- /kramme:pr:code-review - Review changes for issues
```

---

## Step 10: Sync Decisions to Specification (COMPLETION PHASE)

**CRITICAL:** Before marking implementation complete, ensure the specification reflects all decisions made during implementation.

### 10.1 Review siw/LOG.md Decision Log

Check siw/LOG.md for any decisions recorded during implementation:
- New decisions made that aren't in the spec
- Changes to originally planned approach
- Discovered constraints or requirements
- Technical choices that affect future work

### 10.2 Compare Decisions Against Spec (and Supporting Specs)

For each decision in siw/LOG.md:
1. Check if the decision aligns with what's documented in the spec or supporting specs
2. Identify decisions that:
   - Contradict the spec (spec needs updating)
   - Add new information (spec needs expanding)
   - Clarify ambiguities (spec needs refinement)

**If supporting specs exist (`siw/supporting-specs/`)**, route decisions by topic:
- Data model decisions → `*-data-model*.md`
- API decisions → `*-api*.md`
- UI/frontend decisions → `*-ui*.md` or `*-frontend*.md`
- User story updates → `*-user-stories*.md`
- Default → main spec if no matching supporting spec

### 10.3 Present Spec Update Candidates

If misalignments found:

```
Spec Sync Check

The following decisions from implementation don't match the current specification:

Decisions needing spec update:
1. Decision #{n}: {title}
   - siw/LOG.md says: {decision}
   - Spec says: {current spec content or "not mentioned"}
   - Target file: {main spec or relevant supporting spec}
   - Recommendation: {update/add/clarify}

2. Decision #{n}: {title}
   ...
```

Use AskUserQuestion:

```yaml
header: "Update Specification"
question: "Should I update the specification to reflect these implementation decisions?"
options:
  - label: "Update spec with all decisions"
    description: "Add all listed decisions to the specification"
  - label: "Review each decision"
    description: "Let me choose which decisions to include"
  - label: "Skip spec update"
    description: "Keep spec as-is (decisions remain only in siw/LOG.md)"
```

### 10.4 Update Specification File(s)

For selected decisions, update the appropriate spec file (main spec or supporting spec).

**CRITICAL for supporting specs:** Don't just add to a "Design Decisions" section - **update the actual spec content** to reflect the decision. Supporting specs should always reflect current reality.

**Example:** If a decision changes an API endpoint from POST to PUT:
- **Wrong:** Add "Decision #5: Changed to PUT" to Design Decisions section
- **Right:** Update the endpoint definition in the API spec to show PUT, add brief note about why

**When to update supporting spec content directly:**
- Data model changes → Update entity definitions in `*-data-model*.md`
- API changes → Update endpoint contracts in `*-api*.md`
- UI changes → Update component specs in `*-ui*.md`
- Architecture changes → Update diagrams/descriptions in architecture specs

**When to use Design Decisions section (main spec only):**
- Cross-cutting decisions that affect multiple areas
- High-level architectural choices
- Decisions that don't map to a specific spec section

**Migration format for main spec's `## Design Decisions` section:**

```markdown
### Decision #5: Make ActionByUserId Nullable
**Date:** 2025-11-05 | **Source:** ISSUE-G-003 implementation

**Context:** Not all entities undergo this action, so the field shouldn't be required at the database level.
**Decision:** Nullable at storage; required parameter when calling PerformAction().
**Rationale:** Matches existing ActionAt pattern; semantically correct representation.
```

**Note:** The spec version is more concise than LOG.md - omit alternatives and detailed impact (those stay in LOG.md for historical reference).

### 10.5 Confirm Sync Complete

```
Specification(s) Updated

Main spec ({spec_filename}):
- Decision #{n}: {title}

Supporting specs:
- siw/supporting-specs/01-data-model.md: Decision #{n}: {title}
- siw/supporting-specs/02-api-specification.md: Decision #{n}: {title}

Sections updated:
- Design Decisions
- {other sections if applicable}

Specs and siw/LOG.md are now aligned.
```

**If no updates needed:**
```
Spec Sync Check: All implementation decisions align with the specifications.
No updates needed.
```

---

## Step 11: Close Issue and Check Phase Completion (COMPLETION PHASE)

After verification passes and the implementation is complete, close out tracking for the issue.

### 11.1 Mark Issue as DONE

1. Update the issue file status line to `DONE`.
2. Update the issue row in `siw/OPEN_ISSUES_OVERVIEW.md` to `DONE`.

### 11.2 If This Was the Last Open Issue in a Phase, Confirm Phase Completion

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

### 11.3 Update siw/LOG.md Current Progress

Update `siw/LOG.md` to reflect completion:
- Move the completed issue into "Last Completed"
- Set "Next Steps" to the next READY issue (or the next planned task)
- If a phase was marked DONE, note that in the summary/last-completed entry

---

## Important Constraints

### No AI Attribution

**NEVER** add Claude attribution to commits or code.

### Verification Before Completion

**ALWAYS** run verification before claiming completion. Use `kramme:verify:run` skill.

### Respect Existing Patterns

**ALWAYS** search for and follow existing patterns before implementing.

### Update siw/LOG.md

**ALWAYS** update siw/LOG.md with progress and decisions.

### Sync Decisions to Spec

**ALWAYS** run Step 10 (Spec Sync) before marking implementation complete. The specification must reflect the actual implementation.

---

## Error Handling

### Git Errors
- Merge conflicts: Ask user to resolve
- Stash failures: Report and suggest manual handling

### Issue File Errors
- Malformed issue: Report what's missing, suggest `/kramme:siw:issue-define` to fix

### Implementation Errors
- Test failures: Present errors, ask how to proceed
- Build failures: Show full error output
