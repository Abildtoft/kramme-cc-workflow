---
name: kramme:siw:resolve-audit
description: Resolve audit findings one-by-one with executive summaries, alternatives, recommendation, and SIW issue creation
argument-hint: "[audit-report-path] [finding-id(s)] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Resolve Audit Findings

Turn an audit report into decision-ready SIW issues by walking findings one at a time with clear options and a recommended path.

**Flag:** `--auto` — Skip the per-finding AskUserQuestion step and automatically choose the best resolution option for each finding based on spec alignment, maintenance cost, delivery risk, and follow-up effort. If multiple audit reports exist and you want to stay scoped to one of them, pass that report path explicitly.

## Workflow Boundaries

**This command triages audit findings and creates planning issues.**

- **DOES**: Read audit report, summarize each finding, propose alternatives, recommend an option, capture user preference or auto-select a resolution, create SIW issue(s)
- **DOES NOT**: Implement code changes

Implementation stays separate and should happen later via `/kramme:siw:issue-implement`.

## Hard Constraints

**One finding at a time, every time.** Each finding completes its full cycle — executive summary → alternatives → recommendation → resolution → SIW issue — before the next finding is presented. Never batch, group, summarize, or preview multiple findings in a single message during Steps 4–6.

**Default mode:** the per-finding AskUserQuestion (Step 4.4) is mandatory. STOP after asking and wait for the user's response before creating the issue or advancing.

**`--auto` mode:** do not ask the user to choose. Select the strongest option, create the issue, continue.

## Required Review Style

For every finding, follow this structure:

1. Executive summary (with code references when available)
2. Alternative options
3. Preferred option with justification
4. Resolution: user-selected via AskUserQuestion (default) or model-selected (`--auto`)
5. SIW issue creation for the chosen option

## Process Overview

```
/kramme:siw:resolve-audit [audit-report-path] [finding-id(s)] [--auto]
    ↓
[Locate and read audit report]
    ↓
[Extract actionable findings: DIV-*, EXT-*, SPEC-*, PROD-* (plus legacy DISC-*/MISS-*)]
    ↓
[Optionally filter to user-selected finding IDs; skip findings already linked to a G-* issue]
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

1. Parse `$ARGUMENTS` first:
   - Treat `--auto` as an optional control flag, not a path or finding id
   - Remaining markdown path tokens are candidate report paths
   - Remaining `DIV-*`, `EXT-*`, `DISC-*`, `MISS-*`, `SPEC-*`, and `PROD-*` tokens are finding filters
2. If the parsed arguments include a markdown path, use that path and skip auto-detection.
3. Otherwise, discover available report files in this order:
   - `siw/AUDIT_IMPLEMENTATION_REPORT.md`
   - `siw/AUDIT_SPEC_REPORT.md`
   - `siw/PRODUCT_AUDIT.md`
   - `AUDIT_IMPLEMENTATION_REPORT.md` (project root)
   - `AUDIT_SPEC_REPORT.md` (project root)
   - `PRODUCT_AUDIT.md` (project root)
4. If **more than one report type exists** (any location):
   - Without `--auto`, ask which to resolve before continuing. Build the options list from the reports that were actually found (omit unavailable ones); include "All" only when two or more were found:

```yaml
header: "Choose Audit Type"
question: "Multiple audit reports were found. Which findings should I resolve?"
options:
  - label: "Implementation audit (Recommended when available)"
    description: "Resolve DIV-*/EXT-* findings from AUDIT_IMPLEMENTATION_REPORT.md (also supports legacy DISC-*/MISS-*)"
  - label: "Spec quality audit"
    description: "Resolve SPEC-* findings from AUDIT_SPEC_REPORT.md"
  - label: "Product audit"
    description: "Resolve PROD-* findings from PRODUCT_AUDIT.md"
  - label: "All"
    description: "Resolve findings from every available report in one run"
```

       - With `--auto`, resolve every available report in one run, in this order: implementation findings, spec findings, product findings.

5. If only one report exists, use it automatically.
6. If no report exists, stop and instruct the user to run `/kramme:siw:implementation-audit`, `/kramme:siw:spec-audit`, or `/kramme:siw:product-audit` first.
7. If a selected report contains multiple appended top-level report blocks, isolate the last block only and treat it as the active audit run. Ignore earlier appended runs.

## Step 2: Parse Findings

Extract actionable findings from the active audit run headings:

- `### DIV-NNN: ...`
- `### EXT-NNN: ...`
- `### DISC-NNN: ...` (legacy)
- `### MISS-NNN: ...` (legacy)
- `### SPEC-NNN: ...`
- `### PROD-NNN: ...`

For each finding, collect:

- Finding id and title
- Requirement/source references
- Evidence/code references
- Severity/category section
- Severity Note if present
- Existing issue note if present
- Source report path (`AUDIT_IMPLEMENTATION_REPORT.md`, `AUDIT_SPEC_REPORT.md`, or `PRODUCT_AUDIT.md`)

Ignore:

- Fully implemented section
- Summary totals
- Non-actionable uncertain rows unless explicitly requested
- Findings marked `[Auto-fixed]` (already resolved by /kramme:siw:spec-audit:auto-fix)

## Step 3: Select Scope

If the parsed arguments include finding ids (example: `DIV-002 EXT-001 SPEC-003`), process only those. Otherwise, process all actionable findings in severity order:

1. Critical findings, plus SPEC/PROD findings whose `Severity Note` says `from Critical`
2. Major findings, plus SPEC/PROD findings whose `Severity Note` says `from Major`
3. Remaining Minor findings

**Severity-inheritance rule (referenced by issue templates):** map a SPEC/PROD finding's effective priority from its `Severity Note` — `from Critical` → High, `from Major` → Medium, otherwise the finding's own severity.

**Skip findings that already have an issue.** If a finding's "Existing issue" note references a `G-*` issue that exists on disk under `siw/issues/`, drop it from the queue and list it in the Step 7 summary under "Skipped — already has issue". This keeps re-runs idempotent.

**Unknown finding ids.** For each `DIV-*`/`EXT-*`/`SPEC-*`/`PROD-*`/legacy id passed in `$ARGUMENTS` that does not appear in the active report, list it in the Step 7 summary under "Skipped — not in report". If none of the requested ids match any finding, stop before Step 4 with a clear error naming the missing ids and the report path.

## Step 4: One-Finding Triage Loop

Detect the finding type from its ID prefix and use the matching Step 4.1–4.3 style below. Step 4.4 (resolution selection) is shared by all finding types.

---

### For DIV-_/EXT-_ findings (implementation audit)

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

### For SPEC-\* findings (spec quality audit)

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

---

### For PROD-\* findings (product audit)

#### 4.1 Executive Summary

- Which product dimension is affected (target user, problem/solution fit, user state, critical moments, scope, success criteria, prioritization)
- What the spec or product surface says (quote when available) and what's missing
- Why this matters for users or delivery if unfixed
- Which spec section(s), flow(s), or screen(s) need attention

#### 4.2 Alternatives

Provide 2-3 concrete options. Include at least:

- **Option A (Targeted clarification):** Add or sharpen the affected product element in place
- **Option B (Scope or flow change):** Restructure flow, narrow scope, or rework the section to close the gap properly
- **Option C (Accept as-is / defer):** Only when the gap is low-risk for the current rollout

For each option include:

- What changes (spec, flow, scope)
- Pros
- Cons
- Risk to users or delivery if chosen

#### 4.3 Preferred Option

State a clear recommendation and justify it with:

- User value protected or unlocked
- Reduction in rework or wrong-thing risk
- Effort to revise vs. cost of shipping with the gap

---

### 4.4 Select Resolution (applies to all finding types)

Without `--auto`, use AskUserQuestion to choose an option before creating an issue:

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

Send this AskUserQuestion as a standalone message immediately after Step 4.3 (recommendation), with no additional surrounding content. STOP and wait for the user's response before doing anything else (see Hard Constraints).

If the user asks to modify options, refine and re-ask before creating the issue. Once they pick, proceed to Step 5 for this finding only.

With `--auto`:

1. **DO NOT** send AskUserQuestion for the finding
2. Select the best option yourself, usually the recommended option from Step 4.3
3. State `Selected resolution: Option X — {one-line why}` immediately after the recommendation
4. Proceed directly to Step 5 without waiting for user input
5. If the original options are weak or incomplete, refine them first and then choose the strongest revised option

## Step 5: Create SIW Issue For Chosen Option

Prerequisites:

- `siw/OPEN_ISSUES_OVERVIEW.md` exists. If missing, stop with: "SIW workflow not initialized. Run `/kramme:siw:init` before resolving audit findings." Do not create issues without it.
- `siw/issues/` exists (create if missing)
- `siw/LOG.md` exists (create minimal file with a `## Current Progress` section if missing)

Issue creation:

1. Determine next `G-` issue number from `siw/issues/ISSUE-G-*.md`.
2. Create file:
   - `siw/issues/ISSUE-G-{NNN}-resolve-{finding-id}-{slug}.md`
3. Use the matching template based on finding type (read the template file and substitute placeholders):
   - DIV-_/EXT-_ (and legacy DISC-_/MISS-_): `assets/issue-div-ext.md.template`
   - SPEC-\*: `assets/issue-spec.md.template`
   - PROD-\*: `assets/issue-prod.md.template`
   - When the finding has a `Severity Note`, copy it verbatim into the issue body and apply the severity-inheritance rule from Step 3 to set `Priority`.
   - Set the `Mode` field. **Default `AUTO`.** Most resolutions an autonomous agent can implement and verify are AUTO. Set `HITL — <one-line reason>` only when the chosen option carries a concrete human-input requirement: an unsettled architectural/product decision, design review, a judgment call, manual testing that can't be automated, or external-system access. When unclear, choose `AUTO`. (A finding's severity does not by itself make it HITL.)

4. Add row to `siw/OPEN_ISSUES_OVERVIEW.md` with status `READY`.
   - For a brand-new modern section, use the 7-column modern schema including the `Mode` column; the `Mode` cell is `AUTO` or `HITL` (the reason lives in the issue body, not the table):

     ```markdown
     **Parallelization:** {Safe to parallelize | Must be sequential | Needs coordination | Mixed — see issue files}

     | G-{NNN} | {Title} | READY | {Size} | {Priority} | {AUTO | HITL} | Audit Report |
     ```

   - When a section already exists, match its column count exactly (legacy 5-col / pre-Mode 6-col / modern 7-col) and preserve it in place — do not migrate layouts or add a `Mode` column to a section that lacks one.

   - If `## General` already has a section-level `**Parallelization:**` line, treat it as a roll-up summary for the whole section rather than a per-issue mirror.
   - Recompute it from all real `G-*` issue files after adding the new issue: if every issue shares the same section-level category/gating note, keep that shared summary; otherwise set it to `Mixed — see issue files for exact guidance`.
   - If the General section is still in its empty placeholder state (`_None_` row / no real issues yet), replace the default summary from `siw:init` with the first real issue's category.
   - If an existing legacy General section has no `**Parallelization:**` line, preserve that absence instead of inserting one.

5. Append a one-line entry to `siw/LOG.md` under the `## Current Progress` section (in `### Last Completed`). Include finding id, selected option, and created issue id. Example:

   ```markdown
   - {YYYY-MM-DD} G-{NNN}: resolved {finding_id} via Option {X} ({one-line option name})
   ```

## Step 6: Continue Until Done

After creating the SIW issue for one finding:

1. Send a standalone completion message for that finding to the user
2. **Return to Step 4** for the next finding in the queue
3. In a separate subsequent message, present the next finding's full executive summary (Step 4.1) — do not skip or abbreviate
4. With `--auto`, continue immediately after the completion message without waiting for user input

**NEVER** process the next finding without completing the full cycle (Steps 4 through 5) for the current one.

**STOP** only when all selected findings are handled or the user asks to stop.

## Step 7: Final Summary

At the end, report:

- Findings processed count
- Issues created (`G-xxx` list)
- Findings intentionally deferred
- Skipped — already has issue (finding ids + existing `G-*`)
- Skipped — not in report (finding ids passed in arguments that did not match the active report)
- Recommended first implementation issue to start with

This final summary is allowed only after all selected findings complete the full Steps 4-5 cycle.

Then stop and wait for user instruction.
