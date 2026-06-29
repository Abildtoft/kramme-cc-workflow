---
name: kramme:siw:issue-define
description: Define or improve a local SIW issue file through a guided interview. For Linear or other external trackers use kramme:linear:issue-define.
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

**Implementation is a separate workflow.** This skill ends when the issue file is written and the tracker/log are updated. After it completes, the user can invoke `/kramme:siw:issue-implement` if they want to start implementing.

## Prerequisites

**Workflow files should exist.** If `siw/OPEN_ISSUES_OVERVIEW.md` doesn't exist, suggest running `/kramme:siw:init` first. If the file is still missing after that suggestion, stop without creating an issue.

## SIW Issue-State Protocol

This skill owns the manual SIW issue creation/update protocol. Synced SIW issue-state contract (keep aligned across SIW issue creators): every SIW issue creation or tracker-visible issue update keeps the issue file, siw/OPEN_ISSUES_OVERVIEW.md, and siw/LOG.md synchronized as one issue-state change; partial write failures must be surfaced instead of accepted silently.

## Audience Priority

**Primary: Future You** — The issue must be clear enough to understand days or weeks later.

**Secondary: Other Developers** — Technical context helps others understand the work.

### Content Priority Order

1. **Problem Statement** - What pain point or opportunity exists?
2. **Context** - What's the current state and why does this matter?
3. **Scope / Non-Goals** - What's in, what's out, and what should wait?
4. **Acceptance Criteria** - How do we know we've solved the problem?
5. **Technical Notes** - Implementation direction (not detailed how-to)

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

Read `references/classification-and-prefix.md`, then auto-detect issue type from context, present the detected type with reasoning, allow user override, and store `issue_type`. For Bug (Simple), store `is_simple_bug = true` so Phase 4 and Phase 5 use the streamlined path.

### Step 4: Phase Recommendation (Create Mode)

Only for CREATE MODE. Skip for IMPROVE MODE.

Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.

Use the phase-prefix recommendation flow in `references/classification-and-prefix.md`. It defines the spec/log/overview inputs to check, completed-phase heuristics, the prefix confirmation prompt, and how to store `issue_prefix`.

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
   - Compute candidate = highest + 1 (or 001 if no issues with that prefix exist), padded to 3 digits
   - **Verify no on-disk collision:** glob `siw/issues/ISSUE-{issue_prefix}-{candidate}-*.md`. If any file matches, the tracker is out of sync with `siw/issues/`. Increment the candidate and re-check until no file matches, then warn the user that the tracker may need a reindex via `/kramme:siw:issue-reindex`.
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

Before the interview, synthesize a working hypothesis for:

- who is affected
- why this matters now
- what should be explicitly deferred or split into another issue
- which choices belong in the issue versus which should stay implementation-level

Use these as assumptions to validate instead of asking the user to restate obvious context.

## Phase 4: Interview

Read `references/interview-guide.md` and follow the simple-bug or standard interview path based on `issue_type` and `is_simple_bug`. Store priority, size, related work, blockers, parallelization category, and Mode for Phase 5. Confirm inferred metadata before composing.

## Phase 5: Issue Composition

Read `references/issue-templates.md` and select the appropriate template:

- Use the **Simple Bug Template** when `is_simple_bug = true`.
- Use the **Comprehensive Template** otherwise.

Both templates include the `Mode:` field. When emitting the issue, fill `Mode: AUTO` or `Mode: HITL — <one-line reason>` from Round 5.

The references file also defines the **Durability rule**: issue bodies must describe modules, behaviors, and contracts — not file paths, line numbers, or internal helper/class names. Apply it to every section of the composed issue (Problem, Context, Technical Notes, References).

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

Issues are grouped by prefix (General, Phase 1, Phase 2, etc.).

**For new issues:** Add a row to the appropriate section. If the section doesn't exist yet, create the section header and table first.

**For updated issues:** Update the existing row if any tracker-visible metadata changed, including title, status, size, priority, mode, related/dependency metadata, or any other field shown in the current table layout.

Read `references/tracker-schema.md` for the column-layout rules (three coexisting layouts, when to use each, when to migrate), the parallelization-summary recomputation rules, and the `(DONE)` phase-marker rules.

### 5. Update siw/LOG.md

For new issues, add an entry under `## Current Progress` noting the created issue ID, title, and date. For updated issues, add an entry only when tracker-visible metadata changed, naming the issue and changed fields.

If any issue file, overview, or log write fails, stop, surface which file failed, and offer to roll back the partial issue-state update before continuing.

### 6. Return Result

**IMPROVE MODE:**

- Confirm issue file updated
- Summarize what changed

**CREATE MODE:**

- Confirm issue file created
- Show file path

### 7. Workflow Complete

The skill ends here. Surface the file path and tell the user that if they want to implement next, they can run `/kramme:siw:issue-implement {prefix}-{number}`, or re-run `/kramme:siw:issue-define {prefix}-{number}` to refine. Do not start implementation.

## Guidelines

Read `references/definition-guidelines.md` and apply it throughout the workflow.
