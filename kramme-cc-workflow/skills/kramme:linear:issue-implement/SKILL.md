---
name: kramme:linear:issue-implement
description: Requires Linear MCP. Start implementing a Linear issue with branch setup, planning, and guided or --auto workflows. For SIW-tracked work, use kramme:siw:issue-implement instead.
argument-hint: "<ISSUE-ID> [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Implement Linear Issue

Start implementing a Linear issue through an extensive planning phase before any code changes.

**IMPORTANT:** Linear issues are typically written for product teams and may be light on technical implementation details. This command emphasizes thorough planning and codebase exploration to translate product requirements into a concrete technical approach before starting implementation.

**Prerequisite:** Requires the Linear MCP server. For work tracked through the Structured Implementation Workflow, use `kramme:siw:issue-implement` instead — this skill implements a single Linear issue directly.

Parse `$ARGUMENTS` before Step 1. If `--auto` is present, set `AUTO_MODE=true` and remove the flag before extracting the Linear issue id. `--auto` skips plan and approach confirmation when the technical path is clear, then chooses Autonomous Implementation. It does not bypass dirty-worktree handling, branch verification, missing Linear metadata, or genuinely blocking product/technical ambiguities.

## Process Overview

```
/kramme:linear:issue-implement ABC-123
    |
    v
[Validate & Fetch Issue] -> Not found? -> Show error, abort
    |
    v
[Branch Setup] -> IMMEDIATELY create/switch to Linear's branchName
    |
    v
[Parse Requirements] -> Extract acceptance criteria from description
    |
    v
=============== PLANNING PHASE (extensive) ===============
    |
    v
[Codebase Exploration] -> ALWAYS search for patterns/implementations
    |
    v
[Technical Analysis] -> Map product requirements to technical approach
    |
    v
[Upfront Questions] -> Clarify ambiguities before proceeding
    |
    v
[Create Technical Plan] -> Document approach, files, patterns to follow
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

## Step 1: Parse Arguments and Fetch Issue

### 1.1 Extract Issue ID from Arguments

`$ARGUMENTS` contains the issue ID provided by the user.

**Validation:**

- Pattern: `{TEAM}-{number}` where TEAM is any alphanumeric prefix
- Case-insensitive (convert to uppercase for display)
- Examples: `wan-123` -> `WAN-123`, `abc-456` -> `ABC-456`

**If no argument provided or invalid format:**

```
Error: Please provide a Linear issue ID.

Usage: /kramme:linear:issue-implement <ISSUE-ID>
Example: /kramme:linear:issue-implement ABC-123

The issue ID should be in the format TEAM-NUMBER (e.g., WAN-521, HEA-456).
```

**Action:** Abort.

### 1.2 Fetch Issue Details

Use the Linear MCP tool to fetch complete issue details. `{ISSUE_ID}` is the human-readable identifier from `$ARGUMENTS` (e.g. `WAN-123`), which `get_issue` accepts directly:

```
Claude Code: mcp__linear__get_issue with id: {ISSUE_ID}
Codex: get_issue with id: {ISSUE_ID}
```

**If Linear MCP operations are unavailable**, the Linear MCP server is not connected. Stop and tell the user to connect it — do not continue without issue data.

**Capture from issue response:**

- `id` - Linear issue UUID. Use this (referred to below as `{issueUuid}`) for any later call that needs the UUID rather than the identifier.
- `identifier` - Human-readable ID (e.g., WAN-123)
- `title` - Issue title
- `description` - Full issue description (markdown)
- `state` - Current state (Backlog, In Progress, etc.)
- `labels` - Associated labels
- `branchName` - **CRITICAL**: Linear's recommended branch name
- `url` - Link to issue in Linear
- `project` - Associated project
- `priority` - Issue priority

### 1.3 Fetch Issue Comments

Fetch comments for additional context, using the UUID captured in Step 1.2:

```
Claude Code: mcp__linear__list_comments with issueId: {issueUuid}
Codex: list_comments with issueId: {issueUuid}
```

Comments often contain:

- Clarifications from product/design
- Technical discussions
- Updated requirements
- Scope changes

### 1.4 Handle Missing Issue

**If issue not found:**

```
Error: Linear issue {ISSUE_ID} not found.

Please verify:
  - The issue ID is correct (format: TEAM-123)
  - You have access to the issue's team
  - The issue exists in Linear

Try again with /kramme:linear:issue-implement <correct-issue-id>
```

**Action:** Abort.

---

## Step 2: Branch Setup (MANDATORY - DO IMMEDIATELY)

**CRITICAL:** This step MUST be completed before any other actions. Do NOT proceed to issue parsing, planning, or any other step until you are on the correct branch.

### 2.1 Extract Branch Name from Linear

The Linear MCP `get_issue` response includes a `branchName` field - this is Linear's recommended branch name.

**Priority:**

1. **FIRST**: Use `branchName` from Linear if present and non-empty
2. **FALLBACK ONLY**: If `branchName` is empty/missing, generate one using pattern: `{user-initials}/{ISSUE_ID}-{sanitized-title}`

**If generating fallback:**

- Ask user for their initials if not known. If `AUTO_MODE=true` and initials are not known, use `auto` as the prefix instead of asking.
- Sanitize title: lowercase, replace spaces with hyphens, max 50 chars for description

### 2.2 Check Current Git State

```bash
git status --porcelain
git branch --show-current
```

**If uncommitted changes exist:**

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: uncommitted changes exist; rerun without --auto to choose stash, commit, discard, or abort`.

Otherwise:

Use AskUserQuestion:

```yaml
header: "Uncommitted Changes"
question: "You have uncommitted changes. How should I handle them?"
options:
  - label: "Stash changes"
    description: "Save changes to stash, can be restored later"
  - label: "Commit changes"
    description: "Commit current changes before switching branches"
  - label: "Discard changes"
    description: "Warning: This will lose your uncommitted work"
  - label: "Abort"
    description: "Cancel and let me handle it manually"
```

### 2.3 Create and Switch to Branch

**If branch doesn't exist locally or remotely:**

```bash
# Determine base branch
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's|refs/remotes/origin/||' || true)
[ -n "$BASE" ] || BASE="main"

# Fetch latest
git fetch origin $BASE

# Create branch from latest base
git checkout -b "{branchName}" "origin/$BASE"
```

**If branch exists locally:**

```bash
git checkout "{branchName}"
```

**If branch exists only on remote:**

```bash
git checkout -b "{branchName}" "origin/{branchName}"
```

### 2.4 Verify Branch Creation (REQUIRED)

**ALWAYS run this verification:**

```bash
git branch --show-current
```

**The output MUST match the target `branchName`.** If not, something failed - report to user and abort.

### 2.5 Confirm Branch to User

Display confirmation:

```
✓ Branch: {branchName}
  Source: {Linear's suggested name | Generated from issue}

Proceeding with issue analysis...
```

**Only after this confirmation may you proceed to the next step.**

---

## Step 3: Parse and Present Issue Context

### 3.1 Parse Issue Description

Analyze the issue description to extract:

**Requirements:**

- Look for bullet points, numbered lists
- Sections labeled "Requirements", "Acceptance Criteria", "Tasks"
- User story format ("As a... I want... So that...")

**Acceptance Criteria:**

- Explicit criteria sections
- "Done when..." statements
- Verification checkpoints

**Technical Notes:**

- Implementation hints
- API specifications
- Database changes mentioned
- Related files or components

### 3.2 Present Issue Summary

Show the user what was found:

```
Linear Issue: {identifier}

Title: {title}

Description:
---
{description - first 500 chars}
{if longer: "... [truncated, full description will be used]"}
---

State: {state}
Priority: {priority}
Labels: {labels}
Project: {project}

Recommended Branch: {branchName}

Comments: {count} comments found
{if comments exist: show key points from recent comments}

Requirements Identified:
- {requirement 1}
- {requirement 2}
- ...

Acceptance Criteria:
- {criterion 1}
- {criterion 2}
- ...
```

---

## Step 4: Codebase Exploration (PLANNING PHASE)

Linear issues are typically product-focused and lack technical implementation details. Perform extensive codebase exploration to understand how to implement the feature, regardless of how the issue is written.

### 4.1 Why This Phase Is Essential

Linear issues often describe:

- **What** the user should be able to do (user stories)
- **Why** it matters (business value)
- **Acceptance criteria** (verification conditions)

They typically do NOT describe:

- Which files/modules to modify
- What patterns to follow
- How existing similar features are implemented
- Technical constraints or dependencies

**Your job is to bridge this gap through thorough exploration.**

### 4.2 Mandatory Exploration Steps

Perform these steps even if the issue seems straightforward:

1. **Search for similar features/patterns:**
   - Use the available code-search tools (e.g. Glob and Grep) to find related code
   - Look for existing implementations of similar functionality
   - Identify relevant modules, services, or components

2. **Dispatch a codebase-exploration subagent** (or run the search directly if subagents are unavailable):

   Ask it to find existing implementations related to {feature description from issue} and identify the relevant files, patterns, and conventions used in this codebase. In Claude Code this is the `Explore` agent via the Task tool.

3. **Identify key files and patterns:**
   - List files that will likely need modification
   - Note existing patterns to follow
   - Find test patterns for similar features

### 4.3 Present Findings

After exploration, present findings to the user:

Read the Codebase Exploration Results template from `references/display-templates.md`.

---

## Step 5: Upfront Questions (PLANNING PHASE)

Tend towards asking questions rather than plunging into implementation. Fully understand requirements before writing any code.

### 5.1 Identify Ambiguities

Review the issue and exploration results to identify:

- Unclear requirements or acceptance criteria
- Multiple valid technical approaches
- Scope boundaries (what's in/out)
- Dependencies on other work
- Testing expectations

### 5.2 Ask Clarifying Questions

Use AskUserQuestion for each unclear aspect before proceeding. In `AUTO_MODE`, first choose conservative defaults when the codebase and issue text clearly support them: prefer the smallest in-scope implementation, prefer the existing local pattern with the strongest precedent, and prefer the narrowest test set that covers the acceptance criteria. If an ambiguity would change product scope, data model, security posture, public API, or user-visible behavior, ask even in `AUTO_MODE`.

Read example question patterns from `references/question-examples.md` when composing prompts.

### 5.3 Create Technical Plan

After gathering answers, create a comprehensive technical plan that translates the product requirements into a concrete implementation approach:

Read the technical plan template from `assets/technical-plan.md` and populate it based on the gathered context and user answers.

**Present this plan to the user and get confirmation before proceeding to implementation approach selection.** If `AUTO_MODE=true`, present the plan, add `AUTO: proceeding with autonomous implementation`, and continue without the confirmation prompt only when no blocking ambiguity remains.

---

## Step 6: Implementation Approach Selection

### 6.1 Present Approach Options

Use AskUserQuestion:

```yaml
header: "Implementation Approach"
question: "How would you like to proceed with implementing this issue?"
options:
  - label: "Guided Implementation"
    description: "I'll create a detailed plan with tasks, then implement step-by-step with verification at each stage. Best for complex features."
  - label: "Context Setup Only"
    description: "I'll set up the branch and create a todo list, but you'll guide the implementation. Best when you know the approach."
  - label: "Autonomous Implementation"
    description: "I'll analyze the codebase, plan, implement, commit as I go, and verify. Check in when done. Best for straightforward tasks."
```

If `AUTO_MODE=true`, skip this question and choose **Autonomous Implementation**.

---

## Step 7: Workflow Execution by Approach

Read the implementation workflow for the selected approach from `references/implementation-workflows.md`. Follow the Guided, Context Setup, or Autonomous workflow based on the user's choice from Step 6.

---

## Step 8: Success Output

After setup is complete:

Read the Success Output template from `references/display-templates.md`.

---

## Important Constraints

### No AI Attribution

Never add AI/Claude attribution to commits or code.

### Linear Issue Linking

When creating commits, **PREFER** including issue reference:

- `WAN-123: Add platform picker guard`
- `Fixes WAN-123`

### Verification Before Completion

**ALWAYS** run verification before claiming completion. Use `kramme:verify:run` skill.

### Respect Existing Patterns

**ALWAYS** search for and follow existing patterns in the codebase before implementing.

---

## Error Handling

Read the error handling guidance from `references/error-handling.md`.
