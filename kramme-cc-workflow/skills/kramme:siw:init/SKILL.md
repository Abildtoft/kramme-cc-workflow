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

**Issue definition is a separate workflow.** After this command completes, invoke `/kramme:siw:issue-define` to create your first issue, or `/kramme:siw:generate-phases` when the spec should be decomposed into phased issues. **Spec hardening is a separate workflow.** To strengthen an existing SIW spec, use `/kramme:siw:discovery`.

### Artifact Readiness Contract

Use this shared vocabulary in setup summaries and handoffs:

- `product-only`: the source explains the problem, user, or desired outcome but still lacks testable scope or success criteria.
- `requirements-only`: scope and success criteria exist, but implementation planning still lacks phase boundaries, dependencies, or enough technical context.
- `planning-ready`: the SIW spec is concrete enough for `/kramme:siw:generate-phases` or `/kramme:siw:issue-define`.
- `implementation-ready`: an issue file has executable scope, dependencies, acceptance criteria, and verification. This skill never produces implementation-ready artifacts.

`siw:init` creates the tracked planning container. It may preserve a `product-only` or `requirements-only` source as context, or produce a `planning-ready` SIW spec when the imported/discovered content is concrete enough; it must not imply implementation is ready until issues exist.

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
[Report success] -> Suggest next readiness-gated skill
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
# Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
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

## Phase 1.5: Handle Arguments

Read `references/argument-handling.md` and follow the matching case for file paths, folder paths, `discover` / `interview`, or no arguments. This phase sets `linked_spec_files`, `linked_spec_readiness_context`, `discovered_content`, `project_description`, or `resolved_arguments` for later phases.

## Phase 2: Brief Interview

**Skip this phase if `imported_spec_content` or `discovered_content` exists from Phase 1.5.**

If `AUTO_MODE=true` and Phase 2 would run, stop before asking with `MISSING REQUIREMENT: project context required for --auto; pass a spec file, folder, discovery brief, or use discover <topic>`.

Read the Phase 2 templates from `references/interviews.md`, use them to gather project context, urgency and outcome, scope boundaries, and decision boundaries, then store the responses as `project_description`, `why_now`, `out_of_scope_non_goals`, and `decision_boundaries_notes`.

## Phase 2.5: Confirm Linked Sources

**Only executed if `linked_spec_files` exists from Phase 1.5 (file/folder import).**

**Skip this phase if `discovered_content` exists (discover mode already has confirmation built in).**

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

If `AUTO_MODE=true`, choose **Keep in place**. Otherwise read the Phase 2.5 file-location template from `references/interviews.md` and use AskUserQuestion.

For both **"Move to siw/"** and **"Copy to siw/"**, before transferring each file, check the target path with `[ -e "siw/{filename}" ]`. If a file already exists at the target, read the Phase 2.5 collision template from `references/interviews.md` and use AskUserQuestion before overwriting.

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

If `AUTO_MODE=true`, use the inferred default value. Otherwise read the Phase 2.6 project-context template from `references/interviews.md` and use AskUserQuestion.

Store the response as `project_description`.

If user provides empty response or selects "Skip", use a generic description derived from the linked file names.

## Phase 2.8: Work Context Selection

Before selecting the work context, check for repo-root `STRATEGY.md`. If it exists, read it, store concise `strategy_context`, mark stale context with `STALE:` when `last_updated` is older than 90 days, and surface conflicts with active tracks or non-goals without blocking initialization. If no strategy exists, stay silent for narrow work; for broad product-direction work, include `MISSING PRODUCT CONTEXT: no STRATEGY.md found` in the generated spec's strategy context note and suggest `/kramme:product:strategy` after initialization.

Select a work context profile that tells downstream tools (spec-audit, product-review, discovery, generate-phases) how to adapt their rigor and focus.

Read the profile definitions and auto-detection heuristics from `references/work-context-profiles.md`.

Based on `project_description` or `discovered_content` topic, use the keyword heuristics from the reference file to suggest a profile. If `AUTO_MODE=true`, choose the auto-detected profile; otherwise read the Phase 2.8 work-context template from `references/interviews.md`, deduplicate options as documented there, and use AskUserQuestion.

Store the selected profile as `work_context_profile` with all attribute values from the reference file (work_type, maturity, priority_dimensions, deprioritized, notes).

## Phase 3: Auto-detect Spec Type and Confirm

Use the Phase 3 filename detection heuristics in `references/interviews.md` to auto-detect the most appropriate spec filename. If `AUTO_MODE=true`, choose it automatically. Otherwise read the Phase 3 specification-document template from `references/interviews.md` and use AskUserQuestion; if "Custom name" is selected, use AskUserQuestion to get the filename.

Store as `spec_filename`.

## Phase 3.5: Ask About Supporting Specs

If `AUTO_MODE=true`, choose **No - single spec file is enough**. Otherwise read the Phase 3.5 supporting-specifications template from `references/interviews.md` and use AskUserQuestion.

Store as `use_supporting_specs`.

## Phase 4: Create Documents

Read `references/document-creation.md`, apply its readiness classification procedure, and follow it to create `siw/`, `siw/{spec_filename}`, `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/issues/`, and optional `siw/supporting-specs/`.

When `strategy_context` exists, include a concise `## Product Strategy Context` section in the generated SIW spec using the relevant placeholders from `assets/spec-templates.md`. Keep it to strategy facts and conflicts; do not duplicate the entire `STRATEGY.md`.

## Phase 5: Report Success

Read the Phase 5 success-report templates from `references/success-report.md`, display the applicable summary sections, then stop.

Include one readiness line in the success report:

```
Artifact readiness: <product-only|requirements-only|planning-ready> — <one-line reason and next skill>
```

If the result is `product-only` or `requirements-only`, point to `/kramme:siw:discovery` before phase or issue creation. If it is `planning-ready`, point to `/kramme:siw:generate-phases` for phased work or `/kramme:siw:issue-define` for a single first issue.

**STOP HERE.** Wait for the user's next instruction.

## Important Guidelines

1. **Link, don't duplicate** - When external specs are provided, reference them; never copy their content into the SIW spec (single source of truth)
2. **Smart input handling** - Accept file paths, folders, or "discover" keyword; fall back to brief interview if no arguments
3. **Offer file relocation** - Ask if linked files should be moved into siw/ or kept in place
4. **Thorough discovery** - When using discover mode, conduct comprehensive interview before creating spec
5. **Smart defaults** - Auto-detect spec type but always confirm
6. **Clear next steps** - Always point user to the next skill implied by readiness: discovery for hardening, generate-phases for phased planning, or issue-define for a single issue
7. **Respect existing work** - Never overwrite without explicit confirmation
