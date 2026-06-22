---
name: kramme:siw:spec-audit
description: Audit specification documents for quality — coherence, completeness, clarity, scope, actionability, testability, value proposition, and technical design. Supports --inline and --apply. Use --team for multi-agent cross-validation and codebase pattern review.
argument-hint: "[spec-file-path(s) | 'siw'] [--auto] [--apply] [--model opus|sonnet|haiku] [--inline] [--team]"
disable-model-invocation: true
user-invocable: true
---

# Audit Specification Quality

Evaluate specification documents for quality across 8 dimensions before implementation begins. The standard workflow is spec-only; `--team` also runs a bounded codebase pattern reviewer that checks whether the spec introduces new implementation patterns without rationale.

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

Read and follow `references/spec-resolution.md`. It defines mode flag parsing, `--inline`/`--apply` incompatibility, explicit path handling, `siw` auto-detection, linked-spec discovery, no-spec error behavior, and the Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.

At the end of Step 1, store verified paths as `spec_files` and continue only when at least one valid specification file was found.

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

Each agent receives the full spec text and analysis instructions for its assigned dimensions. Read `references/audit-agent-prompt.md`, populate the placeholders for the assigned dimension group, and omit the Work Context Adjustments block when the work context is Production Feature or unspecified.

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

If a previous report exists at the target path from Step 5.1 (`siw/AUDIT_SPEC_REPORT.md`, or `AUDIT_SPEC_REPORT.md` in the project root), read it and record the highest previously reported `SPEC-NNN` as `previous_max_id`. Findings that match a previously reported finding (same issue, even if reworded) retain their existing IDs; new findings get sequential IDs starting at `previous_max_id + 1`, ordered by severity (Critical first, then Major, then Minor). If no previous report exists, number all findings `SPEC-001`, `SPEC-002`, etc. in severity order.

This keeps IDs stable across re-runs so commits, SIW issues (e.g. `/kramme:siw:resolve-audit` filenames `ISSUE-G-XXX-{finding-id}-*.md`), and external references stay valid.

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
