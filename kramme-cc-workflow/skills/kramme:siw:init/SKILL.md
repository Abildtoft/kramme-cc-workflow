---
name: kramme:siw:init
description: Initialize structured implementation workflow documents in siw/ (spec, LOG.md, issues)
argument-hint: "[spec-file(s) | folder | discover] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Initialize Structured Implementation Workflow

Set up the three-document system for tracking complex implementations locally, without requiring Linear or other external issue trackers.

## Workflow Boundaries

**This command ONLY initializes workflow documents.**

- **DOES**: Create siw/ folder, spec file, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, siw/issues/, and optionally siw/supporting-specs/
- **DOES NOT**: Define issues, implement features, or make code changes

**Issue definition is a separate workflow.** After this command completes, invoke `/kramme:siw:issue-define` to create your first issue. **Spec hardening is a separate workflow.** To strengthen an existing SIW spec, use `/kramme:siw:discovery`.

## Process Overview

```
/kramme:siw:init [spec-file(s) | folder | discover]
    ↓
[Check for existing files] -> Found? -> Ask: resume or start fresh
    ↓
[Handle arguments] -> file/folder: import content
                   -> discover: run greenfield discovery, then import siw/DISCOVERY_BRIEF.md
                   -> empty: continue to brief interview
    ↓
[Brief interview OR Confirm imported content]
    ↓
[Read STRATEGY.md if present]
    ↓
[Select work context] -> Profile for downstream tool adaptation
    ↓
[Auto-detect spec type] -> Confirm filename
    ↓
[Ask about supporting specs] -> Need detailed specs?
    ↓
[Create documents] -> siw/spec, siw/LOG.md, siw/issues/, (supporting-specs/)
    ↓
[Report success] -> Suggest /kramme:siw:issue-define
```

Before Phase 1, parse `$ARGUMENTS` as shell-style arguments. If `--auto` is present, set `AUTO_MODE=true` and remove it from the remaining input. `--auto` uses safe initialization defaults when enough context is already supplied: keep linked files in place, use all discovered files from an explicit folder, choose the auto-detected work context and spec filename, and create a single spec file without supporting specs. It does not bypass required project context, existing-workflow protection, deletion confirmation, file overwrite checks, or fresh discovery topic requirements.

## Phase 1: Check for Existing Workflow Files

Check if any workflow files already exist:

```bash
find siw -maxdepth 1 \( \
  -name "LOG.md" -o \
  -name "OPEN_ISSUES_OVERVIEW.md" -o \
  -name "AUDIT_IMPLEMENTATION_REPORT.md" -o \
  -name "AUDIT_SPEC_REPORT.md" -o \
  -name "PRODUCT_AUDIT.md" -o \
  -name "SIW_*.md" -o \
  -name "SPEC_STRENGTHENING_PLAN.md" -o \
  -name "DISCOVERY_BRIEF.md" -o \
  -name "issues" \
\) -print 2> /dev/null
# Permanent SIW spec detection (referenced as `permanent-spec find` elsewhere in this skill).
# Case-insensitive so lowercase/mixed-case filenames like `feature_spec.md` are not missed.
# Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): LOG.md, OPEN_ISSUES_OVERVIEW.md, DISCOVERY_BRIEF.md, SPEC_STRENGTHENING_PLAN.md, AUDIT_*.md, PRODUCT_AUDIT.md, SIW_*.md.
find siw -maxdepth 1 -type f \( -iname "*SPEC*.md" -o -iname "*SPECIFICATION*.md" -o -iname "*PLAN*.md" -o -iname "*DESIGN*.md" \) \
  ! -iname "LOG.md" \
  ! -iname "OPEN_ISSUES_OVERVIEW.md" \
  ! -iname "DISCOVERY_BRIEF.md" \
  ! -iname "SPEC_STRENGTHENING_PLAN.md" \
  ! -iname "AUDIT_*.md" \
  ! -iname "PRODUCT_AUDIT.md" \
  ! -iname "SIW_*.md" \
  2> /dev/null
```

Read `references/existing-workflow-handling.md` and follow the first matching branch for `siw/DISCOVERY_BRIEF.md` only, `siw/DISCOVERY_BRIEF.md` + `siw/SPEC_STRENGTHENING_PLAN.md`, `siw/SPEC_STRENGTHENING_PLAN.md` only, other workflow files, or no files.

**If other workflow files exist:**

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: SIW workflow files already exist; rerun without --auto to resume, start fresh, or abort`. Do not delete existing workflow files in auto mode.

Use AskUserQuestion:

```yaml
header: "Existing Workflow Files Found"
question: "Workflow files already exist in this directory. How would you like to proceed?"
options:
  - label: "Resume existing workflow"
    description: "Continue with current files (invokes kramme:siw:continue skill)"
  - label: "Start fresh"
    description: "Delete existing workflow files and create new ones"
  - label: "Abort"
    description: "Cancel and keep existing files"
```

**If "Resume existing workflow":**

- Stop this command
- Inform user that the `kramme:siw:continue` skill will auto-trigger when they start working
- Suggest reading siw/LOG.md for current progress

**If "Start fresh":**

- Before deleting `siw/issues/`, count any existing issue files:

  ```bash
  ls siw/issues/ISSUE-*.md 2> /dev/null | wc -l
  ```

  If the count is greater than zero, surface a second confirmation using AskUserQuestion before deleting:

  ```yaml
  header: "Delete Existing Issues"
  question: "{n} issue file(s) in siw/issues/ will be deleted. This cannot be undone."
  options:
    - label: "Delete all issues"
      description: "Proceed with Start fresh; all issue files are removed"
    - label: "Abort"
      description: "Stop so I can back up or move issues out of siw/issues/ first"
  ```

  If "Abort", stop this command without changing any files.

- Delete existing temporary workflow files (`siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/issues/`, `siw/DISCOVERY_BRIEF.md`, `siw/SPEC_STRENGTHENING_PLAN.md`, `siw/AUDIT_IMPLEMENTATION_REPORT.md`, `siw/AUDIT_SPEC_REPORT.md`, `siw/PRODUCT_AUDIT.md`, and `siw/SIW_*.md`), but preserve any permanent SIW spec files matched by the `permanent-spec find` from earlier in Phase 1 (`*SPEC*.md`, `*SPECIFICATION*.md`, `*PLAN*.md`, `*DESIGN*.md`, case-insensitive; the permanent-spec find already excludes the synced SIW spec-exclusion contract). Use `trash` without recursive flags when available so the deleted workflow files are recoverable from the system Trash. If `trash` is missing, warn that deletion will be permanent and ask for explicit confirmation before running `rm -rf`. After deletion, verify each target with `[ ! -e "$path" ]`; report any surviving path as a deletion failure instead of continuing as if Start fresh succeeded.
- Continue to Phase 1.5

**If no files exist:** Continue to Phase 1.5

## Phase 1.5: Handle Arguments

`$ARGUMENTS` contains any text the user provided after `/kramme:siw:init`.

Use `resolved_arguments` as the effective Phase 1.5 input. If no Phase 1 branch already set `resolved_arguments`, default it to `$ARGUMENTS` now.

### Argument Parsing

Parse `resolved_arguments` to detect the input type:

1. **File path(s)**: Contains `.md`, `.txt`, or other file extensions
2. **Folder path**: A directory path (verify with `ls -d {path}`)
3. **"discover" keyword**: Starts with "discover" or "interview"
4. **Empty**: No arguments provided

If `resolved_arguments` is empty because the user ran plain `/kramme:siw:init`, but Phase 1 found only `siw/DISCOVERY_BRIEF.md`, treat that file as the single file-path input and follow Case 1.

### Case 1: File Path(s) Provided

If `resolved_arguments` contains file path(s):

1. Split arguments by spaces to get individual paths
2. If exactly one provided path ends with `DISCOVERY_BRIEF.md`:
   - Verify the file exists with `ls {path}`
   - Read the full file
   - Follow `references/discovery-brief-import.md` to extract sections and map them into `discovered_content`
   - Set `project_description` from the brief title or `What You Actually Want`
   - **Skip Phase 2**, continue to Phase 2.8 (Work Context Selection)
3. For any other file paths provided:
   - Verify file exists with `ls {path}`
   - Read file to extract only: title/name (from first heading)
   - If file doesn't exist, warn and skip it
4. Store file paths as `linked_spec_files` (do NOT extract full content - these remain the source of truth)
5. Extract a brief project name from the file titles for `project_description`
6. **Continue to Phase 2.5** (Confirm Linked Sources)

### Case 2: Folder Path Provided

If `resolved_arguments` is a directory (verified with `ls -d`):

1. Scan folder for relevant specification files:

   ```bash
   find {folder} -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" \) 2> /dev/null
   ```

2. Present found files to user. If `AUTO_MODE=true`, select **All files** automatically. Otherwise use AskUserQuestion:

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

3. If "None - start fresh" selected: Set `resolved_arguments` empty, **continue to Phase 2**
4. If "All files" or specific files selected: Store selected paths as `linked_spec_files`
5. **Continue to Phase 2.5** (Confirm Linked Sources)

### Case 3: "discover" Mode

If `resolved_arguments` starts with "discover" or "interview":

1. Extract optional topic from remaining `resolved_arguments`:
   - `discover authentication system` → topic = "authentication system"
   - `discover` alone → ask for topic

2. If no topic provided and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: discovery topic required for --auto`. If no topic provided and `AUTO_MODE` is false, use AskUserQuestion:

   ```yaml
   header: "Discovery Topic"
   question: "What topic should we explore? Describe what you're building or the problem you're solving."
   freeform: true
   ```
3. Do **not** run the legacy inline interview path here.
4. Before launching discovery, re-run the `permanent-spec find` from Phase 1 to check for permanent SIW spec files left in `siw/`.
5. If permanent spec files still exist, do **not** run greenfield discovery. If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: permanent SIW spec files already exist; rerun without --auto to choose whether to use them`. Otherwise use AskUserQuestion:
   ```yaml
   header: "Existing Spec Files Found"
   question: "Permanent SIW spec files still exist in siw/. A fresh discovery run would treat this as refinement, not a new project. How should I proceed?"
   options:
     - label: "Use existing specs"
       description: "Treat the existing spec files as linked sources instead of running discovery"
     - label: "Abort"
       description: "Stop so I can archive or remove the old spec files before running fresh discovery"
   ```
6. If "Use existing specs":
   - Store the detected paths as `linked_spec_files`
   - Read only the first heading from each file to infer titles
   - Set `project_description` from those titles
   - Continue to Phase 2.5
7. If "Abort": stop this command without changing files.
8. If no permanent spec files exist, read `references/greenfield-discovery-handoff.md` and follow it to run the greenfield discovery handoff. That handoff must produce `siw/DISCOVERY_BRIEF.md` before returning here.
9. Set `resolved_arguments=siw/DISCOVERY_BRIEF.md`.
10. Follow the import procedure from `references/discovery-brief-import.md` to populate `discovered_content`.
11. **Skip Phase 2**, continue to Phase 2.8 (Work Context Selection)

### Case 4: No Arguments

**Continue to Phase 2** (structured brief interview for overview, why-now, non-goals, and decision boundaries).

## Phase 2: Brief Interview

**Skip this phase if `imported_spec_content` or `discovered_content` exists from Phase 1.5.**

If `AUTO_MODE=true` and Phase 2 would run, stop before asking with `MISSING REQUIREMENT: project context required for --auto; pass a spec file, folder, discovery brief, or use discover <topic>`.

Use AskUserQuestion to gather context:

```yaml
header: "Project Context"
question: "In one sentence, what are you building or working on?"
freeform: true
```

Store the response as `project_description`.

Use AskUserQuestion to capture urgency and outcome:

```yaml
header: "Why Now"
question: "Why does this work matter now, and what outcome matters most?"
freeform: true
```

Store the response as `why_now`.

Use AskUserQuestion to capture scope boundaries:

```yaml
header: "Non-Goals"
question: "What should stay out of scope for this first pass?"
freeform: true
```

Store the response as `out_of_scope_non_goals`.

Use AskUserQuestion to capture decision boundaries:

```yaml
header: "Decision Scope"
question: "What decisions should this spec lock down now, and what should be left to implementation?"
freeform: true
```

Store the response as `decision_boundaries_notes`.

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

If `AUTO_MODE=true`, choose **Keep in place**. Otherwise use AskUserQuestion:

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

For both **"Move to siw/"** and **"Copy to siw/"**, before transferring each file, check the target path with `[ -e "siw/{filename}" ]`. If a file already exists at the target, use AskUserQuestion before overwriting:

```yaml
header: "Target File Exists"
question: "siw/{filename} already exists. How should I proceed for this file?"
options:
  - label: "Overwrite"
    description: "Replace siw/{filename} with the incoming file"
  - label: "Rename incoming"
    description: "Keep siw/{filename} and write the new file as siw/{filename-stem}-imported{ext}"
  - label: "Skip"
    description: "Leave both files where they are and reference the original path"
```

Apply the user's choice per file, then:

- **"Keep in place"**: Store paths as-is in `linked_spec_files`, continue to Phase 2.6
- **"Move to siw/"**:
  - Move each file to `siw/{filename}` (or the renamed/skipped path per the collision prompt above)
  - Update `linked_spec_files` with the resulting paths
  - Continue to Phase 2.6
- **"Copy to siw/"**:
  - Warn: "This creates duplicate files. Consider using 'Keep in place' to maintain a single source of truth."
  - If user confirms, copy files to `siw/` (or the renamed/skipped path per the collision prompt above)
  - Update `linked_spec_files` with the resulting paths
  - Continue to Phase 2.6

## Phase 2.6: Confirm Project Context

**Only executed if `linked_spec_files` exists.**

If `AUTO_MODE=true`, use the inferred default value. Otherwise use AskUserQuestion:

```yaml
header: "Project Context"
question: "Based on the linked files, what is this project about? (One sentence summary)"
freeform: true
defaultValue: "{inferred from file titles}"
```

Store the response as `project_description`.

### Alternative: Skip Context

If user provides empty response or selects "Skip", use a generic description derived from the linked file names.

## Phase 2.8: Work Context Selection

Before selecting the work context, check for repo-root `STRATEGY.md`.

- If it exists, read it and extract target problem, approach, who it is for, key metrics, active tracks, and non-goals.
- Store this as `strategy_context`.
- If its `last_updated` frontmatter is older than 90 days, mark relevant context `STALE:` in the generated spec.
- If the initialized work conflicts with an active track or non-goal, surface the conflict before asking about Work Context. Do not block initialization; the user may be intentionally changing strategy.
- If no `STRATEGY.md` exists, do not block or mention it for narrow work. For broad product-direction work, include `MISSING PRODUCT CONTEXT: no STRATEGY.md found` in the generated spec's strategy context note and suggest `/kramme:product:strategy` after initialization.

Select a work context profile that tells downstream tools (spec-audit, product-review, discovery, generate-phases) how to adapt their rigor and focus.

Read the profile definitions and auto-detection heuristics from `references/work-context-profiles.md`.

### Auto-detect Suggested Profile

Based on `project_description` (or `discovered_content` topic), use the keyword heuristics from the reference file to suggest a profile. Default to Production Feature.

### Ask User

If `AUTO_MODE=true`, choose the auto-detected profile. Otherwise use AskUserQuestion:

```yaml
header: "Work Context"
question: "What type of work is this? This adjusts how spec audits, product reviews, and phase generation behave."
options:
  - label: "{auto-detected profile} (Recommended)"
    description: "{one-line description from profile}"
  - label: "Production Feature"
    description: "Full rigor across all quality dimensions"
  - label: "Prototype / Spike"
    description: "Focus on actionability and technical design; skip commercial viability"
  - label: "Internal Tool"
    description: "Focus on actionability and clarity; skip value proposition"
  - label: "Tech Debt / Refactor"
    description: "Focus on technical design and testability; skip value proposition and scope"
  - label: "Documentation / Process"
    description: "Focus on clarity and completeness; skip technical design"
```

**Note:** Deduplicate — if the auto-detected profile is Production Feature, do not show it twice. Show one "Production Feature (Recommended)" option instead.

Store the selected profile as `work_context_profile` with all attribute values from the reference file (work_type, maturity, priority_dimensions, deprioritized, notes).

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

If `AUTO_MODE=true`, choose `{detected_name}` automatically.

Otherwise:

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

If `AUTO_MODE=true`, choose **No - single spec file is enough**. Otherwise use AskUserQuestion:

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

Read `references/document-creation.md` and follow it to create `siw/`, `siw/{spec_filename}`, `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/issues/`, and optional `siw/supporting-specs/`.

When `strategy_context` exists, include a concise `## Product Strategy Context` section in the generated SIW spec using the relevant placeholders from `assets/spec-templates.md`. Keep it to strategy facts and conflicts; do not duplicate the entire `STRATEGY.md`.

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
     OR /kramme:siw:issue-define to create issues one at a time
  2. Run /kramme:siw:issue-implement <G-XXX or P1-XXX> to start implementing

Tips:
  - The spec file is permanent; keep it updated as your source of truth
  - siw/LOG.md and siw/issues are temporary; delete them when work is complete
  - Use /kramme:workflow-artifacts:cleanup to remove temporary files when done
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
6. **Clear next steps** - Always point user to `/kramme:siw:issue-define`
7. **Respect existing work** - Never overwrite without explicit confirmation
