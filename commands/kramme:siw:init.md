---
name: kramme:siw:init
description: Initialize structured implementation workflow documents in siw/ (spec, LOG.md, issues)
---

# Initialize Structured Implementation Workflow

Set up the three-document system for tracking complex implementations locally, without requiring Linear or other external issue trackers.

## Workflow Boundaries

**This command ONLY initializes workflow documents.**

- **DOES**: Create siw/ folder, spec file, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, siw/issues/, and optionally siw/supporting-specs/
- **DOES NOT**: Define issues, implement features, or make code changes

**Issue definition is a separate workflow.** After this command completes, invoke `/kramme:siw:define-issue` to create your first issue.

## Process Overview

```
/kramme:siw:init
    ↓
[Check for existing files] -> Found? -> Ask: resume or start fresh
    ↓
[Brief interview] -> "What are you building?"
    ↓
[Auto-detect spec type] -> Confirm filename
    ↓
[Ask about supporting specs] -> Need detailed specs?
    ↓
[Create documents] -> siw/spec, siw/LOG.md, siw/issues/, (supporting-specs/)
    ↓
[Report success] -> Suggest /kramme:siw:define-issue
```

## Phase 1: Check for Existing Workflow Files

Check if any workflow files already exist:

```bash
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/*SPEC*.md siw/*SPECIFICATION*.md siw/issues/ 2>/dev/null
```

**If files exist:**

Use AskUserQuestion:

```yaml
header: "Existing Workflow Files Found"
question: "Workflow files already exist in this directory. How would you like to proceed?"
options:
  - label: "Resume existing workflow"
    description: "Continue with current files (invokes structured-implementation-workflow skill)"
  - label: "Start fresh"
    description: "Delete existing workflow files and create new ones"
  - label: "Abort"
    description: "Cancel and keep existing files"
```

**If "Resume existing workflow":**
- Stop this command
- Inform user that the `kramme:structured-implementation-workflow` skill will auto-trigger when they start working
- Suggest reading siw/LOG.md for current progress

**If "Start fresh":**
- Delete existing workflow files (siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, siw/issues/, but preserve any siw/*SPEC*.md files with user confirmation)
- Continue to Phase 2

**If no files exist:** Continue to Phase 2

## Phase 2: Brief Interview

Use AskUserQuestion to gather context:

```yaml
header: "Project Context"
question: "In one sentence, what are you building or working on?"
freeform: true
```

Store the response as `project_description`.

## Phase 3: Auto-detect Spec Type and Confirm

Based on `project_description`, auto-detect the most appropriate spec filename:

**Detection heuristics:**
- Keywords like "feature", "add", "implement", "new" → `FEATURE_SPECIFICATION.md`
- Keywords like "api", "endpoint", "service" → `API_DESIGN.md`
- Keywords like "doc", "documentation", "guide" → `DOCUMENTATION_SPEC.md`
- Keywords like "tutorial", "learn", "teach" → `TUTORIAL_PLAN.md`
- Keywords like "system", "architecture", "design" → `SYSTEM_DESIGN.md`
- Default fallback → `PROJECT_PLAN.md`

**Confirm with user:**

```yaml
header: "Specification Document"
question: "I'll create a specification document. Which name fits best?"
options:
  - label: "{detected_name}"
    description: "Recommended based on your description"
  - label: "FEATURE_SPECIFICATION.md"
    description: "For feature implementations"
  - label: "API_DESIGN.md"
    description: "For API design work"
  - label: "PROJECT_PLAN.md"
    description: "For general projects"
  - label: "Custom name"
    description: "Enter your own filename"
```

If "Custom name" selected, use AskUserQuestion to get the filename.

Store as `spec_filename`.

## Phase 3.5: Ask About Supporting Specs

Use AskUserQuestion:

```yaml
header: "Supporting Specifications"
question: "Will this project need detailed supporting specifications? (For large projects with separate data model, API, UI specs, etc.)"
options:
  - label: "Yes - create supporting-specs folder"
    description: "For complex projects with multiple spec domains"
  - label: "No - single spec file is enough"
    description: "For simpler projects"
```

Store as `use_supporting_specs`.

## Phase 4: Create Documents

Create the `siw/` directory if it doesn't already exist.

### 4.1 Create Specification Document

Create `siw/{spec_filename}` with initial structure:

```markdown
# {Project Title from description}

## Overview

{project_description}

**Status:** Planning
**Created:** {current date}

## Objectives

- [ ] {Placeholder - define during issue creation}

## Scope

### In Scope
- {To be defined}

### Out of Scope
- {To be defined}

## Success Criteria

- [ ] {To be defined}

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

## Design Decisions

Key decisions will be documented in `siw/LOG.md` as they are made.

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
```

**If `use_supporting_specs` is true**, add this section before "## Design Decisions":

```markdown
## Supporting Specifications

| # | Document | Description |
|---|----------|-------------|
| _None yet_ | _Create files in `siw/supporting-specs/`_ | |

**Naming convention:** `NN-descriptor.md` (e.g., `01-data-model.md`, `02-api-specification.md`)

See `resources/templates/spec-guidance.md` for detailed guidance on supporting specs.
```

### 4.2 Create siw/LOG.md

**Note:** Creating LOG.md during init ensures consistent structure. The file will be populated as work progresses.

Create `siw/LOG.md` with initial structure:

```markdown
# LOG.md

## Current Progress

**Last Updated:** {current date}
**Quick Summary:** Project initialized, ready for issue definition.

### Project Status

- **Status:** Planning | **Current Phase:** Initialization | **Overall Progress:** 0 tasks

### Last Completed

- Project initialization

### Next Steps

1. Define first issue with `/kramme:siw:define-issue`
2. Begin implementation with `/kramme:siw:implement-issue`
3. **Blockers:** None

---

## Decision Log

_Decisions will be documented here as they are made._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| _None yet_ | | | |

---

## Guiding Principles

1. {To be defined during implementation}

## References

- Spec: `siw/{spec_filename}`
- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
```

### 4.3 Create siw/OPEN_ISSUES_OVERVIEW.md

Create `siw/OPEN_ISSUES_OVERVIEW.md`:

```markdown
# Open Issues Overview

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| _None_ | _Use `/kramme:siw:define-issue` to create first issue_ | | | |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Details:** See `siw/issues/ISSUE-XXX-*.md` files.
```

### 4.4 Create siw/issues/ Directory

```bash
mkdir -p siw/issues
```

Create placeholder file `siw/issues/.gitkeep` to ensure directory is tracked:

```bash
touch siw/issues/.gitkeep
```

### 4.5 Create siw/supporting-specs/ Directory (if enabled)

**Only if `use_supporting_specs` is true:**

```bash
mkdir -p siw/supporting-specs
touch siw/supporting-specs/.gitkeep
```

## Phase 5: Report Success

Display summary:

```
Structured Implementation Workflow Initialized

Created:
  siw/{spec_filename}          - Main specification (permanent)
  siw/supporting-specs/        - Detailed specifications (permanent) [if enabled]
  siw/LOG.md                   - Progress and decisions (temporary)
  siw/OPEN_ISSUES_OVERVIEW.md  - Issue tracking (temporary)
  siw/issues/                  - Individual issue files (temporary)

Next Steps:
  1. Run /kramme:siw:define-issue to create your first issue
  2. Run /kramme:siw:implement-issue <ISSUE-XXX> to start implementing

Tips:
  - The spec file is permanent; keep it updated as your source of truth
  - siw/LOG.md and siw/issues are temporary; delete them when work is complete
  - Use /kramme:clean-up-artifacts to remove temporary files when done
```

**If supporting specs enabled, also show:**

```
Supporting Specs:
  - Create files in siw/supporting-specs/ with naming: NN-descriptor.md
  - Example: 01-data-model.md, 02-api-specification.md
  - Update the TOC in the main spec when adding new supporting specs
```

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

1. **Keep it lightweight** - This command only creates files, no deep analysis
2. **Smart defaults** - Auto-detect spec type but always confirm
3. **Clear next steps** - Always point user to `/kramme:siw:define-issue`
4. **Respect existing work** - Never overwrite without explicit confirmation
