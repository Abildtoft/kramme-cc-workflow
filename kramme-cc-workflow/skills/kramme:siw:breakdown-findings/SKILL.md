---
name: kramme:siw:breakdown-findings
description: Break down unresolved spec-audit or implementation-audit findings into executive summaries, resolution options, and a recommendation without creating SIW issues. Use it after spec-audit, spec-audit:auto-fix, or implementation-audit when you want decision-ready analysis before choosing a follow-up path. Not for product audits or direct issue creation.
argument-hint: "[audit-report-path] [finding-id(s)]"
disable-model-invocation: true
user-invocable: true
---

# Breakdown Audit Findings

Turn unresolved findings from a spec-audit or implementation-audit report into a single inline, decision-ready breakdown.

## Workflow Boundaries

**This command is analysis-only.** It reads a spec-audit or implementation-audit report, identifies unresolved supported findings, explains each one, presents 2-3 resolution options, recommends one, and routes the user toward the next command. Issue creation stays separate and happens later via `/kramme:siw:resolve-audit` or `/kramme:siw:issue-define`.

## Hard Constraints

- **NEVER** create or modify files as part of this command (no SIW issues, no updates to `siw/LOG.md` or `siw/OPEN_ISSUES_OVERVIEW.md`, no breakdown artifact such as `siw/FINDINGS_BREAKDOWN.md`, no new report file)
- **NEVER** read product-audit reports (e.g. `PRODUCT_AUDIT.md`) for this command
- **NEVER** include unsupported finding ids in the breakdown
- **ALWAYS** return a single inline response covering all selected findings
- **ALWAYS** treat explicit supported finding ids as an override to the default unresolved-only filter

## Process Overview

```text
/kramme:siw:breakdown-findings [audit-report-path] [finding-id(s)]
    ↓
[Locate audit report]
    ↓
[Extract supported findings]
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
3. Treat `SPEC-*`, `DIV-*`, `EXT-*`, `DISC-*`, and `MISS-*` tokens as explicit finding filters.
   - If any remaining token looks like an audit finding id but does not use a supported prefix (for example `PROD-001`), stop and list the unsupported ids. Say this command supports only `SPEC-*`, `DIV-*`, `EXT-*`, `DISC-*`, and `MISS-*`.
4. If more than one markdown path is supplied, stop and ask the user to provide only one report path.
5. If a report path is supplied:
   - Verify the file exists.
   - Verify it ends in `.md`.
   - Verify it is a supported audit report by checking that it contains at least one supported finding heading:
     - Spec audit: `### SPEC-`
     - Implementation audit: `### DIV-`, `### EXT-`, `### DISC-`, or `### MISS-`
   - If the file instead looks like a product audit, stop and instruct the user to use the corresponding product audit flow.
6. If no report path is supplied:
   - If explicit ids include only `SPEC-*`, search only spec-audit reports.
   - If explicit ids include only `DIV-*`, `EXT-*`, `DISC-*`, or `MISS-*`, search only implementation-audit reports.
   - If explicit ids mix `SPEC-*` with implementation-audit prefixes, stop and ask the user to pass one report path or run separate breakdowns.
   - Otherwise discover compatible reports in this order:
     - `siw/AUDIT_IMPLEMENTATION_REPORT.md`
     - `siw/AUDIT_SPEC_REPORT.md`
     - `AUDIT_IMPLEMENTATION_REPORT.md`
     - `AUDIT_SPEC_REPORT.md`
   - If more than one compatible report exists and explicit ids do not disambiguate the report type, ask the user which report to use before continuing.
7. If no supported audit report exists, stop and instruct the user to run `/kramme:siw:implementation-audit` or `/kramme:siw:spec-audit` first.
8. If the selected report contains multiple appended top-level report blocks, isolate the last block only and treat it as the active audit run. Ignore earlier appended runs. Supported top-level markers include `# Audit Report: Implementation vs. Specification` and `# Spec Audit Report`.
9. If the isolated active block contains zero supported finding headings (for example a run with only verified alignments), stop and tell the user the latest audit run produced no supported findings to break down. Do not fall through to the "filtered to zero" message in Step 4.1, which is reserved for findings that existed but were all auto-fixed or already tracked.

## Step 2: Extract Findings

Read the active audit run fully enough to extract every supported finding and its surrounding metadata.

Supported findings:

- Spec audit: `SPEC-*`
- Implementation audit: `DIV-*`, `EXT-*`, `DISC-*`, `MISS-*`

For each finding, collect:

- Finding id and title
- Finding type / report type
- Severity section or severity field (`Critical`, `Major`, `Minor`)
- Dimension, category, or extension type when present
- Requirement/source references
- Location / source section
- Details
- Evidence and code references when present
- Runtime behavior when present
- Impact, if present
- Recommendation from the audit report
- `Severity Note`, if present
- `Existing issue` note or `Existing-Issue Cross-Reference` table row, if present
- Whether the heading or body marks it as `[Auto-fixed]`

Ignore:

- Summary tables
- Dimension summaries
- Verified alignments / fully implemented sections
- Findings from unsupported report types

## Step 3: Determine Which Findings Are Unresolved

### 3.1 Default unresolved definition

Without explicit finding ids, include only findings that are:

- supported by this command
- not marked `[Auto-fixed]`
- not already represented by an open SIW issue

### 3.2 Open issue detection

If `siw/` exists, prefer live SIW state over stale report annotations.

Check these sources when present:

- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/issues/*.md`

Treat a finding as already tracked when an issue references the same finding id and the issue is **not** in a closed state. The only closed state is:

- `DONE`

Every other state — including but not limited to `READY`, `IN PROGRESS`, `IN REVIEW`, `BLOCKED`, `DEFERRED`, `DRAFT`, and any unrecognized state — counts as still open. When in doubt, treat the issue as open so the finding is filtered out by default rather than re-surfaced in error.

If live SIW state is missing or inconclusive, fall back to report annotations:

- `Existing issue: ISSUE-G-...`
- `## Existing-Issue Cross-Reference` rows where the `Finding` column matches the finding id and `Existing issue(s)` contains `ISSUE-G-...`

### 3.3 Explicit finding filters

If the user passed one or more supported finding ids:

- Select only those findings
- Include them even if they are auto-fixed or already tracked by an open issue
- Annotate that state clearly in the output

If any requested finding id is not found in the report, stop and list the missing ids.

### 3.4 Output ordering

When no explicit ids are passed, order findings like this:

1. Critical findings, plus findings whose `Severity Note` says `from Critical`
2. Major findings, plus findings whose `Severity Note` says `from Major`
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

If explicit finding ids were used, state that the normal unresolved-only filter was overridden.

If no findings remain after filtering:

- State that no unresolved supported findings were found
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

- For `SPEC-*`: what the spec currently says or fails to say, which quality dimension is affected, which spec section(s) are impacted, and why this matters for implementation
- For `DIV-*` and `MISS-*`: what the spec requires, what the code currently lacks or does differently, which requirement/section is impacted, and why this matters
- For `EXT-*` and `DISC-*`: what boundary the spec defines, what extra behavior the implementation introduces, which requirement/section is impacted, and why this matters

If the finding was explicitly requested but is already tracked or auto-fixed, add a short state note before the summary:

- `State: already tracked by open issue {issue_id}`
- `State: marked [Auto-fixed] in the audit report`

### 4.4 Evidence

Use the audit report as the evidence source.

Include:

- short quotes or paraphrases from the finding
- spec file and section references when present
- code references and runtime behavior when present
- `Severity Note` when present and relevant to urgency

Do not quote more than needed. Favor concise excerpts and paraphrase the rest.

### 4.5 Resolution options

Provide 2-3 concrete options.

For `SPEC-*` findings, include at least:

- **Option A (Targeted addition)**: Add the minimum missing detail, rule, or section
- **Option B (Section rework)**: Rewrite or restructure the affected section for clarity and completeness
- **Option C (Defer / accept as-is)**: Only when it is genuinely credible

For implementation-audit findings (`DIV-*`, `EXT-*`, `DISC-*`, `MISS-*`), include at least:

- **Option A (Minimal fix)**: Make the smallest code change that satisfies the spec or removes the out-of-spec behavior
- **Option B (Robust fix)**: Align the implementation through clearer contracts, tests, or structure that reduces future drift
- **Option C (Defer / spec adjustment)**: Only when deferring or changing the spec is genuinely credible

For each option include:

- What changes in the spec or implementation
- Pros
- Cons
- Risk if chosen

Keep the options materially different. Do not present cosmetic variants of the same fix.

### 4.6 Recommendation

Pick one option and justify it explicitly using:

- correctness against the spec or clarity for implementors
- ambiguity, drift, or rework reduction
- effort to revise the spec or implementation
- delivery and maintenance risk if the gap remains

Be decisive. Do not end with "it depends" unless the report truly lacks enough information to recommend a path.

## Step 5: Ask What To Do Next

After the inline breakdown, ask the user what they want to do next using `AskUserQuestion` with these options:

```yaml
header: "Next Step"
question: "What should I do with these audit findings next?"
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

- Provide one exact `/kramme:siw:resolve-audit` command using the current report path
- Always list every finding id that appeared in this breakdown explicitly, even when the user did not pass a subset. This keeps the follow-up command deterministic if SIW state shifts between runs (for example, an issue moves to `IN PROGRESS`) and prevents `resolve-audit` from re-deriving a different unresolved set
- If the user narrowed the breakdown to a subset, list only that subset

Example shape:

```text
/kramme:siw:resolve-audit siw/AUDIT_IMPLEMENTATION_REPORT.md DIV-001 EXT-004
```

### If the user chooses "Create/refine issue manually"

- Provide one `/kramme:siw:issue-define` command per selected finding
- Use the finding id and title in the prompt text so the issue has enough context
- Include the report path as a supporting context argument when useful

Example shape:

```text
/kramme:siw:issue-define "Resolve DIV-001 - Enforce retry limit" siw/AUDIT_IMPLEMENTATION_REPORT.md
```

### If the user chooses "Stop here"

- Acknowledge that the breakdown is complete
- Do not propose or run further actions

## Error Handling

- Invalid path: stop and state the missing or invalid report path
- Wrong report type: stop and say this command supports spec-audit and implementation-audit reports
- No supported findings in the report: stop and explain that the report has no supported findings to break down
- Unsupported requested finding ids: stop and list the unsupported ids with the supported prefixes
- Missing requested finding ids: stop and list the missing ids
- Missing `siw/OPEN_ISSUES_OVERVIEW.md` or `siw/issues/`: continue without live issue-state cross-check and fall back to report annotations
