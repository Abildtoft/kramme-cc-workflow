---
name: kramme:siw:breakdown-findings
description: Break down unresolved spec-audit findings into executive summaries, resolution options, and a recommendation without creating SIW issues. Use it after spec-audit or spec-audit:auto-fix when you want decision-ready analysis before choosing a follow-up path. Not for implementation audits or direct issue creation.
argument-hint: "[audit-report-path] [SPEC-id(s)]"
disable-model-invocation: true
user-invocable: true
---

# Breakdown Spec Audit Findings

Turn unresolved `SPEC-*` findings from a spec-audit report into a single inline, decision-ready breakdown.

## Workflow Boundaries

**This command is analysis-only.**

- **DOES**: Read a spec-audit report, identify unresolved `SPEC-*` findings, explain each finding, present 2-3 concrete resolution options, recommend one option, and route the user toward the next command
- **DOES NOT**: Create or edit SIW issues, update `siw/LOG.md`, update `siw/OPEN_ISSUES_OVERVIEW.md`, or write a new report file
- **DOES NOT**: Read implementation-audit or product-audit reports

Issue creation stays separate and should happen later via `/kramme:siw:resolve-audit` or `/kramme:siw:issue-define`.

## Hard Constraints

- **NEVER** create or modify files as part of this command
- **NEVER** write a breakdown artifact such as `siw/FINDINGS_BREAKDOWN.md`
- **NEVER** read `AUDIT_IMPLEMENTATION_REPORT.md` or `PRODUCT_AUDIT.md` for this command
- **NEVER** include non-`SPEC-*` findings in the breakdown
- **ALWAYS** return a single inline response covering all selected findings
- **ALWAYS** preserve report order within each severity band
- **ALWAYS** treat explicit `SPEC-*` ids as an override to the default unresolved-only filter

## Process Overview

```text
/kramme:siw:breakdown-findings [audit-report-path] [SPEC-id(s)]
    ↓
[Locate spec audit report]
    ↓
[Extract SPEC-* findings]
    ↓
[Detect auto-fixed and already-tracked findings]
    ↓
[Select findings to break down]
    ↓
[Produce one inline report with options and recommendations]
    ↓
[Ask what to do next and wait]
```

## Step 1: Locate Report

1. Parse `$ARGUMENTS` as shell-style arguments so quoted paths remain intact.
2. Treat markdown path tokens as candidate report paths.
3. Treat `SPEC-*` tokens as explicit finding filters.
4. If more than one markdown path is supplied, stop and ask the user to provide only one report path.
5. If a report path is supplied:
   - Verify the file exists.
   - Verify it ends in `.md`.
   - Verify it is a spec-audit report by checking that it contains at least one `### SPEC-` heading.
   - If the file instead looks like an implementation or product audit, stop and instruct the user to use `/kramme:siw:resolve-audit` or the corresponding audit flow instead.
6. If no report path is supplied, auto-detect in this order:
   - `siw/AUDIT_SPEC_REPORT.md`
   - `AUDIT_SPEC_REPORT.md`
7. If no spec-audit report exists, stop and instruct the user to run `/kramme:siw:spec-audit` first.

## Step 2: Extract Findings

Read the chosen spec-audit report fully enough to extract every `SPEC-*` finding and its surrounding metadata.

For each finding, collect:
- Finding id and title
- Severity section (`Critical`, `Major`, `Minor`)
- Dimension
- Location / source section
- Details
- Impact, if present
- Recommendation from the audit report
- `Severity Note`, if present
- `Existing issue` note, if present
- Whether the heading or body marks it as `[Auto-fixed]`

Ignore:
- Summary tables
- Dimension summaries
- Non-`SPEC-*` findings

## Step 3: Determine Which Findings Are Unresolved

### 3.1 Default unresolved definition

Without explicit `SPEC-*` ids, include only findings that are:
- `SPEC-*`
- not marked `[Auto-fixed]`
- not already represented by an open SIW issue

### 3.2 Open issue detection

If `siw/` exists, prefer live SIW state over stale report annotations.

Check these sources when present:
- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/issues/*.md`

Treat a finding as already tracked when an issue references the same `SPEC-*` id and the issue is still open:
- `READY`
- `IN PROGRESS`
- `IN REVIEW`

Do **not** treat `DONE` issues as open.

If live SIW state is missing or inconclusive, fall back to the report annotation:
- `Existing issue: ISSUE-G-...`

### 3.3 Explicit finding filters

If the user passed one or more `SPEC-*` ids:
- Select only those findings
- Include them even if they are auto-fixed or already tracked by an open issue
- Annotate that state clearly in the output

If any requested `SPEC-*` id is not found in the report, stop and list the missing ids.

### 3.4 Output ordering

When no explicit ids are passed, order findings like this:
1. Critical findings, plus Minor findings whose `Severity Note` says `from Critical`
2. Major findings, plus Minor findings whose `Severity Note` says `from Major`
3. Remaining Minor findings

Within each band, preserve the report order.

## Step 4: Build the Inline Breakdown

Produce one inline response only. Do not split findings across multiple messages.

### 4.1 Start with a short overview

Include:
- report path used
- number of findings selected
- number skipped as auto-fixed
- number skipped as already tracked by an open issue

If explicit `SPEC-*` ids were used, state that the normal unresolved-only filter was overridden.

If no findings remain after filtering:
- State that no unresolved `SPEC-*` findings were found
- Mention whether all findings were auto-fixed, already tracked, or absent
- Skip the per-finding breakdown
- Continue directly to Step 5 so the user still gets next-step guidance

### 4.2 Required per-finding structure

For every selected finding, use this exact section order:

1. `## {finding_id}: {title}`
2. **Executive summary**
3. **Evidence**
4. **Resolution options**
5. **Recommendation**

### 4.3 Executive summary

Cover:
- What the spec currently says or fails to say
- Which quality dimension is affected
- Which spec section(s) are impacted
- Why this matters for implementation

If the finding was explicitly requested but is already tracked or auto-fixed, add a short state note before the summary:
- `State: already tracked by open issue {issue_id}`
- `State: marked [Auto-fixed] in the audit report`

### 4.4 Evidence

Use the audit report as the evidence source.

Include:
- short quotes or paraphrases from the finding
- spec file and section references when present
- `Severity Note` when present and relevant to urgency

Do not quote more than needed. Favor concise excerpts and paraphrase the rest.

### 4.5 Resolution options

Provide 2-3 concrete options. Include at least:
- **Option A (Targeted addition)**: Add the minimum missing detail, rule, or section
- **Option B (Section rework)**: Rewrite or restructure the affected section for clarity and completeness
- **Option C (Defer / accept as-is)**: Only when it is genuinely credible

For each option include:
- What changes in the spec
- Pros
- Cons
- Risk to implementation if chosen

Keep the options materially different. Do not present cosmetic variants of the same fix.

### 4.6 Recommendation

Pick one option and justify it explicitly using:
- clarity for implementors
- ambiguity or rework reduction
- effort to revise the spec
- implementation risk if the gap remains

Be decisive. Do not end with "it depends" unless the report truly lacks enough information to recommend a path.

## Step 5: Ask What To Do Next

After the inline breakdown, ask the user what they want to do next using `AskUserQuestion` with these options:

```yaml
header: "Next Step"
question: "What should I do with these spec findings next?"
options:
  - label: "Resolve selected findings"
    description: "Move the findings into /kramme:siw:resolve-audit for issue-oriented triage"
  - label: "Create/refine issue manually"
    description: "Prepare /kramme:siw:issue-define commands instead of running the audit-resolution flow"
  - label: "Stop here"
    description: "Keep the breakdown only with no follow-up action"
```

Send the question after the full inline report. Then stop and wait for the user's answer.

## Step 6: Respond To The User's Next-Step Choice

After the user answers the Step 5 question, do **not** create issues or run another command automatically.

Instead, reply with the exact next command syntax to run.

### If the user chooses "Resolve selected findings"

- Provide one exact `/kramme:siw:resolve-audit` command using the current report path and the finding ids from the current breakdown
- If the user asked for a subset, use only that subset

Example shape:

```text
/kramme:siw:resolve-audit siw/AUDIT_SPEC_REPORT.md SPEC-001 SPEC-004
```

### If the user chooses "Create/refine issue manually"

- Provide one `/kramme:siw:issue-define` command per selected finding
- Use the finding id and title in the prompt text so the issue has enough context
- Include the report path as a supporting context argument when useful

Example shape:

```text
/kramme:siw:issue-define "Resolve SPEC-001 - Clarify retry behavior" siw/AUDIT_SPEC_REPORT.md
```

### If the user chooses "Stop here"

- Acknowledge that the breakdown is complete
- Do not propose or run further actions

## Error Handling

- Invalid path: stop and state the missing or invalid report path
- Wrong report type: stop and say this command only supports spec-audit reports
- No `SPEC-*` findings in the report: stop and explain that the report has no spec findings to break down
- Missing requested `SPEC-*` ids: stop and list the missing ids
- Missing `siw/OPEN_ISSUES_OVERVIEW.md` or `siw/issues/`: continue without live issue-state cross-check and fall back to report annotations
