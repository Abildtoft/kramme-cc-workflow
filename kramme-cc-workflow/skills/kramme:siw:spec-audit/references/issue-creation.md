# SIW Issue Creation (Step 6 detail)

Use this when `SKILL.md` reaches Step 6 and the audit found issue-eligible findings.

**Do not invoke this reference when `INLINE_MODE=true`.** Inline runs are read-only previews and must not write issue files or update tracker/log files.

## Eligibility

Only create SIW issues if ALL of these conditions are met:

- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Critical or Major findings were found, or a Minor finding preserves original Critical or Major severity via `**Severity Note:** [Deprioritized — capped at Minor from {original_severity}]`

## 6.1 Ask User

If `AUTO_MODE=true`, skip this prompt and choose **Critical and major only** (this also includes Minor findings whose `Severity Note` preserves original Critical or Major severity).

Otherwise:

```yaml
header: "Create SIW Issues"
question: "Found {N} actionable spec findings. Create SIW issues for them?"
options:
  - label: "Critical and major only"
    description: "Create {N} issues for visible Critical/Major findings plus Minor findings that preserve original Critical or Major severity"
  - label: "All findings"
    description: "Create {N} issues including minor ones"
  - label: "Let me select"
    description: "Choose which findings become issues"
  - label: "No issues"
    description: "Keep the report only"
```

## 6.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 6 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section.
   - If creation fails, warn and skip Step 6 (report-only mode).

## 6.2.5 Determine Issue-Eligible Findings

Use the issue-eligible finding set selected from Step 6 in `SKILL.md`; do not create issues for findings that fail those selection rules.

## 6.3 Create Issue Files

For each selected finding:

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-spec-{slugified-title}.md` using `assets/spec-issue-template.md`.
   - If the finding carries `**Severity Note:** [Deprioritized — capped at Minor from Critical]`, set the issue priority to `High` and copy the `Severity Note` into the issue body.
   - If the finding carries `**Severity Note:** [Deprioritized — capped at Minor from Major]`, set the issue priority to `Medium` and copy the `Severity Note` into the issue body.
   - Assign each issue an explicit `Size` (`XS|S|M|L`) and `Parallelization` category (`Safe to parallelize | Must be sequential | Needs coordination`) so the generated SIW issue matches the current tracker schema.
   - Assign each issue an explicit `Mode`. **Default `AUTO`.** Most spec-revision findings are AUTO. Set `HITL — <one-line reason>` only when resolving the finding requires a concrete human-input step: an unsettled architectural/product decision, design review, a judgment call, manual testing that can't be automated, or external-system access. When unclear, choose `AUTO`.

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
   - For a brand-new modern section, use the 7-column modern schema including the `Mode` column (`# | Title | Status | Size | Priority | Mode | Related`); the `Mode` cell is `AUTO` or `HITL` (the reason lives in the issue body, not the table).
   - When a section already exists, match its column count exactly (legacy 5-col / pre-Mode 6-col / modern 7-col) and preserve it in place — do not migrate layouts or add a `Mode` column to a section that lacks one.
   - If `## General` already has a section-level `**Parallelization:**` line, treat that line as a roll-up summary for the whole section rather than a per-issue mirror.
   - Recompute it from all real `G-*` issue files after adding the new issue: if every issue shares the same section-level category/gating note, keep that shared summary; otherwise set it to `Mixed — see issue files for exact guidance`.
   - If the General section is still in its empty placeholder state (`_None_` row / no real issues yet), replace the default summary from `siw:init` with the first real issue's category.
   - If an existing legacy General section has no `**Parallelization:**` line, preserve that absence instead of inserting one.
4. Update `siw/LOG.md` Current Progress section using `assets/spec-log-last-completed.md`.
