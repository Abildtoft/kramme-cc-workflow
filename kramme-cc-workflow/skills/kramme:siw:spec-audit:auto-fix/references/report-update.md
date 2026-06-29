# Auto-Fix Report Update Procedure

Use this reference during Step 6 of `/kramme:siw:spec-audit:auto-fix` after all selected fixes have completed their apply-verify cycle.

## Annotate Fixed Findings

For each successfully fixed finding, add annotations to its report entry.

After the `**Severity:**` line, add:

```markdown
**Status:** [Auto-fixed]
```

Then handle `Fix Confidence` as follows:

- If the entry already contains `**Fix Confidence:**`, replace that line with the final score and tier from the auto-fix pass.
- If the entry does not contain `**Fix Confidence:**` (legacy report), insert:

```markdown
**Fix Confidence:** {score}/100 ({tier})
```

After the confidence line, add:

```markdown
**Fix applied:** {one-line description of the change}
```

## Update Summary Counts

The audit report's Summary section contains a fixed-schema severity table:

```markdown
| Severity  | Count       |
| --------- | ----------- |
| Critical  | {count}     |
| Major     | {count}     |
| Minor     | {count}     |
| **Total** | **{total}** |
```

If an `Auto-fixed` row already exists from a previous auto-fix run, update its count in place to the total number of findings now annotated `**Status:** [Auto-fixed]`.

Otherwise insert a new `Auto-fixed` row immediately before the `**Total**` row so it slots into the existing two-column schema:

```markdown
| Auto-fixed | {count}     |
```

Leave the Critical / Major / Minor counts unchanged. The per-finding `**Status:** [Auto-fixed]` annotation carries the resolution state.

If the table schema does not match the expected shape, skip this step and log:

```text
Severity table schema unrecognized — per-finding annotations applied; summary table left unchanged.
```

## Document Failures

If any findings failed verification and were reclassified, add a section at the end of the report:

```markdown
## Auto-Fix Notes

The following findings were initially classified as mechanical but failed verification and have been reclassified as requiring decisions:

- **{SPEC-NNN}:** {failure reason}
```

## Update Overall Assessment

Update the `**Overall Assessment:**` line in the report's Summary section only if all of the following hold:

- All Critical and Major findings were auto-fixed.
- No remaining Minor finding carries `**Severity Note:** [Deprioritized — capped at Minor from Critical]` or any other preserved-critical cap.
- Only uncapped Minor findings remain, or zero findings remain.

When those conditions hold, replace the existing value with `Ready for implementation`. Otherwise, leave the existing value untouched.

## Optional SIW Log Update

If `siw/LOG.md` exists and at least one finding was auto-fixed, append one concise entry under `## Current Progress` / `### Last Completed`:

```markdown
- {YYYY-MM-DD}: Auto-fixed {N} spec-audit finding(s) in {spec_file_list}; {remaining_count} finding(s) still require decisions. Report: {report_path}
```

Do not create `siw/LOG.md` if it is missing. Do not update the log during `--dry-run` or when no findings were auto-fixed.

If `siw/LOG.md` exists but does not contain a recognizable `## Current Progress` section, leave it unchanged and include `SIW log: not updated (missing Current Progress section)` in the summary.
