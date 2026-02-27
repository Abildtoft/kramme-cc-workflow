---
name: kramme:siw:spec-audit
description: Audit specification documents for quality — coherence, completeness, clarity, scope, actionability, testability, value proposition, and technical design. Catches spec issues before implementation begins.
argument-hint: "[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
---

# Audit Specification Quality

Evaluate specification documents for quality across 8 dimensions before implementation begins. This is a spec-only analysis — no codebase code is read or compared.

**IMPORTANT:** This is a thorough quality audit. Do not return early. Do not assume a section is well-written without reading it carefully. Check every part of the specification against quality criteria. The goal is to find ALL weaknesses — a clean report is suspicious, not reassuring.

## Process Overview

```
/kramme:siw:spec-audit [spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]
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
[Step 6: Optionally Create SIW Issues] -> Convert findings to issues
    |
    v
[Step 7: Report Summary] -> Stats and next steps
```

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s), keyword, and optional flags.

**Extract `--model` flag first (Claude Code only — ignored on other platforms):**
- If `$ARGUMENTS` contains `--model opus`, `--model sonnet`, or `--model haiku`, extract it and store as `agent_model`.
- **Default:** `opus`
- Remove the flag from `$ARGUMENTS` before processing remaining arguments.

**Detection rules for remaining arguments:**
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
     find {path} -maxdepth 2 -type f -name "*.md" 2>/dev/null
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
   ls siw/ 2>/dev/null
   ```

2. Find spec files (exclude workflow files):
   - Use Glob to find `siw/*.md`
   - Exclude: `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_IMPLEMENTATION_REPORT.md`, `AUDIT_SPEC_REPORT.md`, `SPEC_STRENGTHENING_PLAN.md`

3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`

4. Check for linked external specs:
   - Read **every detected spec file** (both `siw/*.md` and `siw/supporting-specs/*.md` candidates).
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list (verify each exists).

5. **Use all found spec files by default.** Only ask the user to select if there are files that look unrelated to each other (e.g., specs for entirely different features). Do NOT ask when the files are clearly parts of the same specification (main spec + supporting specs).

6. Store files as `spec_files`.

### 1.4 If No Spec Files Found

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
|---------|-----------------|
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

### 2.3 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - {spec_file_1}
  - {spec_file_2}

Structural Elements Found: {total}
Sections identified: {count}
```

**If no extractable structure found:**

```
Warning: Could not extract structured sections from {file}.
The file may need clearer headings, task definitions, or section organization.
```

Use AskUserQuestion:

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

## Rules

- **Report on every dimension.** Even if no findings, confirm the dimension was analyzed.
- **Do not return early.** Continue until you have checked every section against every assigned dimension.
- **Quote the spec.** When flagging an issue, include the relevant text from the spec.
- **Be specific in recommendations.** "Add more detail" is not enough. Say what detail is missing.
- **Mark confidence on Technical Design findings.** These are more subjective — use HIGH | MEDIUM | LOW.

{Dimension-specific instructions inserted here — see Section 3.4}
```

### 3.4 Dimension Analysis Instructions

Read the dimension-specific instructions from `resources/dimension-instructions.md` and include the relevant dimension blocks in each agent's prompt based on its assigned dimensions.

The 8 dimensions are: Coherence, Completeness, Clarity, Scope, Actionability, Testability, Value Proposition, Technical Design. Each includes check items and a severity guide.

---

## Step 4: Analyze Findings

After all Explore agents complete:

### 4.1 Collect Results

Gather all findings from every agent. Deduplicate — if multiple dimensions flagged the same issue, merge into one finding and note all affected dimensions.

### 4.2 Assign Global Finding IDs

Re-number all findings as `SPEC-001`, `SPEC-002`, etc. in severity order (Critical first, then Major, then Minor).

### 4.3 Assign Severity

For each finding:

| Severity | Criteria |
|----------|----------|
| **Critical** | Would block implementation or lead to fundamentally wrong implementation. Missing core requirements, contradictory specs, undefined key behaviors, fundamental design flaws. |
| **Major** | Risks incorrect implementation or significant rework. Ambiguous requirements, missing edge cases, unclear scope boundaries, design gaps. |
| **Minor** | Cosmetic or low-risk. Inconsistent terminology, missing non-critical sections, formatting issues, suboptimal choices. |

### 4.4 Compute Dimension Scores

For each dimension, compute a quality score:

| Score | Meaning |
|-------|---------|
| **Strong** | No Critical or Major findings. At most Minor findings. |
| **Adequate** | No Critical findings. Some Major findings. |
| **Weak** | Has Critical findings or many Major findings. |
| **Missing** | Dimension not addressed at all in the spec. |

### 4.5 Cross-reference Existing Issues

**Only if SIW workflow is active:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any found spec gaps already have open issues. Mark these findings with a note: "Existing issue: {issue-id}".

---

## Step 5: Write Report

### 5.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_SPEC_REPORT.md`
- If no `siw/` directory: `AUDIT_SPEC_REPORT.md` in project root

### 5.2 Handle Existing Report

If a previous report exists at the target path:

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

### 5.3 Compile and Write Report

Use the report format template from `resources/templates/spec-audit-report-format.md`.

After writing:
```
Spec audit report written to: {path}
```

---

## Step 6: Optionally Create SIW Issues

**Only if ALL of these conditions are met:**
- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Critical or Major findings were found

### 6.1 Ask User

```yaml
header: "Create SIW Issues"
question: "Found {N} actionable spec findings. Create SIW issues for them?"
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

### 6.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 6 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section.
   - If creation fails, warn and skip Step 6 (report-only mode).

### 6.3 Create Issue Files

For each selected finding:

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-spec-{slugified-title}.md` using `resources/templates/spec-issue-template.md`.

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
4. Update `siw/LOG.md` Current Progress section using `resources/templates/spec-log-last-completed.md`.

---

## Step 7: Report Summary

Use the summary template from `resources/templates/spec-audit-summary.md`.

**STOP HERE.** Wait for the user's next instruction.

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
