---
name: kramme:siw:spec-audit:auto-fix
description: Auto-fix mechanical spec-audit findings that have a single obvious correct resolution — cross-reference errors, terminology inconsistencies, numbering mistakes, formatting issues, and weasel words replaceable with specifics already in the spec. Run after spec-audit.
argument-hint: "[audit-report-path] [--auto] [--dry-run] [--threshold 50-100]"
disable-model-invocation: true
user-invocable: true
---

# Auto-Fix Mechanical Spec Audit Findings

Apply deterministic fixes to spec-audit findings that have a single obvious correct resolution. This skill runs after `/kramme:siw:spec-audit` (or `:team`) and directly edits spec files to resolve mechanical issues — cross-reference errors, terminology inconsistencies, numbering mistakes, formatting issues, and weasel words replaceable with specifics already in the spec.

Findings that require product decisions, stakeholder input, or still lack a clearly best fix are left untouched for `/kramme:siw:resolve-audit`.

**Flags:**
- `--auto` — Skip classification approval, apply all auto-fixable fixes without asking
- `--dry-run` — Show classification and proposed fixes without modifying any files
- `--threshold N` — Set confidence threshold for auto-fixing (50-100, default 80). Findings with confidence >= N are auto-fixable only after safety caps and the determinism/alternative guardrails are applied. Use 90 for a stricter pass, 60 for aggressive, 50 for the most permissive allowed run.

## Hard Constraints

**NEVER** modify a finding below the confidence threshold. If in doubt, score conservatively.

**NEVER** auto-fix a safety-capped finding regardless of threshold. Critical findings in Completeness, Scope, or Value Proposition dimensions always require decisions. Findings whose recommendations use decision-signal language ("consider", "decide whether", "choose between", "discuss with", "evaluate options"), change scope, or define success-criteria substance always require decisions.

**NEVER** auto-fix a finding when either `Determinism` or `Alternative Absence` scores below 15. Those findings still require choosing an approach or between valid alternatives, so they belong in `/kramme:siw:resolve-audit` even if the total confidence reaches the active threshold.

**NEVER** apply a fix that changes the meaning, scope, or intent of any requirement. Fixes correct form, not substance.

**NEVER** invent information not already present in the spec. Every fix must derive from content that already exists somewhere in the spec files.

**NEVER** skip the spot-check verification after applying a fix. If verification fails, revert the edit and reclassify the finding.

## Process Overview

```
/kramme:siw:spec-audit:auto-fix [audit-report-path] [--auto] [--dry-run] [--threshold N]
    |
    v
[Step 1: Locate Report and Spec Files]
    |
    v
[Step 2: Extract Findings]
    |
    v
[Step 3: Score & Classify Findings] -> Confidence 0-100 -> AUTO-FIXABLE or REQUIRES_DECISION
    |
    v
[Step 4: Approval Gate] -> User confirms (skip with --auto, stop with --dry-run, adjust with --threshold)
    |
    v
[Step 5: Apply Fixes] -> Edit spec files, spot-check each fix
    |
    v
[Step 6: Update Audit Report] -> Annotate fixed findings
    |
    v
[Step 7: Summary]
```

---

## Step 1: Locate Report and Spec Files

### 1.1 Parse Arguments

Extract control flags from `$ARGUMENTS`:
- `--auto` → set `AUTO_MODE=true`
- `--dry-run` → set `DRY_RUN=true`
- `--threshold N` → set `CONFIDENCE_THRESHOLD=N` (validate 50-100, default 80)
- Remaining markdown path token → candidate report path

### 1.2 Find Report

If a report path was provided, use it directly.

Otherwise, auto-detect in order:
1. `siw/AUDIT_SPEC_REPORT.md`
2. `AUDIT_SPEC_REPORT.md` (project root)

If no report found:

```
No spec audit report found.

Run /kramme:siw:spec-audit first to generate one.

Expected locations:
  - siw/AUDIT_SPEC_REPORT.md
  - AUDIT_SPEC_REPORT.md
```

**Action:** Abort.

### 1.3 Read Report and Spec Files

1. Read the report file completely.
2. Extract the spec file paths from the report header ("Spec Files Reviewed").
3. Read every referenced spec file completely.

If a spec file no longer exists at its path, warn and skip all findings for that file.

### 1.4 Check for Uncommitted Changes

Run `git status` on the spec files. If any have uncommitted changes, warn:

```
Warning: {file} has uncommitted changes. Auto-fixes will be applied on top of these changes.
```

With `--auto`, continue with the warning. Otherwise, ask:

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

## Step 2: Extract Findings

Parse all `### SPEC-NNN: {title}` headings from the report.

For each finding, extract:
- Finding ID and title
- Dimension
- Severity
- Location (source file > section heading)
- Details (including quotes from the spec)
- Recommendation
- Fix Confidence (if present in the report)

**Skip findings that match any of:**
- Already marked `**Status:** [Auto-fixed]` (from a previous run)
- Contains `Existing issue:` note (already tracked via SIW)

If no actionable findings remain:

```
No actionable findings to process.

{If all auto-fixed:} All {N} findings were previously auto-fixed.
{If all have issues:} All {N} findings already have SIW issues.
```

**Action:** Stop.

---

## Step 3: Score & Classify Findings

Read the classification rubric from `references/classification-rubric.md`.

For each extracted finding, assign a **fix confidence score** (0-100):

1. Score each of the four conditions (0-25): Determinism, Information Availability, Meaning Preservation, Alternative Absence.
2. Sum the four scores for the finding's confidence (0-100).
3. Apply safety caps — safety-capped findings are forced to confidence 0 regardless of score.
4. If the audit report already includes a `Fix Confidence` score for a finding, use it as a starting point and adjust only if the rubric evaluation yields a materially different score. If the report is from an older format and has no `Fix Confidence` line, score the finding from scratch.

Classify based on the final confidence vs `CONFIDENCE_THRESHOLD` (default 80):
- safety-capped finding → **REQUIRES_DECISION** regardless of threshold
- finding with `Determinism < 15` or `Alternative Absence < 15` → **REQUIRES_DECISION** regardless of threshold
- non-safety-capped finding with confidence >= `CONFIDENCE_THRESHOLD` → **AUTO-FIXABLE**
- otherwise → **REQUIRES_DECISION**

Display confidence tier labels alongside scores:
- 90-100: MECHANICAL
- 75-89: HIGH_CONFIDENCE
- 50-74: MODERATE_CONFIDENCE
- 0-49: REQUIRES_DECISION

### 3.1 Present Classification

```
Finding Classification (threshold: {CONFIDENCE_THRESHOLD})
==========================================================

Auto-fixable ({N} findings at or above threshold):
{For each:}
  {SPEC-NNN} ({Severity}/{Dimension}) [confidence: {score} — {tier}]: {one-line description of the fix}

Requires decision ({M} findings below threshold):
{For each:}
  {SPEC-NNN} ({Severity}/{Dimension}) [confidence: {score} — {tier}]: {one-line reason}
{For safety-capped:}
  {SPEC-NNN} ({Severity}/{Dimension}) [safety cap]: {one-line reason}

Skipped: {K}
{For each:}
  {SPEC-NNN}: {reason — already auto-fixed or has SIW issue}
```

If no findings at or above threshold:

```
No auto-fixable findings at threshold {CONFIDENCE_THRESHOLD}. All {N} findings require decisions.
{If any findings score 50-79:}
Tip: {count} finding(s) scored 50-79. Use --threshold 60 to include moderate-confidence fixes.

Next: /kramme:siw:resolve-audit {report_path}
```

**Action:** Stop.

---

## Step 4: Approval Gate

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

Proceed directly to Step 5 with all auto-fixable findings.

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

---

## Step 5: Apply Fixes

### 5.1 Order Fixes

Group findings by spec file, then sort by location within each file (top of document to bottom). Processing top-to-bottom avoids line-offset drift from earlier edits.

### 5.2 Apply Each Fix

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

### 5.3 Fix Application Rules

- **One fix at a time.** Complete the full apply-verify cycle for one finding before starting the next.
- **Minimal edits.** Change only what the finding requires. Do not improve surrounding text.
- **Preserve formatting.** Match the existing style of the spec (heading levels, list markers, whitespace).
- **Never add content not derivable from the spec.** If the fix requires inventing new requirements, constraints, or behaviors, it is not mechanical — revert and reclassify.

---

## Step 6: Update Audit Report

### 6.1 Annotate Fixed Findings

For each successfully fixed finding, add annotations to its report entry:

After the `**Severity:**` line, add:
```
**Status:** [Auto-fixed]
```

Then handle `Fix Confidence` as follows:
- If the entry already contains `**Fix Confidence:**`, replace that line with the final score and tier from the auto-fix pass.
- If the entry does not contain `**Fix Confidence:**` (legacy report), insert:
```
**Fix Confidence:** {score}/100 ({tier})
```

After the confidence line, add:
```
**Fix applied:** {one-line description of the change}
```

### 6.2 Update Summary Counts

In the severity count table at the top of the report, add a row:

```
| Auto-fixed | {count} |
```

### 6.3 Document Failures

If any findings failed verification and were reclassified, add a section at the end of the report:

```markdown
## Auto-Fix Notes

The following findings were initially classified as mechanical but failed verification
and have been reclassified as requiring decisions:

- **{SPEC-NNN}:** {failure reason}
```

### 6.4 Update Overall Assessment

If all Critical and Major findings were auto-fixed and only Minor findings remain, update the overall assessment line to reflect the improved state.

---

## Step 7: Summary

Use the summary template from `assets/auto-fix-summary.md`.

**STOP HERE.** Wait for the user's next instruction.

---

## Usage Examples

```bash
# Default (balanced — fixes mechanical + high-confidence findings)
/kramme:siw:spec-audit:auto-fix

# Stricter pass (higher confidence bar)
/kramme:siw:spec-audit:auto-fix --threshold 90

# Aggressive (includes moderate-confidence fixes)
/kramme:siw:spec-audit:auto-fix --threshold 60

# Preview what aggressive mode would fix
/kramme:siw:spec-audit:auto-fix --dry-run --threshold 60

# Auto-apply all auto-fixable findings without asking
/kramme:siw:spec-audit:auto-fix --auto

# Auto-apply with lower threshold
/kramme:siw:spec-audit:auto-fix --auto --threshold 70

# Most permissive allowed threshold
/kramme:siw:spec-audit:auto-fix --dry-run --threshold 50
```

---

## Error Handling

### Report Format Unexpected
If the report does not contain `### SPEC-NNN:` headings, stop:
```
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
If the Edit tool fails (e.g., old_string not found because the spec was modified since the audit):
- Warn: `Edit failed for SPEC-{NNN}: text has changed since audit`
- Skip this finding and reclassify as `REQUIRES_DECISION`
- Continue with remaining findings

### All Fixes Fail
If every mechanical fix fails verification:
```
All {N} mechanical fixes failed verification.
The spec may have changed significantly since the audit.

Recommended: Re-run /kramme:siw:spec-audit to get a fresh report.
```
