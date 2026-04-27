# Overview Update

Rebuild the issues table **maintaining section groupings**:

1. Remove all DONE rows from each section
2. Update issue numbers for remaining rows within each prefix group
3. Preserve the existing table schema for each section:
   - If the section uses `| # | Title | Status | Size | Priority | Mode | Related |`, keep `Size` and `Mode`
   - If the section uses `| # | Title | Status | Size | Priority | Related |`, keep `Size`
   - If the section uses the legacy `| # | Title | Status | Priority | Related |`, keep the legacy layout
4. Handle section-level metadata lines carefully:
   - Preserve non-`**Parallelization:**` metadata exactly as written.
   - For `## General`, only recompute the `**Parallelization:**` summary if that line already exists:
     - If every real General issue shares the same section-level category/gating note, use that shared summary.
     - If real General issues disagree, set the summary to `Mixed — see issue files for exact guidance`.
     - If no real General issues remain, keep or restore the default summary from `siw:init`.
   - If an existing legacy General section has no `**Parallelization:**` line, keep it absent; do not add or restore one during reindex.
   - For phase sections, preserve the approved summary wording, but if the `**Parallelization:**` line names concrete issue ids (`P1-003`, `ISSUE-P1-003`, etc.), rewrite those ids with the same collision-safe `renumberById` / `deletedById` rules used for issue bodies and `LOG.md` so the gating note stays accurate after renumbering. If a legacy phase section has no `**Parallelization:**` line, keep it absent.
5. Preserve section headers (General, Phase 1, Phase 2, etc.) exactly as written (including any ` (DONE)` marker on phase headers)

**Before:**
```markdown
## General

**Parallelization:** Safe to parallelize

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| G-001 | Setup | DONE | S | High | AUTO | |
| G-002 | Docs | READY | XS | Low | AUTO | |
| G-003 | Config | READY | S | Medium | HITL | |

## Phase 1: Foundation

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| P1-001 | Feature A | IN PROGRESS | M | High | AUTO | Task 1.0 |
| P1-002 | Feature B | DONE | S | High | AUTO | Task 2.0 |
| P1-003 | Bug Fix | READY | S | Medium | HITL | Task 3.0 |
```

**After:**
```markdown
## General

**Parallelization:** Safe to parallelize

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| G-001 | Docs | READY | XS | Low | AUTO | |
| G-002 | Config | READY | S | Medium | HITL | |

## Phase 1: Foundation

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Mode | Related |
|---|-------|--------|------|----------|------|---------|
| P1-001 | Feature A | IN PROGRESS | M | High | AUTO | Task 1.0 |
| P1-002 | Bug Fix | READY | S | Medium | HITL | Task 3.0 |
```
