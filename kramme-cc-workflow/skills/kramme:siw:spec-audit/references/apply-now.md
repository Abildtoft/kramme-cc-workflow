# Apply Mode (`--apply`)

This reference is the canonical owner of every direct spec update made from spec-audit findings. It runs after an audit (Step 6, including `--team` runs) and for `--apply <report>`, which fixes an existing spec audit report without re-auditing. It applies deterministic and clearly-best fixes to findings that can be corrected safely from the spec itself: mechanical issues plus higher-confidence cleanup that still stays within the existing spec meaning.

Findings that require product decisions, stakeholder input, or still lack a clearly best fix are left untouched for `/kramme:siw:resolve-audit`.

## Entry Points

Both entries use the flags parsed in `references/spec-resolution.md` §1.1:

- `--auto` (`AUTO_MODE=true`) — Skip classification approval, apply all auto-fixable fixes without asking
- `--dry-run` (`DRY_RUN=true`) — Show classification and proposed fixes for `--apply <report>` without modifying any files. Requires an existing report path; argument validation rejects audit-first dry runs before the audit starts.
- `--threshold N` (`CONFIDENCE_THRESHOLD=N`) — Set confidence threshold for auto-fixing (60-100, default 80). Findings with confidence >= N are auto-fixable only after safety caps and the four sub-score guardrails are applied. Use 90 for a stricter pass, 60 for the most permissive allowed run.
- `--allow-dirty` (`ALLOW_DIRTY=true`) — Allow `--auto` runs to proceed when spec files have uncommitted changes. Without this flag, dirty spec files abort an apply-only `--auto` run.

Whenever a stage below says **Stop**, end the apply run. In an apply-only run, end the turn after the output. In an after-audit run, continue to Step 7 of `SKILL.md` and report `Applied Now: 0`.

### After-Audit Entry

Use this when `/kramme:siw:spec-audit` reaches Step 6 and either `APPLY_MODE=true` (from `--apply` / `--apply-now` without a report path) or the user chooses **Apply now** from the Step 6 prompt.

- `report_path` is the report written in Step 5.
- If the user chose **Apply now**, treat the A4 approval gate as already satisfied.
- If `AUTO_MODE=true`, use the non-interactive approval path and set `ALLOW_DIRTY=true`, because the dirty spec files are the active audit targets owned by this apply run.

### Apply-Only Entry

Use this when the `SKILL.md` Apply Mode section routes here (`APPLY_ONLY=true`). No audit runs: Team Mode, Product Mode, and Steps 2-7 are skipped.

- `report_path` is `APPLY_REPORT_PATH`, already verified in `references/spec-resolution.md` §1.1.
- If `AUTO_MODE=true`, use the non-interactive approval path. Dirty spec files abort the run unless `ALLOW_DIRTY=true`.
- End the turn after the Summary.

In either entry, if the active report run has no `SPEC-NNN` findings (only `PROD-NNN` product findings), apply nothing and list the product findings as left for `/kramme:siw:resolve-audit {report_path}` (A7, Report Format Unexpected).

## Hard Constraints

**NEVER** modify a finding below the confidence threshold. If in doubt, score conservatively.

**NEVER** auto-fix a safety-capped finding regardless of threshold. Critical findings in Completeness, Scope, or Rationale Documentation dimensions always require decisions; treat the legacy `Value Proposition` label in older reports as Rationale Documentation. Findings whose recommendations use decision-signal language ("consider", "decide whether", "choose between", "discuss with", "evaluate options"), change scope, or define success-criteria substance always require decisions.

**NEVER** auto-fix a finding when any sub-score is below 15. See `${CLAUDE_PLUGIN_ROOT}/shared/siw/references/fix-confidence-rubric.md` (Auto-Fix Guardrails) for the authoritative rule and its rationale; this rubric is the canonical scoring model for every apply run.

**NEVER** apply a fix that changes the meaning, scope, or intent of any requirement. Fixes correct form, not substance.

**NEVER** invent information not already present in the spec. Every fix must derive from content that already exists somewhere in the spec files.

**NEVER** skip the spot-check verification after applying a fix. If verification fails, revert the edit and reclassify the finding.

## A1: Read Report and Spec Files

### A1.1 Read Report and Spec Files

1. Read the report file at `report_path` completely.
2. If the file contains multiple appended `# Spec Audit Report` blocks, isolate the **last** block only. Treat that as the active audit run and ignore older appended runs.
3. Extract the spec file paths from the active run's report header ("Spec Files Reviewed").
4. Read every referenced spec file completely.

If a spec file no longer exists at its path, follow A7, Spec File Missing.

### A1.2 Check for Uncommitted Changes

Run `git status` on the spec files. If any have uncommitted changes, warn:

```
Warning: {file} has uncommitted changes. Auto-fixes will be applied on top of these changes.
```

With `--auto` **and** `ALLOW_DIRTY=true`, continue with the warning. With `--auto` alone, abort:

```
Spec files have uncommitted changes. --auto refuses to edit dirty spec files without --allow-dirty.

Either commit or stash the changes, or re-run with: /kramme:siw:spec-audit --apply {report_path} --auto --allow-dirty
```

Otherwise (interactive), ask:

```yaml
header: "Uncommitted Spec Changes"
question: "{N} spec file(s) have uncommitted changes. Proceed anyway?"
options:
  - label: "Continue"
    description: "Apply fixes on top of current changes"
  - label: "Abort"
    description: "Cancel — commit or stash changes first"
```

---

## A2: Extract Findings

Parse all `### SPEC-NNN: {title}` headings from the active audit run only.

Never extract, score, or edit `### PROD-NNN:` findings. They come from the Product dimension of `/kramme:siw:spec-audit --product`, are product judgment calls, and always route to `/kramme:siw:resolve-audit`. Count the open ones in the Summary as product findings left for decisions.

For each finding, extract:

- Finding ID and title
- Dimension
- Severity
- Severity Note (if present)
- Location (source file > section heading)
- Details (including quotes from the spec)
- Recommendation
- Fix Confidence (if present in the report)

**Skip findings that match any of:**

- Already marked `**Status:** [Auto-fixed]` (from a previous run)
- Already marked `**Status:** [Applied directly]` (legacy marker from older `/kramme:siw:spec-audit --apply` runs)
- Contains `Existing issue:` note (already tracked via SIW)

If no actionable findings remain:

```
No actionable findings to process.

{If all auto-fixed:} All {N} findings were previously auto-fixed.
{If all legacy-applied:} All {N} findings were previously applied directly with the legacy marker.
{If all have issues:} All {N} findings already have SIW issues.
```

**Action:** Stop.

---

## A3: Score & Classify Findings

Read the classification rubric from `${CLAUDE_PLUGIN_ROOT}/shared/siw/references/fix-confidence-rubric.md`.

For each extracted finding, assign a **fix confidence score** (0-100):

1. Score each of the four conditions (0-25): Determinism, Information Availability, Meaning Preservation, Alternative Absence. **Always score from scratch using the rubric** — do not rely on a `Fix Confidence` value already present in the report (treat any such value as informational only).
2. Sum the four scores for the finding's confidence (0-100).
3. Apply safety caps — safety-capped findings are forced to confidence 0 regardless of score. If the report carries `**Severity Note:** [Deprioritized — capped at Minor from Critical]` for a Completeness, Scope, Rationale Documentation, or legacy Value Proposition finding, preserve that safety cap here as well.

Classify based on the final confidence vs `CONFIDENCE_THRESHOLD` (default 80):

- safety-capped finding, or a Completeness / Scope / Rationale Documentation / legacy Value Proposition finding marked `**Severity Note:** [Deprioritized — capped at Minor from Critical]` → **REQUIRES_DECISION** regardless of threshold
- finding with `Determinism < 15`, `Information Availability < 15`, `Meaning Preservation < 15`, or `Alternative Absence < 15` → **REQUIRES_DECISION** regardless of threshold
- non-safety-capped finding with confidence >= `CONFIDENCE_THRESHOLD` → **AUTO-FIXABLE**
- otherwise → **REQUIRES_DECISION**

Display confidence tier labels alongside scores:

- 90-100: MECHANICAL
- 75-89: HIGH_CONFIDENCE
- 50-74: MODERATE_CONFIDENCE
- 0-49: REQUIRES_DECISION

### A3.1 Present Classification

```
Finding Classification (threshold: {CONFIDENCE_THRESHOLD})
==========================================================

Auto-fixable ({N} findings at or above threshold):
{For each:}
  {SPEC-NNN} ({Severity}/{Dimension}) [confidence: {score} — {tier}]: {one-line description of the fix}

Requires decision ({M} findings):
{For below-threshold:}
  {SPEC-NNN} ({Severity}/{Dimension}) [below threshold; confidence: {score} — {tier}]: {one-line reason}
{For guardrail-blocked:}
  {SPEC-NNN} ({Severity}/{Dimension}) [guardrail-blocked; confidence: {score} — {tier}]: {one-line reason}
{For safety-capped:}
  {SPEC-NNN} ({Severity}/{Dimension}) [safety cap]: {one-line reason}

Skipped: {K}
{For each:}
  {SPEC-NNN}: {reason — already auto-fixed or has SIW issue}
```

If no findings at or above threshold:

```
No auto-fixable findings at threshold {CONFIDENCE_THRESHOLD}. All {N} findings require decisions.
{If any findings score 60-79 and clear all guardrails:}
Tip: {count} finding(s) cleared all guardrails but are below the threshold. Use --threshold 60 to include them.

Next: /kramme:siw:resolve-audit {report_path}
```

**Action:** Stop.

---

## A4: Approval Gate

If the After-Audit Entry already counts as approval (the user chose **Apply now**), proceed to A5 with all auto-fixable findings.

### With `--dry-run`

For each auto-fixable finding, show the proposed fix:

```
Proposed Fixes (dry run — threshold: {CONFIDENCE_THRESHOLD}, no files will be modified)
========================================================================================

SPEC-{NNN}: {title}
  Confidence: {score}/100 ({tier})
  File: {spec_file} > {section}
  Current: "{quoted text from spec}"
  Proposed: "{what it would change to}"
  Reason: {why this fix is correct}

{Repeat for each auto-fixable finding}
```

**Action:** Stop after showing all proposed fixes.

### With `--auto`

Proceed directly to A5 with all auto-fixable findings.

### Default (interactive)

```yaml
header: "Auto-Fix Findings (threshold: {CONFIDENCE_THRESHOLD})"
question: "Found {N} auto-fixable findings (confidence >= {CONFIDENCE_THRESHOLD}) and {M} findings requiring decisions. Proceed?"
options:
  - label: "Fix all {N} auto-fixable findings"
    description: "Apply fixes and update the audit report"
  - label: "Let me review first"
    description: "Show proposed fixes before applying (same as --dry-run)"
  - label: "Abort"
    description: "Cancel — no changes"
```

If user chooses "Let me review first", show the dry-run output from above, then ask:

```yaml
header: "Apply Fixes?"
question: "Apply these {N} fixes?"
options:
  - label: "Apply all"
    description: "Apply all proposed fixes"
  - label: "Abort"
    description: "Cancel — no changes"
```

This procedure is intentionally batch-only — per-finding selection is **not** offered. To exclude specific findings, abort and re-run with a higher `--threshold`, or address them individually via `/kramme:siw:resolve-audit`.

---

## A5: Apply Fixes

### A5.1 Order Fixes

Group findings by spec file, then sort by location within each file (top of document to bottom). Processing top-to-bottom avoids `old_string` mismatches that occur when an earlier edit changes the surrounding text a later finding expects.

### A5.2 Apply Each Fix

For each auto-fixable finding in order:

1. **Read the section** referenced by the finding's location, plus enough surrounding context to understand the fix.
2. **Determine the fix** — Based on the finding's details, recommendation, and the surrounding spec context, determine the exact text change.
3. **Apply the edit** to the spec file.
4. **Spot-check verification** — Re-read the edited section. Confirm:
   - The specific issue flagged by the finding no longer exists
   - No new issues were introduced (broken references, grammar errors, meaning changes)
5. **Record the result:**
   - **Success:** Record finding ID, old text, new text, one-line description
   - **Failure:** Revert the edit, reclassify the finding as `REQUIRES_DECISION`, record the failure reason

### A5.3 Fix Application Rules

- **One fix at a time.** Complete the full apply-verify cycle for one finding before starting the next.
- **Minimal edits.** Change only what the finding requires. Do not improve surrounding text.
- **Preserve formatting.** Match the existing style of the spec (heading levels, list markers, whitespace).
- **Never add content not derivable from the spec.** If the fix requires inventing new requirements, constraints, or behaviors, it is not mechanical — revert and reclassify.

---

## A6: Update Audit Report and SIW Log

Read `references/apply-report-update.md`, then update the audit report and optional SIW log exactly as specified there.

Required outcomes:

- Each successfully fixed finding has `**Status:** [Auto-fixed]`, final `**Fix Confidence:**`, and `**Fix applied:**` annotations.
- The summary table's `Auto-fixed` count is updated when the severity table has the expected schema.
- Failed verification is documented in `## Auto-Fix Notes`.
- `**Overall Assessment:**` changes to `Ready for implementation` only under the reference's all-clear conditions.
- `siw/LOG.md` is updated only when it already exists, has a recognizable Current Progress section, and at least one finding was auto-fixed.

---

## A7: Error Handling

### Report Format Unexpected

If the active run has no `### SPEC-NNN:` headings but does contain `### PROD-NNN:` headings, stop with:

```text
No SPEC findings to auto-fix in {report_path}.
{N} PROD findings need decisions. Run /kramme:siw:resolve-audit {report_path}.
```

If the active run contains neither `### SPEC-NNN:` nor `### PROD-NNN:` headings, stop:

```text
Could not parse findings from {report_path}.
Expected format: ### SPEC-NNN: {title}

The report may be from an incompatible version. Re-run /kramme:siw:spec-audit.
```

### Spec File Missing

If a spec file referenced in the report no longer exists:

- Warn: `Spec file not found: {path} — skipping {N} findings for this file`
- Skip all findings referencing that file
- Continue with remaining findings

### Edit Conflict

If the Edit tool fails because `old_string` was not found or the spec was modified since the audit:

- Warn: `Edit failed for SPEC-{NNN}: text has changed since audit`
- Skip this finding and reclassify it as `REQUIRES_DECISION`
- Continue with remaining findings

### All Fixes Fail

If every auto-fixable fix fails verification:

```text
All {N} auto-fixable fixes failed verification.
The spec may have changed significantly since the audit.

Recommended: Re-run /kramme:siw:spec-audit to get a fresh report.
```

---

## Summary

Use the summary template from `assets/auto-fix-summary.md`, including its SIW log status. In an after-audit run, Step 7 then reports `Applied Now: {N}` and `Issues Created: 0`.

## Boundaries

- Do not create files under `siw/issues/`.
- Do not update `siw/OPEN_ISSUES_OVERVIEW.md`.
- Do not run the issue-creation flow after an apply run completes.
- Use the canonical marker and report annotations for new writes: `**Status:** [Auto-fixed]`, `**Fix applied:** ...`, and the `Auto-fixed` summary row.
- Preserve the optional `siw/LOG.md` progress update when a log already exists.
- Treat `**Status:** [Applied directly]` as a legacy read marker only. New runs must not write it.
- Never apply product findings. This procedure reads only `SPEC-NNN` findings; leave every `PROD-NNN` finding from `--product` untouched and list the open ones as left for `/kramme:siw:resolve-audit {report_path}`.
