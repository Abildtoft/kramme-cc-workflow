---
name: kramme:siw:audit-spec
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
/kramme:siw:audit-spec [spec-file-path(s) | 'siw'] [--model opus|sonnet|haiku]
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
   - Exclude: `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_IMPLEMENTATION_REPORT.md`, `AUDIT_SPEC_REPORT.md`

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
  /kramme:siw:audit-spec path/to/spec.md
  /kramme:siw:audit-spec docs/spec1.md docs/spec2.md

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

Include the relevant blocks below in each agent's prompt based on its assigned dimensions.

---

#### Dimension: Coherence

Check for:

1. **Contradictions between sections.** Does one section say X while another says not-X? Check naming, behaviors, data types, constraints.

2. **Terminology consistency.** Does the spec use the same term for the same concept throughout? Does it switch between names for the same entity?

3. **Cross-reference accuracy.** Do internal references (to other sections, tasks, specs) point to things that actually exist? Are task numbers consistent?

4. **Design decision alignment.** Do design decisions in one section conflict with requirements in another?

5. **Scope consistency.** Does the in-scope section align with what the tasks actually cover? Are out-of-scope items accidentally included in tasks?

**Severity guide:**
- Critical: Direct contradiction between requirements
- Major: Terminology inconsistency that could cause confusion during implementation
- Minor: Cosmetic inconsistencies (formatting, numbering)

---

#### Dimension: Completeness

Check for:

1. **Missing sections.** A well-structured spec should have: overview/objectives, scope and audience, success criteria, requirements and constraints, design decisions, implementation tasks, testing/verification checklist, edge cases, and out-of-scope declarations. Which are absent or empty?

2. **Incomplete requirements.** Are there requirements that mention a concept but don't define it? Vague references to "appropriate handling" or "as needed"?

3. **Missing edge cases.** For each requirement, are error scenarios and boundary conditions addressed? What happens on failure?

4. **Missing acceptance criteria.** Do tasks have verifiable completion criteria? Can someone objectively determine if a task is done?

5. **Gaps between tasks.** Are there logical gaps where one task ends and another begins? Would something fall through the cracks?

6. **Missing dependencies.** Are cross-task or external dependencies identified?

7. **Missing non-functional requirements.** Performance, security, accessibility, backwards compatibility — are relevant ones addressed?

**Severity guide:**
- Critical: Missing core requirements, entire undefined subsystems
- Major: Missing edge cases for important flows, missing acceptance criteria on complex tasks
- Minor: Missing nice-to-have sections, minor gaps in coverage

---

#### Dimension: Clarity

Check for:

1. **Ambiguous requirements.** Phrases like "should handle appropriately", "user-friendly", "fast enough", "as needed" — anything that two developers could interpret differently.

2. **Missing specifics.** Requirements that describe WHAT but not HOW MUCH, WHEN, or UNDER WHAT CONDITIONS. Missing sizes, limits, timeouts, thresholds.

3. **Undefined terms.** Technical terms, acronyms, or domain concepts used without definition.

4. **Passive voice hiding responsibility.** "The data will be processed" — by whom? By what component?

5. **Weasel words.** "Etc.", "and so on", "similar to", "like", "various", "appropriate" — these hide missing detail.

6. **Implicit knowledge.** Requirements that assume knowledge not documented in the spec.

7. **Conflicting levels of detail.** Some sections highly detailed while others are hand-wavy.

**Severity guide:**
- Critical: Ambiguity that blocks implementation (can't start without guessing)
- Major: Ambiguity that risks wrong implementation
- Minor: Cosmetic confusion, minor vagueness in non-critical areas

---

#### Dimension: Scope

Check for:

1. **Missing scope boundaries.** Is there an explicit in-scope/out-of-scope section?

2. **Scope creep indicators.** Tasks or requirements that seem to go beyond the stated objectives. Features mentioned in passing that aren't in the task list.

3. **Implicit inclusions.** Things not explicitly listed as in-scope but required for the stated goals to work.

4. **Missing out-of-scope declarations.** Related features or improvements that are NOT being addressed — are they explicitly excluded?

5. **Phase boundary clarity.** If the spec has phases, are phase boundaries clear? Could a task leak from one phase to another?

6. **Task-to-objective alignment.** Do the defined tasks collectively achieve the stated objectives? Are there objectives with no corresponding tasks?

**Severity guide:**
- Critical: No scope definition at all, objectives don't match tasks
- Major: Implicit inclusions that could derail timeline, unclear phase boundaries
- Minor: Missing out-of-scope declarations for unlikely features

---

#### Dimension: Actionability

Check for:

1. **Non-actionable tasks.** Tasks that describe outcomes but not concrete steps. "Make the system fast" vs "Reduce API response time to under 200ms".

2. **Missing file/component references.** Tasks without clear indication of WHERE changes need to happen.

3. **Tasks that are too large.** Single tasks covering multiple unrelated changes that should be subdivided.

4. **Tasks that are too granular.** Micro-tasks that could be combined. Tasks with no meaningful independent value.

5. **Missing acceptance criteria per task.** Each task should have testable criteria. Can an implementor know when they're done?

6. **Self-containedness.** Can each task be understood without reading all other tasks? Does it have enough context to be picked up independently?

7. **Ordering and dependency clarity.** Is it clear which tasks must be done before others? Are blocking dependencies explicit?

**Severity guide:**
- Critical: Tasks so vague they can't be started
- Major: Missing acceptance criteria, tasks too large to estimate
- Minor: Minor dependency gaps, slightly over-granular tasks

---

#### Dimension: Testability

Check for:

1. **Unmeasurable success criteria.** Success criteria that can't be objectively verified. "System should be intuitive" vs "User can complete task X in under 3 clicks".

2. **Missing verification methods.** Requirements without any indication of how to verify them.

3. **Subjective acceptance criteria.** Criteria that require judgment calls. "Clean code", "good performance", "well-documented".

4. **Missing error/failure test cases.** Happy path covered but no mention of what failure looks like or how to test error handling.

5. **Missing data requirements for testing.** Test scenarios that need specific data states or configurations but don't define them.

6. **Unverifiable constraints.** Non-functional requirements without specific thresholds or test methods.

**Severity guide:**
- Critical: Core success criteria that can't be verified
- Major: Important requirements with no way to test
- Minor: Nice-to-have verifications, minor subjective criteria

---

#### Dimension: Value Proposition

Check for:

1. **Missing or weak problem statement.** Is it clear what problem this solves? Is the problem validated or assumed?

2. **Missing stakeholder identification.** Who benefits from this? Who is affected?

3. **Unjustified solution approach.** Why THIS solution and not alternatives? Were alternatives considered?

4. **Missing success metrics.** How will we know this was worth doing?

5. **Over-engineering signals.** Is the solution complexity proportional to the problem? Are there simpler alternatives that would suffice?

6. **Missing context.** Why now? What changed that makes this work necessary?

**Severity guide:**
- Critical: No problem statement, solution doesn't match stated problem
- Major: No alternatives considered, no success metrics
- Minor: Weak justification, missing minor context

---

#### Dimension: Technical Design

**Note:** This dimension requires domain judgment. Mark confidence on all findings: HIGH | MEDIUM | LOW.

Check for:

1. **Data model soundness.** Are entities well-defined? Are relationships between entities clear (one-to-many, many-to-many)? Are there normalization issues? Are constraints (required fields, uniqueness, valid ranges) specified?

2. **API contract completeness.** Are request/response shapes fully defined? Are error responses specified? Are authentication/authorization requirements clear? Are HTTP methods and status codes appropriate?

3. **Architecture fit.** Are the chosen patterns appropriate for the problem? Are there known anti-patterns? Are component boundaries and responsibilities clear? Are integration points between components defined?

4. **Scalability considerations.** Will the design handle expected load? Are pagination, caching, and rate limiting addressed where needed? Are there N+1 query risks or unbounded result sets?

5. **Security surface.** Are authentication and authorization flows defined? Is sensitive data handling specified? Are input validation boundaries clear? Are there data exposure risks?

6. **Technology choice justification.** Are technology selections explained? Are there known limitations that affect the design?

**Severity guide:**
- Critical: Fundamental design flaws (circular dependencies, missing entities for core flows, no auth on sensitive endpoints)
- Major: Design gaps that will require rework (missing error contracts, unclear component boundaries, scalability blind spots)
- Minor: Suboptimal choices, missing non-critical constraints

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

Write the report to the target path using this format:

```markdown
# Spec Audit Report

**Date:** {current date}
**Spec Files Reviewed:** {list of spec files with paths}

## Summary

| Dimension | Score | Findings |
|-----------|-------|----------|
| Coherence | {Strong/Adequate/Weak/Missing} | {count} |
| Completeness | {Strong/Adequate/Weak/Missing} | {count} |
| Clarity | {Strong/Adequate/Weak/Missing} | {count} |
| Scope | {Strong/Adequate/Weak/Missing} | {count} |
| Actionability | {Strong/Adequate/Weak/Missing} | {count} |
| Testability | {Strong/Adequate/Weak/Missing} | {count} |
| Value Proposition | {Strong/Adequate/Weak/Missing} | {count} |
| Technical Design | {Strong/Adequate/Weak/Missing} | {count} |

| Severity | Count |
|----------|-------|
| Critical | {count} |
| Major | {count} |
| Minor | {count} |
| **Total** | **{total}** |

**Overall Assessment:** {Ready for implementation / Needs revision / Significant gaps}

## Critical Findings

### SPEC-001: {Brief title}

**Dimension:** {dimension}
**Severity:** Critical
**Location:** {source_file} > {source_section}
**Details:** {explanation with quotes from the spec}
**Impact:** {what goes wrong if this isn't fixed}
**Recommendation:** {specific action to fix}

---

{Repeat for each critical finding}

## Major Findings

{Same format as Critical}

## Minor Findings

{Same format, without Impact field}

## Dimension Details

### Coherence: {Score}

{2-3 sentence assessment}

**Strengths:**
- {what's consistent and well-aligned}

**Gaps:**
- {references to relevant SPEC-NNN findings}

{Repeat for each of the 8 dimensions}

## Sections Present vs. Expected

| Section | Status | Notes |
|---------|--------|-------|
| Overview/objectives | {Present/Missing/Incomplete} | {brief note} |
| Scope and audience | {Present/Missing/Incomplete} | {brief note} |
| Success criteria | {Present/Missing/Incomplete} | {brief note} |
| Requirements and constraints | {Present/Missing/Incomplete} | {brief note} |
| Design decisions | {Present/Missing/Incomplete} | {brief note} |
| Implementation tasks | {Present/Missing/Incomplete} | {brief note} |
| Testing/verification checklist | {Present/Missing/Incomplete} | {brief note} |
| Edge cases and considerations | {Present/Missing/Incomplete} | {brief note} |
| Out of scope | {Present/Missing/Incomplete} | {brief note} |
```

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
2. Create issue file `siw/issues/ISSUE-G-{NNN}-spec-{slugified-title}.md`:

```markdown
# ISSUE-G-{NNN}: Spec: {finding title}

**Status:** Ready | **Priority:** {Critical→High, Major→Medium, Minor→Low} | **Phase:** General | **Related:** Spec Audit Report

## Problem

Spec audit found a {dimension} issue in the specification.

**Spec finding (SPEC-{id}):** {finding title}
**Source:** {source_file} > {source_section}

## Context

{Details from the finding — what's wrong with the spec}
{Impact if not addressed}

## Scope

### In Scope
- {Specific spec revision needed}

### Out of Scope
- Code implementation changes
- Refactoring unrelated spec sections

## Acceptance Criteria

- [ ] Spec section addresses the finding
- [ ] {Specific criterion based on the recommendation}
- [ ] Follow-up spec audit no longer reports SPEC-{id}

---

## Technical Notes

### Recommendation
{Recommendation from the finding}

### References
- Spec: `{spec_file}` > {section}
- Audit Report: `{report_path}` > SPEC-{id}
```

3. Update `siw/OPEN_ISSUES_OVERVIEW.md` with new issue rows.

4. Update `siw/LOG.md` Current Progress section:

```markdown
### Last Completed
- Spec quality audit: {N} findings, {M} issues created
```

---

## Step 7: Report Summary

```
Spec Audit Complete
===================

Spec Files: {list}

Quality Scores:
  Coherence:         {Strong/Adequate/Weak/Missing}
  Completeness:      {Strong/Adequate/Weak/Missing}
  Clarity:           {Strong/Adequate/Weak/Missing}
  Scope:             {Strong/Adequate/Weak/Missing}
  Actionability:     {Strong/Adequate/Weak/Missing}
  Testability:       {Strong/Adequate/Weak/Missing}
  Value Proposition: {Strong/Adequate/Weak/Missing}
  Technical Design:  {Strong/Adequate/Weak/Missing}

Findings:
  Critical: {N}
  Major:    {N}
  Minor:    {N}
  Total:    {N}

Overall: {Ready for implementation / Needs revision / Significant gaps}

Report: {report_path}

{If issues created:}
Issues Created: {N} (G-{start} through G-{end})
See siw/OPEN_ISSUES_OVERVIEW.md for the full list.

Next Steps:
  - Fix critical findings in the spec before starting implementation
  - Address major findings to reduce implementation risk
  - Resolve findings with executive summaries and issue creation: /kramme:siw:resolve-audit {report_path}
  - Re-run after spec revisions to verify quality: /kramme:siw:audit-spec
  - When spec is ready, begin implementation: /kramme:siw:generate-phases or /kramme:siw:implement-issue
  - Clean up report when done: /kramme:clean-up-artifacts
```

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
