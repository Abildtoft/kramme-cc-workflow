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

Implementation stays separate and should happen later via `/kramme:siw:implement-issue`.

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
[Extract actionable findings: DISC-* and MISS-*]
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

1. If `$ARGUMENTS` includes a markdown path, use that path.
2. Otherwise, prefer `siw/AUDIT_REPORT.md`.
3. Fallback to `AUDIT_REPORT.md` at project root.
4. If no report exists, stop and instruct the user to run `/kramme:siw:audit-implementation` first.

## Step 2: Parse Findings

Extract actionable findings from headings:
- `### DISC-NNN: ...`
- `### MISS-NNN: ...`

For each finding, collect:
- Finding id and title
- Requirement/source references
- Evidence/code references
- Severity/category section
- Existing issue note if present

Ignore:
- Fully implemented section
- Summary totals
- Non-actionable uncertain rows unless explicitly requested

## Step 3: Select Scope

If `$ARGUMENTS` includes finding ids (example: `DISC-002 MISS-001`), process only those.
Otherwise, process all actionable findings in this order:
1. Critical discrepancies
2. Major discrepancies
3. Missing implementations
4. Minor discrepancies

## Step 4: One-Finding Triage Loop

For each finding, present:

### 4.1 Executive Summary

- What the spec requires
- What the code currently does (or lacks)
- Why this matters (risk/impact)
- Concrete evidence with file references when available

### 4.2 Alternatives

Provide 2-3 concrete options. Include at least:
- **Option A (Minimal fix):** Smallest change to satisfy requirement
- **Option B (Robust fix):** Better long-term alignment with clearer contracts
- **Option C (Defer/spec adjustment):** Only when truly justified

For each option include:
- Scope
- Pros
- Cons
- Risk

### 4.3 Preferred Option

State a clear recommendation and justify it with:
- Correctness against spec
- Maintenance cost
- Delivery risk
- Expected follow-up effort

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
3. Use this template:

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
