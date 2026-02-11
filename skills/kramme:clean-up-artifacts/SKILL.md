---
name: kramme:clean-up-artifacts
description: Delete workflow artifacts (REVIEW_OVERVIEW.md, AUDIT_REPORT.md, siw/AUDIT_REPORT.md, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, specification files)
disable-model-invocation: true
user-invocable: true
---

# Clean Up Artifacts

Delete workflow artifact files from the current working directory.

**Note:** For SIW-specific cleanup, consider using `/kramme:siw:remove` instead.

## Target Files

Delete the following files if they exist:

**Review artifacts:**
- `REVIEW_OVERVIEW.md`
- `AUDIT_REPORT.md`
- `siw/AUDIT_REPORT.md`

**Structured Implementation Workflow (SIW) artifacts (in `siw/`):**
- `siw/LOG.md`
- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/issues/` directory (only if SIW marker files are present)

**Specification files (in `siw/`):**
- `siw/FEATURE_SPECIFICATION.md`
- `siw/PROJECT_PLAN.md`
- `siw/API_DESIGN.md`
- `siw/DOCUMENTATION_SPEC.md`
- `siw/SYSTEM_DESIGN.md`
- `siw/TUTORIAL_PLAN.md`

## Workflow

1. Check which target files exist in the working directory
2. If `siw/issues/` exists:
   - Only delete it if `siw/OPEN_ISSUES_OVERVIEW.md` exists
   - If `siw/issues/` contains non-`ISSUE-*.md` files, ask before deleting or skip and report
3. Delete each remaining file that exists using `trash` (files can be restored from system Trash if needed)
4. Report results:
   - List files that were deleted
   - Note if no artifact files were found
