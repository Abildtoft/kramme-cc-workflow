---
name: kramme:siw:audit-implementation
description: Exhaustively audit codebase implementation against specification. Finds naming misalignments, missing implementations, contract violations, and spec drift.
argument-hint: "[spec-file-path(s) | 'siw' to auto-detect]"
disable-model-invocation: true
user-invocable: true
---

# Audit Implementation Against Specification

Exhaustively compare the codebase implementation against specification documents to find discrepancies, missing implementations, naming misalignments, and spec drift.

**IMPORTANT:** This command emphasizes thoroughness. Do not return early. Check every requirement in the specification against the codebase before compiling results.

## Process Overview

```
/kramme:siw:audit-implementation [spec-file-path(s) | 'siw']
    |
    v
[Step 1: Resolve Spec Files] -> Parse args or auto-detect from siw/
    |
    v
[Step 2: Read and Parse Specs] -> Extract every requirement
    |
    v
[Step 3: Categorize into Review Domains] -> Group by domain
    |
    v
[Step 4: Configure Review Scope] -> Ask user about depth
    |
    v
[Step 5: Systematic Codebase Search] -> Explore agents per domain
    |
    v
[Step 6: Analyze Findings] -> Classify discrepancies
    |
    v
[Step 7: Compile Discrepancy Report] -> Structured markdown
    |
    v
[Step 8: Write Report File] -> siw/AUDIT_REPORT.md
    |
    v
[Step 9: Optionally Create SIW Issues] -> Convert findings to issues
    |
    v
[Step 10: Report Summary] -> Stats and next steps
```

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s) or keyword provided by the user.

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
   - Exclude: `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_REPORT.md`

3. Find supporting specs:
   - Use Glob to find `siw/supporting-specs/*.md`

4. Check for linked external specs:
   - Read **every detected spec file** (both `siw/*.md` and `siw/supporting-specs/*.md` candidates).
   - Look for a "Linked Specifications" section with a table containing file paths.
   - Add any linked external paths to the candidate file list (verify each exists).

5. If multiple spec files found, present them to the user:

   ```yaml
   header: "Specification Files"
   question: "Found these spec files. Which should I audit against?"
   multiSelect: true
   options:
     - label: "All files"
       description: "Audit against all found specifications"
     - label: "{file1}"
       description: "{first heading from file1}"
     - label: "{file2}"
       description: "{first heading from file2}"
   ```

6. Store selected files as `spec_files`.

### 1.4 If No Spec Files Found

```
Error: No specification files found.

Expected locations:
  - siw/*.md (SIW spec files)
  - siw/supporting-specs/*.md (supporting specifications)

Or provide file path(s) directly:
  /kramme:siw:audit-implementation path/to/spec.md
  /kramme:siw:audit-implementation docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.

---

## Step 2: Read and Parse Specs

Read every file in `spec_files` and extract structured requirements.

### 2.1 Extraction Categories

For each spec file, extract requirements across these categories:

| Category | What to Look For |
|---|---|
| **Named entities** | Class names, component names, service names, table/collection names |
| **API contracts** | Endpoint URLs, HTTP methods, request/response schemas, status codes |
| **Data model** | Entity names, field names, types, nullability, constraints, relationships |
| **Behavior requirements** | "MUST", "SHOULD", "SHALL", acceptance criteria, "when X then Y" patterns |
| **Naming conventions** | Specific names for files, variables, classes, routes, database columns |
| **UI/UX requirements** | Component names, user flows, states (loading, error, empty), labels |
| **Integration points** | External services, events, hooks, middleware, pipelines |
| **Validation rules** | Input validation, business rules, constraints (max length, format, ranges) |
| **Error handling** | Error scenarios, fallback behavior, error messages |
| **Configuration** | Feature flags, environment variables, settings |

### 2.2 Requirement Structure

For each extracted requirement, capture:

- **id**: Auto-generated sequential ID (e.g., `REQ-001`, `REQ-002`)
- **source_file**: Which spec file it came from
- **source_section**: Heading hierarchy (e.g., "API Specification > User Endpoints > POST /users")
- **category**: One of the extraction categories above
- **description**: The requirement text
- **key_terms**: Named identifiers to search for in code (class names, route paths, field names, etc.)

### 2.3 Respect Scope Boundaries

When parsing specs:
- **Skip "Out of Scope" sections** — do not flag out-of-scope items as missing.
- **Skip "Future Work" or "Deferred" sections** — unless spec marks them as partially implemented.
- **Respect phase boundaries** — if spec has phases, only audit requirements for completed phases (check `siw/OPEN_ISSUES_OVERVIEW.md` for phase status if available).

### 2.4 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - siw/FEATURE_SPECIFICATION.md
  - siw/supporting-specs/01-data-model.md
  - siw/supporting-specs/02-api-specification.md

Requirements Extracted: 47
  - API contracts: 12
  - Data model: 8
  - Behavior requirements: 15
  - Naming conventions: 5
  - Validation rules: 7

Key search terms identified: 23 unique names/identifiers
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

## Step 3: Categorize into Review Domains

Group requirements into review domains. Each domain will be assigned to a separate Explore agent.

| Domain | Requirements Included | Search Strategy |
|---|---|---|
| **Data Model** | Entity/field names, types, relationships, constraints | Grep for entity names, field names; Glob for model/entity files |
| **API Surface** | Endpoints, methods, request/response shapes, status codes | Grep for route definitions, controller methods, DTOs |
| **Business Logic** | Behavior rules, validation, error handling, workflows | Grep for function/method names, conditional patterns |
| **Naming & Structure** | File names, class names, variable names, route paths | Glob for expected file patterns, Grep for class/interface declarations |
| **UI/Frontend** | Components, labels, states, user flows | Glob for component files, Grep for component names and text content |
| **Configuration** | Feature flags, environment variables, settings | Grep for config keys, Glob for config files |

**Skip domains with zero requirements.**

---

## Step 4: Configure Review Scope

Use AskUserQuestion:

```yaml
header: "Review Scope"
question: "How thorough should this audit be?"
options:
  - label: "Full exhaustive audit"
    description: "Check every requirement against the codebase (recommended)"
  - label: "Critical domains only"
    description: "Audit API contracts, data model, and business logic only"
  - label: "Quick scan"
    description: "Check for completely missing implementations only"
```

**If "Critical domains only":** Filter to Data Model, API Surface, and Business Logic domains.

**If "Quick scan":** Only check requirements where key_terms produce zero search results.

### 4.1 Optional: Scope to Specific Code Paths

Use AskUserQuestion:

```yaml
header: "Code Scope"
question: "Should I search the entire codebase or focus on specific directories?"
options:
  - label: "Entire codebase"
    description: "Search all project files"
  - label: "Specific directories"
    description: "I'll specify which directories to search"
```

If "Specific directories": Use AskUserQuestion with freeform to get directory paths. Store as `search_scope`.

---

## Step 5: Systematic Codebase Search

**CRITICAL:** This is the core of the audit. Be exhaustive. Do not skip requirements. Do not assume implementation without finding concrete evidence.

### 5.1 Launch Explore Agents

For each active review domain, launch an Explore agent using the Task tool (`subagent_type=Explore`).

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 5.2 Explore Agent Prompt Template

Each agent receives:

```
Audit the codebase against these specification requirements for the [{domain}] domain.

For EACH requirement below, search the codebase thoroughly:
1. Use Grep to find occurrences of key terms
2. Use Glob to find files matching expected patterns
3. Read relevant files to verify implementation details match the spec
4. Note any discrepancy in naming, behavior, structure, or completeness

{If search_scope: "Search scope: {directories}"}
{If no search_scope: "Search scope: entire codebase"}

Requirements to verify:

{For each requirement in this domain:}
---
REQ-{id}: {description}
Source: {source_file} > {source_section}
Key terms to search: {key_terms}
---

For each requirement, report ALL of the following:
- **REQ ID**: The requirement identifier
- **Status**: One of: IMPLEMENTED | PARTIAL | MISSING | NAMING_MISMATCH | BEHAVIOR_MISMATCH
- **Evidence**: File paths and line numbers where implementation was found (or where it was expected but not found)
- **Discrepancy details**: If not IMPLEMENTED, describe exactly what differs between spec and code
- **Confidence**: HIGH | MEDIUM | LOW

IMPORTANT:
- Report on EVERY requirement. Do not skip any.
- For MISSING status, describe what you searched for and where you looked.
- For PARTIAL status, describe what IS implemented and what is NOT.
- Do not assume something is implemented without finding concrete evidence in code.
```

---

## Step 6: Analyze Findings

After all Explore agents complete:

### 6.1 Collect Results

Gather all per-requirement assessments from every agent.

### 6.2 Classify Findings

| Classification | Criteria |
|---|---|
| **Fully Implemented** | Status = IMPLEMENTED, Confidence = HIGH |
| **Discrepancy Found** | Status = PARTIAL, NAMING_MISMATCH, or BEHAVIOR_MISMATCH |
| **Missing** | Status = MISSING |
| **Uncertain** | Confidence = LOW (needs manual verification) |

### 6.3 Assign Severity

For each discrepancy or missing item:

- **Critical**: Missing core functionality, broken contracts, missing entire endpoints/entities
- **Major**: Behavior differs from spec, wrong types, incorrect validation rules
- **Minor**: Naming mismatch, cosmetic differences, documentation gaps

### 6.4 Cross-reference Existing Issues

**Only if SIW workflow is active:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any found discrepancies already have open issues. Mark these findings with a note: "Existing issue: {issue-id}".

---

## Step 7: Compile Discrepancy Report

Generate a structured markdown report:

```markdown
# Audit Report: Implementation vs. Specification

**Date:** {current date}
**Spec Files Reviewed:** {list of spec files with paths}
**Review Scope:** {Full exhaustive / Critical domains / Quick scan}
**Code Scope:** {Entire codebase / specific directories}

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

## Step 8: Write Report File

### 8.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_REPORT.md`
- If no `siw/` directory: `AUDIT_REPORT.md` in project root

### 8.2 Handle Existing Report

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

### 8.3 Write the Report

Write the compiled report to the target path.

```
Audit report written to: {path}
```

---

## Step 9: Optionally Create SIW Issues

**Only if ALL of these conditions are met:**
- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Discrepancies or missing implementations were found (Critical + Major + Missing > 0)

### 9.1 Ask User

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

### 9.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 9 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section so updates can be appended safely.
   - If creation fails, warn and skip Step 9 (report-only mode).

### 9.3 Create Issue Files

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

## Step 10: Report Summary

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
  - Resolve findings one-by-one with executive summaries, alternatives, and issue creation: /kramme:siw:resolve-audit
  - Review the report for accuracy (especially "Uncertain" items)
  - Fix critical discrepancies first: /kramme:siw:implement-issue G-{first}
  - Re-run after fixes to verify compliance: /kramme:siw:audit-implementation
  - Clean up report when done: /kramme:clean-up-artifacts
```

**STOP HERE.** Wait for the user's next instruction.

---

## Error Handling

### Spec File Errors
- File not found: Warn and skip, continue with remaining files.
- File empty or unreadable: Warn, suggest checking file path.

### No Requirements Extracted
- If spec has no clear structure: Offer best-effort scan or abort.
- If all requirements fall into a single domain: Proceed with one agent instead of many.

### Explore Agent Failures
- If an agent returns incomplete results: Note affected requirements as "Uncertain" in the report.
- If an agent times out: Report which domain was affected, suggest re-running with narrower scope.

### SIW Workflow Not Active
- Skip issue creation (Step 9).
- Report file goes to project root instead of `siw/`.
- All other steps work the same.
