# Apply Now (Direct Spec Updates)

Use this when `/kramme:siw:spec-audit` reaches Step 6 and either:

- `APPLY_MODE=true` from `--apply` / `--apply-now`
- the user chooses **Apply now** from the Step 6 prompt

This path updates spec files directly and **never** creates `G-*` issue files.

## Hard Boundaries

- Do not create files under `siw/issues/`.
- Do not update `siw/OPEN_ISSUES_OVERVIEW.md`.
- Do not apply findings that require product, architecture, stakeholder, or scope decisions.
- Do not invent requirements, success criteria, constraints, acceptance criteria, or non-goals.
- Do not change the meaning, scope, or intent of the spec.
- Do not apply a finding solely because the audit recommendation sounds plausible. The fix must be derivable from the existing spec text.

## Eligibility

Start from the active audit run's final findings after Step 4 post-processing.

Skip findings that match any of these:

- `**Fix Confidence:**` below `80/100`
- `Fix Confidence` tier is `MODERATE_CONFIDENCE` or `REQUIRES_DECISION`
- Any `Fix Confidence` sub-score, if available, is below 15
- Safety-capped by `references/fix-confidence-rubric.md`
- Contains `**Severity Note:** [Deprioritized — capped at Minor from Critical]`
- Recommendation uses decision-signal language: `consider`, `decide whether`, `choose between`, `discuss with`, `evaluate options`
- Recommendation adds or removes scope
- Recommendation defines success-criteria substance instead of making an existing criterion measurable
- Contains an `Existing issue:` note

If a finding has no final `Fix Confidence` line, score it from scratch with `references/fix-confidence-rubric.md` and apply the same eligibility rules before considering it.

If no findings are eligible:

```
No findings were safe to apply directly.

Report remains at: {report_path}
Next: /kramme:siw:resolve-audit {report_path}
```

Then stop Step 6.

## Approval

If `APPLY_MODE=true` and `AUTO_MODE=true`, proceed with all eligible findings.

If `APPLY_MODE=true` and `AUTO_MODE=false`, show the eligible and skipped counts, then ask:

```yaml
header: "Apply Spec Updates"
question: "Found {N} findings safe to apply directly and {M} findings that still need decisions. Update the spec now?"
options:
  - label: "Apply now"
    description: "Edit the reviewed spec files and annotate the audit report"
  - label: "Keep report only"
    description: "Make no spec edits or issue files"
```

If the user selected **Apply now** from the Step 6 prompt, this approval is already satisfied. Do not ask twice.

## Apply Procedure

1. Group eligible findings by target spec file, then sort top-to-bottom within each file.
2. For each finding:
   - Read the referenced section and enough surrounding context to confirm the exact edit.
   - Determine the smallest spec text change that resolves the finding.
   - Apply exactly one finding at a time.
   - Re-read the edited section.
   - Confirm the original issue is gone and no new ambiguity, broken reference, formatting issue, or meaning change was introduced.
   - If verification fails, revert that finding's edit and mark it as skipped with the failure reason.
3. Preserve existing markdown style, heading levels, list markers, terminology, and section ordering unless the finding specifically requires correcting them.
4. If multiple eligible findings would edit the same text, merge them only when the combined edit is still deterministic. Otherwise apply the first deterministic fix and skip the overlapping finding with the reason `overlaps with another applied edit`.

## Report Annotation

For each successfully applied finding, update the audit report entry:

After the `**Severity:**` line, add:

```markdown
**Status:** [Applied directly]
```

After the `**Fix Confidence:**` line, add:

```markdown
**Applied directly:** {one-line description of the spec edit}
```

If the report summary severity table has the standard two-column shape, insert this row immediately before `**Total**`:

```markdown
| Applied directly | {count}     |
```

Leave the Critical / Major / Minor counts unchanged. The per-finding status carries resolution state.

If skipped findings failed verification, add or append:

```markdown
## Direct Apply Notes

- **{SPEC-NNN}:** {failure reason}
```

## Optional SIW Log Update

If `siw/LOG.md` exists, append one concise entry under `## Current Progress` / `### Last Completed`:

```markdown
- {YYYY-MM-DD}: Applied {N} spec-audit finding(s) directly to {spec_file_list}; {M} finding(s) still require decisions.
```

Do not create `siw/LOG.md` if it is missing.

## Summary

End Step 6 with:

```
Applied Now: {applied_count} finding(s)
Skipped: {skipped_count} finding(s)
Spec Files Updated: {list}
Report Updated: {report_path}
Issues Created: 0
Remaining decision-required findings: {remaining_count}
```
