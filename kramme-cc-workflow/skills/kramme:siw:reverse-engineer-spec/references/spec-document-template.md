Write `siw/{spec_filename}` with this structure:

```markdown
# {Feature/Project Name}

## Overview

{Problem statement: what user/business pain this addresses, inferred from code and tests}

{Solution overview: high-level description of the approach and key design properties}

**Status:** Reverse-engineered from code
**Created:** {current date}
**Source:** {Branch `{branch}` vs `{base}` | Folder `{path}` | Files}

## Objectives

{Inferred from tests and code structure, formatted as checkbox list}
- [ ] {objective 1}
- [ ] {objective 2}

## Scope

### In Scope
{What the code actually implements}

### Out of Scope
{What the code explicitly does NOT handle, inferred from boundaries and missing test coverage}

## Success Criteria

{Inferred from test assertions and observable behavior, formatted as checkbox list}
- [ ] {criterion 1 — a verifiable condition that must hold}
- [ ] {criterion 2}

## Architecture

{If component relationships are clear from analysis, include an ASCII diagram showing data flow. Otherwise, use a bullet-point list of components and their dependencies.}

### Data Lifecycle
{Step-by-step flow from initial state through steady state}

## Technical Design

### Data Model
{Core data structures, types, schemas — from Agent A synthesis}

### API Contracts
{Endpoints, methods, request/response shapes — from Agent B synthesis}
{Skip if not applicable}

### Key Patterns
{Architectural patterns, algorithms, integration approaches}

### Feature Flags & Gating
{From Agent D synthesis, skip if none}

### Error Handling
{Error scenarios and fallback behavior observed in code}

## File Inventory

### New Files
| File | Purpose |
|------|---------|
| `{path}` | {one-line description} |

### Modified Files
| File | Changes |
|------|---------|
| `{path}` | {one-line description of key changes} |

## Testing Strategy

### Unit Tests
{From Agent C synthesis}

### Integration / E2E Tests
{From Agent C synthesis}

### Coverage Gaps
{Missing test coverage identified by Agent C}

## Tasks

Tasks will be tracked in individual issue files. See `siw/OPEN_ISSUES_OVERVIEW.md` for active work.

## Design Decisions

| Decision | Choice | Rationale (inferred) |
|----------|--------|----------------------|
| {area} | {what was chosen} | {why, from code patterns and commits} |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {risk} | {H/M/L} | {H/M/L} | {existing or suggested mitigation} |

## Open Questions

{Areas where intent is unclear from code alone — these are candidates for `/kramme:siw:discovery`}

- {question 1}
- {question 2}

## References

- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
- Progress: `siw/LOG.md`
{If branch diff mode:}
- Branch: `{branch}` (base: `{base_branch}`)
- Commits: {n} commits, {files_changed} files changed
```
