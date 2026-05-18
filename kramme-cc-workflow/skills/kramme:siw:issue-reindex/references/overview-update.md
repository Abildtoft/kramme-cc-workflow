# Overview Update

Use this procedure to rebuild `siw/OPEN_ISSUES_OVERVIEW.md` after DONE issues are deleted and active issue ids are renumbered.

## Inputs

- The original `siw/OPEN_ISSUES_OVERVIEW.md` content.
- The confirmed restart scope.
- `renumberById`: original active issue id to new active issue id.
- `deletedById`: original DONE issue id to deleted issue title.
- The renamed active issue files.

## Rebuild Rules

1. Preserve section order, section headings, section-level metadata, status legend, issue naming notes, and non-table prose.
2. Preserve each section's table schema:
   - 7-column: `#`, `Title`, `Status`, `Size`, `Priority`, `Mode`, `Related`
   - 6-column: `#`, `Title`, `Status`, `Size`, `Priority`, `Related`
   - legacy 5-column: `#`, `Title`, `Status`, `Priority`, `Related`
3. Remove rows for DONE issues that are in the confirmed restart scope.
4. Preserve rows outside the confirmed scope exactly, except when their `Related` column references ids that must be annotated as deleted.
5. For active rows in scope, replace the issue id with its new id from `renumberById`.
6. Keep active rows grouped under their original section. Do not move issues across General, Phase, or prefix groups.
7. Sort active rows in each affected prefix group by the new numeric id.
8. Preserve each row's title, status, size, priority, mode, and related-task prose unless an issue-id reference inside that prose must be updated.
9. Preserve section-level metadata wording, but rewrite any issue-id references inside metadata with the same `renumberById` / `deletedById` rules used for related-task prose.

## Related Column References

Use the original maps for all related-task rewrites:

- If a related id is active and renumbered, replace it with the new id.
- If a related id was deleted, keep the original id and append `(deleted: "{title}")`.
- If a related id is outside the confirmed scope or not recognized, leave it unchanged.
- Classify all references against the original text first; do not chain replacements.

## Empty Sections

If a section has no active rows after DONE rows are removed:

- Preserve the section.
- Emit one `_None_` row matching the section's table column count.
- Use the first new id for that section's prefix when it is obvious; otherwise use a neutral placeholder such as `_No open issues_`.

## Consistency Checks

Before writing:

- Every active issue in the confirmed scope appears exactly once with its new id.
- No DONE issue row remains in the confirmed scope.
- No duplicate issue id appears in the overview.
- Every issue id in the overview matches the renamed issue files, except intentionally untouched out-of-scope rows.

If any check fails, stop and report the mismatch instead of writing a partially rebuilt overview.
