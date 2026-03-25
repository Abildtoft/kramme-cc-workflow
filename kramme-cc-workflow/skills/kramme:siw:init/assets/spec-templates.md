# SIW Spec Templates

Three spec template variants for Phase 4 "Create Specification Document". Choose based on how the project was initialized.

## Slim Spec (for linked external files)

Use when `linked_spec_files` exists. The SIW spec acts as a lightweight coordination document that references external specifications. **Do NOT duplicate content from linked files.**

```markdown
# {Project Title}

## Overview

{project_description from Phase 2.6}

**Status:** Planning
**Created:** {current date}

## Work Context

| Attribute | Value |
|-----------|-------|
| **Work Type** | {work_context_profile.work_type} |
| **Maturity** | {work_context_profile.maturity} |
| **Priority Dimensions** | {work_context_profile.priority_dimensions} |
| **Deprioritized** | {work_context_profile.deprioritized or "None"} |
| **Notes** | {work_context_profile.notes or empty} |

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

## Rich Spec (from discovery mode interview)

Use when `discovered_content` exists. Discovery mode generates content through interview, so the spec should capture those findings.

```markdown
# {Project Title}

## Overview

{Discovered description from interview}

**Status:** Planning
**Created:** {current date}
**Source:** Discovery interview

## Work Context

| Attribute | Value |
|-----------|-------|
| **Work Type** | {work_context_profile.work_type} |
| **Maturity** | {work_context_profile.maturity} |
| **Priority Dimensions** | {work_context_profile.priority_dimensions} |
| **Deprioritized** | {work_context_profile.deprioritized or "None"} |
| **Notes** | {work_context_profile.notes or empty} |

## Why Now

{Why this matters now and what outcome matters most}

## Objectives

{Objectives from interview}
{Format as checkbox list}

## Scope

### In Scope
{If available from interview}
{Else: "- To be defined"}

### Out of Scope / Non-Goals
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
  Use /kramme:siw:issue-define to create formal issues."}

## Design Decisions

{Include Key Decisions table from interview:
| Decision | Choice | Rationale |
|----------|--------|-----------|
| {area} | {what decided} | {why} |
}

## Decision Boundaries

{If available from interview:
### Captured in this spec
{Product, behavior, or scope decisions that need alignment}

### Left to implementation
{Engineering choices intentionally left open}
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

## Basic Spec (brief interview only)

Use when no linked files or discovered content (current default behavior).

```markdown
# {Project Title from description}

## Overview

{project_description}

**Status:** Planning
**Created:** {current date}

## Work Context

| Attribute | Value |
|-----------|-------|
| **Work Type** | {work_context_profile.work_type} |
| **Maturity** | {work_context_profile.maturity} |
| **Priority Dimensions** | {work_context_profile.priority_dimensions} |
| **Deprioritized** | {work_context_profile.deprioritized or "None"} |
| **Notes** | {work_context_profile.notes or empty} |

## Why Now

{why_now or "To be defined"}

## Objectives

- [ ] {Placeholder - define during issue creation}

## Scope

### In Scope
- {To be defined}

### Out of Scope / Non-Goals
{out_of_scope_non_goals or "To be defined"}

## Success Criteria

- [ ] {To be defined}

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

## Design Decisions

Key decisions will be documented in `siw/LOG.md` as they are made.

## Decision Boundaries

{decision_boundaries_notes or "To be defined"}

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
```

## Supporting Specs Section (optional)

If `use_supporting_specs` is true, add this section before "## Design Decisions" in any template:

```markdown
## Supporting Specifications

| # | Document | Description |
|---|----------|-------------|
| _None yet_ | _Create files in `siw/supporting-specs/`_ | |

**Naming convention:** `NN-descriptor.md` (e.g., `01-data-model.md`, `02-api-specification.md`)

See `assets/spec-guidance.md` for detailed guidance on supporting specs.
```
