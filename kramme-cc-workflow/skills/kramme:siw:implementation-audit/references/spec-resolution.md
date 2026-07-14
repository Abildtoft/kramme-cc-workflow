# Implementation Audit Spec Resolution

Use this reference during Step 1 of `/kramme:siw:implementation-audit` after flags have been parsed and remaining arguments have been classified as explicit paths, `siw`, or empty/default auto-detection.

## If File Paths Are Provided

1. Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.
   - Respect quotes and escaped spaces.
   - Do **not** naively split on spaces.
2. For each parsed path:
   - Verify file exists with `ls {path}`.
   - If path is a directory, scan for markdown files:
     ```bash
     find {path} -maxdepth 2 -type f -name "*.md" 2> /dev/null
     ```
   - If file does not exist, warn and skip it.
3. Store verified paths as `spec_files`.

If no valid files remain after verification:

```text
Error: No valid specification files found at the provided path(s).

Provided: {arguments}
```

Abort.

## If No Arguments or `siw` Keyword

Auto-detect spec files from the `siw/` directory:

1. Check if `siw/` exists:

   ```bash
   ls siw/ 2> /dev/null
   ```

2. Find spec files:
   - Use Glob to find `siw/*.md`.
   - Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
   - When the filter excludes every candidate, report the excluded filenames and ask for an explicit spec path instead of silently proceeding.
3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`.
   - Use Glob to find `siw/contracts/*.md`.
4. Check for linked external specs:
   - Read every detected spec file candidate.
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list after verifying each exists.
5. Use all found spec files by default.
   - Ask the user to select only when files look unrelated to each other, such as specs for entirely different features.
   - Do not ask when files are clearly parts of one specification, such as a main spec plus supporting specs and contract specs.
6. Store files as `spec_files`.

## If No Spec Files Are Found

If auto-detection found no spec files because every top-level `siw/*.md` candidate was excluded by the workflow-artifact filter, report the excluded filenames and ask the user for explicit spec path(s). Validate provided paths with the explicit-path flow above and continue when valid.

If the user provides no path, emit the generic error below and abort:

```text
Error: No specification files found.

Expected locations:
  - siw/*.md (SIW spec files)
  - siw/supporting-specs/*.md (supporting specifications)
  - siw/contracts/*.md (contract specifications)

Or provide file path(s) directly:
  /kramme:siw:implementation-audit path/to/spec.md
  /kramme:siw:implementation-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```
