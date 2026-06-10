---
name: kramme:siw:spec-audit
description: Audit specification documents for quality — coherence, completeness, clarity, scope, actionability, testability, value proposition, and technical design. Catches spec issues before implementation begins. Supports inline report output with --inline; --apply runs the same auto-fix procedure as kramme:siw:spec-audit:auto-fix. Use --team for multi-agent cross-validation.
argument-hint: "[spec-file-path(s) | 'siw'] [--auto] [--apply] [--model opus|sonnet|haiku] [--inline] [--team]"
disable-model-invocation: true
user-invocable: true
---

# Audit Specification Quality

Evaluate specification documents for quality across 8 dimensions before implementation begins. This is a spec-only analysis — no codebase code is read or compared.

**IMPORTANT:** This is a thorough quality audit. Do not return early. Do not assume a section is well-written without reading it carefully. Check every part of the specification against quality criteria. The goal is to find ALL weaknesses — a clean report is suspicious, not reassuring.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

## Process Overview

```
/kramme:siw:spec-audit [spec-file-path(s) | 'siw'] [--auto] [--apply] [--model opus|sonnet|haiku] [--inline] [--team]
    |
    v
[Step 1: Resolve Spec Files] -> Parse args or auto-detect from siw/
    |
    v
[Step 2: Read Specs and Extract Structure] -> Read fully, detect type, extract elements
    |
    v
[Step 3: Launch Parallel Analysis] -> Explore agents per dimension group
    |
    v
[Step 4: Analyze Findings] -> Classify, deduplicate, assign severity and scores
    |
    v
[Step 5: Write Report] -> siw/AUDIT_SPEC_REPORT.md
    |
    v
[Step 6: Optionally Apply Findings or Create SIW Issues] -> Canonical auto-fix or issue creation
    |
    v
[Step 7: Report Summary] -> Stats and next steps
```

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

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

### 1.2 If File Paths Provided

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
   - **Coupling note for SIW skill authors:** Any new top-level workflow file added under `siw/` by sibling skills must either match one of the patterns above or be added to this list, or it will be silently audited as a spec.

3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`

4. Check for linked external specs:
   - Read **every detected spec file** (both `siw/*.md` and `siw/supporting-specs/*.md` candidates).
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list (verify each exists).

5. **Use all found spec files by default.** Only ask the user to select if there are files that look unrelated to each other (e.g., specs for entirely different features). Do NOT ask when the files are clearly parts of the same specification (main spec + supporting specs).

6. Store files as `spec_files`.

### 1.4 If No Spec Files Found

If auto-detection found no spec files because every top-level `siw/*.md` candidate was excluded by the workflow-artifact filter, report the excluded filenames and ask the user for explicit spec path(s). Validate provided paths with the explicit-path flow from Step 1.2 and continue when valid. If the user provides no path, then emit the generic error below and abort.

```
Error: No specification files found.

Expected locations:
  - siw/*.md (SIW spec files)
  - siw/supporting-specs/*.md (supporting specifications)

Or provide file path(s) directly:
  /kramme:siw:spec-audit path/to/spec.md
  /kramme:siw:spec-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.

---

## Step 2: Read Specs and Extract Structure

### 2.1 Read Every Spec File End-to-End

Read each spec file completely. Do not skim. Understand the full picture before analyzing quality.

### 2.2 Extract Structural Elements

For each spec file, identify and extract:

| Element | What to look for |
| --- | --- |
| Overview/Objectives | Opening section, project description, goals |
| Scope Definition | In-scope items, out-of-scope items, boundaries |
| Success Criteria | Measurable outcomes, checkboxes, definitions of done |
| Requirements | Named entities, behaviors, constraints, contracts |
| Design Decisions | Technical choices, rationale, alternatives considered |
| Implementation Tasks | Task breakdowns, phases, work items |
| Testing/Verification | Test plans, verification checklists, quality gates |
| Edge Cases | Boundary conditions, error scenarios, exceptional flows |
| Out of Scope | Explicit exclusions |
| Technical Architecture | Data models, API contracts, system design, component boundaries |

For each element, capture:

- **id**: Sequential ID (e.g., `ELEM-001`)
- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **content_summary**: Brief description of what the section contains

### 2.2.5 Extract Work Context

After reading all spec files, look for a `## Work Context` section in the spec files:

1. Parse the markdown table to extract: Work Type, Priority Dimensions, Deprioritized dimensions
   - If multiple spec files define Work Context, prefer the top-level `siw/*.md` candidate (specs in `siw/supporting-specs/` are auxiliary). If more than one top-level spec defines Work Context, use the lexicographically first one and emit a one-line warning that names the ignored files.
2. If not found or malformed, default to Production Feature (all dimensions equally weighted, no caps)
3. Store as `work_context`

**Work Context drives severity adjustments in Steps 3 and 4.** See downstream behavior rules below.

### 2.3 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - {spec_file_1}
  - {spec_file_2}

Structural Elements Found: {total}
Sections identified: {count}
Work Context: {work_context.work_type} — Priority: {priority_dimensions}, Deprioritized: {deprioritized}
```

If no Work Context found, show: `Work Context: Not specified (using Production Feature defaults)`

**If no extractable structure found:**

```
Warning: Could not extract structured sections from {file}.
The file may need clearer headings, task definitions, or section organization.
```

If `AUTO_MODE=true`, choose **Attempt best-effort analysis** automatically.

Otherwise use AskUserQuestion:

```yaml
header: "No Structure Found"
question: "Could not extract structured sections. How should I proceed?"
options:
  - label: "Attempt best-effort analysis"
    description: "Analyze the spec text as-is, even without clear section structure"
  - label: "Abort"
    description: "Cancel the audit"
```

---

## Step 3: Launch Parallel Analysis

### 3.1 Determine Agent Groups

Group the 8 quality dimensions across Explore agents based on spec size:

**Small specs** (single file, under 200 lines) — **2 agents:**

- Agent A: Coherence, Completeness, Value Proposition, Scope
- Agent B: Clarity, Actionability, Testability, Technical Design

**Medium specs** (1-3 files, 200-800 lines) — **3 agents:**

- Agent A: Coherence, Value Proposition, Technical Design
- Agent B: Completeness, Scope
- Agent C: Clarity, Actionability, Testability

**Large specs** (3+ files or 800+ lines) — **4 agents:**

- Agent A: Coherence, Value Proposition
- Agent B: Completeness, Scope
- Agent C: Clarity, Actionability
- Agent D: Testability, Technical Design

### 3.2 Launch Explore Agents

**Platform requirement:** The standard workflow assumes the Claude Code `Task` tool with `subagent_type=Explore`. For multi-agent execution on Codex or other runtimes, invoke this skill with `--team` (see `references/team-mode.md` for the cross-platform multi-agent path). If the standard workflow runs in a runtime without the Task/Explore tooling, fall back to a single sequential pass that walks every dimension group inline and report this in the summary.

For each agent group, launch an Explore agent using the Task tool (`subagent_type=Explore`, `model={agent_model}`).

**Default model:** `opus`. Override with `--model sonnet` or `--model haiku` for faster/cheaper runs.

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 3.3 Explore Agent Prompt Structure

Each agent receives the full spec text and analysis instructions for its assigned dimensions:

```
You are auditing a specification document for quality. Do NOT look at any implementation code. Do NOT use Grep or Glob against the codebase. Analyze the spec text ONLY using the Read tool on the provided spec files.

## Spec Files

Read these files completely:
{list of spec file paths}

## Your Assigned Dimensions

Analyze the spec against each dimension below. For each finding, report:
- **Finding ID**: SPEC-{NNN} (use sequential numbers starting from {start_number})
- **Dimension**: {which dimension}
- **Title**: Brief description
- **Location**: Source file > section heading
- **Details**: What the issue is, with quotes from the spec
- **Severity**: Critical | Major | Minor
- **Recommendation**: Specific action to fix
- **Fix Confidence**: {score}/100 ({MECHANICAL|HIGH_CONFIDENCE|MODERATE_CONFIDENCE|REQUIRES_DECISION})

## Rules

- **Report on every dimension.** Even if no findings, confirm the dimension was analyzed.
- **Do not return early.** Continue until you have checked every section against every assigned dimension.
- **Quote the spec.** When flagging an issue, include the relevant text from the spec.
- **Be specific in recommendations.** "Add more detail" is not enough. Say what detail is missing.
- **Score provisional fix confidence on every finding using `references/fix-confidence-rubric.md`.** Sum the four 0-25 sub-scores, then apply the tier boundaries, the sub-score guardrail, and the safety caps documented in that file before writing the provisional `Fix Confidence`.

{Dimension-specific instructions inserted here — see Section 3.4}

## Work Context Adjustments

This spec has Work Type: {work_context.work_type}

Priority dimensions (flag even minor issues): {work_context.priority_dimensions}
Deprioritized dimensions (cap at Minor severity): {work_context.deprioritized}

When evaluating **deprioritized dimensions**:
- Assess severity normally and keep that original severity in the finding data
- Tag each finding with: **[Deprioritized — cap to Minor during aggregation]**
- Do NOT downgrade the severity yourself; the lead applies the Minor cap in Step 4.3.5 after recording `original_severity`

When evaluating **priority dimensions**:
- Apply strict scrutiny. Even small gaps should be flagged.
- Tag priority findings with: **[Priority dimension]**

{If work_context is Production Feature or not specified, omit this entire section from the agent prompt.}
```

### 3.4 Dimension Analysis Instructions

Read the dimension-specific instructions from `references/dimension-instructions.md` and include the relevant dimension blocks in each agent's prompt based on its assigned dimensions.

The 8 dimensions are: Coherence, Completeness, Clarity, Scope, Actionability, Testability, Value Proposition, Technical Design. Each includes check items and a severity guide.

---

## Step 4: Analyze Findings

After all Explore agents complete:

### 4.1 Collect Results

Gather all findings from every agent. Deduplicate — if multiple dimensions flagged the same issue, merge into one finding and note all affected dimensions.

Read `references/post-processing-rules.md` once at the start of Step 4 and apply it throughout: merged-finding handling here in 4.1, severity-cap accounting in 4.3.5, final fix-confidence normalization in 4.3.6, dimension-score effects in 4.4, and issue eligibility in Step 6.

### 4.2 Assign Global Finding IDs

Re-number all findings as `SPEC-001`, `SPEC-002`, etc. in severity order (Critical first, then Major, then Minor).

### 4.3 Assign Severity

For each finding:

| Severity | Criteria |
| --- | --- |
| **Critical** | Would block implementation or lead to fundamentally wrong implementation. Missing core requirements, contradictory specs, undefined key behaviors, fundamental design flaws. |
| **Major** | Risks incorrect implementation or significant rework. Ambiguous requirements, missing edge cases, unclear scope boundaries, design gaps. |
| **Minor** | Cosmetic or low-risk. Inconsistent terminology, missing non-critical sections, formatting issues, suboptimal choices. |

### 4.3.5 Apply Work Context Severity Caps

If `work_context` specifies deprioritized dimensions:

For each finding whose affected dimensions are all deprioritized:

- If severity was assigned as Critical or Major, record `original_severity={severity}`, then downgrade to Minor
- Annotate capped findings with: `**Severity Note:** [Deprioritized — capped at Minor from {original_severity}]`

If a merged finding also affects any non-deprioritized dimension, do **not** apply the cap. Keep the normally assigned severity and note all affected dimensions in the finding body.

This ensures purely deprioritized dimensions never produce Critical or Major findings, while still preserving blockers that also affect prioritized or neutral dimensions.

### 4.3.6 Normalize Final Fix Confidence

Apply the "Final Fix Confidence" section of `references/post-processing-rules.md` (already loaded in Step 4.1) after severity assignment and any Work Context caps.

### 4.4 Compute Dimension Scores

For each dimension, compute a quality score:

| Score        | Meaning                                                |
| ------------ | ------------------------------------------------------ |
| **Strong**   | No Critical or Major findings. At most Minor findings. |
| **Adequate** | No Critical findings. Some Major findings.             |
| **Weak**     | Has Critical findings or many Major findings.          |
| **Missing**  | Dimension not addressed at all in the spec.            |

Apply the "Overall Assessment After Severity Caps" section of `references/post-processing-rules.md` (already loaded in Step 4.1) when computing dimension scores and the overall assessment.

### 4.5 Cross-reference Existing Issues

**Only if SIW workflow is active:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any found spec gaps already have open issues. Mark these findings with a note: "Existing issue: {issue-id}".

---

## Step 5: Write Report

### 5.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_SPEC_REPORT.md`
- If no `siw/` directory: `AUDIT_SPEC_REPORT.md` in project root

### 5.2 Handle Existing Report

If `INLINE_MODE=true`, skip this overwrite step because no report file will be written.

Otherwise, if a previous report exists at the target path:

If `AUTO_MODE=true`, choose **Replace** automatically.

Otherwise:

```yaml
header: "Existing Spec Audit Report"
question: "A previous spec audit report exists. How should I proceed?"
options:
  - label: "Replace"
    description: "Overwrite with new audit results"
  - label: "Append"
    description: "Add new audit as a dated section (preserves history)"
  - label: "Abort"
    description: "Cancel — keep existing report"
```

If the user chooses **Append**, append the new report as a complete new `# Spec Audit Report` block at the end of the file, separated from the previous run with `---`. Do not merge sections across runs.

### 5.3 Compile and Write Report

Use the report format template from `assets/spec-audit-report-format.md`.

If `INLINE_MODE=true`:

- Reply with the fully populated report inline
- Do **not** create or update `siw/AUDIT_SPEC_REPORT.md` or `AUDIT_SPEC_REPORT.md`

Otherwise, after writing:

```
Spec audit report written to: {path}
```

---

## Step 6: Optionally Apply Findings or Create SIW Issues

**If `INLINE_MODE=true`, skip this entire step.** Inline runs are read-only previews — do not write issue files or touch `siw/OPEN_ISSUES_OVERVIEW.md` / `siw/LOG.md`.

If there are no findings, skip the rest of Step 6.

If `APPLY_MODE=true`, read and follow `references/apply-now.md`, then skip issue creation entirely.

If `AUTO_MODE=true`, apply the "Issue-Eligible Findings" section of `references/post-processing-rules.md` (already loaded in Step 4.1), then read and follow `references/issue-creation.md` using the standard auto-mode behavior.

Before prompting, determine whether SIW issue creation is available:

- Apply the "Issue-Eligible Findings" section of `references/post-processing-rules.md` using the **Critical and major only** selection to compute `ISSUE_ELIGIBLE_FINDINGS`.
- Set `ISSUE_CREATION_AVAILABLE=true` only if all `references/issue-creation.md` eligibility requirements are met: `siw/OPEN_ISSUES_OVERVIEW.md` exists, `siw/issues/` exists or can be created, `siw/LOG.md` exists or can be created, and `ISSUE_ELIGIBLE_FINDINGS` is not empty.
- If `ISSUE_CREATION_AVAILABLE=false`, do not show any issue-creation options.

If `ISSUE_CREATION_AVAILABLE=false`, ask the user which follow-up path to take:

```yaml
header: "Resolve Spec Findings"
question: "Found {N} actionable spec findings. Auto-fix safe findings now or keep the report only?"
options:
  - label: "Apply now"
    description: "Run the canonical auto-fix procedure against the audit report"
  - label: "Keep report only"
    description: "Make no spec edits or issue files"
```

If the user chooses **Apply now**, read and follow `references/apply-now.md`, then skip issue creation entirely.

If the user chooses **Keep report only**, stop Step 6 after keeping the report only.

If `ISSUE_CREATION_AVAILABLE=true`, ask the user which follow-up path to take:

```yaml
header: "Resolve Spec Findings"
question: "Found {N} actionable spec findings. Auto-fix safe findings, create SIW issues, or keep the report only?"
options:
  - label: "Apply now"
    description: "Run the canonical auto-fix procedure against the audit report; create no G-* issues"
  - label: "Create SIW issues"
    description: "Choose which findings become SIW issues"
  - label: "Keep report only"
    description: "Make no spec edits or issue files"
```

If the user chooses **Apply now**, read and follow `references/apply-now.md`, then skip issue creation entirely.

If the user chooses **Keep report only**, stop Step 6 after keeping the report only.

If the user chooses **Create SIW issues**, read and follow `references/issue-creation.md` starting at §6.1. Treat **Create SIW issues** as a routing choice only, not as the detailed issue-selection choice; §6.1 must still ask for or resolve **Critical and major only**, **All findings**, **Let me select**, or **No issues**.

---

## Step 7: Report Summary

Use the summary template from `assets/spec-audit-summary.md`, then end the turn.

---

## Error Handling

### Spec File Errors

- File not found: Warn and skip, continue with remaining files.
- File empty or unreadable: Warn, suggest checking file path.

### Linked Spec (TOC) Detection

- If the main spec is a lightweight TOC linking to supporting specs, automatically include the supporting specs in the audit. Do not audit the TOC structure alone.

### No Structural Elements Found

- If spec has no clear structure: Offer best-effort analysis or abort.
- If all elements fall into a single dimension: Proceed with fewer agents.

### Explore Agent Failures

- If an agent returns incomplete results: Note affected dimensions as "Incomplete analysis" in the report.
- If an agent times out: Report which dimension was affected, suggest re-running.

### SIW Workflow Not Active

- Skip issue creation (Step 6).
- Report file goes to project root instead of `siw/`.
- All other steps work the same.
