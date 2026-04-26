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

1. Parse arguments → read and validate the issue file
2. Verify git state → warn on uncommitted changes
3. Present issue context to the user
4. **Planning phase:** codebase exploration → upfront questions → technical plan
5. **Execution phase:** approach selection (Guided / Context-only / Autonomous) → run workflow
6. Verify status update → success output
7. **Completion phase:** sync decisions to spec → close issue → check phase completion

When executing those phases, read and follow `references/execution-approaches.md` and `references/spec-sync.md` at the step where each reference is named.

---

## Status Update Procedure

**CRITICAL — MANDATORY for every status change.** Every time an issue's status changes (to "In Progress", "IN REVIEW", or "DONE"), you MUST update ALL THREE files below. Never update one without the others.

**Checklist (all three required):**

- [ ] **Issue file** (`siw/issues/ISSUE-{prefix}-{number}-*.md`) — Change the `**Status:**` line to the new status
- [ ] **Overview** (`siw/OPEN_ISSUES_OVERVIEW.md`) — Update the issue's row in the table to match the new status
- [ ] **Log** (`siw/LOG.md`) — Update the "Current Progress" section to reflect the status change

Skipping any of these files leaves the tracking state inconsistent. Treat this as a single atomic operation.

This procedure is referenced as **"Run the Status Update Procedure"** throughout this skill.

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
  - Status, Priority, Phase, Mode, Related tasks (from frontmatter line)
  - Problem description
  - Context (if present)
  - Scope (in/out)
  - Acceptance Criteria
  - Technical Notes (if present)
- If `Mode` is missing, set it to `HITL — mode missing; requires human triage` for this run. Missing Mode is not safe for Autonomous Implementation.

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
Mode: {AUTO | HITL — <one-line reason> | (not classified)}
Related: {related tasks}

Acceptance Criteria:
- {criterion 1}
- {criterion 2}
...

Technical Notes:
{if present, show summary}
```

**If the issue's Mode is `HITL`**, including the inferred `HITL — mode missing; requires human triage` fallback, surface this prominently. HITL means the issue requires human input for at least one of: architectural decision, design review, judgment call, manual testing, or external system access. The team variant `kramme:siw:issue-implement:team` excludes HITL issues from autonomous batches; this singular variant honors the same constraint at approach selection (Step 6) — recommend Guided Implementation and require explicit confirmation before Autonomous Implementation.

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

After gathering answers, read `references/plan-template.md` and create a comprehensive plan using that structure (Summary, Requirements → Technical Approach, Files to Modify/Create, Patterns to Follow, Implementation Steps, Testing Approach, Open Questions).

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
    description: "I'll implement and verify, check in when done. Best for straightforward tasks. Not recommended for HITL issues."
```

### 6.1 HITL Confirmation Gate (conditional)

**If the issue's `Mode` is `HITL` and the user selected "Autonomous Implementation"**, do not proceed silently. Issue the following confirmation question:

```yaml
header: "HITL Issue Confirmation"
question: "This issue is marked HITL — {one-line reason from issue file}. Autonomous implementation is not recommended for HITL issues. Proceed anyway?"
options:
  - label: "Proceed autonomously — human input handled outside this session"
    description: "Confirm that the required architectural decision, review, judgment call, manual testing, or external access has already been resolved."
  - label: "Switch to Guided Implementation"
    description: "Get verification at each step instead. Recommended for HITL issues."
  - label: "Abort and revisit later"
    description: "Stop now; pick this issue back up after the human input is handled."
```

- If the user picks **Proceed autonomously**, continue with Step 7.3 (Autonomous Implementation). Log the override in `siw/LOG.md` Decision Log: `Decision: proceeded autonomously on HITL issue {prefix}-{number}; user confirmed prerequisites handled outside session`.
- If the user picks **Switch to Guided Implementation**, treat the original answer as if "Guided Implementation" had been selected; continue with Step 7.1.
- If the user picks **Abort**, halt the workflow and surface the issue identifier so the user can return later.

This gate fires when (a) the issue carries `Mode: HITL` or Mode was missing and inferred as `HITL — mode missing; requires human triage`, and (b) the user picked Autonomous. Only explicit `Mode: AUTO` skips this gate.

---

## Step 7: Workflow Execution by Approach

Run the workflow that matches the user's selection from Step 6:

- **Option 1 — Guided:** user reviews after each task.
- **Option 2 — Context-only:** prepare context and starting points; user drives.
- **Option 3 — Autonomous:** complete end-to-end with verification and decision sync.

Read and follow `references/execution-approaches.md` for the selected workflow's task list, status-update points, and presentation templates. All three workflows must run the Status Update Procedure (top of skill) when transitioning to "In Progress".

---

## Step 8: Verify Status Update Completed

**CRITICAL:** Before proceeding, confirm the Status Update Procedure (top of skill) ran in Step 7 and all three tracking files now show "In Progress". The issue file's status line must preserve any existing `**Size:**` / `**Parallelization:**` metadata, and `siw/LOG.md` must match the Current Progress shape in `references/execution-approaches.md`. Re-run the procedure for any file that wasn't updated. Do not proceed to Step 9 until all three files reflect "In Progress".

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

Check siw/LOG.md for decisions recorded during implementation: new decisions not in the spec, changes to the originally planned approach, discovered constraints, and technical choices that affect future work.

### 10.2 Compare Decisions Against Spec (and Supporting Specs)

For each decision, check whether it aligns with the spec or supporting specs. Identify decisions that contradict (spec needs updating), add new information (spec needs expanding), or clarify ambiguities (spec needs refinement).

**If supporting specs exist (`siw/supporting-specs/`)**, route decisions by topic:
- Data model decisions → `*-data-model*.md`
- API decisions → `*-api*.md`
- UI/frontend decisions → `*-ui*.md` or `*-frontend*.md`
- User story updates → `*-user-stories*.md`
- Default → main spec if no matching supporting spec

### 10.3 Present Spec Update Candidates and Ask

If misalignments are found, read `references/spec-sync.md`, present them using its template, and use AskUserQuestion to choose between updating all, reviewing each, or skipping.

### 10.4 Update Specification File(s)

For selected decisions, update the appropriate spec file.

**CRITICAL for supporting specs:** Update the actual spec content (entity definitions, endpoint contracts, component specs, diagrams) — do **not** just append to a "Design Decisions" section. Supporting specs should always reflect current reality.

Use the main spec's `## Design Decisions` section only for cross-cutting decisions, high-level architectural choices, or decisions that don't map to a specific spec section. For the worked POST → PUT example, per-area routing reminders, and the Design Decisions migration format, read `references/spec-sync.md`.

### 10.5 Confirm Sync Complete

Read the confirmation template in `references/spec-sync.md` and use it to confirm the update to the user. If no updates were needed, report: "Spec Sync Check: All implementation decisions align with the specifications. No updates needed."

---

## Step 11: Close Issue and Check Phase Completion (COMPLETION PHASE)

After verification passes and the implementation is complete, close out tracking for the issue.

### 11.1 Document Resolution in Issue File

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

### 11.2 Determine Confidence and Set Status

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

**If "Confident":** Set status to `DONE`.
**If "Needs review":** Set status to `IN REVIEW`.

### 11.3 Update All Tracking Files

**CRITICAL:** Run the Status Update Procedure with the chosen status (`DONE` or `IN REVIEW`). All three files:

- [ ] **Issue file** — Set `**Status:**` to the chosen status
- [ ] **Overview** (`siw/OPEN_ISSUES_OVERVIEW.md`) — Update the issue row to match
- [ ] **Log** (`siw/LOG.md`) — Move the issue into "Last Completed", set "Next Steps" to the next READY issue

Do NOT proceed to 11.4 until all three files are updated.

### 11.4 If This Was the Last Open Issue in a Phase, Confirm Phase Completion

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

### 11.5 Post-Phase LOG.md Update (only if phase marked DONE in 11.4)

If a phase was marked DONE in 11.4, update `siw/LOG.md` to note the phase completion in the summary/last-completed entry.

---

## Important Constraints

- **NEVER** add Claude attribution to commits or code.
- **ALWAYS** run verification (`kramme:verify:run`) before claiming completion.
- **ALWAYS** search for and follow existing patterns before implementing.
- **ALWAYS** update `siw/LOG.md` with progress and decisions.
- Status updates are atomic — update all three tracking files together (see Status Update Procedure at top of skill).
- **ALWAYS** run Step 10 (Spec Sync) before marking implementation complete.

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
