---
name: kramme:siw:product-audit
description: (experimental) Product audit of SIW specs and plans before implementation. Evaluates target user clarity, problem/solution fit, user state modeling, critical moments coverage, scope correctness, and success criteria quality. Not for code review or implementation auditing.
argument-hint: "[spec-file-path(s) | 'siw'] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Product Audit of SIW Specs

Critique specification documents from a product perspective before implementation begins. This is a spec-only analysis — no codebase code is read or compared.

**IMPORTANT:** This is a thorough product critique. Do not return early. Do not assume a section is well-designed without reading it carefully. Evaluate whether the spec will actually solve the right problem for the right users. A clean report is suspicious, not reassuring.

## Process Overview

```
/kramme:siw:product-audit [spec-file-path(s) | 'siw'] [--auto]
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

---

## Step 1: Resolve Spec Files

### 1.1 Parse Arguments

`$ARGUMENTS` contains the spec file path(s) or keyword.

**Extract control flags first:**
- If `$ARGUMENTS` contains `--auto`, set `AUTO_MODE=true` and remove the flag before processing remaining arguments.

`--auto` means:
- replace any previous product review automatically
- create SIW issues for **Critical and Major** findings when Step 7 applies
- skip the report overwrite / issue-creation prompts
- if Work Context is `Prototype` or `Refactor`, skip the product review and direct the user to `/kramme:siw:spec-audit`

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
   - Exclude: `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_IMPLEMENTATION_REPORT.md`, `AUDIT_SPEC_REPORT.md`, `PRODUCT_AUDIT.md`, `SPEC_STRENGTHENING_PLAN.md`, `issues/`

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
  /kramme:siw:product-audit path/to/spec.md
  /kramme:siw:product-audit docs/spec1.md docs/spec2.md

To initialize a workflow with a spec, run /kramme:siw:init
```

**Action:** Abort.

---

## Step 2: Read Specs Fully

### 2.1 Read Every Spec File End-to-End

Read each spec file completely. Do not skim. Understand the full picture before launching the product review.

### 2.1.5 Extract Work Context

After reading all spec files, look for a `## Work Context` section in the spec files:

1. Parse the markdown table to extract: Work Type, Priority Dimensions, Deprioritized dimensions
   - If multiple spec files define Work Context, use the main spec file (the one matching the SIW init filename). If ambiguous, use the first found and warn.
2. If not found or malformed, default to Production Feature (full product review, no adjustments)
3. Store as `work_context`

### 2.2 Extract Product Elements

For each spec file, identify and extract:

| Element | What to look for |
|---------|-----------------|
| Target User | Who is the user? Persona, role, segment, or archetype |
| Problem Statement | What problem is being solved? Current pain, unmet need |
| Proposed Solution | What is being built? Core approach, key decisions |
| User Flows | How does the user interact? Steps, entry points, transitions |
| User States | What states can the user be in? Empty, error, loading, success, edge |
| Critical Moments | First use, error recovery, data loss, permission change, upgrade |
| Scope | What is in and out? Boundaries, explicit exclusions |
| Success Criteria | How is success measured? Metrics, definitions of done |
| Phases / Milestones | How is delivery sequenced? What ships first? |

For each element, capture:
- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **content_summary**: Brief description of what the section contains

### 2.3 Present Extraction Summary

```
Product Review Scope

Sources:
  - {spec_file_1}
  - {spec_file_2}

Product elements identified: {count}
Target user defined: {yes/no}
Problem statement found: {yes/no}
User flows documented: {count}
```

### 2.5 Work Context Gate

If `work_context.work_type` is **Prototype** or **Refactor**:

If `AUTO_MODE=true`, stop here and suggest `/kramme:siw:spec-audit` instead.

Otherwise:

Use AskUserQuestion:

```yaml
header: "Work Context: {work_type}"
question: "This spec's Work Context is '{work_type}'. Product review evaluates user-facing concerns that may not apply. The spec audit (/kramme:siw:spec-audit) may be more useful."
options:
  - label: "Skip product review"
    description: "Abort — product review is not relevant for this work type"
  - label: "Proceed anyway"
    description: "Run the full product review regardless"
```

If "Skip product review": Stop and suggest `/kramme:siw:spec-audit` instead.

For all other work types, continue to Step 3.

---

## Step 3: Check for Previous Review

If `siw/PRODUCT_AUDIT.md` (or `PRODUCT_AUDIT.md` in project root) exists:

1. Read the file.
2. Parse for previously reported findings and their IDs (PROD-NNN).
3. Note which findings were marked as addressed or resolved.
4. This context is passed to the reviewer agent to avoid re-reporting resolved items.

---

## Step 4: Launch Product Reviewer Agent

### 4.1 Launch Explore Agent

Launch a single `kramme:product-reviewer` Explore agent via the Task tool (`subagent_type=Explore`, `model=opus`).

No relevance validation step is needed — the entire spec is the scope.

### 4.2 Agent Prompt

```
You are a product reviewer critiquing a specification before implementation begins. You are in spec mode. Focus on the plan's product quality. Do not look at any code. Every finding must reference a spec file and section heading.

## Spec Files

Read these files completely:
{list of spec file paths}

## Previously Addressed Findings

{list of previously resolved PROD-NNN findings, or "None — first review"}

## Work Context Adjustments

{Include this block ONLY if work_context is not Production Feature and not absent:}

This spec has Work Type: {work_context.work_type}

{If Internal Tool:}
- For "Target User Clarity": The target user is the development team. Assess whether the spec makes this clear, but do NOT flag the absence of market segmentation or persona research.
- For "Problem/Solution Fit": Internal tools are justified by team productivity needs. Do NOT flag the absence of competitive analysis or market alternatives.

{If Documentation / Process:}
- Focus primarily on "Scope Correctness" and "Success Criteria Quality".
- Cap "User State Modeling" and "Critical Moments Coverage" findings at Minor severity.

## Product Dimensions to Evaluate

### 1. Target User Clarity
- Is the target user explicitly defined (not just implied)?
- Could two team members read this spec and agree on who the user is?
- Are there multiple user types? If so, are priorities clear?
- Severity guide: Missing target user = Critical. Vague or implied = Major.

### 2. Problem/Solution Fit
- Does the spec clearly state the problem before jumping to solution?
- Would the proposed solution actually solve the stated problem?
- Are there simpler alternatives the spec doesn't consider?
- Does the solution introduce new problems for users?
- Severity guide: Solution doesn't match problem = Critical. Missing alternatives analysis = Major.

### 3. User State Modeling
- Does the spec account for: empty state, loading, error, success, partial, edge states?
- What happens on first use when there's no data?
- What happens when the user has too much data?
- What happens when an operation fails partway through?
- Severity guide: Missing error/empty states = Major. Missing edge states = Minor.

### 4. Critical Moments Coverage
- First-time experience: Is onboarding addressed?
- Error recovery: Can users recover from mistakes?
- Data loss scenarios: Are destructive actions guarded?
- Permission/access changes: What happens when access is revoked?
- Migration/upgrade: How do existing users transition?
- Severity guide: Missing error recovery = Critical. Missing onboarding = Major.

### 5. Scope Correctness
- Is the scope too large for a single deliverable?
- Is the scope too small to be useful to users?
- Are there dependencies that aren't acknowledged?
- Does the phasing make sense from a user value perspective (not just engineering convenience)?
- Severity guide: Scope that can't deliver user value = Critical. Phasing that delays value = Major.

### 6. Success Criteria Quality
- Are success criteria measurable and specific?
- Do they measure user outcomes (not just feature completion)?
- Could you actually verify these criteria after shipping?
- Are there metrics that matter but aren't tracked?
- Severity guide: No success criteria = Critical. Unmeasurable criteria = Major. Missing metrics = Minor.

## Output Format

For each finding, report:
- **Finding ID**: PROD-{NNN} (sequential)
- **Dimension**: {which dimension}
- **Title**: Brief description
- **Location**: {source_file} > {section_heading}
- **Details**: What the issue is, with quotes from the spec
- **Severity**: Critical | Major | Minor
- **Product Impact**: What goes wrong for users if this isn't addressed
- **Recommendation**: Specific action to fix

## Rules

- Report on every dimension. Even if no findings, confirm the dimension was analyzed.
- Do not return early. Check every section against every dimension.
- Quote the spec. Include relevant text when flagging an issue.
- Be specific in recommendations. "Add more detail" is not enough.
- Note strengths. Identify what the spec does well from a product perspective.
- List open questions. Product questions the spec doesn't address.
```

---

## Step 5: Classify and Deduplicate Findings

### 5.1 Collect and Classify

Gather all findings from the reviewer agent. Assign final severity using:

| Severity | Criteria |
|----------|----------|
| **Critical** | Would lead to building the wrong thing or shipping something users can't use. Missing target user, solution doesn't fit problem, no error recovery, undeliverable scope. |
| **Major** | Risks a poor user experience or significant rework. Missing states, weak success criteria, phasing that delays value, gaps in critical moments. |
| **Minor** | Low-risk product concerns. Missing edge states, suboptimal naming, cosmetic flow issues. |

### 5.2 Deduplicate

If multiple dimensions flagged the same issue, merge into one finding and note all affected dimensions.

### 5.3 Assign Final IDs

Re-number all findings as `PROD-001`, `PROD-002`, etc. in severity order (Critical first, then Major, then Minor).

### 5.4 Cross-reference Existing SIW Issues

**Only if `siw/OPEN_ISSUES_OVERVIEW.md` exists:**

Read `siw/OPEN_ISSUES_OVERVIEW.md` and `siw/issues/*.md` to check if any product findings already have open issues. Mark these findings with a note: "Existing issue: {issue-id}".

---

## Step 6: Write Report

### 6.1 Determine File Location

- If `siw/` directory exists: `siw/PRODUCT_AUDIT.md`
- If no `siw/` directory: `PRODUCT_AUDIT.md` in project root

### 6.2 Handle Existing Report

If a previous report exists at the target path:

If `AUTO_MODE=true`, choose **Replace** automatically.

Otherwise:

```yaml
header: "Existing Product Review"
question: "A previous product review exists. How should I proceed?"
options:
  - label: "Replace"
    description: "Overwrite with new review results"
  - label: "Append"
    description: "Add new review as a dated section (preserves history)"
  - label: "Abort"
    description: "Cancel — keep existing review"
```

### 6.3 Compile and Write Report

Use the report format template from `assets/product-audit-report-format.md`.

After writing:
```
Product review written to: {path}
```

---

## Step 7: Optionally Create SIW Issues

**Only if ALL of these conditions are met:**
- `siw/OPEN_ISSUES_OVERVIEW.md` exists (SIW workflow is active)
- `siw/issues/` exists or can be created
- `siw/LOG.md` exists or can be created
- Critical or Major findings were found

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

1. Determine next available `G-` issue number from `siw/issues/`.
2. Create issue file `siw/issues/ISSUE-G-{NNN}-product-{slugified-title}.md`.
3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.
4. Update `siw/LOG.md` Current Progress section.

---

## Step 8: Report Summary

Display a summary:

```
Product Review Complete

Report: {report_path}
Findings: {critical_count} Critical, {major_count} Major, {minor_count} Minor
Issues created: {count} (or "None")

Dimensions evaluated:
  - Target User Clarity: {assessed/not assessed}
  - Problem/Solution Fit: {assessed/not assessed}
  - User State Modeling: {assessed/not assessed}
  - Critical Moments Coverage: {assessed/not assessed}
  - Scope Correctness: {assessed/not assessed}
  - Success Criteria Quality: {assessed/not assessed}

Suggested next steps:
  - /kramme:siw:resolve-audit siw/PRODUCT_AUDIT.md  (address findings)
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
- If the main spec is a lightweight TOC linking to supporting specs, automatically include the supporting specs in the review. Do not review the TOC structure alone.

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
```
