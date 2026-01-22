---
name: kramme:clean-up-artifacts
description: Delete workflow artifacts (REVIEW_RESPONSES.md, LOG.md, OPEN_ISSUES.md, specification files)
---

# Clean Up Artifacts

Delete workflow artifact files from the current working directory.

## Target Files

Delete the following files if they exist:

**Review artifacts:**
- `REVIEW_RESPONSES.md`

**Structured implementation workflow artifacts:**
- `LOG.md`
- `OPEN_ISSUES.md`

**Specification files:**
- `FEATURE_SPECIFICATION.md`
- `PROJECT_PLAN.md`
- `API_DESIGN.md`
- `DOCUMENTATION_SPEC.md`
- `SYSTEM_DESIGN.md`
- `TUTORIAL_PLAN.md`

## Workflow

1. Check which target files exist in the working directory
2. Delete each file that exists using `trash` (files can be restored from system Trash if needed)
3. Report results:
   - List files that were deleted
   - Note if no artifact files were found
