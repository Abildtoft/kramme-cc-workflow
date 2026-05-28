# Log Update

Use this procedure to update `siw/LOG.md` and to apply the same issue-reference replacement rules when updating active issue file bodies.

## Inputs

- The original file content being rewritten.
- `renumberById`: original active issue id to new active issue id.
- `deletedById`: original DONE issue id to deleted issue title.
- The confirmed reindex scope.

## Matching Rules

Recognize both short and full issue references:

- short ids such as `G-001`, `P1-002`, and `P12-014`
- full ids or filenames such as `ISSUE-G-001` and `ISSUE-P1-002-api-design.md`

Use collision-safe matching:

- Match issue ids only when they are not embedded inside a longer alphanumeric or hyphenated token.
- Prefer longest matches first.
- Build all replacements from the original content before applying any replacement.
- Do not run sequential global replacements that can turn a newly written id into another id.

## Replacement Rules

- Active issue id in `renumberById`: replace with the new id.
- DONE issue id in `deletedById`: keep the original id and append `(deleted: "{title}")` the first time that reference is rewritten in a local phrase.
- Issue id outside the confirmed scope: leave unchanged.
- Unknown issue id: leave unchanged.
- Full issue filenames for active issues: update only the id portion and preserve the slug and extension.
- Full issue filenames for deleted issues: leave the filename unchanged and annotate it as deleted.

## LOG.md Handling

If `siw/LOG.md` does not exist, skip this step and omit it from the updated-files report.

When it exists:

1. Rewrite issue references using the rules above.
2. Preserve dates, headings, decision numbering, historical wording, and author-entered prose.
3. Do not remove entries about deleted issues; they are historical records.
4. Add deletion annotations only where they prevent the old id from being mistaken for a still-active issue.
5. Count rewritten active references and deleted annotations separately for the final report.

If no issue references are present, leave the file unchanged and report `siw/LOG.md (no issue references)`.

## Active Issue File Body Handling

When Step 6 updates active issue files, use the same matching and replacement rules for:

- `**Related:**` metadata
- blocked-by and blocks lists
- parallelization guidance
- acceptance criteria and implementation notes
- prose references to sibling issues

Deleted dependency references must remain identifiable. Never silently point a deleted dependency at a newly renumbered active issue.
