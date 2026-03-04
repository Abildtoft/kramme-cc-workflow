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

Read `templates/spec-guidance.md` for structure details.

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

Read `templates/issues-template.md` for the full structure.

**When first issue arises:**
1. Create `siw/issues/` directory
2. Create `siw/OPEN_ISSUES_OVERVIEW.md` with the overview table
3. Create `siw/issues/ISSUE-G-001-short-title.md` for the first issue

**When resolved:** Document the resolution in the issue file's `## Resolution` section, set status to `IN REVIEW` or `DONE` based on confidence, update the overview row, and document the decision in siw/LOG.md. If it was the last open issue in a phase (`P1-*`, `P2-*`, etc.), ask the user whether to mark the phase as DONE by appending ` (DONE)` to the phase section header.

## Step 3: siw/LOG.md

**Note:** If you used `/kramme:siw:init`, LOG.md was already created with the initial structure.

**If creating manually** (when first decision is made OR first task is completed):
- Read `templates/log-template.md` for structure
- Add "Current Progress" section at the very top
- Add Decision Template
- Document first decision with full rationale (if applicable)
- Create Rejected Alternatives Summary table
- List Guiding Principles
- Add References section
