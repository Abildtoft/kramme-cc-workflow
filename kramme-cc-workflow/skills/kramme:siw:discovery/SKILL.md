---
name: kramme:siw:discovery
description: Strengthen SIW specifications through a targeted discovery interview. Reviews spec quality gaps, asks structured tradeoff questions, and produces concrete improvements for SIW spec files.
argument-hint: "[spec-file-path(s) | 'siw'] [--apply]"
disable-model-invocation: true
user-invocable: true
---

# SIW Spec Discovery

Strengthen SIW spec quality before issue generation or implementation. This command runs a focused interview against SIW quality dimensions and outputs concrete spec improvements.

Use this when the spec feels incomplete, vague, risky, or hard to implement.

## Process Overview

```
/kramme:siw:discovery [spec-file(s) | 'siw'] [--apply]
    |
    v
[Step 1: Resolve SIW spec files]
    |
    v
[Step 2: Build quality gap map]
    |
    v
[Step 3: Run targeted discovery interview]
    |
    v
[Step 4: Write strengthening plan]
    |
    v
[Step 5: Optional apply] -> update spec files + log decisions
```

## Step 1: Resolve Spec Files

Resolve target files using this order:

1. Parse flags and remaining arguments from `$ARGUMENTS`
2. Explicit file paths from remaining arguments
3. `siw/` auto-detection (main spec + `siw/supporting-specs/*.md`)

### 1.1 Parse Arguments and Flags

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--apply` is present, set `apply_changes=true` and remove `--apply` from the argument list before file resolution.
- Treat remaining arguments as either explicit file paths, the `siw` keyword, or empty input.
- If remaining arguments are empty after flag extraction, default to `siw` auto-detection.

Auto-detection rules:
- Include `siw/*.md` except `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_IMPLEMENTATION_REPORT.md`, `AUDIT_SPEC_REPORT.md`, `SPEC_STRENGTHENING_PLAN.md`
- Include `siw/supporting-specs/*.md`
- If no spec files are found, stop and ask the user to run `/kramme:siw:init` first

If `siw/AUDIT_SPEC_REPORT.md` exists, read it and use unresolved findings as input signals.

## Step 2: Build Quality Gap Map

Analyze the spec files against these SIW quality dimensions:

1. Coherence
2. Completeness
3. Clarity
4. Scope definition
5. Actionability
6. Testability
7. Value proposition
8. Technical design

Create a short gap map:
- Dimension
- Severity (`critical|major|minor`)
- Affected file/section
- One-line problem summary

Prioritize the top 3-5 highest-impact gaps for interview focus.

## Step 3: Run Targeted Discovery Interview

Use AskUserQuestion for each round. Ask 1-3 high-value questions per round.

### Question Rules

For each question, always include:
- **Why this matters** (1-2 sentences)
- **Recommendation** (preferred option + rationale)

Ask options that force concrete tradeoffs (2-4 options, plus user "Other").

### Interview Focus by Dimension

- **Completeness**: Missing requirements, edge cases, non-functional constraints
- **Clarity**: Ambiguous language, undefined terms, unclear acceptance criteria
- **Scope**: Out-of-scope boundaries, phase cut lines, anti-goals
- **Actionability**: Task breakdown quality, handoff readiness, sequencing
- **Testability**: Verifiable outcomes, measurable success criteria, failure criteria
- **Technical design**: Data contracts, API behavior, state ownership, migration details

Stop when:
- Major gaps are resolved by decisions, or
- Further questions produce low-value churn

## Step 4: Write Strengthening Plan

Write `siw/SPEC_STRENGTHENING_PLAN.md` with:

1. **Summary**: what was weak and what changed
2. **Decisions made**: decision, rationale, impacted section
3. **Spec patch plan**: per-file checklist of exact edits
4. **Open questions**: unresolved items blocking confidence
5. **Suggested next command**:
   - `/kramme:siw:audit-spec` to validate improvements
   - `/kramme:siw:generate-phases` or `/kramme:siw:define-issue` when ready

## Step 5: Optional Apply (`--apply`)

If `apply_changes=true` (`--apply` was provided), or the user explicitly asks to apply changes:

1. Edit spec files directly using decisions from Step 3
2. Preserve file structure and headings where possible
3. Add missing sections instead of scattering content
4. Update `siw/LOG.md` with:
   - summary of spec hardening
   - key decisions
   - remaining open questions

If not applying, keep this command planning-only.

## Output Quality Bar

Do not finish with generic advice like "improve clarity".

Every recommendation must be:
- tied to a specific section
- phrased as an actionable edit
- testable after modification

## Usage

```
/kramme:siw:discovery
# Auto-detect SIW specs and run targeted spec-strengthening interview

/kramme:siw:discovery siw/FEATURE_SPEC.md
# Focus discovery on one spec file

/kramme:siw:discovery siw --apply
# Discover and directly apply spec improvements
```
