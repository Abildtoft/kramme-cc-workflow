---
name: kramme:siw:generate-phases
description: Break spec into atomic, phase-based issues with tests and validation
argument-hint: "[spec-file-path]"
disable-model-invocation: true
user-invocable: true
---

# Generate Phases from Specification

Break down a specification into atomic, committable issues organized into phases. Each phase results in a demoable or reviewable outcome appropriate to the work type, and each issue represents a self-contained piece of work with tests/validation.

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

## Shared Guardrails

Before executing Phase 2 or any later step, read `references/quality-gates.md` so the required output markers, hard gates, and final verification checklist are active throughout the workflow.

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
ls siw/*.md | grep -v -E '(LOG\.md|OPEN_ISSUES_OVERVIEW\.md|DISCOVERY_BRIEF\.md|SPEC_STRENGTHENING_PLAN\.md|AUDIT_.*\.md)'
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

### 2.1 Extract Work Context

After finding spec files, look for a `## Work Context` section in the spec files:

1. Parse the markdown table to extract: Work Type, Priority Dimensions, Deprioritized dimensions
   - If multiple spec files define Work Context, use the main spec file (the one matching the SIW init filename). If ambiguous, use the first found and warn.
2. If not found or malformed, default to Production Feature (3-5 phases, standard sizing)
3. Store as `work_context`

### 2.2 Read Spec Content

Read the main spec file and any supporting specs found in Phase 1.2.

### 2.3 Extract Key Elements

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
- Each phase should result in a **demoable or reviewable outcome** appropriate to the work type
- Default phase count depends on Work Context:
  - **Production Feature** (default): 3-5 phases. Each phase results in demoable, tested software.
  - **Prototype / Spike**: 2-3 phases. Larger, more exploratory phases. Phase 1 proves the core concept. Acceptance criteria focus on "does it work" over "is it production-ready." Skip polish and documentation phases.
  - **Internal Tool**: 3-4 phases. Prioritize getting to a working tool fast. Phase 1 is the happy-path core workflow.
  - **Tech Debt / Refactor**: 2-4 phases ordered by risk. Phase 1 tackles the highest-risk transformation with rollback capability. Include explicit rollback verification in phase acceptance criteria.
  - **Documentation / Process**: Phases map to document sections or workflow stages. Each phase produces a reviewable deliverable.
- Identify cross-cutting concerns for the "General" category (setup, tooling, docs)

### 3.2 Break Into Atomic Tasks

For each phase, decompose into atomic tasks:

**Each task should be:**
- **Committable independently** - A single focused change
- **Testable** - Has clear acceptance criteria and validation
- **Sized XS, S, M, or L** per `references/task-sizing.md`. XL tasks MUST be decomposed further before approval.
- **Clearly defined** - Unambiguous scope with explicit boundaries
- **Mode-tagged** - `AUTO` or `HITL` (see Mode taxonomy below)

**Mode taxonomy (HITL vs AUTO — load-bearing for autonomous-agent pickup):**

- **AUTO** — an autonomous agent can pick up, implement, verify, and prepare for review without human input.
- **HITL** — human-in-the-loop is required for at least one of: architectural decision, design review, judgment call, manual testing, external system access. HITL tasks MUST carry a one-line reason (e.g., "needs architectural decision", "involves manual UAT").

Tag each task during decomposition. Default to HITL when unclear; the subagent in Phase 4 will flag any task without a Mode label and any HITL task without a reason.

**Sizing and triggers:**

Read sizing grammar, break-down triggers, and the context-appropriate slicing rule from `references/task-sizing.md` and apply them during decomposition. Every task gets an explicit size (XS/S/M/L); any task that hits a break-down trigger — especially one that bundles multiple independently reviewable outcomes — splits before leaving this step.

**Slicing shape (context-aware — load-bearing):**

- For user-facing feature work:
  - ❌ Horizontal: "Build entire DB schema → build all APIs → build all UI".
  - ✅ Vertical: "User can create account (schema + API + UI, end-to-end)".
- For documentation, refactors, architecture, or process work:
  - ❌ Horizontal: "Document all data models → document all APIs → document all UI flows".
  - ✅ End-to-end: "Document account creation end-to-end, including constraints, API contract, and UI behavior".

**Identify dependencies:**
- Which tasks block other tasks within the same phase?
- Which phases depend on completing previous phases?

### 3.3 Generate Phase Plan Structure

For each phase:
- **Phase goal** - What milestone does this achieve?
- **Outcome description** - What can be demonstrated or reviewed after this phase?
- **Tasks** - List of atomic issues with titles, sizes, and brief descriptions
- **Dependencies** - What blocks what
- **Parallelization** - Group category plus any gating note from Phase 3.4
- **Validation** - How to verify the phase is complete

For general tasks:
- Setup/scaffolding that doesn't fit a specific phase
- Tooling and configuration
- Documentation tasks

### 3.4 Parallelization Assessment

Annotate each task group with one of three parallelization categories so the plan surfaces safe-to-run-in-parallel work explicitly rather than defaulting to serial execution:

- **Safe to parallelize**: independent slices, tests, docs.
- **Must be sequential**: migrations, shared-state changes.
- **Needs coordination**: shared API contract → define contract first, then parallelize consumers.

Record the chosen category per group (e.g., "Phase 1 tasks: Safe to parallelize after P1-001") so Phase 5's user-facing plan reflects it, the generated issue files keep the exact approved guidance, and `siw/OPEN_ISSUES_OVERVIEW.md` stores the same decision as one section-level summary per task group.

## Phase 4: Subagent Review

Launch a Task subagent to review the proposed breakdown:

**Before the prompt, instruct the subagent to read `references/task-sizing.md` completely and use it as the source of truth for sizing, break-down triggers, slicing shape, and parallelization taxonomy.**

**Prompt:**
```
Review this phase/task breakdown for a software project or adjacent documentation/process deliverable.

Before evaluating the plan, read `references/task-sizing.md` completely and use it as the source of truth for task sizing, break-down triggers, slicing shape, and parallelization categories.

Work Context: {work_context.work_type}
- Verify phase count and granularity match the work type
- For prototypes, do not flag broad task scope or missing test tasks
- For refactors, verify each task has rollback safety
- For documentation/process work, interpret "end-to-end" as the smallest reviewable deliverable for that workflow rather than schema + API + UI

Evaluate:

1. **Atomicity**: Is each task truly independent and committable on its own?
2. **Testability**: Does each task have clear, verifiable acceptance criteria?
3. **Dependencies**: Are dependencies correctly identified? Any missing?
4. **Completeness**: Are any tasks missing to achieve the phase goals?
5. **Phase coherence**: Does each phase result in a demoable or reviewable outcome that matches the work context?
6. **Sizing (hard gate)**: Every task must land XS, S, M, or L per `references/task-sizing.md`. Flag any XL task explicitly — XL is not an acceptable final state.
7. **Slicing shape**: For feature work, does each task cut vertically (end-to-end slice — schema + API + UI together) rather than horizontally (one layer across many features)? For documentation, refactors, architecture, or process work, does each task deliver the smallest reviewable end-to-end outcome for that context? Flag tasks that are layer-by-layer or that bundle multiple independent deliverables.
8. **Parallelization**: Are parallelization categories (Safe / Must be sequential / Needs coordination) correctly assigned? Flag any safely-parallel work serialized unnecessarily, or any shared-state change marked parallel.
9. **Mode (AUTO vs HITL)**: Does every task carry a Mode label? Does every HITL task include a one-line reason (architectural decision, design review, judgment call, manual testing, external system access)? Flag any unlabeled task or HITL-without-reason. Do NOT second-guess the AUTO/HITL choice itself unless the rationale is obviously wrong (e.g., a task that requires manual UAT but is marked AUTO).

For each issue found, provide:
- What's wrong
- Specific suggestion to fix it

If the breakdown looks good, confirm it's ready.
```

**Incorporate feedback:** Update the phase plan based on subagent suggestions.

**Loopback gate:** If the subagent reports any XL task, any context-inappropriate horizontal / over-bundled slice, any task without a Mode label, or any HITL task without a one-line reason, re-run Phase 3.2 decomposition and re-submit to the subagent. Only proceed to Phase 5 once the subagent confirms zero XL tasks, zero slicing-shape issues, and complete Mode coverage.

## Phase 5: User Approval

Present the proposed structure clearly, prefixed with the `PLAN:` output marker so downstream tooling can parse this block as the generated plan. Show each issue's size and Mode inline, and include one `Parallelization:` line per task group. HITL tasks include the one-line reason in the bracket:

```
PLAN: Phase Plan for {Project Name}
═══════════════════════════════════

General Tasks ({N} tasks)
─────────────────────────
  Parallelization: {Safe to parallelize | Must be sequential | Needs coordination}
  ISSUE-G-001: {Title} [Ready | Size: XS|S|M|L | AUTO]
  ISSUE-G-002: {Title} [Ready | Size: XS|S|M|L | HITL — needs architectural decision]

Phase 1: {Goal} ({N} tasks)
───────────────────────────
  Parallelization: {Safe to parallelize after P1-001 | Must be sequential | Needs coordination}
  ISSUE-P1-001: {Title} [Ready | Size: XS|S|M|L | AUTO]
  ISSUE-P1-002: {Title} [Blocked by P1-001 | Size: XS|S|M|L | AUTO]
  ISSUE-P1-003: {Title} [Ready | Size: XS|S|M|L | HITL — needs design review]

  Outcome: {What can be demonstrated or reviewed}
  Tests: {What tests validate this phase}

Phase 2: {Goal} ({N} tasks)
───────────────────────────
  Parallelization: {Safe to parallelize | Must be sequential after Phase 1 | Needs coordination}
  ISSUE-P2-001: {Title} [Blocked by Phase 1 | Size: XS|S|M|L | HITL — manual UAT]
  ISSUE-P2-002: {Title} [Ready | Size: XS|S|M|L | AUTO]

  Outcome: {What can be demonstrated or reviewed}
  Tests: {What tests validate this phase}

...

Total: {X} issues across {Y} phases + {Z} general
AUTO: {n} | HITL: {m}
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

**Status:** Ready | **Priority:** {High|Medium|Low} | **Size:** {XS|S|M|L} | **Phase:** {N or General} | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination; include gating note if applicable} | **Mode:** {AUTO | HITL — <one-line reason>} | **Related:** {dependencies}

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

### Parallelization Guidance
{Whether this issue can proceed in parallel, must stay sequential, or needs coordination first. Start from the same group-level note shown in Phase 5, then add issue-specific gating detail when needed. `siw/OPEN_ISSUES_OVERVIEW.md` keeps only the group summary line for that section.}
```

### 6.2 Update Overview Table

Update `siw/OPEN_ISSUES_OVERVIEW.md` with all new issues, grouped by phase. Modern sections keep one group-level `**Parallelization:**` summary line; exact per-issue guidance lives in the issue files. Legacy sections that predate that metadata keep their existing format unless the user is explicitly migrating the tracker schema.

If you add any non-DONE issues to a phase section currently marked ` (DONE)`, remove the marker (or ask the user) so the header stays accurate.

**Append-mode compatibility rules:**
- Inspect each existing section before appending rows.
- If a section already uses the **7-column** schema `| # | Title | Status | Size | Priority | Mode | Related |`, keep that schema and emit Mode for new rows.
- If a section already uses the **6-column** schema `| # | Title | Status | Size | Priority | Related |` (pre-Mode), preserve it for compatibility. Only migrate to the 7-column schema when the user explicitly requests a schema migration.
- If a section already uses the legacy **5-column** `| # | Title | Status | Priority | Related |`, preserve that schema and do not inject Size or Mode columns into that section.
- If you're creating a brand-new section while appending into a tracker whose existing sections are legacy 5- or pre-Mode 6-column tables, match the existing dominant schema for the new section instead of mixing layouts mid-file.
- Preserve any existing section-level `**Parallelization:**` line exactly as written. If a legacy section predates that metadata, do not add the line unless the user is explicitly migrating the tracker schema.

The `Mode` cell is `AUTO` or `HITL` (no inline reason in the table; the reason lives in the issue file's frontmatter).

```markdown
# Open Issues Overview

## General

**Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination}

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| G-001 | {Title} | Ready | {Size} | {Priority} | AUTO | |
| G-002 | {Title} | Ready | {Size} | {Priority} | HITL | |

## Phase 1: {Goal}

**Parallelization:** {Safe to parallelize after P1-001 | Must be sequential | Needs coordination}

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| P1-001 | {Title} | Ready | {Size} | High | AUTO | |
| P1-002 | {Title} | Ready | {Size} | Medium | AUTO | P1-001 |

## Phase 2: {Goal}

**Parallelization:** {Safe to parallelize | Must be sequential after Phase 1 | Needs coordination}

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| P2-001 | {Title} | Ready | {Size} | High | HITL | Phase 1 |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

Legacy compatibility example when appending to an older 5-column tracker:

```markdown
## Phase 1: {Goal}

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| P1-001 | {Title} | Ready | High | |
| P1-002 | {Title} | Ready | Medium | P1-001 |
```

## Phase 7: Summary

Report the results using the standard end-of-turn triplet (adapted: this skill creates files rather than changing code, so "CHANGES MADE" becomes "FILES CREATED"):

```
Phase Generation Complete
═════════════════════════

FILES CREATED:
  • siw/issues/ISSUE-*.md ({X} files)
    - General: {N} issues (G-001 to G-{N})
    - Phase 1: {N} issues (P1-001 to P1-{N})
    - Phase 2: {N} issues (P2-001 to P2-{N})
    ...
  • siw/OPEN_ISSUES_OVERVIEW.md (updated)

THINGS I DIDN'T TOUCH:
  • Any existing non-issue files under siw/ (LOG.md, spec files, supporting-specs/)
  • Source code — implementation is a separate workflow
  • {List any issues explicitly preserved during Append mode}

POTENTIAL CONCERNS:
  • {Any subagent-flagged risks that survived user approval}
  • {Any CONFUSION or MISSING REQUIREMENT markers from Phase 2 that were resolved by assumption — worth re-checking before implementation}
  • {If empty, state: "None"}

Suggested starting point:
  /kramme:siw:issue-implement ISSUE-{first-ready-issue}

Tips:
  • Work through phases sequentially (Phase 1 → Phase 2 → ...)
  • General tasks follow their recorded parallelization guidance; only `Safe to parallelize` work can truly be done anytime
  • Mark issues DONE in the overview as you complete them
```

**STOP HERE.** Wait for the user's next instruction.

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
