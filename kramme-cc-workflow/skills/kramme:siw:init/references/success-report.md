# Success Report

Use these templates during Phase 5 after the SIW documents have been created.

Display summary:

```
Structured Implementation Workflow Initialized

Created:
  siw/{spec_filename}          - Main specification (permanent)
  siw/supporting-specs/        - Detailed specifications (permanent) [if enabled]
  siw/LOG.md                   - Progress and decisions (temporary)
  siw/OPEN_ISSUES_OVERVIEW.md  - Issue tracking (temporary)
  siw/issues/                  - Individual issue files (temporary)

Next Steps:
  1. Run /kramme:siw:generate-phases to decompose spec into phase-based issues
     OR /kramme:siw:issue-define to create issues one at a time
  2. Run /kramme:siw:issue-implement <G-XXX or P1-XXX> to start implementing

Tips:
  - The spec file is permanent; keep it updated as your source of truth
  - siw/LOG.md and siw/issues are temporary; delete them when work is complete
  - Use /kramme:workflow-artifacts:cleanup to remove temporary files when done
```

**If external files were linked, also show:**

```
Linked Specifications:
  {If kept in place:}
  - {file1} (external)
  - {file2} (external)
  These files remain the source of truth. The SIW spec references them.

  {If moved to siw/:}
  - siw/{file1} (moved)
  - siw/{file2} (moved)
  Files were moved into siw/ for co-location.
```

**If content was discovered via interview, also show:**

```
Discovery:
  Spec populated from discovery interview.
  {n} key decisions documented.
  {n} open questions to address during implementation.
```

**If supporting specs enabled, also show:**

```
Supporting Specs:
  - Create files in siw/supporting-specs/ with naming: NN-descriptor.md
  - Example: 01-data-model.md, 02-api-specification.md
  - Update the TOC in the main spec when adding new supporting specs
```
