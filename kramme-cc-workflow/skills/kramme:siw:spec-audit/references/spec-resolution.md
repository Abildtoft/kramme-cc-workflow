# Spec File Resolution (Step 1 detail)

Use this when `SKILL.md` reaches Step 1. Resolve `$ARGUMENTS` into mode flags and verified `spec_files` before reading spec content.

## 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s), keyword, and optional flags.

**Extract control flags first:**

- If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag before processing remaining arguments.
- If `$ARGUMENTS` contains `--apply` or `--apply-now`, set `APPLY_MODE=true` and remove the flag before processing remaining arguments.
- If `$ARGUMENTS` contains `--inline`, set `INLINE_MODE=true` and remove the flag before processing remaining arguments.
- If `$ARGUMENTS` contains `--team`, use Team Mode and remove the flag before processing remaining arguments.

**Extract `--model` flag next (Claude Code only — ignored on other platforms):**

- If `$ARGUMENTS` contains `--model opus`, `--model sonnet`, or `--model haiku`, extract it and store as `agent_model`.
- **Default:** `opus`
- Remove the flag from `$ARGUMENTS` before processing remaining arguments.

`--auto` means:

- replace any previous audit report automatically
- create SIW issues for **Critical and Major** findings, plus Minor findings that preserve original Critical or Major severity when Step 6 applies
- skip the report overwrite / issue-creation prompts

`--apply` means:

- write the audit report as usual, then run the same procedure as `/kramme:siw:spec-audit:auto-fix` against that report for findings that clear the canonical auto-fix gates
- skip Step 6 issue creation entirely — do **not** create `G-*` issues, do **not** update `siw/OPEN_ISSUES_OVERVIEW.md`, and do **not** touch `siw/issues/`
- if combined with `--auto`, pass the same approval behavior to the auto-fix procedure

`--inline` means:

- print the report inline in the reply instead of writing `siw/AUDIT_SPEC_REPORT.md`
- skip Step 6 (no SIW issues, no `siw/OPEN_ISSUES_OVERVIEW.md` / `siw/LOG.md` updates) so the workspace is not mutated

If `INLINE_MODE=true` and `APPLY_MODE=true` (from `--apply` or `--apply-now`), abort before reading specs:

```
Error: --inline cannot be combined with --apply or --apply-now.

--inline is read-only. Re-run without --inline to apply spec updates.
```

**Detection rules for remaining arguments:**

1. **File path(s)**: Contains `/` or ends in `.md`, `.txt`
2. **Keyword `siw`**: Explicitly requests auto-detection
3. **Empty**: Default to auto-detection
4. **Anything else** (e.g., a bare `myspec` token with no slash or extension): Treat as a candidate path and verify it with `ls`. If verification fails, surface the same "No valid specification files found" error from Section 1.2 — never silently fall through to auto-detection on an unrecognized token.

## 1.2 If File Paths Provided

1. Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.
   - Respect quotes and escaped spaces.
   - Do **not** naively split on spaces.
2. For each parsed path:
   - Verify file exists with `ls {path}`
   - If path is a directory, scan for markdown files (always quote the interpolated path so spaces and shell metacharacters are preserved):
     ```bash
     find "{path}" -maxdepth 2 -type f -name "*.md" 2> /dev/null
     ```
   - If file doesn't exist, warn and skip.
3. Store verified paths as `spec_files`.

**If no valid files remain after verification:**

```
Error: No valid specification files found at the provided path(s).

Provided: {arguments}
```

**Action:** Abort.

## 1.3 If No Arguments or `siw` Keyword

Auto-detect spec files from the `siw/` directory:

1. Check if `siw/` exists:

   ```bash
   ls siw/ 2> /dev/null
   ```

2. Find spec files (exclude workflow files):
   - Use Glob to find `siw/*.md`
   - Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
   - Exclude that workflow-artifact set before treating any top-level `siw/*.md` file as a spec. When the filter excludes every candidate, report the excluded filenames and ask for an explicit spec path instead of silently proceeding.
   - **Coupling note for SIW skill authors:** Any new top-level workflow file added under `siw/` by sibling skills must either match one of the patterns above or be added to this list, or it will be silently audited as a spec.

3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`
   - Use Glob to find `siw/contracts/*.md`

4. Check for linked external specs:
   - Read **every detected spec file** (`siw/*.md`, `siw/supporting-specs/*.md`, and `siw/contracts/*.md` candidates).
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list (verify each exists).

5. **Use all found spec files by default.** Only ask the user to select if there are files that look unrelated to each other (e.g., specs for entirely different features). Do NOT ask when the files are clearly parts of the same specification (main spec + supporting specs + contract specs).

6. Store files as `spec_files`.

## 1.4 If No Spec Files Found

If auto-detection found no spec files because every top-level `siw/*.md` candidate was excluded by the workflow-artifact filter, report the excluded filenames and ask the user for explicit spec path(s). Validate provided paths with the explicit-path flow from Section 1.2 and continue when valid. If the user provides no path, then emit the generic error below and abort.

```
Error: No specification files found.

Expected locations:
  - siw/*.md (SIW spec files)
  - siw/supporting-specs/*.md (supporting specifications)
  - siw/contracts/*.md (contract specifications)

Or provide file path(s) directly:
  /kramme:siw:spec-audit path/to/spec.md
  /kramme:siw:spec-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.
