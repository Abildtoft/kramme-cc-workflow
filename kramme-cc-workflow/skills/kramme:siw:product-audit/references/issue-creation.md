# SIW Issue Creation Detail

Use this during Step 7 after the main skill confirms issue creation is eligible and not running in inline mode.

## Ask User

If `AUTO_MODE=true`, skip this prompt and choose **Critical and major only**.

Otherwise:

```yaml
header: "Create SIW Issues"
question: "Found {N} actionable product findings. Create SIW issues for them?"
options:
  - label: "Critical and major only"
    description: "Create {N} issues (skip minor findings)"
  - label: "All findings"
    description: "Create {N} issues including minor ones"
  - label: "Let me select"
    description: "Choose which findings become issues"
  - label: "No issues"
    description: "Keep the report only"
```

## Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 7 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section.
   - If creation fails, warn and skip Step 7 (report-only mode).

## Create Issue Files

For each selected finding:

1. Apply the standard handled-finding skip rule. Skip the finding and report the matched artifact if it carries an `Existing issue:` annotation that resolves to an existing `siw/issues/ISSUE-G-*.md` file, is marked `**Status:** [Auto-fixed]` or `**Status:** [Applied directly]`, or a file matching `siw/issues/ISSUE-G-*-{finding-id}-*.md` exists. Treat unresolved `Existing issue:` annotations as stale metadata: warn in the final summary, but do not skip the finding.
2. Determine the next available `G-` issue number: parse `siw/OPEN_ISSUES_OVERVIEW.md` for the highest `G-` number, compute candidate = highest + 1 (padded to 3 digits), then verify no on-disk collision by globbing `siw/issues/ISSUE-G-{candidate}-*.md`. If any file matches, the tracker is out of sync with `siw/issues/`; increment the candidate and re-check until no file matches, then warn that the tracker may need `/kramme:siw:issue-reindex`.
3. Create issue file `siw/issues/ISSUE-G-{NNN}-product-{finding-id}-{slugified-title}.md`. Give it a status line carrying explicit `Size` (`XS|S|M|L`), `Parallelization` (`Safe to parallelize | Must be sequential | Needs coordination`), and `Mode` metadata so it matches the current tracker schema:

   ```markdown
   **Status:** READY | **Priority:** {Critical->High, Major->Medium, Minor->Low} | **Size:** {XS|S|M|L} | **Phase:** General | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination} | **Mode:** {AUTO | HITL — <reason>} | **Related:** Product Audit Report
   ```

   **Mode default is `AUTO`.** Set `HITL — <one-line reason>` only when resolving the finding requires a concrete human-input step: an unsettled product/architectural decision, design review, a judgment call, manual testing that can't be automated, or external-system access. When unclear, choose `AUTO`. A finding's severity does not by itself make it HITL.
4. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
   - For a brand-new modern section, use the 7-column modern schema including the `Mode` column (`# | Title | Status | Size | Priority | Mode | Related`); the `Mode` cell is `AUTO` or `HITL` (the reason lives in the issue body, not the table).
   - When a section already exists, match its column count exactly (legacy 5-col / pre-Mode 6-col / modern 7-col) and preserve it in place - do not migrate layouts or add a `Mode` column to a section that lacks one.
5. Annotate the source product audit report entry with `Existing issue: G-{NNN}` immediately after the issue is created. If the report cannot be edited, warn in the final summary and include the finding id plus created issue id.
6. Update `siw/LOG.md` Current Progress section.

If any issue file, overview, source-report annotation, or log write fails after issue creation starts, surface the partial state in the completion summary and offer rollback guidance instead of reporting the issue as cleanly created.
