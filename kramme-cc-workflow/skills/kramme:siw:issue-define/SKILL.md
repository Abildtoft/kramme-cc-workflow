---
name: kramme:siw:issue-define
description: Define a new local issue with guided interview process
argument-hint: "[ISSUE-G-XXX or ISSUE-P1-XXX] or [description and/or file paths for context]"
disable-model-invocation: true
user-invocable: true
---

# Define Local Issue

Create or improve a local issue through guided interactive refinement. Can start from scratch with a description, or improve an existing issue by providing its identifier. Supports file references for technical context and proactively explores the codebase to inform issue definition.

**Issue Naming:** New issues default to `G-XXX` (General). Use `P1-`, `P2-`, etc. for phase-specific issues. When creating a new issue, recommend a phase prefix if the issue fits an active (not completed) phase.

## Workflow Boundaries

**This command ONLY creates or updates local issue files.**

- **DOES**: Interview user, explore codebase for context, compose well-structured issue, create/update issue file
- **DOES NOT**: Write code, implement features, fix bugs, or make any changes to the codebase

**Implementation is a separate workflow.** After this command completes, the user can invoke `/kramme:siw:issue-implement` if they want to start implementing.

**CRITICAL**: Do NOT proceed to code implementation after creating the issue. The workflow is complete once the issue file is created.

## Prerequisites

**Workflow files should exist.** If `siw/OPEN_ISSUES_OVERVIEW.md` doesn't exist, suggest running `/kramme:siw:init` first.

## Audience Priority

**Primary: Future You** — The issue must be clear enough to understand days or weeks later.

**Secondary: Other Developers** — Technical context helps others understand the work.

### Content Priority Order

1. **Problem Statement** - What pain point or opportunity exists?
2. **Context** - What's the current state and why does this matter?
3. **Scope** - What's in and out of scope?
4. **Acceptance Criteria** - How do we know we've solved the problem?
5. **Technical Notes** - Implementation direction (not detailed how-to)

## Process Overview

1. **Input Parsing & Mode Detection**: Detect if improving existing issue or creating new
2. **File References**: Read provided files (if any) to gather technical context
3. **Issue Type Classification**: Classify the issue type (bug/feature/improvement)
4. **Phase Recommendation (Create Mode)**: Suggest a phase prefix if the issue fits an active phase
5. **Existing Issue Handling**: For improve mode, fetch issue; for create mode, check for similar issues
6. **Codebase Exploration**: Search for related implementations and patterns
7. **Interview**: Multi-round questioning (adapted for issue type and mode)
8. **Issue Composition**: Draft issue following the template
9. **Review & Create/Update**: User approval, then create or update issue file

## Phase 1: Input Parsing & Mode Detection

**Handling `$ARGUMENTS`:**

### Step 1: Detect Mode

Check if input matches an existing issue:
- **Issue identifier patterns**:
  - Full format: `ISSUE-G-001`, `ISSUE-P1-001`, `ISSUE-P2-001`, etc.
  - Short format: `G-001`, `P1-001`, `P2-001`, etc.
  - Legacy format: `ISSUE-001` or `001` (treated as `G-001`)

**Detection rule:** Only treat it as an existing issue if a matching file exists in `siw/issues/ISSUE-{prefix}-{number}-*.md`.

**If existing issue detected → IMPROVE MODE:**
1. Extract the prefix and number (e.g., `G` and `001` from `ISSUE-G-001`, or `P1` and `002` from `P1-002`)
2. Find and read the issue file from `siw/issues/ISSUE-{prefix}-{number}-*.md`
3. Store the existing issue content
4. Set mode flag to "improve"

**If an identifier-like argument was provided but no file exists:**
1. Use `AskUserQuestion` to confirm whether they want to create a new issue instead
2. If creating: treat the provided prefix as `requested_prefix` and ignore the provided number
3. If the identifier was followed by additional text, treat that remainder as the initial description; otherwise ask for a description
4. Continue in CREATE MODE

**If no issue detected → CREATE MODE:**
1. Parse optional **prefix hint** at the start of `$ARGUMENTS`:
   - Accepted: `G`, `G-`, `P1`, `P1-`, `P2`, `P2-`, etc.
   - Store as `requested_prefix` (without trailing `-`) and strip it from the description
2. Parse for file paths (anything containing `/` or ending in common extensions) and store for Step 2
3. Remaining text is the description/idea
4. If empty, use `AskUserQuestion` to gather the initial concept
5. Set mode flag to "create"

### Step 2: Process File References (Both Modes)

**If file paths provided:**
1. Read each file using the `Read` tool
2. Extract relevant context:
   - What functionality does this code provide?
   - What patterns or conventions does it follow?
   - What dependencies or integrations exist?
3. Store findings for use in interview and issue composition

### Step 3: Issue Type Classification

Auto-detect from context and suggest to the user (they can override):

**Issue Types:**
- **Bug (Simple)**: Root cause is known or easily identified, fix is localized, no architectural decisions needed
- **Bug (Complex)**: Unknown root cause, affects multiple components, requires investigation
- **Feature**: New functionality
- **Improvement**: Enhance existing functionality

**Detection Heuristics:**
- Keywords like "bug", "fix", "broken", "doesn't work", "error" → suggest Bug
- If user provides root cause and specific file(s) → suggest Bug (Simple)
- If scope is unclear, multiple components mentioned → suggest Bug (Complex)
- Keywords like "add", "new", "implement", "create" → suggest Feature
- Keywords like "improve", "refactor", "enhance", "optimize" → suggest Improvement

**Present classification to user via `AskUserQuestion`:**
- Show detected type with reasoning
- Allow override to any type
- Store `issue_type` for conditional behavior

**For Bug (Simple), store:**
- `is_simple_bug = true`
- This enables streamlined interview and simple template

### Step 4: Phase Recommendation (Create Mode)

Only for CREATE MODE. Skip for IMPROVE MODE.

Goal: recommend a phase prefix (`P1-`, `P2-`, etc.) when the issue clearly fits an **active** (not completed) phase. If the issue doesn't suit a phase well, or the relevant phase is completed, recommend `G` (General, i.e., IDs like `G-001`).

**Inputs to check:**
1. `siw/` spec file created by `/kramme:siw:init` (phase breakdown and tasks).
2. `siw/LOG.md` for phase completion notes (e.g., "Phase 1 complete", "Status: DONE").
3. `siw/OPEN_ISSUES_OVERVIEW.md` for existing phase sections and active work.

If multiple candidate spec files exist under `siw/`, ask the user which one is the main spec (exclude `siw/LOG.md` and `siw/OPEN_ISSUES_OVERVIEW.md`).

**Heuristics:**
- Map the issue description and any referenced tasks to the most relevant phase in the spec.
- If the phase is explicitly marked complete in the spec or log, do **not** recommend that phase.
- If the phase section header in `siw/OPEN_ISSUES_OVERVIEW.md` is marked with ` (DONE)`, treat the phase as completed.
- If `siw/OPEN_ISSUES_OVERVIEW.md` has a Phase N section and all issues in that phase are `DONE`, treat the phase as completed.
- If no phase info exists or mapping is unclear (or the issue doesn't suit a phase well), default to `G`.
- If the user explicitly supplied a prefix (`requested_prefix`), treat it as preferred, but warn if the phase appears completed and offer alternatives.

**AskUserQuestion (recommendation + confirmation):**
```
header: "Choose Issue Prefix"
question: "Which prefix should we use? Recommendation: {recommended_prefix}- ({reason})."
options:
  - label: "Use {recommended_prefix}- (recommended)"
    description: "Matches the spec/tasks and the phase isn't completed"
  - label: "Use a different phase prefix"
    description: "Pick P1-, P2-, P3-, etc."
  - label: "Use G- (General)"
    description: "Standalone or doesn't fit a phase well"
```

If `{recommended_prefix}` is `G`, omit the separate "Use G-" option to avoid duplicates.

Store `issue_prefix` based on the selection **without the trailing dash** (e.g., `P1`, `P2`, `G`).

## Phase 2: Existing Issue Handling

### IMPROVE MODE

Present the existing issue to the user:

1. **Present Current Issue**
   - Show the issue title, problem, context, and criteria
   - Format clearly for review

2. **Identify Improvement Areas**
   - Use `AskUserQuestion`:
     - Problem statement clarity
     - Context/background
     - Scope definition
     - Acceptance criteria
     - Technical notes
     - All of the above (full refinement)
   - Store selected areas for focused interview

### CREATE MODE

Before creating a new issue, check for existing similar issues:

1. **Scan Existing Issues**
   - List files in `siw/issues/` directory
   - Read `siw/OPEN_ISSUES_OVERVIEW.md` for existing issue titles

2. **Check for Similar Issues**
   - If any existing issue titles match keywords from the description, warn user
   - Use `AskUserQuestion`:
     - Proceed with new issue
     - Improve existing issue instead → Switch to IMPROVE MODE
     - Abort

3. **Generate Next Issue Number**
   - Determine `issue_prefix` (from Step 4; fallback to `requested_prefix` if present; otherwise default `G`)
   - Parse `siw/OPEN_ISSUES_OVERVIEW.md` table to find highest issue number **within that prefix group**
   - Next issue = highest + 1 within group (or 001 if no issues with that prefix exist)
   - Pad number to 3 digits (1 → 001, 12 → 012)
   - Store as `issue_number`
   - Full ID: `{issue_prefix}-{issue_number}` (e.g., `G-001`, `P1-002`)

## Phase 3: Codebase Exploration

**For Simple Bugs (`is_simple_bug = true`):** Skip if user provided root cause and affected file(s).

**For all other issue types:** Proactively search the repository:

1. **Find Related Implementations**
   - Use `Grep` to search for keywords from the description
   - Use `Glob` to find files in related areas
   - Identify existing code that does something similar

2. **Identify Patterns & Conventions**
   - Look for architectural patterns in related code
   - Note naming conventions, file organization

3. **Discover Related Components**
   - Find services, modules, or components that may be affected
   - Identify integration points

4. **Find Existing Tests**
   - Search for test files covering similar functionality
   - Note testing patterns

**Output**: Summarize findings to share with user and inform interview.

## Phase 4: Interview

The interview adapts based on issue type.

### Simple Bug Interview (if `is_simple_bug = true`)

Streamlined 2-round interview:

**Round 1: Problem & Reproduction**
- What's the bug? (brief description)
- Steps to reproduce (numbered list ending with "Bug: [what happens]")
- What should happen instead?

**Round 2: Root Cause & Fix**
- What's causing the bug? (if known)
- What needs to change to fix it?
- Which file(s) are affected?

**If root cause unknown after Round 2:**
- Reclassify as Bug (Complex)
- Switch to Standard Interview

Then proceed to Phase 5 with simple template.

### Standard Interview (for all other types)

Multi-round interview using `AskUserQuestion`.

**IMPROVE MODE:** Focus on selected improvement areas. Show current content first.

**CREATE MODE:** Follow standard flow below.

### Round 1: Problem & Context (Most Important)

**Questions:**
- What specific problem or pain point does this solve?
- Who is affected (end users, internal teams)?
- How significant is the impact?
- What happens if we don't address this?

**Dig deep:**
- Don't accept vague answers
- Push for concrete impact

### Round 2: Scope & Boundaries

**Questions:**
- What is explicitly in scope?
- What is explicitly out of scope?
- Are there related changes that should be separate issues?
- What is the minimum viable implementation?

### Round 3: Technical Context

**Questions:**
- Which components/areas are affected?
- Are there dependencies or blocking issues?
- What existing patterns should be followed?
- Are there technical constraints?

**Leverage exploration findings:**
- Present discovered patterns as options
- Highlight related code

### Round 4: Acceptance Criteria

**Questions:**
- What defines "done"?
- How should this be tested/verified?
- Are there specific edge cases?
- What quality criteria must be met?

**Guide toward testable criteria:**
- Each criterion should be verifiable
- Include both happy path and error scenarios

### Round 5: Priority & Related Work

**Questions:**
- What priority level? (High/Medium/Low)
- Are there related issues or tasks?
- Does this block or depend on other work?

## Phase 5: Issue Composition

### Template Selection

- **Bug (Simple)**: Simple Bug Template
- **All others**: Comprehensive Template

### Simple Bug Template

**File naming:** `siw/issues/ISSUE-{prefix}-{number}-{short-description}.md`

```markdown
# ISSUE-{prefix}-{number}: Fix {what's broken}

**Status:** Ready | **Priority:** {priority} | **Phase:** {N or General} | **Related:** {tasks if any}

## Problem

{1-2 sentence description of the bug}

**Steps to reproduce:**
1. {Step 1}
2. {Step 2}
3. **Bug:** {What happens}

## Root Cause

{1-2 sentences explaining what's causing the bug}

## Fix

{1-2 sentences describing what needs to change}

**File:** `{path/to/affected/file}`
```

### Comprehensive Template

**File naming:** `siw/issues/ISSUE-{prefix}-{number}-{short-description}.md`

```markdown
# ISSUE-{prefix}-{number}: {Title}

**Status:** Ready | **Priority:** {priority} | **Phase:** {N or General} | **Related:** {tasks if any}

## Problem

{What pain point or issue exists}
{Who is affected and how}

## Context

{Current state and background}
{Why this matters now}

## Scope

### In Scope
- {Specific item 1}
- {Specific item 2}

### Out of Scope
- {Explicitly excluded item 1}

## Acceptance Criteria

- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}

## Edge Cases

- {Edge case 1}: {Expected behavior}

---

## Technical Notes

### Implementation Approach
{High-level approach - what components/areas need changes}

### Affected Areas
- {Component/module 1}

### Patterns to Follow
{Reference existing patterns in the codebase}

### References
- {Related files: `path/to/file`}
```

## Phase 6: Review & Create/Update

### 1. Present Draft

**IMPROVE MODE:** Show updated issue with change indicators.

**CREATE MODE:** Show complete issue.

### 2. Allow Refinements

- Ask if any changes are needed
- Iterate until user is satisfied

### 3. Write Issue File

**Create/Update issue file:**
```
siw/issues/ISSUE-{prefix}-{number}-{sanitized-title}.md
```

**Sanitize title:**
- Lowercase
- Replace spaces with hyphens
- Remove special characters
- Max 40 characters

### 4. Update siw/OPEN_ISSUES_OVERVIEW.md

**For new issues:** Add row to the appropriate section (General, Phase 1, Phase 2, etc.). If the section doesn't exist yet, create the section header and table first.
```markdown
| {prefix}-{number} | {Title} | Ready | {Priority} | {Related} |
```

**For updated issues:** Update existing row if title/priority/status changed.

**Section organization:** Issues are grouped by prefix (General, Phase 1, Phase 2, etc.).

**If updating a phase issue to `DONE`:**
- Check whether this was the last open issue in that phase section (no READY / IN PROGRESS / IN REVIEW remaining).
- If so, ask the user whether to mark the entire phase as DONE by appending ` (DONE)` to the phase section header in `siw/OPEN_ISSUES_OVERVIEW.md`.

**If creating or updating a phase issue that is not `DONE`:**
- If the phase section header is currently marked ` (DONE)`, ask the user whether to remove the marker because there is now open work in that phase.

### 5. Return Result

**IMPROVE MODE:**
- Confirm issue file updated
- Summarize what changed

**CREATE MODE:**
- Confirm issue file created
- Show file path

### 6. Workflow Complete - STOP

**The define-issue workflow is now complete.**

- Do NOT proceed to code implementation
- Do NOT start working on the issue

**Next steps for the user:**
- Review the created issue file
- If ready to implement, invoke `/kramme:siw:issue-implement {prefix}-{number}` (e.g., `G-001`, `P1-001`)
- If changes needed, run `/kramme:siw:issue-define {prefix}-{number}` again

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

### Template Selection

1. **Use Simple Bug Template when:**
   - Root cause is known
   - Fix is localized to 1-3 files
   - No architectural decisions needed

2. **Use Comprehensive Template when:**
   - Root cause unknown
   - Multiple components affected
   - Feature, improvement, or complex bug
   - Scope needs definition

### General Guidelines

1. **Lead with "Why"** - Problem statement is most important
2. **Be specific** - Vague issues lead to vague implementations
3. **Check for similar issues** - Don't create duplicates
4. **Keep simple bugs simple** - Don't over-engineer
5. **Exhaust the interview** - Especially Round 1 for complex issues
6. **Get user approval** - Always show draft before creating

## Starting the Process

1. Parse `$ARGUMENTS` and detect mode (issue ID → improve, otherwise → create)
2. If improve mode: read the existing issue file
3. If create mode with no input: ask what issue to define
4. Process file references (if any)
5. Classify issue type
6. Phase 2: Handle existing issues appropriately
7. Phase 3: Codebase exploration (skip for simple bugs if root cause known)
8. Phase 4: Interview
9. Phase 5: Compose issue
10. Phase 6: Review, refine, and create/update
