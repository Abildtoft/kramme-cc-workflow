---
name: kramme:define-linear-issue
description: Create or improve a well-structured Linear issue through exhaustive guided refinement
argument-hint: [issue-id] or [description and/or file paths for context]
---

# Define Linear Issue

Create or improve a Linear issue through exhaustive interactive refinement. Can start from scratch with a description, or improve an existing issue by providing its identifier. Supports file references for technical context and proactively explores the codebase to inform issue definition.

## Workflow Boundaries

**This command ONLY creates or updates Linear issues.**

- **DOES**: Interview user, explore codebase for context, compose well-structured issue, create/update in Linear
- **DOES NOT**: Write code, implement features, fix bugs, or make any changes to the codebase

**Linear Issue Creation Override**: Invoking this command IS explicit instruction to create or update a Linear issue. When Phase 7 is reached and the user approves the draft, proceed with `mcp__linear__create_issue` or `mcp__linear__update_issue`. This overrides any global rules requiring "explicit instruction" to create/modify Linear issues.

**Implementation is a separate workflow.** After this command completes, the user can invoke `/kramme:implement-linear-issue` if they want to start implementing.

**CRITICAL**: Do NOT proceed to code implementation after creating the issue. The workflow is complete once the issue URL is returned.

## Audience Priority

**Primary: Product Team** — The issue must be understandable and compelling to non-technical stakeholders.

**Secondary: Development Team** — Technical context helps engineers, but they determine implementation details.

### Content Priority Order

1. **Problem Statement** - What pain point or opportunity exists?
2. **Value Proposition** - Why should we invest time in this?
3. **User/Business Impact** - Who benefits and how?
4. **Success Criteria** - How do we know we've solved the problem?
5. **Technical Context** - High-level implementation direction (not detailed how-to)

### Technical Content Guidelines

- Implementation proposals should be **strategic, not tactical**
- Describe **what** needs to change, not **how** to change it
- Only include code examples for:
  - Specific bugs (show the problematic code)
  - Very concrete, well-defined fixes
- For new features: describe the approach architecturally
- Engineers will determine the detailed implementation

## Process Overview

1. **Input Parsing & Mode Detection**: Detect if improving existing issue or creating new
2. **File References & Issue Type**: Read provided files (if any) and classify the issue type
3. **Linear Context Discovery**: Fetch available teams, labels, and projects
4. **Existing Issue Handling**: For improve mode, fetch issue; for create mode, check duplicates
5. **Codebase Exploration**: Search for related implementations and patterns
6. **Interview**: Multi-round questioning (adapted for issue type and mode)
7. **Issue Composition**: Draft issue following the template
8. **Review & Create/Update**: User approval, then create or update in Linear

## Phase 1: Input Parsing & Mode Detection

**Handling `$ARGUMENTS`:**

### Step 1: Detect Mode

Check if input matches an existing Linear issue:
- **Issue identifier pattern**: `TEAM-123` (uppercase letters, hyphen, numbers)
- **Linear URL**: Contains `linear.app` with issue path
- **UUID**: 36-character UUID format

**If existing issue detected → IMPROVE MODE:**
1. Extract the issue identifier
2. Fetch issue details using `mcp__linear__get_issue` with `id` parameter
3. Store the existing issue content (title, description, labels, etc.)
4. Set mode flag to "improve"
5. **Check for Dev Ask label**
   - Inspect the fetched issue's labels
   - If the issue has the "Dev Ask" label (case-insensitive match):
     - Set `is_dev_ask` flag to true
     - Store the original issue description as `original_dev_ask_content`
     - This content will be preserved in the final issue regardless of refinements

**If no issue detected → CREATE MODE:**
1. Parse for file paths (anything that looks like a path: contains `/`, ends in common extensions) and store them for Step 2
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

After determining the mode (and any file context, if provided), classify the issue type. Auto-detect from context and suggest to the user (they can override):

**Issue Types:**
- **Bug (Simple)**: Root cause is known or easily identified, fix is localized, no architectural decisions needed
- **Bug (Complex)**: Unknown root cause, affects multiple components, requires investigation
- **Feature**: New functionality
- **Improvement**: Enhance existing functionality

**Detection Heuristics:**
- Keywords like "bug", "fix", "broken", "doesn't work", "error", "issue" → suggest Bug
- If user provides root cause and specific file(s) → suggest Bug (Simple)
- If scope is unclear, multiple components mentioned, or investigation needed → suggest Bug (Complex)
- Keywords like "add", "new", "implement", "create" → suggest Feature
- Keywords like "improve", "refactor", "enhance", "optimize" → suggest Improvement

**Present classification to user via `AskUserQuestion`:**
- Show detected type with reasoning
- Allow override to any type
- Store `issue_type` for conditional behavior in later phases

**For Bug (Simple), store these flags:**
- `is_simple_bug = true`
- This enables the streamlined interview and simple template

## Phase 2: Linear Context Discovery

Fetch Linear workspace context to enable informed metadata selection:

1. **Teams**: `mcp__linear__list_teams` - Get available teams for assignment
2. **Labels**: `mcp__linear__list_issue_labels` - Get available labels for classification
3. **Projects**: `mcp__linear__list_projects` - Get active projects for association

Store this context for use in Phase 5 (Metadata & Classification round).

## Phase 3: Existing Issue Handling

This phase differs based on mode:

### IMPROVE MODE

The target issue was already fetched in Phase 1. Now present it to the user:

1. **Present Current Issue**
   - Show the issue title, description, labels, and metadata
   - Format clearly for review
   - If this is a Dev Ask issue (has "Dev Ask" label):
     - Note to user: "This issue was created through Linear Asks. The original request will be preserved in an 'Original Dev Ask' section at the bottom of the refined issue."

2. **Identify Improvement Areas**
   - Use `AskUserQuestion` to ask what aspects to improve:
     - Problem statement clarity
     - Value proposition
     - Scope definition
     - Acceptance criteria
     - Technical context
     - Metadata (labels, priority, etc.)
     - All of the above (full refinement)
   - Store selected areas for focused interview in Phase 5

3. **Search for Related Issues**
   - Use `mcp__linear__list_issues` with keywords from the existing issue
   - Identify issues to link as related or blockers

**Output**: Improvement areas selected, related issues identified.

### CREATE MODE

Before creating a new issue, check for existing Linear issues that may already cover this topic:

1. **Search for Duplicates**
   - Use `mcp__linear__list_issues` with `query` parameter containing keywords from the description
   - Search across relevant teams identified in Phase 2

2. **Identify Related Issues**
   - Look for issues that partially overlap with the proposed scope
   - Find issues that might be blockers or dependencies
   - Identify issues that could be affected by this work

3. **Present Findings to User**
   - If potential duplicates found, show them to the user via `AskUserQuestion`:
     - Option to proceed with new issue (if not truly a duplicate)
     - Option to improve an existing issue instead → **Switch to IMPROVE MODE**
     - Option to link as related issue
   - If related issues found, note them for the Dependencies section

4. **Decision Point**
   - If user confirms this is a duplicate → Stop and direct to existing issue
   - If user wants to improve existing issue → Fetch that issue with `mcp__linear__get_issue`, switch to IMPROVE MODE, and restart from Phase 3
   - If user confirms new issue is needed → Continue to Phase 4
   - Store any related issues for later linking

**Output**: List of related issues to reference, confirmation to proceed.

## Phase 4: Codebase Exploration

**For Simple Bugs (`is_simple_bug = true`):** Skip this phase if the user has already provided the root cause and affected file(s). Only explore if root cause is uncertain.

**For all other issue types:** Proactively search the repository to inform the issue definition:

1. **Find Related Implementations**
   - Use `Grep` to search for keywords from the description
   - Use `Glob` to find files in related areas
   - Identify existing code that does something similar

2. **Identify Patterns & Conventions**
   - Look for architectural patterns in related code
   - Note naming conventions, file organization
   - Find configuration or setup patterns

3. **Discover Related Components**
   - Find services, modules, or components that may be affected
   - Identify integration points
   - Map dependencies

4. **Find Existing Tests**
   - Search for test files covering similar functionality
   - Note testing patterns and conventions

5. **Collect TODOs & FIXMEs**
   - Search for `TODO`, `FIXME`, `HACK` comments related to the topic
   - These may inform scope or reveal known issues

**Output**: Summarize findings to share with user and inform interview questions.

## Phase 5: Interview

The interview process adapts based on the issue type detected in Step 3.

### Simple Bug Interview (if `is_simple_bug = true`)

For simple bugs, use a streamlined 2-round interview instead of the full 5-round process. The goal is to quickly capture the essential information without unnecessary overhead.

**Round 1: Problem & Reproduction**

Questions to cover:
- What's the bug? (brief description)
- Steps to reproduce (numbered list ending with "Bug: [what happens]")
- What should happen instead?

**Round 2: Root Cause & Fix**

Questions to cover:
- What's causing the bug? (if known - 1-2 sentences)
- What needs to change to fix it? (1-2 sentences)
- Which file(s) are affected?

**If root cause is unknown or unclear after Round 2:**
- Reclassify as **Bug (Complex)** and set `is_simple_bug = false`
- Switch to the **Standard Interview** starting at Round 1
- Use the **Comprehensive Template** in Phase 6

After these 2 rounds, skip to **Round 5: Metadata & Classification** (streamlined - just team and labels, skip project/priority unless user wants them).

Then proceed directly to Phase 6 with the simple bug template.

---

### Standard Interview (for all other issue types)

Conduct a thorough, multi-round interview using `AskUserQuestion`. Provide context before each question explaining why it matters and your recommendation if you have one.

### Mode-Specific Behavior

**IMPROVE MODE:**
- Focus on the improvement areas selected in Phase 3
- For each round, show the current content from the existing issue first
- Ask if the user wants to: keep as-is, modify, or expand the current content
- Skip rounds not selected for improvement (but allow user to request them)
- Track what has changed vs. original

**CREATE MODE:**
- Follow the standard interview flow below
- Start from blank for each section

### Round 1: Problem & Value (Most Important)

**This round is critical.** Spend extra time here to deeply understand the "why."

**Questions to cover:**
- What specific problem or pain point does this solve?
- Who is affected (end users, customers, internal teams)?
- How significant is the impact? (frequency, severity, scale)
- What triggers the need for this change now?
- What happens if we don't address this? (cost of inaction)
- What value does solving this deliver? (user benefit, business outcome)
- How does this align with product/company goals?

**Dig deep on value:**
- Don't accept vague answers like "it would be nice" or "users want it"
- Push for concrete impact: numbers, user quotes, business metrics
- Understand the opportunity cost of NOT doing this

**Context to provide:**
- Share relevant findings from codebase exploration
- Reference any related code or patterns discovered

### Round 2: Scope & Boundaries

**Questions to cover:**
- What is explicitly in scope for this issue?
- What is explicitly out of scope?
- Are there related changes that should be separate issues?
- What is the minimum viable implementation?

**Dig deeper when:**
- Scope seems too broad for a single issue
- There are natural breakpoints for phased delivery

### Round 3: Technical Context

**Questions to cover:**
- Which components/areas are affected? (informed by exploration)
- Are there dependencies or blocking issues?
- What existing patterns should be followed?
- Are there technical constraints to consider?

**Leverage exploration findings:**
- Present discovered patterns as options
- Highlight related code that should be considered
- Note any TODOs/FIXMEs that are relevant

### Round 4: Acceptance Criteria

**Questions to cover:**
- What defines "done" for this issue?
- How should this be tested/verified?
- Are there specific edge cases to handle?
- What quality criteria must be met?

**Guide toward testable criteria:**
- Each criterion should be verifiable
- Include both happy path and error scenarios
- Consider performance/security if relevant

### Round 5: Metadata & Classification

**Questions to cover:**
- Which team should own this issue? (present options from Phase 2)
- What labels apply? (present options from Phase 2)
- Should this be associated with a project?
- What priority level is appropriate?
- Are there related issues (blockers, related work)?

**Use predefined options:**
- Present actual team names from `list_teams`
- Present actual labels from `list_issue_labels`
- Present active projects from `list_projects`

### Adaptive Follow-up

After each round:
- **Dig deeper** when answers reveal unexpected complexity
- **Pivot** when answers reveal the problem is different than assumed
- **Clarify** when answers are ambiguous or contradictory

**Track coverage:**
```
Coverage: [Problem: X%] [Scope: X%] [Technical: X%] [Acceptance: X%] [Metadata: X%]
```

Continue until all dimensions show adequate coverage for a well-defined issue.

## Phase 6: Issue Composition

### Template Selection

Choose the template based on `issue_type`:
- **Bug (Simple)**: Use the Simple Bug Template below
- **All others**: Use the Comprehensive Template

---

### Simple Bug Template (for `is_simple_bug = true`)

For simple bugs, use this concise format:

#### Title Format

`Fix [what's broken] when [trigger condition]`

**Examples:**
- "Fix dialog reopening after cancel when navigating between roles"
- "Fix null pointer in user search when query is empty"

#### Description Template

```markdown
## Problem

[1-2 sentence description of the bug]

**Steps to reproduce:**
1. [Step 1]
2. [Step 2]
3. **Bug:** [What happens]

## Root Cause

[1-2 sentences explaining what's causing the bug]

## Fix

[1-2 sentences describing what needs to change]

**File:** `path/to/affected/file.ts`
```

**Notes:**
- If multiple files are affected, list each on its own line with `**File:**` prefix
- If root cause is unknown, reclassify to Bug (Complex), set `is_simple_bug = false`, and switch to the comprehensive interview/template
- Keep each section brief - this template is intentionally minimal

---

### Comprehensive Template (for features, improvements, complex bugs)

### Mode-Specific Behavior

**IMPROVE MODE:**
- Merge interview findings with existing issue content
- For unchanged sections, preserve the original text
- For modified sections, use the new content from the interview
- When presenting the draft, indicate what changed vs. original:
  - `[UNCHANGED]` for preserved sections
  - `[MODIFIED]` for updated sections
  - `[ADDED]` for new sections

**CREATE MODE:**
- Compose the issue from scratch using interview findings

Draft the issue following this template:

### Title Format

`[Action verb] [what] [where/context]`

**Examples:**
- "Add dark mode toggle to settings page"
- "Fix pagination in user list API"
- "Refactor authentication flow to use OAuth2"

### Description Template

**Note:** The template is ordered by importance for a Product Team audience. Problem and Value come first.

```markdown
## Problem
[What pain point or issue exists today]
[Who is affected and how often]
[What is the cost/impact of this problem]

## Value Proposition
[Why solving this matters]
[What benefit users/business will gain]
[How this aligns with product goals]

## Goal
[What success looks like - the desired outcome]
[Clear statement of the end state]

## Scope

### In Scope
- [Specific item 1]
- [Specific item 2]
- [Specific item 3]

### Out of Scope
- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

## Acceptance Criteria
- [ ] [Testable criterion 1 - user-facing behavior]
- [ ] [Testable criterion 2 - user-facing behavior]
- [ ] [Testable criterion 3 - user-facing behavior]

## Edge Cases
- [Edge case 1]: [Expected behavior]
- [Edge case 2]: [Expected behavior]

---

## Technical Notes (For Engineering)

### Implementation Proposal
[High-level approach - what components/areas need changes]
[Architectural considerations if relevant]
[Keep this strategic, not detailed implementation steps]

### Affected Areas
- [Component/module 1]
- [Component/module 2]

### Patterns to Follow
[Reference existing patterns in the codebase]
[Only include code examples for specific bugs or concrete fixes]

### References
- [Related files: `path/to/file.ts`]

## Dependencies
- [Blocking issue or prerequisite, if any]
- [Related issues for context]

<!-- Only include this section if the issue has the "Dev Ask" label -->
## Original Dev Ask

> [Preserve the complete original issue description here exactly as it was submitted]
> [This section is automatically included for issues created via Linear Asks]
```

**Dev Ask Handling:**
- If `is_dev_ask` flag is true, always include the "Original Dev Ask" section at the bottom
- Quote the entire original description using markdown blockquote (`>`)
- Do not modify the original text - preserve it exactly
- This section comes after all other sections, including Dependencies

**Technical Notes Guidelines:**
- Keep implementation proposals **high-level** (what, not how)
- Only include code examples when:
  - Fixing a specific bug (show the problematic code)
  - Making a very concrete, well-defined fix
  - The code example clarifies something that words cannot
- For new features, describe the approach architecturally, not the implementation details
- Engineers will determine the detailed implementation

### Metadata to Set

- **Team**: From Round 5 selection
- **Labels**: From Round 5 selection
- **Project**: From Round 5 selection (if applicable)
- **Priority**: From Round 5 selection (if determined)
- **Related Issues**: From Phase 3 findings (if any)

## Phase 7: Review & Create/Update

### 1. Present Draft

**IMPROVE MODE:**
- Show the updated issue with change indicators
- Highlight what changed vs. original content
- Show before/after for significant modifications

**CREATE MODE:**
- Show the complete issue (title, description, metadata)
- Format clearly for review

### 2. Allow Refinements

- Ask if any changes are needed
- Iterate on feedback until user is satisfied

### 3. Create or Update Issue

**IMPROVE MODE:**
- Use `mcp__linear__update_issue` with:
  - `id`: The existing issue ID
  - `title`: Updated title (if changed)
  - `description`: The updated markdown description (include "Original Dev Ask" section at the bottom if `is_dev_ask` is true)
  - `labels`: Updated labels (if changed)
  - `priority`: Updated priority (if changed)
  - Other metadata as applicable

**CREATE MODE:**
- Use `mcp__linear__create_issue` with:
  - `title`: The composed title
  - `description`: The full markdown description
  - `team`: Selected team ID or name
  - `labels`: Array of selected label names
  - `project`: Selected project (if any)
  - `priority`: Selected priority (if any)

### 4. Return Result

**IMPROVE MODE:**
- Provide the updated issue URL
- Summarize what was changed

**CREATE MODE:**
- Provide the created issue URL
- Confirm successful creation

### 5. Workflow Complete - STOP

**The define-linear-issue workflow is now complete.**

- Do NOT proceed to code implementation
- Do NOT start working on the issue
- Do NOT invoke other commands automatically

**Next steps for the user:**
- Review the created/updated issue in Linear
- If ready to implement, invoke `/kramme:implement-linear-issue {issue-id}`
- If changes needed, run `/kramme:define-linear-issue {issue-id}` again to refine

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

### Template Selection

1. **Use Simple Bug Template when:**
   - The root cause is known or easily identified
   - The fix is localized to 1-3 files
   - No architectural decisions are needed
   - The bug can be fully described in a few sentences

2. **Use Comprehensive Template when:**
   - Root cause is unknown and needs investigation
   - Multiple components are affected
   - The issue is a feature, improvement, or complex bug
   - Scope boundaries need definition
   - Stakeholder alignment is important

### General Guidelines

1. **Lead with "Why"** - Problem and value proposition are the most important parts. Don't settle for vague justifications.
2. **Write for Product Team first** - The issue should be compelling to non-technical stakeholders. They read Problem, Value, Goal, Scope, and Acceptance Criteria.
3. **Technical details are secondary** - Keep implementation proposals high-level. Engineers determine the detailed how.
4. **Code examples only when necessary** - Only for specific bugs or concrete fixes. New features don't need code examples.
5. **Check for duplicates first** - Always search existing issues before creating new ones.
6. **Exhaust the interview** - Don't rush through questions. Especially Round 1 (Problem & Value) for comprehensive issues.
7. **Use exploration findings strategically** - Reference patterns and affected areas, but don't dump implementation details.
8. **Craft real options** - Every AskUserQuestion option should be a legitimate choice.
9. **Connect the dots** - Show how different decisions interact and affect each other.
10. **Challenge diplomatically** - If scope seems too broad, suggest splitting.
11. **Get user approval** - Always show the draft before creating the issue.
12. **Keep simple bugs simple** - Don't over-engineer the issue definition. If root cause and fix are clear, the simple template is sufficient.

## Starting the Process

1. Parse `$ARGUMENTS` and detect mode (issue ID → improve, otherwise → create)
2. If improve mode: fetch the existing issue details
3. If create mode with no input: ask what issue they want to define
4. Process file references (if any)
5. Classify issue type (auto-detect and confirm with user)
6. Begin Phase 2 (Linear Context Discovery)
7. Phase 3: For improve mode, present issue and select areas to improve; for create mode, check for duplicates
8. Phase 4: Codebase exploration (skip for simple bugs if root cause known)
9. Phase 5: Interview (simple 2-round for simple bugs, full 5-round for others)
10. Phase 6: Compose issue using appropriate template
11. Phase 7: Review, refine, and create/update issue
