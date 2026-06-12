---
name: kramme:siw:issue-implement
description: Start implementing a defined local issue with codebase exploration and planning. Use --team to implement multiple independent SIW issues in parallel.
argument-hint: "<issue-id> | --team [issue-ids | 'phase N'] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Implement Local Issue

Plan before coding: explore the codebase, agree on a technical approach, then implement against the chosen approach.

## Expected Issue File Contract

This skill consumes issue files produced by `kramme:siw:issue-define`. Each issue carries a status line of the form:

```
**Status:** {status} | **Priority:** {priority} | **Size:** {size} | **Phase:** {N or General} | **Parallelization:** {value} | **Mode:** {AUTO | HITL — <one-line reason>} | **Related:** {tasks if any}
```

The `Mode` field gates the HITL safety logic in Step 3.1 and Step 6.1. If `Mode` is absent, the skill treats the issue as `HITL — mode missing; requires human triage` and routes it through the HITL gate.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments. `--auto` is team-mode-only: it skips the plan confirmation and starts the proposed parallel implementation plan immediately (full semantics in `references/team-mode.md`); ignore it in the standard workflow.

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

Every status change (to "IN PROGRESS", "IN REVIEW", or "DONE") must update all three tracking files atomically. Skipping any file leaves the tracking state inconsistent.

**Required updates:**

- [ ] **Issue file** (`siw/issues/ISSUE-{prefix}-{number}-*.md`) — Set the `**Status:**` line to the new status. Preserve the rest of the status line (`Size`, `Parallelization`, `Mode`, `Related`, etc.) — do not delete adjacent metadata.
- [ ] **Overview** (`siw/OPEN_ISSUES_OVERVIEW.md`) — Update the issue's row in the table to match the new status.
- [ ] **Log** (`siw/LOG.md`) — Update the `## Current Progress` section to reflect the change. The block must identify the active issue and preserve any more-specific `Last Completed` / `Next Steps` already written by the calling step:

  ```markdown
  ## Current Progress

  **Last Updated:** {date} **Quick Summary:** {one-line summary mentioning {prefix}-{number}}

  ### Project Status

  - **Status:** {status} | **Current Issue:** {prefix}-{number} | ...

  ### Last Completed

  - {most recent meaningful event}

  ### Next Steps

  1. {next unfinished task from plan}
  ```

When re-running the procedure to repair a partial update, touch only stale fields; do not overwrite accurate `Last Completed` / `Next Steps` entries.

This procedure is referenced as **"Run the Status Update Procedure"** throughout this skill.

---

## Step 1: Parse Arguments and Read Issue

### 1.1 Extract Issue Identifier from Arguments

`$ARGUMENTS` contains the issue identifier provided by the user.

If `$ARGUMENTS` contains `--team`, use Team Mode and remove the flag before parsing issue identifiers.

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
ls siw/issues/ISSUE-{prefix}-{padded_number}-*.md 2> /dev/null
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

**If the issue's Mode is `HITL`**, including the inferred `HITL — mode missing; requires human triage` fallback, surface this prominently. HITL means the issue requires human input for at least one of: architectural decision, design review, judgment call, manual testing, or external system access. Team mode excludes HITL issues from autonomous batches; this standard mode honors the same constraint at approach selection (Step 6) — recommend Guided Implementation and require explicit confirmation before Autonomous Implementation.

---

## Step 4: Codebase Exploration (PLANNING PHASE)

Explore the codebase before proposing a technical approach. Scale the depth to the issue: a tightly-scoped issue that already lists files and patterns needs targeted verification; a broadly-scoped issue needs full exploration.

### 4.1 Why This Phase Is Essential

Issues describe:

- **What** should be accomplished
- **Why** it matters
- **Acceptance criteria** for verification

They may not describe:

- Which files/modules to modify
- What patterns to follow
- How existing similar features are implemented

Exploration bridges this gap before any code changes.

### 4.2 Exploration Steps

Run all of the following before drafting the technical plan:

1. **Check supporting specs (if they exist):**

   ```bash
   ls siw/supporting-specs/ 2> /dev/null
   ```

   If supporting specs exist, identify which ones are relevant:
   - Data model specs for entity-related work
   - API specs for endpoint-related work
   - UI specs for frontend-related work Read relevant sections for detailed requirements.

2. **Search for similar features/patterns:**
   - Use Glob and Grep to find related code
   - Look for existing implementations of similar functionality
   - Identify relevant modules, services, or components

3. **Delegate broader exploration to a sub-agent when available:**

   On Claude Code, invoke the Task tool with `subagent_type=Explore`. On Codex or other harnesses, use the equivalent exploration agent if one is available; otherwise continue with direct Glob/Grep. The prompt:

   ```
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

Ask before assuming. Resolve ambiguities in scope, technical approach, and testing expectations before writing code.

### 5.1 Identify Ambiguities

Review the issue and exploration results to identify:

- Unclear requirements or acceptance criteria
- Multiple valid technical approaches
- Scope boundaries (what's in/out)
- Dependencies on other work
- Testing expectations

### 5.2 Ask Clarifying Questions

Use AskUserQuestion for each unresolved ambiguity.

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

If the issue's `Mode` is `HITL` and the user selected "Autonomous Implementation", issue the following confirmation question before continuing:

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

Read and follow `references/execution-approaches.md` for the selected workflow's task list, status-update points, and presentation templates. All three workflows must run the Status Update Procedure (top of skill) when transitioning to "IN PROGRESS".

---

## Step 8: Verify Status Update Completed

Confirm the Status Update Procedure ran during Step 7 and that all three tracking files now show "IN PROGRESS" per the checklist at the top of this skill. Re-run the procedure for any file that wasn't updated. Do not proceed to Step 9 until all three files reflect "IN PROGRESS".

---

## Step 9: Success Output

```
Issue Implementation Started

Issue: {prefix}-{number} - {title}
Branch: {branch}
Approach: {selected approach}

{Approach-specific next steps}
```

If the companion skills `/kramme:verify:run`, `/kramme:pr:create`, and `/kramme:pr:code-review` are installed in this environment, append a "Quick Commands" block listing them. Omit the block (or any individual line) for skills that are not available.

---

## Step 10: Sync Decisions to Specification (COMPLETION PHASE)

Before marking implementation complete, ensure the specification reflects all decisions made during implementation.

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

For supporting specs, update the actual spec content (entity definitions, endpoint contracts, component specs, diagrams) — do not just append to a "Design Decisions" section. Supporting specs should always reflect current reality.

Use the main spec's `## Design Decisions` section only for cross-cutting decisions, high-level architectural choices, or decisions that don't map to a specific spec section. For the worked POST → PUT example, per-area routing reminders, and the Design Decisions migration format, read `references/spec-sync.md`.

### 10.5 Confirm Sync Complete

Read the confirmation template in `references/spec-sync.md` and use it to confirm the update to the user. If no updates were needed, report: "Spec Sync Check: All implementation decisions align with the specifications. No updates needed."

---

## Step 11: Close Issue and Check Phase Completion (COMPLETION PHASE)

After verification passes and the implementation is complete, close out tracking for the issue.

Read and follow `references/issue-closeout.md` for the closeout procedure:

- Check whether the issue is already closed (status `DONE` with an existing `## Resolution`) and short-circuit if so.
- Add (or replace, or amend) the `## Resolution` section without deleting the issue file.
- Ask for confidence and set the final status to `DONE` or `IN REVIEW`.
- Run the Status Update Procedure for all three tracking files.
- For phase-prefixed issues, check whether the phase should be marked complete.

---

## Constraints

- Do not add Claude attribution to commits or code.
- Run verification (`kramme:verify:run`) before claiming completion.
- Search for and follow existing patterns before introducing new ones.
- Update `siw/LOG.md` with progress and decisions as you go.
- Status updates are atomic — update all three tracking files together (see Status Update Procedure).
- Run Step 10 (Spec Sync) before marking implementation complete.
