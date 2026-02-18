---
name: kramme:siw:generate-phases
description: Break spec into atomic, phase-based issues with tests and validation
argument-hint: "[spec-file-path]"
disable-model-invocation: true
user-invocable: true
---

# Generate Phases from Specification

Break down a specification into atomic, committable issues organized into phases. Each phase results in demoable software, and each issue represents a self-contained piece of work with tests/validation.

## Workflow Boundaries

**This command creates issue files from a specification.**

- **DOES**: Read spec, decompose into phases/tasks, create issue files, update overview table
- **DOES NOT**: Implement features, write code, or make changes to the codebase

**Implementation is a separate workflow.** After this command completes, use `/kramme:siw:issue-implement` to start implementing.

## Issue Numbering Scheme

Use **phase-prefixed numbering** for clear organization:
- Phase 1 tasks: `ISSUE-P1-001`, `ISSUE-P1-002`, `ISSUE-P1-003`...
- Phase 2 tasks: `ISSUE-P2-001`, `ISSUE-P2-002`...
- General tasks: `ISSUE-G-001`, `ISSUE-G-002`... (cross-cutting concerns like setup, tooling, documentation)

## Process Overview

```
/kramme:siw:generate-phases [spec-file-path]
    ↓
[Validate SIW workflow exists]
    ↓
[Find and read spec file(s)]
    ↓
[Check if implementation in progress] -> Ask: continue or abort
    ↓
[Check for existing issues] -> Ask: append, replace, or abort
    ↓
[Analyze spec and decompose into phases/tasks]
    ↓
[Launch review subagent] -> Validates atomicity, testability, dependencies
    ↓
[Present phase plan to user] -> Confirm or request changes
    ↓
[Create issue files and update overview]
    ↓
[Report summary] -> Suggest /kramme:siw:issue-implement
```

## Phase 1: Prerequisites & Input

### 1.1 Validate SIW Workflow Exists

Check for `siw/OPEN_ISSUES_OVERVIEW.md`:
```bash
ls siw/OPEN_ISSUES_OVERVIEW.md 2>/dev/null
```

**If not found:** Inform user and suggest running `/kramme:siw:init` first. Stop.

### 1.2 Find Spec File(s)

**If `$ARGUMENTS` provided:** Use as spec path.

**Otherwise:** Glob for spec files:
```bash
ls siw/*.md | grep -v -E '(LOG\.md|OPEN_ISSUES_OVERVIEW\.md)'
```

Also check for supporting specs:
```bash
ls siw/supporting-specs/*.md 2>/dev/null
```

### 1.3 Check Implementation Status

Check if implementation appears to be in progress by looking for:
- Issues with status "IN PROGRESS" in `siw/OPEN_ISSUES_OVERVIEW.md`
- Recent entries in `siw/LOG.md` indicating active work
- Uncommitted changes in git related to the spec
- Recent commits that reference the spec, issues, or project keywords (check `git log --oneline -10`)

**If implementation appears in progress:** Use AskUserQuestion:
```yaml
header: "Implementation In Progress"
question: "It looks like implementation may already be underway. Generating phases now could disrupt the current workflow. How should I proceed?"
options:
  - label: "Continue anyway"
    description: "Generate phases despite ongoing work (use with caution)"
  - label: "Abort"
    description: "Cancel and continue with current workflow"
```

**If "Abort":** Stop the workflow.

### 1.4 Check for Existing Issues

List files in `siw/issues/`:
```bash
ls siw/issues/ISSUE-*.md 2>/dev/null
```

**If issues exist:** Use AskUserQuestion:
```yaml
header: "Existing Issues"
question: "Found existing issues in siw/issues/. How should I proceed?"
options:
  - label: "Append"
    description: "Add new phase issues alongside existing ones"
  - label: "Replace"
    description: "Delete existing issues and create fresh phase breakdown"
  - label: "Abort"
    description: "Cancel and keep existing issues"
```

**If "Abort":** Stop the workflow.

**If "Replace":** Delete existing issue files:
```bash
rm siw/issues/ISSUE-*.md
```

## Phase 2: Spec Analysis

### 2.1 Read Spec Content

Read the main spec file and any supporting specs found in Phase 1.2.

### 2.2 Extract Key Elements

Identify and extract:
- **Overview/objectives** - What is the project trying to achieve?
- **Scope** - What's in and out of scope?
- **Success criteria** - How do we know we're done?
- **Technical design** - Architecture, data model, API contracts
- **Existing task breakdowns** - Any phases or tasks already defined
- **Implementation phases** - Natural groupings or milestones

## Phase 3: Phase Decomposition

### 3.1 Identify Phase Boundaries

Analyze the spec to find natural phase boundaries:
- Look for milestones, logical groupings, or dependency chains
- Each phase should result in **demoable software** that can be run and tested
- Default to 3-5 phases for medium projects
- Identify cross-cutting concerns for the "General" category (setup, tooling, docs)

### 3.2 Break Into Atomic Tasks

For each phase, decompose into atomic tasks:

**Each task should be:**
- **Committable independently** - A single focused change
- **Testable** - Has clear acceptance criteria and validation
- **Appropriately sized** - Not too granular, not too broad
- **Clearly defined** - Unambiguous scope with explicit boundaries

**Identify dependencies:**
- Which tasks block other tasks within the same phase?
- Which phases depend on completing previous phases?

### 3.3 Generate Phase Plan Structure

For each phase:
- **Phase goal** - What milestone does this achieve?
- **Demo description** - What can be demonstrated after this phase?
- **Tasks** - List of atomic issues with titles and brief descriptions
- **Dependencies** - What blocks what
- **Validation** - How to verify the phase is complete

For general tasks:
- Setup/scaffolding that doesn't fit a specific phase
- Tooling and configuration
- Documentation tasks

## Phase 4: Subagent Review

Launch a Task subagent to review the proposed breakdown:

**Prompt:**
```
Review this phase/task breakdown for a software project. Evaluate:

1. **Atomicity**: Is each task truly independent and committable on its own?
2. **Testability**: Does each task have clear, verifiable acceptance criteria?
3. **Dependencies**: Are dependencies correctly identified? Any missing?
4. **Completeness**: Are any tasks missing to achieve the phase goals?
5. **Phase coherence**: Does each phase result in demoable, runnable software?
6. **Sizing**: Are tasks appropriately sized (not too granular, not too broad)?

For each issue found, provide:
- What's wrong
- Specific suggestion to fix it

If the breakdown looks good, confirm it's ready.
```

**Incorporate feedback:** Update the phase plan based on subagent suggestions.

## Phase 5: User Approval

Present the proposed structure clearly:

```
Phase Plan for {Project Name}
═════════════════════════════

General Tasks ({N} tasks)
─────────────────────────
  ISSUE-G-001: {Title} [Ready]
  ISSUE-G-002: {Title} [Ready]

Phase 1: {Goal} ({N} tasks)
───────────────────────────
  ISSUE-P1-001: {Title} [Ready]
  ISSUE-P1-002: {Title} [Blocked by P1-001]
  ISSUE-P1-003: {Title} [Ready]

  Demo: {What can be demonstrated}
  Tests: {What tests validate this phase}

Phase 2: {Goal} ({N} tasks)
───────────────────────────
  ISSUE-P2-001: {Title} [Blocked by Phase 1]
  ISSUE-P2-002: {Title} [Ready]

  Demo: {What can be demonstrated}
  Tests: {What tests validate this phase}

...

Total: {X} issues across {Y} phases + {Z} general
```

Use AskUserQuestion:
```yaml
header: "Phase Plan"
question: "Does this phase breakdown look correct? You can request specific changes."
options:
  - label: "Looks good - create issues"
    description: "Proceed to create all issue files"
  - label: "Need changes"
    description: "I'll describe what needs to be adjusted"
```

**If "Need changes":** Gather feedback and revise the plan. Repeat Phase 5.

## Phase 6: File Creation

### 6.1 Create Issue Files

For each issue, create `siw/issues/ISSUE-{prefix}-{number}-{title}.md`:

**File naming:**
- Prefix: `P1`, `P2`, `P3`... for phases, `G` for general
- Number: 3-digit padded (001, 002, 003)
- Title: lowercase, hyphens, max ~40 characters

**Issue template:**

```markdown
# ISSUE-{prefix}-{number}: {Title}

**Status:** Ready | **Priority:** {High|Medium|Low} | **Phase:** {N or General} | **Related:** {dependencies}

## Problem

{What this task accomplishes and why it matters}

## Context

{How this fits into the overall project and phase goals}

## Scope

### In Scope
- {Specific deliverable 1}
- {Specific deliverable 2}

### Out of Scope
- {What's NOT included in this task}

## Acceptance Criteria

- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
- [ ] Tests pass: {specific test requirement}

## Validation

{How to verify this task is complete}

- [ ] Code compiles/builds
- [ ] Tests: {specific tests to run or write}
- [ ] Manual verification: {what to check}

---

## Technical Notes

### Implementation Approach
{What needs to change - components, files, patterns}

### Affected Areas
- {Component/file 1}
- {Component/file 2}

### Dependencies
- Blocked by: {P1-001, P2-003, etc. if any, or "None"}
- Blocks: {P1-002, P3-001, etc. if any, or "None"}
```

### 6.2 Update Overview Table

Update `siw/OPEN_ISSUES_OVERVIEW.md` with all new issues, grouped by phase:

If you add any non-DONE issues to a phase section currently marked ` (DONE)`, remove the marker (or ask the user) so the header stays accurate.

```markdown
# Open Issues Overview

## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| G-001 | {Title} | Ready | {Priority} | |
| G-002 | {Title} | Ready | {Priority} | |

## Phase 1: {Goal}

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P1-001 | {Title} | Ready | High | |
| P1-002 | {Title} | Ready | Medium | P1-001 |

## Phase 2: {Goal}

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P2-001 | {Title} | Ready | High | Phase 1 |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

## Phase 7: Summary

Report the results:

```
Phase Generation Complete
═════════════════════════

Created {X} issues:
  • General: {N} issues (G-001 to G-{N})
  • Phase 1: {N} issues (P1-001 to P1-{N})
  • Phase 2: {N} issues (P2-001 to P2-{N})
  ...

Files:
  • siw/issues/ISSUE-*.md ({X} files)
  • siw/OPEN_ISSUES_OVERVIEW.md (updated)

Suggested starting point:
  /kramme:siw:issue-implement ISSUE-{first-ready-issue}

Tips:
  • Work through phases sequentially (Phase 1 → Phase 2 → ...)
  • General tasks can be done anytime
  • Mark issues DONE in the overview as you complete them
```

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

1. **Demoable phases** - Each phase must result in software that runs and can be demonstrated
2. **Atomic tasks** - Each task is one commit, one focused change
3. **Testable criteria** - Every task has verifiable acceptance criteria
4. **Clear dependencies** - Explicit about what blocks what
5. **Appropriate sizing** - Tasks should be meaningful but focused, not micro-tasks
6. **Review before create** - Always use subagent review and user approval

## Starting the Process

1. Parse `$ARGUMENTS` for optional spec file path
2. Validate SIW workflow exists (`siw/OPEN_ISSUES_OVERVIEW.md`)
3. Find and read spec file(s)
4. Check if implementation is in progress, warn if so
5. Check for existing issues, handle accordingly
6. Analyze spec and decompose into phases/tasks
7. Launch review subagent for validation
8. Present plan and get user approval
9. Create issue files and update overview
10. Report summary
