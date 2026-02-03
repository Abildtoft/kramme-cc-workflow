---
name: kramme:siw:define-issue
description: Define a new local issue with guided interview process
argument-hint: [ISSUE-XXX] or [description and/or file paths for context]
---

# Define Local Issue

Create or improve a local issue through guided interactive refinement. Can start from scratch with a description, or improve an existing issue by providing its identifier. Supports file references for technical context and proactively explores the codebase to inform issue definition.

## Workflow Boundaries

**This command ONLY creates or updates local issue files.**

- **DOES**: Interview user, explore codebase for context, compose well-structured issue, create/update issue file
- **DOES NOT**: Write code, implement features, fix bugs, or make any changes to the codebase

**Implementation is a separate workflow.** After this command completes, the user can invoke `/kramme:siw:implement-issue` if they want to start implementing.

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
2. **File References & Issue Type**: Read provided files (if any) and classify the issue type
3. **Existing Issue Handling**: For improve mode, fetch issue; for create mode, check for similar issues
4. **Codebase Exploration**: Search for related implementations and patterns
5. **Interview**: Multi-round questioning (adapted for issue type and mode)
6. **Issue Composition**: Draft issue following the template
7. **Review & Create/Update**: User approval, then create or update issue file

## Phase 1: Input Parsing & Mode Detection

**Handling `$ARGUMENTS`:**

### Step 1: Detect Mode

Check if input matches an existing issue:
- **Issue identifier pattern**: `ISSUE-XXX` or just `XXX` (3-digit number)

**If existing issue detected → IMPROVE MODE:**
1. Extract the issue number (e.g., `001` from `ISSUE-001`)
2. Find and read the issue file from `siw/issues/ISSUE-XXX-*.md`
3. Store the existing issue content
4. Set mode flag to "improve"

**If no issue detected → CREATE MODE:**
1. Parse for file paths (anything containing `/` or ending in common extensions) and store for Step 2
2. Remaining text is the description/idea
3. If empty, use `AskUserQuestion` to gather the initial concept
4. Set mode flag to "create"

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
   - Parse `siw/OPEN_ISSUES_OVERVIEW.md` table to find highest issue number
   - Next issue = highest + 1 (or 001 if no issues exist)
   - Store as `issue_number`

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

**File naming:** `siw/issues/ISSUE-{number}-{short-description}.md`

```markdown
# ISSUE-{number}: Fix {what's broken}

**Status:** Ready | **Priority:** {priority} | **Related:** {tasks if any}

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

**File naming:** `siw/issues/ISSUE-{number}-{short-description}.md`

```markdown
# ISSUE-{number}: {Title}

**Status:** Ready | **Priority:** {priority} | **Related:** {tasks if any}

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
siw/issues/ISSUE-{number}-{sanitized-title}.md
```

**Sanitize title:**
- Lowercase
- Replace spaces with hyphens
- Remove special characters
- Max 40 characters

### 4. Update siw/OPEN_ISSUES_OVERVIEW.md

**For new issues:** Add row to table:
```markdown
| {number} | {Title} | Ready | {Priority} | {Related} |
```

**For updated issues:** Update existing row if title/priority/status changed.

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
- If ready to implement, invoke `/kramme:siw:implement-issue {ISSUE-XXX}`
- If changes needed, run `/kramme:siw:define-issue {ISSUE-XXX}` again

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
