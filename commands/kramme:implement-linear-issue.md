---
name: kramme:implement-linear-issue
description: Start implementing a Linear issue with branch setup, context gathering, and guided workflow
---

# Implement Linear Issue

Start implementing a Linear issue through an extensive planning phase before any code changes.

**IMPORTANT:** Linear issues are typically written for product teams and may be light on technical implementation details. This command emphasizes thorough planning and codebase exploration to translate product requirements into a concrete technical approach before starting implementation.

## Process Overview

```
/kramme:implement-linear-issue ABC-123
    |
    v
[Validate & Fetch Issue] -> Not found? -> Show error, abort
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
=================== SETUP PHASE ===================
    |
    v
[Branch Setup] -> Use Linear's branchName field, handle uncommitted changes
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

Usage: /kramme:implement-linear-issue <ISSUE-ID>
Example: /kramme:implement-linear-issue ABC-123

The issue ID should be in the format TEAM-NUMBER (e.g., WAN-521, HEA-456).
```

**Action:** Abort.

### 1.2 Fetch Issue Details

**ALWAYS** use the Linear MCP tool to fetch complete issue details:

```
mcp__linear__get_issue with id: {ISSUE_ID}
```

**Capture from issue response:**

- `id` - Linear issue UUID (for API calls)
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

**ALWAYS** fetch comments for additional context:

```
mcp__linear__list_comments with issueId: {ISSUE_ID}
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

Try again with /kramme:implement-linear-issue <correct-issue-id>
```

**Action:** Abort.

---

## Step 2: Parse and Present Issue Context

### 2.1 Parse Issue Description

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

### 2.2 Present Issue Summary

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

## Step 3: Codebase Exploration (PLANNING PHASE)

**CRITICAL:** Linear issues are typically product-focused and lack technical implementation details. **ALWAYS** perform extensive codebase exploration to understand how to implement the feature, regardless of how the issue is written.

### 3.1 Why This Phase Is Essential

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

### 3.2 Mandatory Exploration Steps

**ALWAYS perform these steps, even if the issue seems straightforward:**

1. **Search for similar features/patterns:**

   - Use Glob and Grep to find related code
   - Look for existing implementations of similar functionality
   - Identify relevant modules, services, or components

2. **Use the Explore agent:**

   ```
   Task tool with subagent_type=Explore:
   "Find existing implementations related to {feature description from issue}.
    Identify relevant files, patterns, and conventions used in this codebase."
   ```

3. **Identify key files and patterns:**
   - List files that will likely need modification
   - Note existing patterns to follow
   - Find test patterns for similar features

### 3.3 Present Findings

After exploration, present findings to the user:

```
Codebase Exploration Results:

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

## Step 4: Upfront Questions (PLANNING PHASE)

**CRITICAL:** Tend towards asking questions rather than plunging into implementation. The goal is to fully understand requirements before writing any code.

### 4.1 Identify Ambiguities

Review the issue and exploration results to identify:

- Unclear requirements or acceptance criteria
- Multiple valid technical approaches
- Scope boundaries (what's in/out)
- Dependencies on other work
- Testing expectations

### 4.2 Ask Clarifying Questions

**ALWAYS** use AskUserQuestion for each unclear aspect before proceeding.

**Example questions to consider:**

```yaml
header: "Implementation Scope"
question: "The issue mentions {feature}. Should this include {related functionality} or just the core feature?"
options:
  - label: "Core feature only"
    description: "Minimal implementation as described"
  - label: "Include {related functionality}"
    description: "Broader scope with additional features"
```

```yaml
header: "Technical Approach"
question: "I found two patterns in the codebase for similar features. Which approach should we follow?"
options:
  - label: "Pattern A - {description}"
    description: "Used in {files}"
  - label: "Pattern B - {description}"
    description: "Used in {files}"
```

```yaml
header: "Testing Requirements"
question: "What level of test coverage is expected?"
options:
  - label: "Unit tests only"
    description: "Test individual functions/methods"
  - label: "Unit + integration tests"
    description: "Also test component interactions"
  - label: "Full coverage including E2E"
    description: "Complete test suite"
```

### 4.3 Create Technical Plan

After gathering answers, create a comprehensive technical plan that translates the product requirements into a concrete implementation approach:

```
Technical Implementation Plan for {identifier}

## Summary
{One paragraph describing what will be built}

## Product Requirements -> Technical Approach
| Requirement | Technical Implementation |
|-------------|-------------------------|
| {user story 1} | {how it will be implemented} |
| {user story 2} | {how it will be implemented} |

## Files to Modify/Create
- {file 1} - {what changes}
- {file 2} - {what changes}
- {new file if needed} - {purpose}

## Patterns to Follow
Based on exploration of {similar feature}, follow these patterns:
- {pattern 1}
- {pattern 2}

## Implementation Steps
1. {step 1}
2. {step 2}
3. {step 3}
...

## Testing Approach
- {test type}: {what to test}

## Open Questions (if any)
- {any remaining uncertainties}
```

**Present this plan to the user and get confirmation before proceeding to branch setup.**

---

## Step 5: Branch Setup (SETUP PHASE)

### 5.1 Check Current Git State

**ALWAYS** verify git state before branch operations:

```bash
# Check for uncommitted changes
git status --porcelain

# Check current branch
git branch --show-current

# Check for merge conflicts
git ls-files -u
```

**If uncommitted changes exist:**

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

### 5.2 Determine Target Branch

Use the `branchName` field from Linear issue response.

**Format typically:** `{initials}/{TEAM-number}-{description}`

Example: `mab/wan-521-ensure-that-platform-picker-page-is-only-shown-if-the-user`

**If branchName is empty/missing, generate one:**

- Use pattern: `{user-initials}/{ISSUE_ID}-{sanitized-title}`
- Sanitize: lowercase, replace spaces with hyphens, max 50 chars for description part
- Ask user for their initials if not known

### 5.3 Check if Branch Exists

```bash
# Check if branch exists locally
git rev-parse --verify {branchName} 2>/dev/null

# Check if branch exists on remote
git ls-remote --heads origin {branchName}
```

**If branch exists locally:**

Use AskUserQuestion:

```yaml
header: "Branch Exists"
question: "Branch '{branchName}' already exists locally. What should I do?"
options:
  - label: "Switch to existing branch"
    description: "Continue work on the existing branch"
  - label: "Delete and recreate"
    description: "Start fresh from main/master"
  - label: "Use different name"
    description: "Create branch with '-v2' suffix"
```

**If branch exists only on remote:**

```bash
git checkout -b {branchName} origin/{branchName}
```

### 5.4 Create New Branch

**If branch doesn't exist:**

```bash
# Determine base branch
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || BASE="main"

# Fetch latest
git fetch origin $BASE

# Create branch from latest base
git checkout -b {branchName} origin/$BASE
```

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
    description: "I'll analyze the codebase, plan, implement, and verify. Check in when done. Best for straightforward tasks."
```

---

## Step 7: Workflow Execution by Approach

### 7.1 Guided Implementation (Option 1)

**Goal:** Create detailed plan, implement with user verification at each step.

1. **Create Implementation Plan**

   - Break requirements into discrete tasks
   - Identify dependencies between tasks
   - Consider using `kramme:structured-implementation-workflow` for complex issues

2. **Create Todo List**

   Use TodoWrite with tasks from the plan:

   ```
   - Analyze existing patterns for {feature area}
   - Implement {task 1 from requirements}
   - Add tests for {task 1}
   - Implement {task 2 from requirements}
   - ...
   - Run verification (kramme:verify)
   ```

3. **Begin Implementation**
   - Work through tasks one at a time
   - **ALWAYS** ask user to review after completing each task
   - Update todo list as tasks complete

### 7.2 Context Setup Only (Option 2)

**Goal:** Prepare everything, let user drive implementation.

1. **Create Minimal Context**

   - Branch is already created (Step 5)
   - Create todo list from extracted requirements

2. **Use TodoWrite for Requirements**

   Create tasks from acceptance criteria:

   ```
   - [ ] {Acceptance criterion 1}
   - [ ] {Acceptance criterion 2}
   - [ ] {Requirement from description}
   - [ ] Verify implementation meets requirements
   - [ ] Run verification checks
   ```

3. **Provide Starting Points**

   ```
   Context is set up. Here's where to start:

   Branch: {branchName}
   Linear Issue: {url}

   Likely affected areas based on requirements:
   - {file/module 1} - {why}
   - {file/module 2} - {why}

   Similar implementations to reference:
   - {existing feature 1} - {relevance}

   Ready when you want to begin. Just tell me what to work on.
   ```

### 7.3 Autonomous Implementation (Option 3)

**Goal:** Complete implementation with minimal interaction, verify at end.

1. **Deep Codebase Analysis**

   - Search for related files using Glob and Grep
   - Read similar implementations for patterns
   - Identify all files that need modification
   - Understand testing patterns in the codebase

2. **Create Comprehensive Plan**

   - Use TodoWrite with detailed task breakdown
   - Include exploration, implementation, testing, and verification

3. **Implement Iteratively**

   - Work through all tasks
   - Make implementation decisions based on existing patterns
   - Run tests after each significant change
   - Document decisions in commit messages

4. **Verification Phase**

   - Invoke `kramme:verify` skill for full verification
   - Fix any issues found
   - Ensure all acceptance criteria are met

5. **Present Results**

   ```
   Implementation Complete

   Linear Issue: {identifier}
   Branch: {branchName}

   Changes Made:
   - {summary of changes}

   Files Modified:
   - {list of key files}

   Verification Results:
   - Tests: {status}
   - Lint: {status}
   - Build: {status}

   Acceptance Criteria:
   - [x] {criterion 1}
   - [x] {criterion 2}

   Ready for your review. Run `/kramme:create-pr` when ready to submit.
   ```

---

## Step 8: Success Output

After setup is complete:

```
Linear Issue Implementation Started

Issue: {identifier} - {title}
Branch: {branchName}
Approach: {selected approach}

{Approach-specific next steps from Step 7}

Quick Commands:
- `/kramme:verify` - Run verification checks
- `/kramme:create-pr` - Create PR when ready
- `/kramme:find-bugs` - Review changes for issues
```

---

## Important Constraints

### No AI Attribution

**NEVER** add Claude attribution to commits or code. See `kramme:recreate-commits` skill.

### Linear Issue Linking

When creating commits, **PREFER** including issue reference:

- `WAN-123: Add platform picker guard`
- `Fixes WAN-123`

### Verification Before Completion

**ALWAYS** run verification before claiming completion. Use `kramme:verify` skill.

### Respect Existing Patterns

**ALWAYS** search for and follow existing patterns in the codebase before implementing.

---

## Error Handling

### Git Errors

- Merge conflicts: Ask user to resolve manually
- Push failures: Suggest manual push command
- Branch conflicts: Offer rename options

### Linear API Errors

- Rate limits: Wait and retry
- Authentication: Direct user to check MCP setup
- Not found: Verify issue ID and access

### Implementation Errors

- Test failures: Present errors, ask how to proceed
- Build failures: Show full error output
- Lint errors: Fix automatically if minor, ask if significant
