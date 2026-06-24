---
name: kramme:siw:product-audit
description: (experimental) Product audit of SIW specs and plans before implementation. Evaluates target user clarity, problem/solution fit, user state modeling, critical moments coverage, scope correctness, success criteria quality, and prioritization quality. Infers likely user goals and non-goals when the spec is incomplete. Not for code review or implementation auditing. Supports inline report output with --inline.
argument-hint: "[spec-file-path(s) | 'siw'] [--auto] [--inline]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Product Audit of SIW Specs

Critique specification documents from a product perspective before implementation begins. This is a spec-only analysis — no codebase code is read or compared.

**IMPORTANT:** This is a thorough product critique. Do not return early. Do not assume a section is well-designed without reading it carefully. Evaluate whether the spec will actually solve the right problem for the right users. A clean report is suspicious, not reassuring.

## Process Overview

```
/kramme:siw:product-audit [spec-file-path(s) | 'siw'] [--auto] [--inline]
    |
    v
[Step 1: Resolve Spec Files] -> Parse args or auto-detect from siw/
    |
    v
[Step 2: Read Specs Fully] -> Read every file, extract product elements
    |
    v
[Step 3: Check for Previous Audit] -> Parse existing PRODUCT_AUDIT.md
    |
    v
[Step 4: Launch Product Reviewer Agent] -> Explore agent for product critique
    |
    v
[Step 5: Classify and Deduplicate Findings] -> Severity, cross-reference issues
    |
    v
[Step 6: Write Report] -> siw/PRODUCT_AUDIT.md
    |
    v
[Step 7: Optionally Create SIW Issues] -> Convert findings to issues
    |
    v
[Step 8: Report Summary] -> Stats and next steps
```

## References

- `references/product-reviewer-prompt.md` - read during Step 4 for the full product reviewer agent prompt, product dimensions, severity guides, output format, and audit rules.

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s) or keyword.

**Extract control flags first:**

- If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag before processing remaining arguments.
- If `$ARGUMENTS` contains `--inline`, set `INLINE_MODE=true` and remove the flag before processing remaining arguments.

`--auto` means:

- replace any previous product audit automatically
- create SIW issues for **Critical and Major** findings when Step 7 applies
- skip the report overwrite / issue-creation prompts

`--inline` means:

- reply with the report inline instead of writing `siw/PRODUCT_AUDIT.md`
- skip Step 7 entirely — no issue files, no `OPEN_ISSUES_OVERVIEW.md` updates, no `LOG.md` updates

**Detection rules:**

1. **File path(s)**: Contains `/` or ends in `.md`, `.txt`
2. **Keyword `siw`**: Explicitly requests auto-detection
3. **Empty**: Default to auto-detection

### 1.2 If File Paths Provided

1. Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.
   - Respect quotes and escaped spaces.
   - Do **not** naively split on spaces.
2. For each parsed path:
   - Verify file exists with `ls {path}`
   - If path is a directory, scan for markdown files:
     ```bash
     find {path} -maxdepth 2 -type f -name "*.md" 2> /dev/null
     ```
   - If file doesn't exist, warn and skip.
3. Store verified paths as `spec_files`.

**If no valid files remain after verification:**

```
Error: No valid specification files found at the provided path(s).

Provided: {arguments}
```

**Action:** Abort.

### 1.3 If No Arguments or `siw` Keyword

Auto-detect spec files from the `siw/` directory:

1. Check if `siw/` exists:

   ```bash
   ls siw/ 2> /dev/null
   ```

2. Find spec files (exclude workflow files):
   - Use Glob to find `siw/*.md`
   - Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
   - Exclude that workflow-artifact set before treating any top-level `siw/*.md` file as a spec. When the filter excludes every candidate, report the excluded filenames and ask for an explicit spec path instead of silently proceeding.

3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`
   - Use Glob to find `siw/contracts/*.md`

4. Check for linked external specs:
   - Read **every detected spec file** (`siw/*.md`, `siw/supporting-specs/*.md`, and `siw/contracts/*.md` candidates).
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list (verify each exists).

5. **Use all found spec files by default.** Only ask the user to select if there are files that look unrelated to each other (e.g., specs for entirely different features). Do NOT ask when the files are clearly parts of the same specification (main spec + supporting specs + contract specs).

6. Store files as `spec_files`.

### 1.4 If Auto-Detection Found Nothing

If auto-detection found no spec files because every top-level `siw/*.md` candidate was excluded by the workflow-artifact filter, report the excluded filenames and ask the user for explicit spec path(s). Validate provided paths with the explicit-path flow from Step 1.2 and continue when valid. If the user provides no path, then emit the generic error below and abort.

```
Error: No specification files found.

Expected locations:
  - siw/*.md (SIW spec files)
  - siw/supporting-specs/*.md (supporting specifications)
  - siw/contracts/*.md (contract specifications)

Or provide file path(s) directly:
  /kramme:siw:product-audit path/to/spec.md
  /kramme:siw:product-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.

---

## Step 2: Read Specs Fully

### 2.1 Read Every Spec File End-to-End

Read each spec file completely. Do not skim. Understand the full picture before launching the product audit.

### 2.2 Extract Work Context

After reading all spec files, look for a `## Work Context` section in the spec files:

1. Parse the markdown table to extract: Work Type, Priority Dimensions, Deprioritized dimensions
   - If multiple spec files define Work Context, use the main spec file (the one matching the SIW init filename). If ambiguous, use the first found and warn.
2. If not found or malformed, default to Production Feature (full product audit, no adjustments)
3. Store as `work_context`

### 2.3 Extract Product Elements

For each spec file, identify and extract:

| Element | What to look for |
| --- | --- |
| Target User | Who is the user? Persona, role, segment, or archetype |
| Problem Statement | What problem is being solved? Current pain, unmet need |
| Proposed Solution | What is being built? Core approach, key decisions |
| Business Reason / Why Now | Why this matters now, what business outcome or urgency exists |
| User Flows | How does the user interact? Steps, entry points, transitions |
| User States | What states can the user be in? Empty, error, loading, success, edge |
| Critical Moments | First use, error recovery, data loss, permission change, upgrade |
| Scope | What is in and out? Boundaries, explicit exclusions |
| Non-Goals | What is explicitly deferred, declined, or left for later |
| Success Criteria | How is success measured? Metrics, definitions of done |
| Phases / Milestones | How is delivery sequenced? What ships first? |
| Strategy Alignment | Whether the spec aligns with repo-root `STRATEGY.md` target users, active tracks, metrics, and non-goals |
| Pulse Signals | Whether recent `docs/pulse-reports/` evidence supports or challenges the spec's priorities |

For each element, capture:

- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **content_summary**: Brief description of what the section contains

### 2.4 Present Extraction Summary

```
Product Audit Scope

Sources:
  - {spec_file_1}
  - {spec_file_2}

Product elements identified: {count}
Target user defined: {yes/no}
Problem statement found: {yes/no}
Why now documented: {yes/no}
Non-goals documented: {yes/no}
User flows documented: {count}
```

### 2.5 Work Context Gate

If `work_context.work_type` is **Prototype** or **Refactor**:

If `AUTO_MODE=true`, stop here and suggest `/kramme:siw:spec-audit` instead.

Otherwise:

Use AskUserQuestion:

```yaml
header: "Work Context: {work_type}"
question: "This spec's Work Context is '{work_type}'. A product audit evaluates user-facing concerns that may not apply. The spec audit (/kramme:siw:spec-audit) may be more useful."
options:
  - label: "Skip product audit"
    description: "Abort — product audit is not relevant for this work type"
  - label: "Proceed anyway"
    description: "Run the full product audit regardless"
```

If "Skip product audit": Stop and suggest `/kramme:siw:spec-audit` instead.

For all other work types, continue to Step 2.6.

---

### 2.6 Load Strategy and Pulse Context

Before checking previous audits, load optional product-loop context:

- If repo-root `STRATEGY.md` exists, read it and extract target problem, approach, who it is for, key metrics, active tracks, milestones if present, and non-goals.
- If its `last_updated` frontmatter is older than 90 days, mark relevant context as `STALE:` in the report.
- If `docs/pulse-reports/` exists, read the 1-3 most recent reports and extract usage, quality, error, performance, customer-signal, and followup highlights that relate to the audited spec.
- If neither exists, continue. Missing strategy or pulse coverage is report context, not a finding by itself unless the spec makes broad product-direction claims that cannot be evaluated without that context.

Store the result as `PRODUCT_LOOP_CONTEXT` for the reviewer agent and final report.

---

## Step 3: Check for Previous Audit

If `siw/PRODUCT_AUDIT.md` (or `PRODUCT_AUDIT.md` in project root) exists:

1. Read the file.
2. Parse for previously reported findings and their IDs (PROD-NNN).
3. Record the highest existing PROD-NNN as `previous_max_id` and note which findings are marked addressed or resolved versus still open.
4. Still-open findings keep their existing IDs; new findings start at `previous_max_id + 1` (see Step 5.3).
5. This context is passed to the reviewer agent to avoid re-reporting resolved items.

---

## Step 4: Launch Product Reviewer Agent

Read `references/product-reviewer-prompt.md`, fill in the placeholders, including `PRODUCT_LOOP_CONTEXT`, and run one product-reviewer pass with that prompt. Use the current host runtime's subagent mechanism when it exposes the `kramme:product-reviewer` reviewer; otherwise perform the same review inline in the main thread. No relevance validation step is needed because the entire spec set is the audit scope.

---

## Step 5: Classify and Deduplicate Findings

### 5.1 Collect and Classify

Gather all findings from the reviewer agent. Assign final severity using:

| Severity | Criteria |
| --- | --- |
| **Critical** | Would lead to building the wrong thing or shipping something users can't use. Missing target user, solution doesn't fit problem, no error recovery, undeliverable scope. |
| **Major** | Risks a poor user experience or significant rework. Missing states, weak success criteria, phasing that delays value, gaps in critical moments. |
| **Minor** | Low-risk product concerns. Missing edge states, suboptimal naming, cosmetic flow issues. |

### 5.2 Deduplicate

If multiple dimensions flagged the same issue, merge into one finding and note all affected dimensions.

### 5.3 Assign Final IDs

- If a previous audit was found in Step 3, still-open findings retain their existing `PROD-NNN` IDs. New findings get sequential IDs starting at `previous_max_id + 1`, ordered by severity (Critical first, then Major, then Minor).
- If no previous audit was found, number all findings `PROD-001`, `PROD-002`, etc. in severity order.

This keeps IDs stable across re-runs so commits, SIW issues, and external references stay valid.

### 5.4 Cross-reference Existing SIW Issues

**Only if `siw/OPEN_ISSUES_OVERVIEW.md` exists:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any product findings already have open issues. Mark these findings with a note: `Existing issue: {issue-id}`. Step 7.3 must skip only annotations that still resolve to an existing issue file instead of creating a duplicate issue.

---

## Step 6: Write Report or Reply Inline

### 6.1 Determine File Location

- If `siw/` directory exists: `siw/PRODUCT_AUDIT.md`
- If no `siw/` directory: `PRODUCT_AUDIT.md` in project root

### 6.2 Handle Existing Report

If `INLINE_MODE=true`, skip this overwrite step because no report file will be written.

Otherwise, if a previous report exists at the target path:

If `AUTO_MODE=true`, choose **Replace** automatically and record the prior report's date so Step 8 can surface that a replacement happened.

Otherwise:

```yaml
header: "Existing Product Audit"
question: "A previous product audit exists. How should I proceed?"
options:
  - label: "Replace"
    description: "Overwrite with new audit results"
  - label: "Append"
    description: "Add new audit as a dated section (preserves history)"
  - label: "Abort"
    description: "Cancel — keep existing audit"
```

### 6.3 Compile and Write Report

Use the report format template from `assets/product-audit-report-format.md`.

If `INLINE_MODE=true`:

- Reply with the fully populated report inline
- Do **not** create or update `siw/PRODUCT_AUDIT.md` or `PRODUCT_AUDIT.md`

Otherwise, after writing:

```
Product audit written to: {path}
```

---

## Step 7: Optionally Create SIW Issues

**Skip this step entirely if `INLINE_MODE=true`.** Inline mode means no file writes — that includes issue files, `OPEN_ISSUES_OVERVIEW.md`, and `LOG.md`. Proceed to Step 8.

Otherwise, only if ALL of these conditions are met:

- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Critical or Major findings were found

### 7.0 SIW Issue-State Protocol

Synced SIW issue-state contract (keep aligned across SIW issue creators): every SIW issue creation or tracker-visible issue update keeps the issue file, siw/OPEN_ISSUES_OVERVIEW.md, and siw/LOG.md synchronized as one issue-state change; partial write failures must be surfaced instead of accepted silently.

### 7.1 Ask User

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

### 7.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 7 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section.
   - If creation fails, warn and skip Step 7 (report-only mode).

### 7.3 Create Issue Files

For each selected finding:

1. Apply the standard handled-finding skip rule. Skip the finding and report the matched artifact if it carries an `Existing issue:` annotation that resolves to an existing `siw/issues/ISSUE-G-*.md` file, is marked `**Status:** [Auto-fixed]` or `**Status:** [Applied directly]`, or a file matching `siw/issues/ISSUE-G-*-{finding-id}-*.md` exists. Treat unresolved `Existing issue:` annotations as stale metadata: warn in the final summary, but do not skip the finding.
2. Determine the next available `G-` issue number: parse `siw/OPEN_ISSUES_OVERVIEW.md` for the highest `G-` number, compute candidate = highest + 1 (padded to 3 digits), then verify no on-disk collision by globbing `siw/issues/ISSUE-G-{candidate}-*.md`. If any file matches, the tracker is out of sync with `siw/issues/`; increment the candidate and re-check until no file matches, then warn that the tracker may need `/kramme:siw:issue-reindex`.
3. Create issue file `siw/issues/ISSUE-G-{NNN}-product-{finding-id}-{slugified-title}.md`. Give it a status line carrying explicit `Size` (`XS|S|M|L`), `Parallelization` (`Safe to parallelize | Must be sequential | Needs coordination`), and `Mode` metadata so it matches the current tracker schema:

   ```markdown
   **Status:** READY | **Priority:** {Critical→High, Major→Medium, Minor→Low} | **Size:** {XS|S|M|L} | **Phase:** General | **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination} | **Mode:** {AUTO | HITL — <reason>} | **Related:** Product Audit Report
   ```

   **Mode default is `AUTO`.** Set `HITL — <one-line reason>` only when resolving the finding requires a concrete human-input step: an unsettled product/architectural decision, design review, a judgment call, manual testing that can't be automated, or external-system access. When unclear, choose `AUTO`. (A finding's severity does not by itself make it HITL.)

4. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
   - For a brand-new modern section, use the 7-column modern schema including the `Mode` column (`# | Title | Status | Size | Priority | Mode | Related`); the `Mode` cell is `AUTO` or `HITL` (the reason lives in the issue body, not the table).
   - When a section already exists, match its column count exactly (legacy 5-col / pre-Mode 6-col / modern 7-col) and preserve it in place — do not migrate layouts or add a `Mode` column to a section that lacks one.
5. Annotate the source product audit report entry with `Existing issue: G-{NNN}` immediately after the issue is created. If the report cannot be edited, warn in the final summary and include the finding id plus created issue id.
6. Update `siw/LOG.md` Current Progress section.

If any issue file, overview, source-report annotation, or log write fails after issue creation starts, surface the partial state in the completion summary and offer rollback guidance instead of reporting the issue as cleanly created.

---

## Step 8: Report Summary

Display a summary:

```
Product Audit Complete

Report: {inline reply | report_path}
{If a prior report was replaced in auto mode:} Replaced previous audit dated {previous_date}.
Findings: {critical_count} Critical, {major_count} Major, {minor_count} Minor
Issues created: {count} (or "None")

Dimensions evaluated:
  - Target User Clarity: {assessed/not assessed}
  - Problem/Solution Fit: {assessed/not assessed}
  - User State Modeling: {assessed/not assessed}
  - Critical Moments Coverage: {assessed/not assessed}
  - Scope Correctness: {assessed/not assessed}
  - Success Criteria Quality: {assessed/not assessed}
  - Prioritization and Decision Quality: {assessed/not assessed}
  - Strategy and Pulse Alignment: {assessed/not assessed}

Suggested next steps:
  - If file output was used: `/kramme:siw:resolve-audit siw/PRODUCT_AUDIT.md`  (address findings)
  - If inline output was used: provide the inline report content to the follow-up workflow
  - /kramme:siw:spec-audit  (technical spec quality audit)
  - /kramme:siw:generate-phases  (when ready for implementation)
```

**STOP HERE.** Wait for the user's next instruction.

---

## Error Handling

### Spec File Errors

- File not found: Warn and skip, continue with remaining files.
- File empty or unreadable: Warn, suggest checking file path.

### Linked Spec (TOC) Detection

- If the main spec is a lightweight TOC linking to supporting or contract specs, automatically include those specs in the audit. Do not audit the TOC structure alone.

### No Product Elements Found

- If spec has no clear product elements: Proceed anyway — the absence of product elements is itself a finding.

### Explore Agent Failures

- If the agent returns incomplete results: Note affected dimensions as "Incomplete analysis" in the report.
- If the agent times out: Report which dimensions were affected, suggest re-running.

### SIW Workflow Not Active

- Skip issue creation (Step 7).
- Report file goes to project root instead of `siw/`.
- All other steps work the same.

---

## Usage Examples

```
/kramme:siw:product-audit
/kramme:siw:product-audit siw
/kramme:siw:product-audit docs/my-spec.md
/kramme:siw:product-audit --inline
```
