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

Artifact readiness: {product-only|requirements-only|planning-ready} - {one-line reason}

Next Steps:
  {If product-only or requirements-only:}
  1. Run /kramme:siw:discovery to harden the spec before phase or issue creation

  {If planning-ready and the work should be phased:}
  1. Run /kramme:siw:generate-phases to decompose spec into phase-based issues
  2. Run /kramme:siw:transfer-to-linear after reviewing the issue set

  {If planning-ready and the work is one coherent issue:}
  1. Run /kramme:siw:issue-define to create the first issue
  2. Run /kramme:siw:transfer-to-linear after reviewing the issue

Tips:
  - Until transfer, the spec file is permanent; keep it updated as the local source of truth
  - siw/LOG.md and siw/issues are temporary preparation artifacts
  - After a verified transfer, update requirements in Linear and use /kramme:siw:remove to retire the local SIW files
```

**If external files were linked, also show:**

```
Linked Specifications:
  {If kept in place:}
  - {file1} (external)
  - {file2} (external)
  Until captured for transfer, these files remain the local source of truth. The SIW spec references them.
  Before transfer, capture every authoritative linked source:
    - Copy Markdown specs into siw/supporting-specs/ and update the SIW links.
    - Copy non-Markdown sources under siw/ so transfer can require relocation or upload before cleanup.
  If any linked source cannot be captured, stop and keep the local SIW source of truth.
  Treat Linear as authoritative only after transfer verifies every linked source's disposition.

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
