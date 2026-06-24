# Knowledge Extraction

Read all existing SIW files and extract structured knowledge before generating documentation.

## Missing Workflow Files and Minimal Mode

If the close is running in minimal mode, or if an optional workflow file is absent, continue with explicit defaults instead of failing or leaving output placeholders:

- Missing `siw/LOG.md`: extract decisions only from the spec's `## Design Decisions` section; set guiding principles, rejected alternatives, and final project status to empty.
- Missing `siw/OPEN_ISSUES_OVERVIEW.md`: set phase structure, issue count, and completion percentage to empty.
- Missing `siw/issues/`: skip issue resolution extraction and deferred-work extraction.
- Missing audit reports: omit quality verification evidence.

If neither LOG.md nor the spec contains design decisions, use the no-decisions handling from `references/edge-cases.md`.

## From the Spec (`siw/[YOUR_SPEC].md`)

Extract:

- **Project title** (from `#` heading)
- **Overview** (from `## Overview`)
- **Problem statement** (from `## Problem Statement` if present)
- **Stakeholders** (from `## Who's Affected` if present)
- **Objectives** (from `## Objectives`)
- **Scope** (from `## Scope` -- In Scope, Out of Scope, and Deferred)
- **Success criteria** (from `## Success Criteria`)
- **Priority tradeoffs** (from `## Priorities & Tradeoffs` if present)
- **Constraints** (from `## Constraints` if present)
- **Design decisions** (from `## Design Decisions`)
- **Decision boundaries** (from `## Decision Boundaries` if present)
- **Risks** (from `## Risks` if present)
- **Discovery notes** (from `## Discovery Notes` if present)
- **Technical design** (from `## Technical Design` if present)
- **Linked specifications** (from `## Linked Specifications` if present)

## From Supporting and Contract Specs (`siw/supporting-specs/*.md`, `siw/contracts/*.md`)

For each supporting or contract spec:

- Extract title and key content
- Categorize by domain (data model, API, UI, etc.)

## From `siw/LOG.md`

Extract:

- **Decision Log entries** -- all decisions with number, title, problem, decision, rationale, alternatives, impact
- **Guiding Principles** (from `## Guiding Principles`)
- **Rejected Alternatives Summary** (from the table)
- **Final project status** (from `## Current Progress`)

## From `siw/OPEN_ISSUES_OVERVIEW.md`

Extract:

- Phase structure (from section headers)
- Issue count and completion percentage
- All issues with final statuses

## From Individual Issue Files (`siw/issues/ISSUE-*.md`)

For DONE issues:

- Title, description, resolution section

For non-DONE issues:

- Title and status (listed as deferred work)

## From Audit Reports (if present)

From `siw/AUDIT_IMPLEMENTATION_REPORT.md` and `siw/AUDIT_SPEC_REPORT.md`:

- Note their existence as quality verification evidence

## Deduplicate Decisions

Decisions may appear in both LOG.md and the spec's Design Decisions section (from prior resets or syncs):

1. Read decisions from LOG.md (primary, most complete)
2. Read decisions from spec's Design Decisions section
3. Match by decision number (`Decision #N`) or title
4. Prefer the LOG.md version (has full detail: alternatives, impact)
5. Include any decisions that appear only in the spec
