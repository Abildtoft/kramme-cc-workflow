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

## Artifact Readiness Contract

Use this shared vocabulary while deciding whether an issue can be written:

- `product-only`: only the problem, user, or desired outcome is known.
- `requirements-only`: scope and success criteria exist, but issue-level dependencies, affected areas, or verification are not clear.
- `planning-ready`: enough context exists to define one or more SIW issues, but the current artifact is not yet executable.
- `implementation-ready`: the issue has bounded scope, dependencies/blockers, acceptance criteria, Mode, and verification.

This skill turns `planning-ready` input into an `implementation-ready` local issue. If the interview cannot harden a `product-only` or `requirements-only` request into a single executable issue, stop and route to `/kramme:siw:discovery` or spec hardening instead of writing a vague issue. Route to `/kramme:siw:generate-phases` only when the artifact is `planning-ready` but too broad for one issue.

## SIW Issue-State Protocol

This skill owns the manual SIW issue creation/update protocol. Synced SIW issue-state contract (keep aligned across SIW issue creators): every SIW issue creation or tracker-visible issue update keeps the issue file, siw/OPEN_ISSUES_OVERVIEW.md, and siw/LOG.md synchronized as one issue-state change; partial write failures must be surfaced instead of accepted silently.

All final issue creation and tracker-visible updates use this skill's `scripts/siw-issue-reservation.sh` helper. The helper serializes its own invocations, provides an ownership-tokened publication lock, and creates exclusive per-ID reservations using portable atomic hard-link claims. A killed invocation's operation claim is reclaimed only after its recorded process no longer exists. Keep the locked critical section short. Draft IDs are provisional; reserve final IDs only at the Phase 6 mutation boundary.

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
2. Resolve exactly one non-symlink regular issue file from `siw/issues/ISSUE-{prefix}-{number}-*.md`; stop on zero matches, duplicate matches, symlinks, or other non-regular paths.
3. Store the exact issue path and existing content as the interview base, then store `IMPROVE_BASE_HASH` from a successful `git hash-object` call. Stop if the content cannot be hashed.
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

3. **Propose Next Issue Number**
   - Determine `issue_prefix` (from Step 4; fallback to `requested_prefix` if present; otherwise default `G`)
   - Parse `siw/OPEN_ISSUES_OVERVIEW.md` table to find highest issue number **within that prefix group**
   - Compute candidate = highest + 1 (or 001 if no issues with that prefix exist), padded to 3 digits
   - **Verify no on-disk collision:** glob `siw/issues/ISSUE-{issue_prefix}-{candidate}-*.md`. If any file matches, the tracker is out of sync with `siw/issues/`. Increment the candidate and re-check until no file matches, then warn the user that the tracker may need a reindex via `/kramme:siw:issue-reindex`.
   - Store as provisional `issue_number` for the draft. Do not create a reservation yet; interviews and review must not hold publication ownership.
   - Provisional full ID: `{issue_prefix}-{issue_number}` (e.g., `G-001`, `P1-002`). Phase 6 may advance it if another creator publishes first.

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
- whether behavior-preserving prefactoring should be a first issue or blocker before the requested feature/change

Use these as assumptions to validate instead of asking the user to restate obvious context.

## Phase 4: Interview

Read `references/interview-guide.md` and follow the simple-bug or standard interview path based on `issue_type` and `is_simple_bug`. Store priority, size, related work, blockers, parallelization category, prefactoring need, and Mode for Phase 5. Confirm inferred metadata before composing.

## Phase 5: Issue Composition

Read `references/issue-templates.md` and select the appropriate template:

- Use the **Simple Bug Template** when `is_simple_bug = true`.
- Use the **Comprehensive Template** otherwise.

Both templates include the `Mode:` field. When emitting the issue, fill `Mode: AUTO` or `Mode: HITL — <one-line reason>` from Round 5.

Apply the prefactoring-first rule before finalizing the draft:

- If behavior-preserving prep work materially unlocks the requested work, define that prefactoring as its own issue first or add it as a blocker/dependency on the requested issue.
- Prefactoring issues must have acceptance criteria that prove behavior is preserved and must not include the new feature behavior.
- Do not hide preparatory refactors inside a feature issue. If the user wants both in one issue, explain the split and ask whether to create the prefactoring issue now or defer it as an explicit blocker.
- Do not create speculative cleanup. Only split prefactoring when it reduces real implementation risk or avoids an over-large/over-bundled issue.

The references file also defines the **Durability rule**: issue bodies must describe modules, behaviors, and contracts — not file paths, line numbers, or internal helper/class names. Apply it to every section of the composed issue (Problem, Context, Technical Notes, References).

## Phase 6: Review & Create/Update

### 1. Present Draft

**IMPROVE MODE:** Show updated issue with change indicators.

**CREATE MODE:** Show complete issue.

### 2. Allow Refinements

- Ask if any changes are needed
- Iterate until user is satisfied

### 3. Reserve and Publish the Issue-State Change

Resolve `scripts/siw-issue-reservation.sh` relative to this `SKILL.md`. Generate a collision-resistant owner token once with `sh <helper> new-owner`, retain it in this workflow's session state, and use it for the workflow's full publication and recovery lifetime. During normal contention, never copy or reuse a token observed in an existing lock or reservation.

1. Immediately before the first mutation, run `sh <helper> acquire siw <owner-token> 30`. This bounded wait is the serialization boundary. If it reports that another writer owns publication, preserve the lock and reservations unchanged and stop for owner-guided recovery without exposing its token. For malformed state or operational failures, preserve state and surface the helper's diagnostic exactly instead of describing the failure as contention.
2. Re-read `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/LOG.md`, and matching on-disk issue files while holding publication ownership. Never publish from the snapshot used during the interview.
3. In IMPROVE MODE, resolve exactly one current issue path and hash it successfully. Compare both its path and hash with the stored interview base. If either changed, run `sh <helper> release-publication siw <owner-token>` before prompting, rebase the proposed edits onto the fresh issue without discarding concurrent changes, show the revised draft and concurrent delta for explicit approval, replace the stored base path/hash, reacquire publication ownership, and repeat from Step 2. Conflicting edits always require approval; never prompt while holding publication ownership. Proceed only when the under-lock path and hash still match the latest approved base.
4. In CREATE MODE, run `sh <helper> reserve siw <issue-prefix> <owner-token> 100 issue-create`. The stable `issue-create` request key makes an interrupted call safe to retry with the retained owner token. Treat the returned ID as final, replacing the provisional ID everywhere in the issue body, filename, overview row, and log entry. The helper recomputes the high-water mark across the overview, issue files, and live reservations, preserves gaps, and retries collisions with exclusive atomic claims. In IMPROVE MODE, keep the existing stable ID and do not reserve a new one.
5. In CREATE MODE, create `siw/issues/ISSUE-{prefix}-{number}-{sanitized-title}.md`. In IMPROVE MODE, update the exact current path verified in Step 3; if an approved title change requires a new sanitized filename, verify the target is absent and rename that file instead of creating a second path for the same ID. Sanitize titles by lowercasing, replacing spaces with hyphens, removing special characters, and limiting them to 40 characters.
6. From the fresh under-lock state, update `siw/OPEN_ISSUES_OVERVIEW.md`: add a new row in the correct prefix section, or update every changed tracker-visible field for an existing issue. Read `references/tracker-schema.md` for the coexisting layouts, parallelization-summary recomputation, and `(DONE)` phase-marker rules.
7. From the same fresh state, update `siw/LOG.md`. For new issues, add the created ID, title, and date under `## Current Progress`; for updated issues, add an entry only when tracker-visible metadata changed and name the changed fields.
8. Re-read all three views and verify the same ID and tracker-visible metadata appear in the issue file, overview, and log without discarding another writer's accurate entries. Only then run `sh <helper> release siw <issue-id> <owner-token>` for a new issue, followed by `sh <helper> release-publication siw <owner-token>`.

In CREATE MODE, retry the same request key after an interrupted reservation call to recover its final ID. If a write fails before the issue file exists, the same owner may run `abandon` for its ID and then `release-publication`. If the issue file exists, do not abandon the reservation: reacquire with the retained token, repair the overview/log from current state, verify all three views, then run `release` followed by `release-publication`. These cleanup and publication-release commands are postcondition-idempotent for interruption recovery. In IMPROVE MODE no ID reservation exists: reacquire with the retained token, repair and verify all three views, then run only `release-publication`. A later recovery session may use the retained token only after the user explicitly confirms it is resuming that interrupted workflow. Never delete a reservation based on age or filename, and never clean up a different owner's token.

### 4. Return Result

**IMPROVE MODE:**

- Confirm issue file updated
- Summarize what changed

**CREATE MODE:**

- Confirm issue file created
- Show file path

### 5. Workflow Complete

The skill ends here. Surface the file path and tell the user that if they want to implement next, they can run `/kramme:siw:issue-implement {prefix}-{number}`, or re-run `/kramme:siw:issue-define {prefix}-{number}` to refine. Do not start implementation.

## Guidelines

Read `references/definition-guidelines.md` and apply it throughout the workflow.
