---
name: kramme:siw:implementation-audit
description: Exhaustively audit codebase implementation against specification. Detects spec divergences, undocumented implementation extensions, contract violations, and spec drift.
argument-hint: "[spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]"
disable-model-invocation: true
user-invocable: true
---

# Audit Implementation Against Specification
Exhaustively compare the codebase implementation against specification documents.

## Primary Objective (Mandatory)

Every audit must detect and report both:

1. **Divergences**: the implementation conflicts with, bypasses, or omits spec requirements.
2. **Extensions**: the implementation introduces behavior, access, data exposure, or flows beyond what the spec defines.

A report is not complete unless it includes:
- Spec divergences
- Implementation extensions beyond spec
- Section coverage proof
- Conflict reconciliation when findings disagree

**IMPORTANT:** This workflow is adversarial and exhaustive. Do not return early. Do not conclude anything is implemented without reading code. Grep hits are not implementation evidence.

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
[Step 3: Plan Coverage + Exploration] -> Build section matrix and code search plan
    |
    v
[Step 4: Pass A (Spec Conformance)] -> Requirement-by-requirement verification
    |
    v
[Step 5: Pass B (Boundary/Extension Discovery)] -> Adversarial extension scan
    |
    v
[Step 6: Reconcile Conflicts + Enforce Gates] -> Tie-break + evidence + coverage gates
    |
    v
[Step 7: Compile Mandatory Report Schema] -> Structured markdown contract
    |
    v
[Step 8: Write Report File] -> siw/AUDIT_IMPLEMENTATION_REPORT.md (only if gates pass)
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

5. **Use all found spec files by default.** Only ask the user to select if there are files that look unrelated to each other (for example, specs for entirely different features). Do NOT ask when the files are clearly parts of the same specification (main spec + supporting specs).

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

- **id**: Sequential ID (for example, `REQ-001`)
- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **spec_citation**: Exact clause/sentence/bullet being checked
- **description**: What the spec describes
- **key_terms**: Named identifiers to search for in code
- **strict_markers**: Any of `MUST`, `ONLY`, `NEVER` (or synonyms)

### 2.3 Mark Strict Requirements for Negative/Permissiveness Checks

For each requirement, detect strict operators:
- `MUST`/`REQUIRED`/`SHALL` -> `MUST`
- `ONLY`/`EXCLUSIVELY` -> `ONLY`
- `NEVER`/`MUST NOT`/`FORBIDDEN` -> `NEVER`

Any requirement with at least one strict marker requires explicit negative/permissiveness testing in Pass A.

### 2.4 Respect Scope Boundaries

When parsing specs:
- **Skip "Out of Scope" sections** — do not flag out-of-scope items as missing.
- **Skip "Future Work" or "Deferred" sections** — unless spec marks them as partially implemented.
- **Respect phase boundaries** — if spec has phases, only audit requirements for completed phases (check `siw/OPEN_ISSUES_OVERVIEW.md` for phase status if available).

### 2.5 Present Extraction Summary

```
Spec Analysis Complete

Sources:
  - {spec_file_1}
  - {spec_file_2}

Requirements Extracted: {total}
Spec Sections: {section_count}
Strict requirements (MUST/ONLY/NEVER): {strict_total}
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

## Step 3: Plan Coverage + Codebase Exploration

Group requirements by **spec file or major spec section** (not by abstract domain). Each group will be assigned to an Explore agent that receives the full context of that spec section.

### 3.1 Determine Grouping

- If there are **1-2 spec files**: One Explore agent per spec file.
- If there are **3+ spec files**: Group related files (for example, main spec + supporting specs) and assign one agent per group. Aim for 2-4 agents total.
- If a single spec file has **clearly distinct major sections** (for example, "Data Model", "API Endpoints", "Authentication"): Split into one agent per major section.

### 3.2 For Each Group, Identify Code Areas

For each group of requirements, identify:
- Which directories/files likely implement these requirements
- Key file patterns to search (for example, `**/*controller*`, `**/*model*`)
- Named identifiers that should appear in code

This information will be passed to Explore agents to direct their search.

### 3.3 Build the Coverage Matrix Skeleton (Mandatory)

Create a section-level matrix row for every spec section that contributed requirements:

| Section ID | Source | Requirement Count | Strict (M/O/N) | Pass A Checked | Pass B Checked | Divergences | Extensions | Alignments | Evidence Refs | Status |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|

Initialize `Status = PENDING`.

Coverage is complete only when each row has:
- Non-empty counts for Pass A and Pass B checks
- Divergence/Extension/Alignment totals
- Evidence references backing row totals

---

## Step 4: Pass A (Spec Conformance)

**CRITICAL:** A grep hit is not evidence. Read and reason about actual behavior.

### 4.1 Launch Explore Agents

For each group from Step 3, launch an Explore agent using the Task tool (`subagent_type=Explore`, `model={agent_model}`).

**Default model:** `opus`. Override with `--model sonnet` or `--model haiku` for faster/cheaper runs.

**All agents run in parallel** — launch them in a single message with multiple Task tool calls.

### 4.2 Explore Agent Prompt

Read the Pass A agent prompt template from `resources/prompts/pass-a-conformance.md`. Each agent receives that prompt structure, populated with its assigned spec section and requirements checklist.

### 4.3 Pass A Output Requirements

Agents must return:
- Full per-requirement results
- List of searched paths for any `MISSING` requirement
- Section-level pass counts to update the coverage matrix

---

## Step 5: Pass B (Boundary/Extension Discovery)

Pass B is mandatory even if Pass A appears mostly compliant.

### 5.1 Launch Adversarial Explore Agents

Launch Explore agents in parallel to hunt for undocumented implementation behavior beyond spec boundaries.

### 5.2 Pass B Prompt

Read the Pass B agent prompt template from `resources/prompts/pass-b-extension.md`. Each agent receives that prompt structure, populated with its assigned spec context.

### 5.3 Suspiciously-Clean Guardrail (Mandatory)

Treat low-findings outcomes on large specs as suspicious:

- Large spec if `requirements >= 30` **or** `sections >= 6`.
- Findings unusually low if `divergences + extensions < max(3, ceil(requirements * 0.05))`.

If suspiciously clean, **auto-run Pass B2** before finalizing:
- Use a different grouping strategy than Pass B.
- Explicitly target strict requirements (`MUST`/`ONLY`/`NEVER`), role checks, config flags, and data-access boundaries.
- Record Pass B2 execution and findings in the final report.

If Pass B2 cannot run, mark the audit **BLOCKED** and do not produce a final report.

---

## Step 6: Reconcile Conflicts + Enforce Quality Gates

### 6.1 Collect and Normalize Results

Aggregate Pass A and Pass B/B2 findings by requirement and section.

### 6.2 Mandatory Conflict Detection

A conflict exists when:
- Two agents disagree on status for the same requirement.
- A requirement is marked aligned while another finding shows bypass/permissiveness mismatch.
- Evidence points to contradictory runtime behavior.

### 6.3 Mandatory Conflict Resolution Tie-Break

For each conflict:
1. Re-open cited files and verify the exact code path with line-level evidence.
2. If still unclear, run a targeted tie-break Explore agent on the conflicting requirement/path.
3. Choose a canonical result and record why.

If any conflict remains unresolved, audit is **BLOCKED** and no final report may be produced.

### 6.4 Evidence Standard (Hard Gate)

Every Divergence, Extension, and Verified Alignment must include:
- **Spec citation**: source file + section + clause
- **Code citation**: file path with line number(s)
- **Runtime behavior statement**: concrete input/state -> observed behavior -> conclusion

Findings missing any of the above are invalid until evidence is completed.

### 6.5 Existing-Issue Hygiene Rule

Existing SIW issues may be used **only as cross-reference** after direct code evidence is established.

Never use existing issues as primary evidence. Never let an existing issue suppress a finding.

### 6.6 Coverage Matrix Completion Gate (Hard Gate)

Complete the section matrix for every audited section with:
- Requirement counts
- Pass A and Pass B checked counts
- Divergence/Extension/Alignment totals
- Evidence references for row totals

If the matrix is incomplete, audit is **BLOCKED** and no final report may be produced.

---

## Step 7: Compile Mandatory Report Schema

Generate the report using the schema from `resources/templates/report-schema.md`. All sections in the schema are mandatory. If a section has zero entries, include the section with `None`.

---

## Step 8: Write Report File

### 8.1 Determine File Location

- If `siw/` directory exists: `siw/AUDIT_IMPLEMENTATION_REPORT.md`
- If no `siw/` directory: `AUDIT_IMPLEMENTATION_REPORT.md` in project root

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

### 8.3 Final Gate Before Write (Mandatory)

Do **not** write a final report unless all are true:
- Coverage matrix is complete
- All conflicts are resolved
- Every reported Divergence/Extension/Alignment has the evidence triplet

If any gate fails:

```
Audit Blocked
=============

Reason(s):
- {missing coverage rows}
- {unresolved conflicts}
- {findings missing evidence}

No final report was written.
```

### 8.4 Write the Report

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
- Actionable findings were found (`Divergences + Extensions > 0`)

### 9.1 Ask User

Use the prompt template from `resources/templates/create-issues-prompt.yaml`.

### 9.2 Preflight SIW Paths

Before creating any issues:

1. Ensure `siw/issues/` exists.
   - If missing, create it.
   - If creation fails, warn and skip Step 9 (report-only mode).
2. Ensure `siw/LOG.md` exists.
   - If missing, create it with a minimal "Current Progress" section so updates can be appended safely.
   - If creation fails, warn and skip Step 9 (report-only mode).

### 9.3 Create Issue Files

For each selected finding:

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-fix-{slugified-title}.md` using the template in `resources/templates/siw-issue-template.md`.

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
4. Update `siw/LOG.md` Current Progress section using `resources/templates/log-last-completed.md`.

---

## Step 10: Report Summary

Use the summary template from `resources/templates/audit-complete-summary.md`.

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
- If Pass B2 is required but fails to run: mark audit BLOCKED and do not write report.

### Conflicting Findings
- If contradictions remain after tie-break: mark audit BLOCKED and do not write report.

### Incomplete Coverage Matrix
- If any section row is incomplete: mark audit BLOCKED and do not write report.

### SIW Workflow Not Active
- Skip issue creation (Step 9).
- Report file goes to project root instead of `siw/`.
- All other steps work the same.
