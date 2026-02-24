---
name: kramme:siw:resolve-audit
description: Resolve audit findings one-by-one with executive summaries, alternatives, recommendation, and SIW issue creation
argument-hint: "[audit-report-path] [finding-id(s)]"
disable-model-invocation: true
user-invocable: true
---

# Resolve Audit Findings

Turn an audit report into decision-ready SIW issues by walking findings one at a time with clear options and a recommended path.

## Workflow Boundaries

**This command triages audit findings and creates planning issues.**

- **DOES**: Read audit report, summarize each finding, propose alternatives, recommend an option, capture user preference, create SIW issue(s)
- **DOES NOT**: Implement code changes

Implementation stays separate and should happen later via `/kramme:siw:issue-implement`.

## Required Review Style

For every finding processed, follow this exact structure:

1. Detailed executive summary (with code references when available)
2. Alternative options
3. Well-argued preferred option
4. User choice
5. SIW issue creation for the chosen option

Then continue to the next finding.

## Process Overview

```
/kramme:siw:resolve-audit [audit-report-path] [finding-id(s)]
    ↓
[Locate and read audit report]
    ↓
[Extract actionable findings: DIV-*, EXT-*, SPEC-* (plus legacy DISC-*/MISS-*)]
    ↓
[Optionally filter to user-selected finding IDs]
    ↓
[Process one finding at a time]
    ↓
[Create SIW issue for chosen option]
    ↓
[Repeat until all selected findings are handled]
    ↓
[Report summary + next implement issue]
```

## Step 1: Locate Report

1. If `$ARGUMENTS` includes a markdown path, use that path and skip auto-detection.
2. Otherwise, discover available report files in this order:
   - `siw/AUDIT_IMPLEMENTATION_REPORT.md`
   - `siw/AUDIT_SPEC_REPORT.md`
   - `AUDIT_IMPLEMENTATION_REPORT.md` (project root)
   - `AUDIT_SPEC_REPORT.md` (project root)
3. If **both implementation and spec reports exist** (any location), ask which type to resolve before continuing:

```yaml
header: "Choose Audit Type"
question: "Both implementation and spec audit reports were found. Which findings should I resolve?"
options:
  - label: "Implementation audit (Recommended)"
    description: "Resolve DIV-*/EXT-* findings from AUDIT_IMPLEMENTATION_REPORT.md (also supports legacy DISC-*/MISS-*)"
  - label: "Spec quality audit"
    description: "Resolve SPEC-* findings from AUDIT_SPEC_REPORT.md"
  - label: "Both"
    description: "Resolve findings from both reports in one run"
```

4. If only one report type exists, use it automatically.
5. If no report exists, stop and instruct the user to run `/kramme:siw:implementation-audit` or `/kramme:siw:spec-audit` first.

## Step 2: Parse Findings

Extract actionable findings from headings:
- `### DIV-NNN: ...`
- `### EXT-NNN: ...`
- `### DISC-NNN: ...` (legacy)
- `### MISS-NNN: ...` (legacy)
- `### SPEC-NNN: ...`

For each finding, collect:
- Finding id and title
- Requirement/source references
- Evidence/code references
- Severity/category section
- Existing issue note if present
- Source report path (`AUDIT_IMPLEMENTATION_REPORT.md` or `AUDIT_SPEC_REPORT.md`)

Ignore:
- Fully implemented section
- Summary totals
- Non-actionable uncertain rows unless explicitly requested

## Step 3: Select Scope

If `$ARGUMENTS` includes finding ids (example: `DIV-002 EXT-001 SPEC-003`), process only those.
Otherwise, process all actionable findings in severity order:
1. Critical findings (DIV-*, EXT-*, DISC-*, MISS-*, SPEC-*)
2. Major findings
3. Minor findings

## Step 4: One-Finding Triage Loop

Detect the finding type from its ID prefix and use the matching triage style below.

---

### For DIV-*/EXT-* findings (implementation audit)

Legacy `DISC-*` and `MISS-*` findings use this same flow.

#### 4.1 Executive Summary

- What the spec requires
- What the code currently does (or lacks)
- Why this matters (risk/impact)
- Concrete evidence with file references when available

#### 4.2 Alternatives

Provide 2-3 concrete options. Include at least:
- **Option A (Minimal fix):** Smallest change to satisfy requirement
- **Option B (Robust fix):** Better long-term alignment with clearer contracts
- **Option C (Defer/spec adjustment):** Only when truly justified

For each option include:
- Scope
- Pros
- Cons
- Risk

#### 4.3 Preferred Option

State a clear recommendation and justify it with:
- Correctness against spec
- Maintenance cost
- Delivery risk
- Expected follow-up effort

---

### For SPEC-* findings (spec quality audit)

#### 4.1 Executive Summary

- What the spec currently says (or fails to say), with quotes
- Which quality dimension is affected (coherence, completeness, clarity, etc.)
- Why this matters — what goes wrong during implementation if unfixed
- Which spec section(s) need revision

#### 4.2 Alternatives

Provide 2-3 concrete options for revising the spec. Include at least:
- **Option A (Targeted addition):** Add the minimum missing detail, constraint, or section
- **Option B (Section rework):** Restructure or rewrite the affected section for clarity and completeness
- **Option C (Accept as-is / defer):** Only when the gap is low-risk or the spec will be revised later anyway

For each option include:
- What changes in the spec
- Pros
- Cons
- Risk to implementation if chosen

#### 4.3 Preferred Option

State a clear recommendation and justify it with:
- Clarity for implementors
- Reduction in ambiguity or rework risk
- Effort to revise vs. cost of leaving the gap

### 4.4 Capture User Choice

Use AskUserQuestion to choose an option before creating an issue:

```yaml
header: "Choose Resolution"
question: "{finding_id}: Which option should become the SIW issue?"
options:
  - label: "Option B (Recommended)"
    description: "{one-line why}"
  - label: "Option A"
    description: "{one-line tradeoff}"
  - label: "Option C"
    description: "{one-line tradeoff}"
```

If user asks to modify options, refine and re-ask before creating the issue.

## Step 5: Create SIW Issue For Chosen Option

Prerequisites:
- `siw/OPEN_ISSUES_OVERVIEW.md` exists
- `siw/issues/` exists (create if missing)
- `siw/LOG.md` exists (create minimal file if missing)

Issue creation:
1. Determine next `G-` issue number from `siw/issues/ISSUE-G-*.md`.
2. Create file:
   - `siw/issues/ISSUE-G-{NNN}-resolve-{finding-id}-{slug}.md`
3. Use the matching template based on finding type:

### Template for DIV-*/EXT-* findings

```markdown
# ISSUE-G-{NNN}: Resolve {finding_id} - {short title}

**Status:** Ready | **Priority:** {High/Medium/Low} | **Phase:** General | **Related:** Audit Report

## Problem

{Executive summary of the finding}

**Audit Finding:** `{finding_id}`
**Source:** `{report_path}`

## Context

{Spec requirement and current behavior gap}

### Evidence
- `{file:path:line}` — {what it shows}

## Scope

### In Scope
- Implement chosen option: {selected option name}

### Out of Scope
- Implementing non-selected alternatives

## Acceptance Criteria

- [ ] Requirement is satisfied according to spec
- [ ] Evidence paths in audit finding are updated/validated
- [ ] Follow-up audit no longer reports `{finding_id}`

---

## Technical Notes

### Selected Option
{chosen option details}

### Alternatives Considered
- Option A: {short summary}
- Option B: {short summary}
- Option C: {short summary if applicable}

### References
- Audit report: `{report_path}` > `{finding_id}`
```

### Template for SPEC-* findings

```markdown
# ISSUE-G-{NNN}: Spec: {finding_id} - {short title}

**Status:** Ready | **Priority:** {High/Medium/Low} | **Phase:** General | **Related:** Spec Audit Report

## Problem

{Executive summary — what the spec says or fails to say, and why it matters}

**Audit Finding:** `{finding_id}`
**Dimension:** {coherence/completeness/clarity/scope/actionability/testability/value/technical design}
**Source:** `{report_path}`

## Context

{Quotes from the spec showing the issue}
{Which section(s) need revision}

## Scope

### In Scope
- Revise spec per chosen option: {selected option name}

### Out of Scope
- Code implementation changes
- Revising unrelated spec sections

## Acceptance Criteria

- [ ] Spec section addresses the finding
- [ ] {Specific criterion from the chosen option}
- [ ] Follow-up spec audit no longer reports `{finding_id}`

---

## Technical Notes

### Selected Option
{chosen option details — what to add, rewrite, or restructure}

### Alternatives Considered
- Option A: {short summary}
- Option B: {short summary}
- Option C: {short summary if applicable}

### References
- Spec audit report: `{report_path}` > `{finding_id}`
- Spec section: `{spec_file}` > {section heading}
```

4. Add row to `siw/OPEN_ISSUES_OVERVIEW.md` with status `READY`.
5. Append to `siw/LOG.md` under current progress with:
   - finding id
   - selected option
   - created issue id

## Step 6: Continue Until Done

After each created issue:
- Confirm completion of that finding
- Move to next finding in queue
- Stop only when all selected findings are handled or user asks to stop

## Step 7: Final Summary

At the end, report:
- Findings processed count
- Issues created (`G-xxx` list)
- Findings intentionally deferred
- Recommended first implementation issue to start with

Then stop and wait for user instruction.
