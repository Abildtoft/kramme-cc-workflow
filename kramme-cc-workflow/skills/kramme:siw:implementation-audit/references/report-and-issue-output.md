## Step 8: Write Report File

### 8.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_IMPLEMENTATION_REPORT.md`
- If no `siw/` directory: `AUDIT_IMPLEMENTATION_REPORT.md` in project root

### 8.2 Handle Existing Report

If `INLINE_MODE=true`, skip this overwrite step because no report file will be written.

Otherwise, if a previous report exists at the target path:

If `AUTO_MODE=true`, choose **Replace** automatically.

Otherwise:

```yaml
header: "Existing Audit Report"
question: "A previous audit report exists. How should I proceed?"
options:
  - label: "Replace"
    description: "Overwrite with new audit results"
  - label: "Append"
    description: "Add new audit as a dated section (preserves history)"
  - label: "Abort"
    description: "Cancel — keep existing report"
```

### 8.3 Final Gate Before Write (Mandatory)

Do **not** write a final report unless all are true:

- Coverage matrix is complete
- All conflicts are resolved
- Every reported Divergence/Extension/Alignment has the evidence triplet

If any gate fails:

```
Audit Blocked
=============

Reason(s):
- {missing coverage rows}
- {unresolved conflicts}
- {findings missing evidence}

No final report was written.
```

**STOP HERE.** Do not continue to Step 9. Wait for the user's next instruction.

### 8.4 Write the Report

If `INLINE_MODE=true`:

- Reply with the compiled report inline
- Do **not** create or update `siw/AUDIT_IMPLEMENTATION_REPORT.md` or `AUDIT_IMPLEMENTATION_REPORT.md`

Otherwise:

- Write the compiled report to the target path
- After writing, confirm:
  ```
  Audit report written to: {path}
  ```

---

## Step 9: Optionally Create SIW Issues

**Skip this step entirely if `INLINE_MODE=true`.** Inline mode means the user asked for ephemeral output; do not write issue files. Proceed straight to Step 10.

**Otherwise, only if ALL of these conditions are met:**

- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Actionable findings were found (`Divergences + Extensions > 0`)

### 9.1 Ask User

If `AUTO_MODE=true`, skip the prompt template and choose **Critical and major only** from `assets/create-issues-prompt.yaml`.

Otherwise:

Use the prompt template from `assets/create-issues-prompt.yaml`.

### 9.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 9 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section so updates can be appended safely.
   - If creation fails, warn and skip Step 9 (report-only mode).

### 9.3 Create Issue Files

For each selected finding:

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-fix-{slugified-title}.md` using the template in `assets/siw-issue-template.md`.
   - Assign each issue an explicit `Size` (`XS|S|M|L`) and `Parallelization` category (`Safe to parallelize | Must be sequential | Needs coordination`) so the generated SIW issue matches the current tracker schema.
   - Assign each issue an explicit `Mode`. **Default `AUTO`.** Most divergence/extension fixes are AUTO. Set `HITL — <one-line reason>` only when the fix requires a concrete human-input step: an unsettled architectural/product decision, design review, a judgment call, manual testing that can't be automated, or external-system access. When unclear, choose `AUTO`.

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
   - For a brand-new modern section, use the 7-column modern schema including the `Mode` column (`# | Title | Status | Size | Priority | Mode | Related`); the `Mode` cell is `AUTO` or `HITL` (the reason lives in the issue body, not the table).
   - When a section already exists, match its column count exactly (legacy 5-col / pre-Mode 6-col / modern 7-col) and preserve it in place — do not migrate layouts or add a `Mode` column to a section that lacks one.
   - If `## General` already has a section-level `**Parallelization:**` line, treat that line as a roll-up summary for the whole section rather than a per-issue mirror.
   - Recompute it from all real `G-*` issue files after adding the new issue: if every issue shares the same section-level category/gating note, keep that shared summary; otherwise set it to `Mixed — see issue files for exact guidance`.
   - If the General section is still in its empty placeholder state (`_None_` row / no real issues yet), replace the default summary from `siw:init` with the first real issue's category.
   - If an existing legacy General section has no `**Parallelization:**` line, preserve that absence instead of inserting one.
4. Update `siw/LOG.md` Current Progress section using `assets/log-last-completed.md`.
