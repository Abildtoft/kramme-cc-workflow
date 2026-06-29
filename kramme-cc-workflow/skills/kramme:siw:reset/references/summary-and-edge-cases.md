# Summary and Edge Cases

## Completion Summary

Use this result format:

```text
SIW Workflow Reset Complete

Migrated to {spec_filename}:
{- X decisions}
{- X completed tasks}
{- X guiding principles}
{- X rejected alternatives}
{Or: "No content migrated"}

Cleared:
- {count(deleted_issue_paths)} issue files deleted
- siw/OPEN_ISSUES_OVERVIEW.md reset to empty
- siw/LOG.md reset to initial state
{If any failed_delete_paths: "- Failed to delete: {each failed path with error}"}

Preserved:
- {spec_filename} (with migrated content)

Next Steps:
- Run /kramme:siw:issue-define to create new issues
- Previous decisions are preserved in the spec for reference
```

## No Content to Migrate

If `siw/LOG.md` is empty or minimal:

```text
siw/LOG.md has no significant content to migrate.
Confirming reset before deleting or overwriting workflow files...
```

Then run Step 4 before Step 5. Do not proceed directly to deletion from this edge case.

## Multiple Spec Files

If multiple spec files are found:

```yaml
header: "Multiple Spec Files Found"
question: "Which specification file should receive the migrated content?"
options:
  - label: "{spec_file_1}"
  - label: "{spec_file_2}"
  - label: "Don't migrate (reset only)"
```

