# SIW Artifact Extraction

Read this file from `Phase 2: Extract SIW Artifacts` in `SKILL.md`.

## Main Spec Detection

Build main-spec candidates from markdown files directly under the SIW directory, excluding:

- `LOG.md`
- `OPEN_ISSUES_OVERVIEW.md`
- `LINEAR_TRANSFER.md`
- `DISCOVERY_BRIEF.md`
- `SPEC_STRENGTHENING_PLAN.md`
- `AUDIT_*.md`
- `PRODUCT_AUDIT.md`
- `SIW_*.md`

If no candidate exists, stop with a missing spec message rather than inventing one. If exactly one candidate exists, use it. If multiple exist, build a deterministic match set from files whose filename or first `#` heading matches the project title in `LOG.md`.

Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.

If exactly one candidate matches, use it. If zero or multiple candidates remain after matching, this interactive migration presents the candidates and asks the user which one is the main spec.

Candidates that lose the tiebreak stay in the Document set: they are still source-of-truth planning documents (a developer brief, for example) and must be migrated as Linear Documents, not dropped.

Read supporting specs from `supporting-specs/*.md` when present.

## Document Sources

The migration captures planning documents as Linear Documents so they survive after `siw/` is retired. Read and keep the full markdown content of:

- The main spec.
- Each `supporting-specs/*.md` file.
- Each non-selected main-spec candidate.
- `LOG.md` — the canonical decision register. Issue bodies cite it as `D-0xx`; without it as a Document, every citation dangles after `siw/` removal.

For each, record a title (first `#` heading, else the filename without extension; Document Mapping appends the original filename) and the file body. Preserve the body as-is. This content feeds Document Mapping in `references/linear-mapping.md`.

## Non-Markdown Artifacts

Enumerate non-`.md` files under the SIW directory (recursively) — `.pptx` storyboards, images, spreadsheets, anything a Linked Specifications table may cite. These cannot become Linear Documents. Surface each one in the migration plan as `cannot migrate — needs relocation`, and gate the Phase 7 removal prompt on them: the prompt may not green-light deleting a cited source artifact that exists nowhere but `siw/`. When Linear attachment-upload tools are available (such as `prepare_attachment_upload` / `create_attachment_from_upload`), offer uploading them instead.

## Project Identity

Extract these fields:

- **Name**: first `#` heading in the main spec. Fall back to the spec filename without extension.
- **Summary**: first useful paragraph under `## Overview`, `## Summary`, or `## Problem Statement`.
- **Problem and value**: the plain-language problem statement, who it affects, and the intended outcome, from sections like `## Problem Statement`, `## Goals`, `## Why`, `## Value Proposition`, or the success criteria. This feeds the stakeholder-facing Summary and Value sections of the project description in `references/linear-mapping.md`, so favor outcome language over implementation detail.
- **Scope**: bullets under `## Scope`, including explicit in-scope and out-of-scope sections.
- **Success criteria**: bullets or checklist items under `## Success Criteria`, `## Acceptance Criteria`, or similar headings.
- **Work context**: table or bullets under `## Work Context`, if present.
- **Phase structure**: headings matching `Phase N`, `P{N}`, or milestone language in the main spec and `OPEN_ISSUES_OVERVIEW.md`.

Keep extraction evidence compact. Store source file paths internally for traceability, but avoid flooding the user with raw file content.

## Log Extraction

From `LOG.md`, extract:

- Current project status.
- Last completed work.
- Next steps.
- Decision log entries.
- Guiding principles.
- Rejected alternatives.

Use the log to enrich the Linear project description, not to create extra issues unless the log explicitly lists deferred work that is not already represented by an SIW issue. The log's full content additionally migrates as a Linear Document (see Document Sources) — description enrichment is a summary, not a substitute.

## Milestone Discovery

Build milestone candidates from phase-like sections in this order:

1. Phase sections in `OPEN_ISSUES_OVERVIEW.md`, such as `## Phase 1: Core Workflow`.
2. Phase or milestone headings in the main spec, such as `## Phase 2`, `### P3`, or `## Milestone: Beta`.
3. Explicit milestone tables or timelines in supporting specs.

For each milestone candidate, extract:

- **Phase key**: `P1`, `P2`, etc. when a numbered phase is present.
- **Name**: use `Phase N: {title}` when available; otherwise use the heading text.
- **Description**: phase goal, outcome, or first useful paragraph/bullets under the phase heading.
- **Target date**: only when the SIW artifacts state a concrete date. Do not infer dates from order, priority, or phase number.
- **Status**: mark phase sections ending in `(DONE)` as completed for planning purposes, but only set a Linear milestone status when the Linear API exposes a confident matching state.

General issues (`G-*`) never receive a milestone assignment. Do not create a "General" milestone for them during this transfer, even when the SIW artifacts have a General section.

## Issue Discovery

Read issue files from:

```text
{siw-dir}/issues/ISSUE-*.md
```

For each issue file, extract:

- SIW ID from the heading or filename, such as `G-001`, `P1-002`, or `ISSUE-G-001`.
- Title from the first heading after the ID.
- Normalized planned Linear issue title for retry matching.
- Status from the `**Status:**` metadata line, compared case-insensitively — legacy issue files may use `Ready` while the tracker/legend uses `READY`; treat them as the same value (READY, IN PROGRESS, IN REVIEW, DONE).
- Priority, size, phase, parallelization, mode, and related values from the same metadata line when present.
- Milestone assignment from the issue phase metadata or the overview section containing the issue. For `G-*` issues, set milestone assignment to empty regardless of section text.
- Body sections: Problem, Context, Scope, Decision Boundaries, Acceptance Criteria, Edge Cases, Technical Notes, Resolution.
- Dependency edges from the `Blocked by:` / `Blocks:` lines (under `Technical Notes > Dependencies`), with `None` treated as empty and ranges like `P3-002..P3-007` expanded into individual SIW IDs. These drive the native-relation pass in `references/linear-mapping.md` > Dependencies.
- Linear transfer marker, if a `## Linear Transfer` section exists:
  - Linear issue identifier and URL from `- Linear issue: ...`
  - Linear project URL from `- Linear project: ...`
  - Transfer date from `- Transferred: ...`
- Source path.

Normalize SIW IDs to short form (`G-001`, `P1-002`) for mapping. Preserve the full source filename in the transfer report.

Build a duplicate-title set from the normalized planned Linear issue titles for source issues that do not already have a `## Linear Transfer` marker, and preserve duplicate groups in the transfer report. The title-fallback rules in `references/linear-mapping.md` consume this set.

Treat a populated `## Linear Transfer` section as evidence that the source issue was already transferred. The retry plan can use the recorded Linear issue identifier/URL for `skip-existing` actions without querying by title first.

## Tracker Extraction

Read `OPEN_ISSUES_OVERVIEW.md` to supplement issue metadata:

- Section headers establish General or Phase grouping.
- Tables may use 5, 6, or 7 columns. Preserve all available columns, but do not assume every table has Size or Mode.
- Section-level `**Parallelization:**` lines provide default parallelization for issues in that section when the issue file omits it.

If an issue appears in the overview but the corresponding issue file is missing, mark it `needs decision` in the plan. The user can choose to create a Linear issue from the overview row only, skip it, or stop and repair SIW tracking.

This migration is one-way and persists no standalone `LINEAR_TRANSFER.md`. Prior-run mapping lives only in per-issue `## Linear Transfer` sections, so every run extracts retry state from the SIW issue files themselves.
