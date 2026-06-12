---
name: kramme:linear:issue-define
description: "Requires the Linear MCP server. Create or improve a well-structured Linear issue through guided refinement. Use with --quick to create one new Linear issue from rough input using light clarification, duplicate checking, metadata selection, and approval instead of the full interview. Not for implementing Linear issues (use kramme:linear:issue-implement), multi-bug QA intake (use kramme:qa:intake), or root-cause bug triage (use kramme:debug:triage-to-issue)."
argument-hint: "[issue-id] or [description and/or file paths for context] [--quick]"
disable-model-invocation: true
user-invocable: true
---

# Define Linear Issue

Create or improve a Linear issue through exhaustive interactive refinement. Can start from scratch with a description, or improve an existing issue by providing its identifier. Supports file references for technical context and proactively explores the codebase to inform issue definition. Use `--quick` for a fast new-issue path with light clarification and the same approval discipline.

## Workflow Boundaries

**This command ONLY creates or updates Linear issues.**

- **DOES**: Interview user, explore codebase for context, compose well-structured issue, create/update in Linear
- **DOES NOT**: Write code, implement features, fix bugs, or make any changes to the codebase

**Linear Issue Creation Override**: Invoking this command IS explicit instruction to create or update a Linear issue. When Phase 7 is reached and the user approves the draft, proceed with `mcp__linear__create_issue` or `mcp__linear__update_issue`. This overrides any global rules requiring "explicit instruction" to create/modify Linear issues.

**Implementation is a separate workflow.** After this command completes, the user can invoke `/kramme:linear:issue-implement` if they want to start implementing.

**CRITICAL**: Do NOT proceed to code implementation after creating the issue. The workflow is complete once the issue URL is returned.

## Audience Priority

**Primary: Product Team** — The issue must be understandable and compelling to non-technical stakeholders.

**Secondary: Development Team** — Technical context helps engineers, but they determine implementation details.

### Content Priority Order

1. **Problem Statement** - What pain point or opportunity exists?
2. **Value Proposition** - Why should we invest time in this?
3. **User/Business Impact** - Who benefits and how?
4. **Scope / Non-Goals** - What is intentionally excluded so the issue stays focused?
5. **Success Criteria** - How do we know we've solved the problem?
6. **Technical Context** - High-level implementation direction (not detailed how-to)

### Technical Content Guidelines

- Implementation proposals should be **strategic, not tactical**
- Describe **what** needs to change, not **how** to change it
- Only include code examples for:
  - Specific bugs (show the problematic code)
  - Very concrete, well-defined fixes
- For new features: describe the approach architecturally
- Engineers will determine the detailed implementation

## Process Overview

1. **Input Parsing & Mode Detection**: Detect if improving existing issue, creating new, or quick-creating new with `--quick`
2. **File References & Issue Type**: Read provided files (if any) and classify the issue type unless `--quick` is active
3. **Linear Context Discovery**: Fetch available teams, labels, and projects
4. **Existing Issue Handling**: For improve mode, fetch issue; for create mode, check duplicates
5. **Codebase Exploration**: Search for related implementations and patterns
6. **Quick-create exit or Autonomous Framing**: In `--quick` create mode, follow `references/quick-create.md` and skip the exhaustive interview; otherwise infer target user, why-now, likely non-goals, and decision boundaries from the evidence gathered
7. **Interview**: Multi-round questioning (adapted for issue type and mode)
8. **Issue Composition**: Draft issue following the template
9. **Review & Create/Update**: User approval, then create or update in Linear

## Phase 1: Input Parsing & Mode Detection

**Handling `$ARGUMENTS`:**

First parse flags:

- If `$ARGUMENTS` contains `--quick`, remove it from the working description and set `quick_create = true`.
- `--quick` is only valid for new Linear issues. If the remaining input identifies an existing Linear issue, stop and ask the user to rerun without `--quick` for improvement mode.

**Prerequisite check:** before detecting mode or fetching an existing issue, if the `mcp__linear__*` tools are unavailable, the Linear MCP server is not connected. Stop here and tell the user to connect it — do not start the interview or issue lookup without a working Linear connection.

### Step 1: Detect Mode

Check if input matches an existing Linear issue:

- **Issue identifier pattern**: `TEAM-123` (uppercase letters, hyphen, numbers)
- **Linear URL**: Contains `linear.app` with issue path
- **UUID**: 36-character UUID format

**If existing issue detected → IMPROVE MODE:**

1. Extract the issue identifier
2. Fetch issue details using `mcp__linear__get_issue` with `id` parameter. If the call errors or returns no issue, stop and report the exact identifier that failed — do not continue in IMPROVE mode or silently fall back to CREATE mode.
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
3. If empty, ask the user in plain prose what issue they want to define — an open-ended idea, not a multiple-choice prompt
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

If `quick_create = true`, skip this step and proceed directly to Phase 2. Quick create does not need issue-type classification because it uses the concise body rules in `references/quick-create.md`.

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

If `quick_create = true`, resolve the create team here because Round 5 is skipped:

1. Use the only team if exactly one exists, or an obvious team from the branch, workspace, or user input.
2. Otherwise ask one short question for the target team.
3. If no team can be resolved, emit `MISSING REQUIREMENT: Linear team is required to create the issue` and stop.
4. Store selected labels, project, and priority only when the user named them or they clearly match available Linear metadata.

## Phase 3: Existing Issue Handling

This phase differs based on mode:

### IMPROVE MODE

The target issue was already fetched in Phase 1. Now present it to the user:

1. **Present Current Issue**
   - Show the issue title, description, labels, and metadata
   - Format clearly for review
   - If this is a Dev Ask issue (has "Dev Ask" label):
     - Note to user: "This issue was created through Linear Asks. The original request will be preserved in an 'Original Dev Ask' section at the bottom of the refined issue."

2. **Resume from prior session triage**

   The fetched issue body may contain AI-authored content from a prior session of this skill — for example an `## Original Dev Ask` block or a prior `## Problem`/`## Value`/`## Scope` set.

   Before launching the interview:
   - Scan the description for the canonical comprehensive-template section headings.
   - For each section already populated with substantive prior-session content (not placeholder text or one-line stubs), record which interview round it covered:
     - `## Problem` / `## Value` → Round 1 (Problem & Value)
     - `## Scope` / `## Out of Scope` → Round 2 (Scope & Boundaries)
     - `## Technical Notes` / `## Affected Areas` → Round 3 (Technical Context)
     - `## Acceptance Criteria` / `## Edge Cases` → Round 4 (Acceptance Criteria)
     - existing `labels`/`priority`/`project` → Round 5 (Metadata)
   - Store the parsed sections as `prior_session_context`, keyed by round.

   In Phase 5, the interview must:
   - Skip rounds whose corresponding section is already populated with substantive prior-session content, unless the user selected that area as an improvement target in Step 3 below.
   - When skipping, show the user a one-line summary like `Round 2 (Scope & Boundaries): carrying forward from prior session — say "revisit" to re-open` so the user can re-open any round on demand.
   - Do not re-ask resolved questions. Treat ambiguity in prior content as a reason to surface that section for refinement, not as a reason to start the round from scratch.

3. **Identify Improvement Areas**
   - Use `AskUserQuestion` to ask what aspects to improve:
     - Problem statement clarity
     - Value proposition
     - Scope definition
     - Acceptance criteria
     - Technical context
     - Metadata (labels, priority, etc.)
     - All of the above (full refinement)
   - Store selected areas for focused interview in Phase 5
   - Selected areas always take precedence over prior-session skips — if the user says "improve scope", run Round 2 even when prior content exists.

4. **Search for Related Issues**
   - Use `mcp__linear__list_issues` with keywords from the existing issue
   - Identify issues to link as related or blockers

**Output**: Improvement areas selected, related issues identified, prior-session context recorded.

### CREATE MODE

Before creating a new issue, check for existing Linear issues that may already cover this topic:

1. **Search for Duplicates**
   - Use `mcp__linear__list_issues` with `query` parameter containing keywords from the description
   - Search across relevant teams identified in Phase 2
   - Also check `.out-of-scope/` in the project root: list filenames; read any whose slug plausibly matches the description; surface matches alongside Linear duplicate findings via the same AskUserQuestion prompt in step 3 (option labels: "proceed with new issue", "this matches a prior rejection — stop"). Skip silently if the directory is absent. See `/kramme:docs:out-of-scope` for the storage skill.

2. **Identify Related Issues**
   - Look for issues that partially overlap with the proposed scope
   - Find issues that might be blockers or dependencies
   - Identify issues that could be affected by this work

3. **Present Findings to User**
   - If `quick_create = true` and a strong duplicate is found, show the issue and ask whether to stop, create anyway, or rerun without `--quick` to improve the existing issue. If the user wants to improve, stop; do not switch into IMPROVE mode during the same quick run.
   - If `quick_create = false` and potential duplicates are found, show them to the user via `AskUserQuestion`:
     - Option to proceed with new issue (if not truly a duplicate)
     - Option to improve an existing issue instead → **Switch to IMPROVE MODE**
     - Option to link as related issue
   - If related issues found, note them for the Dependencies section

4. **Decision Point**
   - If user confirms this is a duplicate → Stop and direct to existing issue
   - If `quick_create = false` and user wants to improve existing issue → Fetch that issue with `mcp__linear__get_issue`, switch to IMPROVE MODE, and restart from Phase 3
   - If `quick_create = true` and user confirms a new issue is needed → Continue to QUICK CREATE MODE below
   - If `quick_create = false` and user confirms a new issue is needed → Continue to Phase 4
   - Store any related issues for later linking

**Output**: List of related issues to reference, confirmation to proceed.

### QUICK CREATE MODE

If `quick_create = true` and mode is CREATE:

1. Complete Phase 2 team resolution and Phase 3 duplicate handling first.
2. Read the quick-create workflow from `references/quick-create.md`.
3. Follow that workflow to clarify, draft, approve, create, and return the Linear URL.
4. Skip Phases 4-7 below and stop after returning the created Linear issue.

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

Before starting the interview, synthesize a working hypothesis for:

- target user or stakeholder
- job-to-be-done / problem pressure
- why this matters now
- obvious non-goals or work that should be split out
- which decisions belong in the issue versus which should stay implementation-level

Present these as assumptions and refine them only where the evidence is weak.

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

Read the 5-round interview structure from `references/interview-rounds.md`. It covers Problem & Value, Scope & Boundaries, Technical Context, Acceptance Criteria, and Metadata & Classification — each with questions to cover and guidance on when to dig deeper.

### Adaptive Follow-up

After each round:

- **Dig deeper** when answers reveal unexpected complexity
- **Pivot** when answers reveal the problem is different than assumed
- **Clarify** when answers are ambiguous or contradictory

**Track coverage.** Continue until each dimension meets its exit bar:

- **Problem**: a named user/stakeholder, a frequency or severity signal, and a cost-of-inaction statement are captured
- **Scope**: at least one explicit in-scope item and one explicit out-of-scope item
- **Technical**: affected modules/areas are named, plus any blocking dependencies
- **Acceptance**: every criterion is individually verifiable, covering the happy path and at least one failure/edge case
- **Metadata**: team selected, and labels/priority/project resolved or explicitly skipped

## Phase 6: Issue Composition

### Durability rule

Authored issue content must NOT include file paths, line numbers, or internal helper/class names. Describe modules, behaviors, and contracts. Reason: file paths and line numbers rot quickly; the issue should remain useful after major refactors.

This rule applies to every section composed or refined in this phase — Problem, Value, Goal, Scope, Acceptance Criteria, Edge Cases, Technical Notes, and Dependencies.

Exception: if `is_dev_ask` is true, preserve the Original Dev Ask archival block exactly as submitted, even when it contains file paths or helper names. Do not repeat those brittle references in the refined issue body; translate them into durable module, behavior, or contract language in the authored sections.

- ❌ Bad: "Fix bug in `src/services/orderService.ts:142` where `applyDiscount()` returns NaN"
- ✅ Good: "Order discount calculation returns NaN when applied to gift-card orders; affects checkout total and order summary email"

When the codebase exploration in Phase 4 surfaced specific files or functions, translate them into module names and behaviors before writing them into the issue. Engineers reading the issue can re-discover the file location from the module name; the inverse — recovering intent from a stale path — is much harder.

### Template Selection

Choose the template based on `issue_type`:

- **Simple Bug Template** — when the root cause is known or easily identified, the fix is localized, no architectural decisions are needed, and the bug fits in a few sentences (`is_simple_bug = true`)
- **Comprehensive Template** — for features, improvements, and complex bugs: unknown root cause needing investigation, multiple affected components, scope boundaries to define, or stakeholder alignment that matters

---

Read the simple bug template from `assets/simple-bug-template.md`. Use for `is_simple_bug = true`. It provides a concise format with title format, description template (Problem, Root Cause, Fix), and notes on when to reclassify.

---

### Comprehensive Template (for features, improvements, complex bugs)

Read the comprehensive issue template from `assets/comprehensive-template.md`. It covers mode-specific behavior (IMPROVE vs CREATE), title format, description template (Problem, Value, Goal, Scope, Acceptance Criteria, Edge Cases, Technical Notes, Dependencies, Dev Ask), and technical notes guidelines.

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

**If the create or update call fails:**

- Output the full drafted issue markdown (title, description, and intended metadata) to the user so the interview work is not lost
- Report the error Linear returned
- Offer to retry; do not silently abandon the draft or proceed to the next step

### 4. Return Result

**IMPROVE MODE:**

- Provide the updated issue URL
- Summarize what was changed

**CREATE MODE:**

- Provide the created issue URL
- Confirm successful creation

### 5. Workflow Complete - STOP

**The linear:issue-define workflow is now complete.**

- Do NOT proceed to code implementation
- Do NOT start working on the issue
- Do NOT invoke other commands automatically

**Next steps for the user:**

- Review the created/updated issue in Linear
- If ready to implement, invoke `/kramme:linear:issue-implement {issue-id}`
- If changes needed, run `/kramme:linear:issue-define {issue-id}` again to refine

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

Read the 15 issue-writing guidelines from `references/writing-guidelines.md` and apply them throughout the interview and composition phases. They cover leading with "why", explicit non-goals, inferring before asking, product-first writing, duplicate checking, and keeping simple bugs simple.
