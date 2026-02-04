---
name: kramme:siw:init
description: Initialize structured implementation workflow documents in siw/ (spec, LOG.md, issues)
argument-hint: [spec-file(s) | folder | discover]
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
/kramme:siw:init [spec-file(s) | folder | discover]
    ↓
[Check for existing files] -> Found? -> Ask: resume or start fresh
    ↓
[Handle arguments] -> file/folder: import content
                   -> discover: run explore-interview
                   -> empty: continue to brief interview
    ↓
[Brief interview OR Confirm imported content]
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
- Continue to Phase 1.5

**If no files exist:** Continue to Phase 1.5

## Phase 1.5: Handle Arguments

`$ARGUMENTS` contains any text the user provided after `/kramme:siw:init`.

### Argument Parsing

Parse `$ARGUMENTS` to detect the input type:

1. **File path(s)**: Contains `.md`, `.txt`, or other file extensions
2. **Folder path**: A directory path (verify with `ls -d {path}`)
3. **"discover" keyword**: Starts with "discover" or "interview"
4. **Empty**: No arguments provided

### Case 1: File Path(s) Provided

If `$ARGUMENTS` contains file path(s):

1. Split arguments by spaces to get individual paths
2. For each path provided:
   - Verify file exists with `ls {path}`
   - Read file to extract only: title/name (from first heading)
   - If file doesn't exist, warn and skip it
3. Store file paths as `linked_spec_files` (do NOT extract full content - these remain the source of truth)
4. Extract a brief project name from the file titles for `project_description`
5. **Continue to Phase 2.5** (Confirm Linked Sources)

### Case 2: Folder Path Provided

If `$ARGUMENTS` is a directory (verified with `ls -d`):

1. Scan folder for relevant specification files:
   ```bash
   find {folder} -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" \) 2>/dev/null
   ```

2. Present found files to user using AskUserQuestion:
   ```yaml
   header: "Select Source Files"
   question: "Found these files in {folder}. Which should I use as linked sources?"
   multiSelect: true
   options:
     - "{file1}"
     - "{file2}"
     - "All files"
     - "None - start fresh"
   ```

3. If "None - start fresh" selected: Clear arguments, **continue to Phase 2**
4. If "All files" or specific files selected: Store selected paths as `linked_spec_files`
5. **Continue to Phase 2.5** (Confirm Linked Sources)

### Case 3: "discover" Mode

If `$ARGUMENTS` starts with "discover" or "interview":

1. Extract optional topic from remaining arguments:
   - `discover authentication system` → topic = "authentication system"
   - `discover` alone → ask for topic

2. If no topic provided, use AskUserQuestion:
   ```yaml
   header: "Discovery Topic"
   question: "What topic should we explore? Describe what you're building or the problem you're solving."
   freeform: true
   ```

3. **Execute explore-interview workflow inline:**

   Classify the topic into one of these categories:
   - **Software Feature**: New functionality, UI changes, API additions
   - **Process/Workflow**: Team processes, approval flows, automation
   - **Architecture Decision**: Technology choice, pattern selection, migration
   - **Documentation/Proposal**: RFC, design doc, specification review

   Conduct multi-round interview using AskUserQuestion:
   - Ask probing questions with 2-4 predefined options per question
   - For each question, provide context (why it matters) and a recommendation
   - Track coverage across relevant dimensions
   - Adapt questions based on answers (dig deeper, pivot, clarify)
   - Continue until 80%+ coverage on all dimensions or no major unknowns remain

   **Question Dimensions by Topic Type:**

   For Software Features: Architecture, Data Model, API Design, UX, Integration, Performance, Security

   For Process/Workflow: Triggers, Steps, Roles, Exceptions, Tooling, Metrics

   For Architecture Decisions: Options, Constraints, Tradeoffs, Reversibility, Migration, Risk

   For Documentation Review: Clarity, Completeness, Feasibility, Actionability, Assumptions

4. **Transform interview output to SIW format:**

   | Interview Output | SIW Spec Section |
   |------------------|------------------|
   | Overview/Summary | Overview |
   | Key Decisions | Design Decisions |
   | Technical Design / Data Model | Technical Design section |
   | Implementation Phases/Steps | Tasks (inform issue creation) |
   | Open Questions | Open Questions section |
   | Risks & Mitigations | Risks section |

5. Store as `discovered_content`
6. **Skip Phase 2**, continue to Phase 3 (Auto-detect Spec Type)

### Case 4: No Arguments

**Continue to Phase 2** (current brief interview) - no change to existing behavior.

## Phase 2: Brief Interview

**Skip this phase if `imported_spec_content` or `discovered_content` exists from Phase 1.5.**

Use AskUserQuestion to gather context:

```yaml
header: "Project Context"
question: "In one sentence, what are you building or working on?"
freeform: true
```

Store the response as `project_description`.

## Phase 2.5: Confirm Linked Sources

**Only executed if `linked_spec_files` exists from Phase 1.5 (file/folder import).**

**Skip this phase if `discovered_content` exists (discover mode already has confirmation built in).**

### Present Linked Files

Show the files that will be linked:

```
Linked Specification Files:
───────────────────────────

The following files will be referenced (not duplicated) in the SIW spec:

1. {file1} - "{title from first heading}"
2. {file2} - "{title from first heading}"
...

These files remain the source of truth. The SIW spec will link to them.
```

### Ask About File Location

Use AskUserQuestion:

```yaml
header: "File Location"
question: "Should these files be moved into the siw/ folder, or kept in their current location?"
options:
  - label: "Keep in place"
    description: "Files stay where they are; SIW spec links to current paths"
  - label: "Move to siw/"
    description: "Move files into siw/ folder for co-location"
  - label: "Copy to siw/"
    description: "Copy files to siw/ (creates duplicates - not recommended)"
```

### Handle File Location Choice

- **"Keep in place"**: Store paths as-is in `linked_spec_files`, continue to Phase 2.6
- **"Move to siw/"**:
  - Move each file to `siw/{filename}`
  - Update `linked_spec_files` with new paths
  - Continue to Phase 2.6
- **"Copy to siw/"**:
  - Warn: "This creates duplicate files. Consider using 'Keep in place' to maintain a single source of truth."
  - If user confirms, copy files to `siw/`
  - Update `linked_spec_files` with new paths
  - Continue to Phase 2.6

## Phase 2.6: Confirm Project Context

**Only executed if `linked_spec_files` exists.**

Use AskUserQuestion:

```yaml
header: "Project Context"
question: "Based on the linked files, what is this project about? (One sentence summary)"
freeform: true
defaultValue: "{inferred from file titles}"
```

Store the response as `project_description`.

### Alternative: Skip Context

If user provides empty response or selects "Skip", use a generic description derived from the linked file names.

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

Create `siw/{spec_filename}` with structure based on available content.

**If `linked_spec_files` exists (external files linked - slim spec):**

The SIW spec acts as a lightweight coordination document that references external specifications. **Do NOT duplicate content from linked files.**

```markdown
# {Project Title}

## Overview

{project_description from Phase 2.6}

**Status:** Planning
**Created:** {current date}

## Linked Specifications

The following external documents are the source of truth for this project:

| Document | Path | Description |
|----------|------|-------------|
| {title1} | `{path1}` | {brief description or "Primary specification"} |
| {title2} | `{path2}` | {brief description} |

**Note:** Do not duplicate content from linked files. Refer to them directly for details.

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

## Design Decisions

Key decisions will be documented in `siw/LOG.md` as they are made.

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
```

**If `discovered_content` exists (from discover mode - rich spec):**

Discovery mode generates content through interview, so the spec should capture those findings:

```markdown
# {Project Title}

## Overview

{Discovered description from interview}

**Status:** Planning
**Created:** {current date}
**Source:** Discovery interview

## Objectives

{Objectives from interview}
{Format as checkbox list}

## Scope

### In Scope
{If available from interview}
{Else: "- To be defined"}

### Out of Scope
{If available from interview}
{Else: "- To be defined"}

## Success Criteria

{From interview if available}
{Format as checkbox list}

## Technical Design

{If topic was Software Feature or Architecture:
  Include relevant sections from interview output:
  - Data Model details
  - API contracts
  - Architecture decisions
  - State management notes}

{If no technical content: omit this section}

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

{If Implementation Phases were identified:
  Add note: "Suggested task breakdown from discovery:
  - {phase/step 1}
  - {phase/step 2}
  Use /kramme:siw:define-issue to create formal issues."}

## Design Decisions

{Include Key Decisions table from interview:
| Decision | Choice | Rationale |
|----------|--------|-----------|
| {area} | {what decided} | {why} |
}

## Open Questions

{Include open questions from interview}

## Risks

{Include risks table from interview:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
}

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
```

**If no linked files or discovered content (brief interview only - current behavior):**

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

**If `use_supporting_specs` is true**, add this section before "## Design Decisions" (applies to both templates):

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

## General

| # | Title | Status | Priority | Related |
|---|-------|--------|----------|---------|
| _None_ | _Use `/kramme:siw:define-issue` to create first issue (G-001)_ | | | |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
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
  1. Run /kramme:siw:generate-phases to decompose spec into phase-based issues
     OR /kramme:siw:define-issue to create issues one at a time
  2. Run /kramme:siw:implement-issue <G-XXX or P1-XXX> to start implementing

Tips:
  - The spec file is permanent; keep it updated as your source of truth
  - siw/LOG.md and siw/issues are temporary; delete them when work is complete
  - Use /kramme:clean-up-artifacts to remove temporary files when done
```

**If external files were linked, also show:**

```
Linked Specifications:
  {If kept in place:}
  - {file1} (external)
  - {file2} (external)
  These files remain the source of truth. The SIW spec references them.

  {If moved to siw/:}
  - siw/{file1} (moved)
  - siw/{file2} (moved)
  Files were moved into siw/ for co-location.
```

**If content was discovered via interview, also show:**

```
Discovery:
  Spec populated from discovery interview.
  {n} key decisions documented.
  {n} open questions to address during implementation.
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

1. **Link, don't duplicate** - When external specs are provided, reference them; never copy their content into the SIW spec (single source of truth)
2. **Smart input handling** - Accept file paths, folders, or "discover" keyword; fall back to brief interview if no arguments
3. **Offer file relocation** - Ask if linked files should be moved into siw/ or kept in place
4. **Thorough discovery** - When using discover mode, conduct comprehensive interview before creating spec
5. **Smart defaults** - Auto-detect spec type but always confirm
6. **Clear next steps** - Always point user to `/kramme:siw:define-issue`
7. **Respect existing work** - Never overwrite without explicit confirmation
