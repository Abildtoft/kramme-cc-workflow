# Documentation Templates

Templates for generating project documentation during SIW close.

## `README.md` -- Project Summary

```markdown
# {Project Title}

## Overview

{Overview text from spec, rewritten to be self-contained}

**Status:** Completed
**Completed:** {current date}

## What Was Built

{Narrative summary synthesized from completed issues and spec objectives.
Describe what the implementation delivers, not a list of issue IDs.}

### Scope

**Included:**
{In-scope items from spec, updated based on what was actually implemented}

**Excluded:**
{Out-of-scope items from spec}

## Key Decisions

{N} design decisions were made during this project. See [decisions.md](decisions.md) for full details.

Notable decisions:
- **{Decision title}**: {one-line summary}
- **{Decision title}**: {one-line summary}
- **{Decision title}**: {one-line summary}
{Top 3-5 most impactful decisions}

## Architecture

{If architecture.md was generated:}
See [architecture.md](architecture.md) for technical design details.

{If no architecture.md: brief technical summary from spec's Technical Design
section if it existed, otherwise omit this section entirely.}

## Guiding Principles

{Principles from LOG.md -- learned wisdom during implementation}

1. {Principle 1}
2. {Principle 2}

## Implementation Summary

| Metric | Value |
|--------|-------|
| Issues completed | {done count} / {total count} |
| Decisions made | {N} |

{If any issues were not DONE:}
### Deferred Work
- {Issue title} ({status})
```

## `decisions.md` -- Architecture Decision Records

```markdown
# Design Decisions

Key design decisions made during the {project title} implementation.
Each decision includes context, the choice made, alternatives considered, and rationale.

## Decision Index

| # | Title | Category | Date |
|---|-------|----------|------|
| 1 | {title} | {category} | {date} |
...

---

## Decision #{N}: {Title}

**Date:** {date} | **Category:** {category}

### Context
{Problem statement -- what needed to be decided and why}

### Decision
{The chosen approach}

### Rationale
{Why this was chosen}

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| {alt 1} | {reason} |
| {alt 2} | {reason} |

### Impact
{What changed as a result}

---
```

**Source mapping:**
- Decision fields from LOG.md Decision Log entries
- Merge rejected alternatives from both LOG.md per-decision "Alternatives" and the Rejected Alternatives Summary table

**If no decisions found:** Write a brief note: "No formal design decisions were recorded during this project."

## `architecture.md` -- Technical Design (Conditional)

**Only generate this file if at least one of:**
- The spec has a `## Technical Design` section
- Supporting specs exist with substantive content
- 5+ decisions with architecture-related categories

```markdown
# Architecture

## Technical Overview

{From spec's Technical Design section and/or supporting specs}

## Data Model

{From supporting spec matching *data-model* or spec's data model section}

## API Design

{From supporting spec matching *api* or spec's API section}

## Component Structure

{From supporting spec matching *ui*, *frontend*, or *architecture*}
```

Include only sections that have content. Omit empty sections.
