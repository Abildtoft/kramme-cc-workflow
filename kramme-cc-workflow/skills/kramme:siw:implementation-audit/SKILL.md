---
name: kramme:siw:implementation-audit
description: Exhaustively audit codebase implementation against specification. Finds naming misalignments, missing implementations, contract violations, and spec drift.
argument-hint: "[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
---

# Audit Implementation Against Specification

Exhaustively compare the codebase implementation against specification documents to find discrepancies, missing implementations, naming misalignments, and spec drift.

**IMPORTANT:** This is a thorough, exhaustive audit. Do not return early. Do not conclude anything is "implemented" without reading the actual code. Check every requirement in the specification against the codebase before compiling results. The goal is to find ALL discrepancies — a clean report is suspicious, not reassuring.

## Process Overview

```
/kramme:siw:implementation-audit [spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]
    |
    v
[Step 1: Resolve Spec Files] -> Parse args or auto-detect from siw/
    |
    v
[Step 2: Read Specs and Extract Requirements] -> Read fully, extract checklist
    |
    v
[Step 3: Plan Codebase Exploration] -> Map spec sections to code areas
    |
    v
[Step 4: Deep Codebase Comparison] -> Explore agents per spec section
    |
    v
[Step 5: Analyze Findings] -> Classify discrepancies
    |
    v
[Step 6: Compile Discrepancy Report] -> Structured markdown
    |
    v
[Step 7: Write Report File] -> siw/AUDIT_IMPLEMENTATION_REPORT.md
    |
    v
[Step 8: Optionally Create SIW Issues] -> Convert findings to issues
    |
    v
[Step 9: Report Summary] -> Stats and next steps
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
  /kramme:siw:implementation-audit path/to/spec.md
  /kramme:siw:implementation-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.

---

## Step 2: Read Specs and Extract Requirements

Read every file in `spec_files` fully and extract a requirements checklist.

### 2.1 Read Every Spec File End-to-End

Read each spec file completely. Do not skim. Understand the full picture before extracting requirements.

### 2.2 Extract Requirements

Everything in the spec is a requirement — names, structures, behaviors, contracts, constraints. If the spec describes it, the code must match it. Extract checkable items across all of these areas:

- Named entities (class names, component names, service names, table names)
- API contracts (endpoints, methods, request/response shapes, status codes)
- Data model details (entity names, field names, types, constraints, relationships)
- Behavior ("when X then Y", business rules, acceptance criteria)
- Specific names (file names, variable names, route paths, database columns)
- UI elements (component names, user flows, states, labels)
- Integration points (external services, events, middleware)
- Validation rules (input constraints, formats, ranges)
- Error handling (error scenarios, fallback behavior, messages)
- Configuration (feature flags, environment variables)

For each item, capture:

- **id**: Sequential ID (e.g., `REQ-001`)
- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **description**: What the spec describes
- **key_terms**: Named identifiers to search for in code

**If the spec describes it, extract it.** Do not limit extraction to things explicitly labeled as requirements — descriptions of behavior, naming, structure, data shapes, and workflows are all checkable against the code.

### 2.3 Respect Scope Boundaries

When parsing specs:
- **Skip "Out of Scope" sections** — do not flag out-of-scope items as missing.
- **Skip "Future Work" or "Deferred" sections** — unless spec marks them as partially implemented.
- **Respect phase boundaries** — if spec has phases, only audit requirements for completed phases (check `siw/OPEN_ISSUES_OVERVIEW.md` for phase status if available).

### 2.4 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - {spec_file_1}
  - {spec_file_2}

Requirements Extracted: {total}
Key search terms identified: {count} unique names/identifiers
```

**If no extractable requirements found:**

```
Warning: Could not extract structured requirements from {file}.
The file may need clearer acceptance criteria, named entities, or explicit contracts.
```

Use AskUserQuestion:

```yaml
header: "No Requirements Found"
question: "Could not extract structured requirements. How should I proceed?"
options:
  - label: "Attempt best-effort scan"
    description: "Search for any named terms found in the spec, even without clear requirement structure"
  - label: "Abort"
    description: "Cancel the audit"
```

---

## Step 3: Plan Codebase Exploration

Group requirements by **spec file or major spec section** (not by abstract domain). Each group will be assigned to an Explore agent that receives the full context of that spec section.

### 3.1 Determine Grouping

- If there are **1-2 spec files**: One Explore agent per spec file.
- If there are **3+ spec files**: Group related files (e.g., main spec + its supporting specs) and assign one agent per group. Aim for 2-4 agents total.
- If a single spec file has **clearly distinct major sections** (e.g., "Data Model", "API Endpoints", "Authentication"): Split into one agent per major section.

### 3.2 For Each Group, Identify Code Areas

For each group of requirements, identify:
- Which directories/files likely implement these requirements
- Key file patterns to search (e.g., `**/*controller*`, `**/*model*`)
- Named identifiers that should appear in code

This information will be passed to the Explore agents to direct their search.

---

## Step 4: Deep Codebase Comparison

**CRITICAL:** This is the core of the audit. You are comparing what the spec says against what the code actually does. A grep hit is NOT sufficient evidence of implementation — you must read and understand the code.

### 4.1 Launch Explore Agents

For each group from Step 3, launch an Explore agent using the Task tool (`subagent_type=Explore`, `model={agent_model}`).

**Default model:** `opus`. Override with `--model sonnet` or `--model haiku` for faster/cheaper runs.

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 4.2 Explore Agent Prompt

Each agent receives this prompt structure:

```
You are auditing whether the codebase matches a specification. Everything in the spec is a requirement — names, behaviors, data shapes, contracts, constraints. Your job is to find EVERY discrepancy — naming mismatches, missing features, behavioral differences, incomplete implementations.

## Your Spec Section

{Paste the FULL raw text of the spec section/file assigned to this agent}

## Requirements Checklist

{For each requirement in this group:}
- REQ-{id}: {description} [Key terms: {key_terms}]
{End for each}

## Instructions

For each requirement, follow this exact process:

1. **Search for the implementation.** Use Grep for key terms and Glob for expected file patterns. Look for the specific names, routes, fields, and classes mentioned in the spec.

2. **Read the implementation files end-to-end.** Do NOT just check that a grep hit exists. Open the file, read the relevant code, and understand what it actually does. Compare the code's behavior against what the spec requires.

3. **Check for naming alignment.** Does the code use the exact names specified in the spec? Field names, route paths, class names, method names, error messages — all must match.

4. **Check for behavioral alignment.** Does the code do what the spec says? Check edge cases, validation rules, error handling, response shapes, status codes.

5. **Report your finding.** For each requirement:
   - **REQ ID**: The requirement identifier
   - **Status**: IMPLEMENTED | PARTIAL | MISSING | NAMING_MISMATCH | BEHAVIOR_MISMATCH
   - **Evidence**: File paths and line numbers. For IMPLEMENTED, quote the specific code. For MISSING, list everywhere you searched.
   - **Discrepancy details**: If not IMPLEMENTED, describe exactly what differs
   - **Confidence**: HIGH | MEDIUM | LOW

## Rules — Read These Carefully

- **Report on EVERY requirement.** Do not skip any, even if they seem trivial.
- **Do not return early.** Continue until you have checked every single requirement.
- **Grep hits are not evidence of implementation.** A function named `createUser` existing does not mean it implements the spec's `createUser` behavior. Read the function body.
- **Absence of grep hits does NOT mean the feature is implemented under a different name.** It likely means it's MISSING. Only mark as implemented-with-different-name if you find concrete evidence.
- **No evidence = MISSING.** If you cannot find positive evidence that a requirement is implemented, mark it MISSING. Do not give the benefit of the doubt.
- **For PARTIAL status**, describe what IS implemented and what is NOT.
- **Read the actual code.** For every requirement you mark as IMPLEMENTED, you must have read the implementation code, not just found a filename or grep match.
```

---

## Step 5: Analyze Findings

After all Explore agents complete:

### 5.1 Collect Results

Gather all per-requirement assessments from every agent.

### 5.2 Classify Findings

| Classification | Criteria |
|---|---|
| **Fully Implemented** | Status = IMPLEMENTED, Confidence = HIGH |
| **Discrepancy Found** | Status = PARTIAL, NAMING_MISMATCH, or BEHAVIOR_MISMATCH |
| **Missing** | Status = MISSING |
| **Uncertain** | Confidence = LOW (needs manual verification) |

### 5.3 Assign Severity

For each discrepancy or missing item:

- **Critical**: Missing core functionality, broken contracts, missing entire endpoints/entities
- **Major**: Behavior differs from spec, wrong types, incorrect validation rules
- **Minor**: Naming mismatch, cosmetic differences, documentation gaps

### 5.4 Cross-reference Existing Issues

**Only if SIW workflow is active:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any found discrepancies already have open issues. Mark these findings with a note: "Existing issue: {issue-id}".

---

## Step 6: Compile Discrepancy Report

Generate a structured markdown report:

```markdown
# Audit Report: Implementation vs. Specification

**Date:** {current date}
**Spec Files Reviewed:** {list of spec files with paths}

## Summary

| Category | Count |
|----------|-------|
| Requirements checked | {total} |
| Fully implemented | {count} |
| Discrepancies found | {count} |
| Missing implementations | {count} |
| Uncertain (needs manual check) | {count} |

**Compliance:** {implemented / total * 100}%

## Critical Discrepancies

### DISC-001: {Brief title}

**Requirement:** REQ-{id} from {source_file} > {source_section}
**Spec says:** {requirement description}
**Code does:** {what was found, with file:line references}
**Severity:** Critical
**Details:** {explanation of the gap}

---

{Repeat for each critical discrepancy}

## Major Discrepancies

{Same format as Critical}

## Minor Discrepancies

{Same format as Critical}

## Missing Implementations

### MISS-001: {Brief title}

**Requirement:** REQ-{id} from {source_file} > {source_section}
**Spec says:** {requirement description}
**Searched in:** {directories/files searched}
**Details:** {why it appears to be missing}

---

{Repeat for each missing item}

## Uncertain Items

Items that could not be confidently verified. Manual review recommended.

| # | Requirement | Concern | Where to Look |
|---|-------------|---------|---------------|
| 1 | REQ-{id}: {brief} | {why uncertain} | {file paths} |

## Fully Implemented

<details>
<summary>{count} requirements verified ({click to expand})</summary>

| # | Requirement | Evidence |
|---|-------------|----------|
| 1 | REQ-{id}: {brief} | {file:line} |

</details>
```

---

## Step 7: Write Report File

### 7.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_IMPLEMENTATION_REPORT.md`
- If no `siw/` directory: `AUDIT_IMPLEMENTATION_REPORT.md` in project root

### 7.2 Handle Existing Report

If a previous report exists at the target path:

```yaml
header: "Existing Audit Report"
question: "A previous audit report exists. How should I proceed?"
options:
  - label: "Replace"
    description: "Overwrite with new audit results"
  - label: "Append"
    description: "Add new audit as a dated section (preserves history)"
  - label: "Abort"
    description: "Cancel — keep existing report"
```

### 7.3 Write the Report

Write the compiled report to the target path.

```
Audit report written to: {path}
```

---

## Step 8: Optionally Create SIW Issues

**Only if ALL of these conditions are met:**
- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Discrepancies or missing implementations were found (Critical + Major + Missing > 0)

### 8.1 Ask User

```yaml
header: "Create SIW Issues"
question: "Found {N} actionable discrepancies. Create SIW issues for them?"
options:
  - label: "Critical and major only"
    description: "Create {N} issues (skip minor discrepancies)"
  - label: "All discrepancies"
    description: "Create {N} issues including minor ones"
  - label: "Let me select"
    description: "Choose which discrepancies become issues"
  - label: "No issues"
    description: "Keep the report only"
```

### 8.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 8 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section so updates can be appended safely.
   - If creation fails, warn and skip Step 8 (report-only mode).

### 8.3 Create Issue Files

For each selected discrepancy:

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-fix-{slugified-title}.md`:

```markdown
# ISSUE-G-{NNN}: Fix {discrepancy title}

**Status:** Ready | **Priority:** {Critical→High, Major→Medium, Minor→Low} | **Phase:** General | **Related:** Audit Report

## Problem

Audit found that the implementation does not match the specification.

**Spec requirement (REQ-{id}):** {requirement description}
**Source:** {source_file} > {source_section}

## Context

{What was found in the code vs. what the spec requires}
{file:line references}

## Scope

### In Scope
- {Specific fix needed}

### Out of Scope
- Refactoring unrelated code

## Acceptance Criteria

- [ ] Implementation matches spec requirement REQ-{id}
- [ ] {Specific testable criterion based on the discrepancy}

---

## Technical Notes

### Affected Areas
- `{file path}` — {what needs to change}

### References
- Spec: `{spec_file}` > {section}
- Audit Report: `{report_path}` > {DISC-NNN or MISS-NNN}
```

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.

4. Update `siw/LOG.md` Current Progress section:

```markdown
### Last Completed
- Spec compliance audit: {N} discrepancies found, {M} issues created
```

---

## Step 9: Report Summary

```
Audit Complete
==============

Spec Files: {list}
Requirements Checked: {total}
Compliance: {X}%

Results:
  Fully implemented:      {N}
  Critical discrepancies: {N}
  Major discrepancies:    {N}
  Minor discrepancies:    {N}
  Missing implementations:{N}
  Uncertain:              {N}

Report: {report_path}

{If issues created:}
Issues Created: {N} (G-{start} through G-{end})
See siw/OPEN_ISSUES_OVERVIEW.md for the full list.

Next Steps:
  - Resolve findings one-by-one with executive summaries, alternatives, and issue creation: /kramme:siw:audit-resolve
  - Review the report for accuracy (especially "Uncertain" items)
  - Fix critical discrepancies first: /kramme:siw:issue-implement G-{first}
  - Re-run after fixes to verify compliance: /kramme:siw:implementation-audit
  - Clean up report when done: /kramme:artifacts:cleanup
```

**STOP HERE.** Wait for the user's next instruction.

---

## Error Handling

### Spec File Errors
- File not found: Warn and skip, continue with remaining files.
- File empty or unreadable: Warn, suggest checking file path.

### No Requirements Extracted
- If spec has no clear structure: Offer best-effort scan or abort.
- If all requirements fall into a single group: Proceed with one agent instead of many.

### Explore Agent Failures
- If an agent returns incomplete results: Note affected requirements as "Uncertain" in the report.
- If an agent times out: Report which spec section was affected, suggest re-running with narrower scope.

### SIW Workflow Not Active
- Skip issue creation (Step 8).
- Report file goes to project root instead of `siw/`.
- All other steps work the same.
