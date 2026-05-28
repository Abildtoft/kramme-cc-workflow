# Edge Cases

Use these rules whenever the issue-reindex workflow encounters ambiguous or partial state.

## Missing Files

- Missing `siw/OPEN_ISSUES_OVERVIEW.md`: abort; there is no authoritative issue list.
- Missing `siw/issues/`: abort; there are no issue files to safely rename.
- Missing DONE issue file selected for deletion: stop before deletion and ask whether to continue with the overview as source of truth.
- Missing active issue file selected for renumbering: stop; renumbering cannot be made consistent.
- Multiple files matching one issue id: stop and ask which file is authoritative.

## Partial Reindex State

Detect partial state before making changes:

- overview id and issue filename disagree
- file heading id and filename id disagree
- duplicate issue ids appear in the overview
- both old and new filenames already exist for the same planned rename
- a previous `_tmp` or backup filename suggests an interrupted rename

If partial state exists, report the exact files and ask the user whether to repair manually before re-running the skill.

## Rename Collisions

Avoid destructive collisions:

- Build the complete original-to-new filename map before renaming anything.
- Ensure every target filename is unique.
- Rename through temporary filenames when two active files swap or compress into lower numbers.
- Do not overwrite an existing target file.
- Do not merge issue content.

## Deleted Dependencies

When an active issue references a deleted issue:

- Keep the original deleted id.
- Annotate it with `(deleted: "{title}")`.
- Do not remove the dependency text unless the user explicitly asks.
- If the deleted issue contains unresolved work, stop during spec capture and ask whether a replacement active issue should be created.

## Mixed Prefix Groups

- Renumber only within each prefix group.
- Never move `G-` issues into `P1-` groups or phase issues into General.
- If the user selected "General issues only", leave all `P1-`, `P2-`, and other phase rows and files unchanged except for deleted annotations in related references when needed.
- Unknown prefixes are valid groups if they appear consistently in the overview and issue files.

## Missing Specs

If no active spec file exists during the capture check:

- Do not delete DONE issue files automatically.
- Report the durable information that would be lost.
- Ask the user whether to create or update a spec before deletion.

## Trash Unavailable

Prefer `trash` when available. If it is unavailable:

- Use `rm -f` only after the reindex plan is confirmed and spec capture is complete.
- Report that permanent deletion was used.
- Do not use recursive deletion for individual issue markdown files.

## Malformed Overview Tables

If a table row cannot be parsed:

- Preserve the original row.
- Do not infer an issue id from the title.
- Stop if the malformed row is in the confirmed reindex scope.
- Report the row and ask the user to repair it before continuing.
