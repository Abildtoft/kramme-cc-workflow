# Tracker Schema Rules

Rules for editing `siw/OPEN_ISSUES_OVERVIEW.md`. Read this file from `Phase 6 Step 3` in `SKILL.md` when adding or updating a row.

Apply these rules only after the parent skill acquires publication ownership, re-reads the current overview, and (for creation) reserves the final ID. Derive the edit from that fresh state and verify it against the issue file and log before releasing ownership.

## Column layouts

Three layouts coexist for backwards compatibility:

| Layout | Columns | When to use |
| --- | --- | --- |
| Legacy 5-col | `# \| Title \| Status \| Priority \| Related` | Preserve in-place when section already uses it |
| Pre-Mode 6-col | `# \| Title \| Status \| Size \| Priority \| Related` | Preserve in-place when section already uses it |
| Modern 7-col | `# \| Title \| Status \| Size \| Priority \| Mode \| Related` | Use for brand-new modern sections |

**Migration rule:** Never migrate a legacy/pre-Mode section to the 7-col layout unless the user explicitly asks for a schema migration. In-place edits must match the existing column count.

The 7-col row template:

```markdown
| {prefix}-{number} | {Title} | {Status} | {Size} | {Priority} | {Mode} | {Related} |
```

The `{Mode}` cell is `AUTO` or `HITL` — no inline reason; the reason lives in the issue file body.

## Parallelization summary line

Optional section-level line that appears under a section header:

```markdown
**Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination | Mixed — see issue files}
```

Whether to add, update, or omit it depends on the section:

### `## General`

Treat any existing `**Parallelization:**` line as a roll-up summary. After creating or updating a real General issue, recompute it from all non-placeholder `G-*` issue files:

- All real General issues share the same category → use that shared summary.
- Real General issues disagree → `Mixed — see issue files for exact guidance`.
- Section is still the empty placeholder (`_None_` row, no real issues) → replace the default summary from `siw:init` with this first real issue's section-level category.
- Legacy General section has no `**Parallelization:**` line → keep it absent.

### Phase sections

Preserve the existing section-level `**Parallelization:**` summary exactly as written. The phase-level plan is approved separately and should stay stable even when individual issues vary.

- Legacy phase section has no `**Parallelization:**` line → keep it absent.
- Creating a brand-new modern phase section → seed the line from this first issue's approved guidance and keep it stable afterwards unless the phase plan is re-approved.

## Phase DONE marker

`(DONE)` suffix on a phase section header signals the entire phase is complete.

- Updating a phase issue to `DONE` and no READY / IN PROGRESS / IN REVIEW remain in that section → append ` (DONE)` to the section header so the marker matches the tracker state.
- Creating or updating a non-`DONE` phase issue under a header currently marked ` (DONE)` → remove the marker so the header matches the tracker state.
