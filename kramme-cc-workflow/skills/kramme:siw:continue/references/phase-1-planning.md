# Phase 1: Planning (Before Starting Work)

## Step 0: Choose Your Specification Document Name

Choose a permanent name based on project type:

- `FEATURE_SPECIFICATION.md` - Feature implementation
- `DOCUMENTATION_SPEC.md` - Documentation projects
- `API_DESIGN.md` - API design work
- `TUTORIAL_PLAN.md` - Tutorial/educational content
- `PROJECT_PLAN.md` - General projects
- `SYSTEM_DESIGN.md` - System architecture
- Or any custom name that fits your context

This is the only document that persists after completion.

## Step 1: Create siw/[YOUR_SPEC].md (Always Required)

Create the `siw/` directory first if it doesn't exist.

Read `assets/spec-guidance.md` for structure details.

**Include:**

- Overview and objectives
- Scope, audience, and success criteria
- Guiding principles and constraints
- Work breakdown into phases and tasks (focused, self-contained chunks)
- Verification/testing checklist
- What's explicitly out of scope
- Initial key decisions
- Current context (what exists already)
- Suggested execution order
- Effort estimates

**ALWAYS:** Ask user to review the plan unless they've explicitly opted out.

## Step 2: Create Issues Structure (On Demand)

**Only create when first blocker or investigation need arises.**

Read `assets/issues-template.md` for the full structure.

Synced SIW issue-state contract (keep aligned across SIW issue creators): every SIW issue creation or tracker-visible issue update keeps the issue file, siw/OPEN_ISSUES_OVERVIEW.md, and siw/LOG.md synchronized as one issue-state change; partial write failures must be surfaced instead of accepted silently.

**When first issue arises:**

1. Create `siw/issues/` directory
2. Create `siw/OPEN_ISSUES_OVERVIEW.md` with the overview table
3. Create `siw/issues/ISSUE-G-001-short-title.md` for the first issue
4. Update `siw/LOG.md` Current Progress with the created issue ID, title, and date

**When resolved:** Document the resolution in the issue file's `## Resolution` section, set the issue file's `**Status:**` line to `IN REVIEW` or `DONE` based on confidence, update the overview row to the same status, document the decision in siw/LOG.md, and update `siw/LOG.md` Current Progress with the resolved issue ID, status, and next step. If it was the last open issue in a phase (`P1-*`, `P2-*`, etc.), ask the user whether to mark the phase as DONE by appending ` (DONE)` to the phase section header.

If any issue file, overview, or log write fails after issue creation or resolution starts, surface the partial state in the completion summary and offer rollback guidance instead of reporting the issue as cleanly created or resolved.

## Step 3: siw/LOG.md

**Note:** If you used `/kramme:siw:init`, LOG.md was already created with the initial structure.

**If creating manually** (when first decision is made OR first task is completed):

- Read `assets/log-template.md` for structure
- Add "Current Progress" section at the very top
- Add Decision Template
- Document first decision with full rationale (if applicable)
- Create Rejected Alternatives Summary table
- List Guiding Principles
- Add References section
