# Spec Audit Report

**Date:** {current date}

**Spec Files Reviewed:** {list of spec files with paths}

## Work Context Applied

{If work_context found:}

| Attribute                | Value       |
| ------------------------ | ----------- |
| Work Type                | {work_type} |
| Priority Dimensions      | {list}      |
| Deprioritized Dimensions | {list}      |

**Effect:** Findings in deprioritized dimensions are capped at Minor severity. If a deprioritized finding was originally Critical or Major, keep the final severity at Minor and record `**Severity Note:** [Deprioritized — capped at Minor from {original_severity}]` so downstream tools preserve the original urgency. Priority dimension findings are strictly evaluated.

{If no work_context found:} Not specified — all dimensions evaluated with equal weight.

## Summary

| Dimension               | Score                          | Findings |
| ----------------------- | ------------------------------ | -------- |
| Coherence               | {Strong/Adequate/Weak/Missing} | {count}  |
| Completeness            | {Strong/Adequate/Weak/Missing} | {count}  |
| Clarity                 | {Strong/Adequate/Weak/Missing} | {count}  |
| Scope                   | {Strong/Adequate/Weak/Missing} | {count}  |
| Actionability           | {Strong/Adequate/Weak/Missing} | {count}  |
| Testability             | {Strong/Adequate/Weak/Missing} | {count}  |
| Rationale Documentation | {Strong/Adequate/Weak/Missing} | {count}  |
| Technical Design        | {Strong/Adequate/Weak/Missing} | {count}  |
| Product                 | {Strong/Adequate/Weak/Missing} | {count}  |

{Include the Product row only when product mode ran (`--product`). If product mode P1 skipped it, show `{PRODUCT_SKIP_REASON}` as its score and `—` as its count.}

| Severity  | Count       |
| --------- | ----------- |
| Critical  | {count}     |
| Major     | {count}     |
| Minor     | {count}     |
| **Total** | **{total}** |

{Severity counts include `PROD-NNN` findings when product mode ran.}

{If preserved critical caps exist:} **Preserved Critical Caps:** {count} (reported as Minor due to Work Context but still decision-required)

**Overall Assessment:** {Ready for implementation / Needs revision / Significant gaps}

## Critical Findings

### SPEC-001: {Brief title}

**Dimension:** {dimension}

**Severity:** Critical

**Fix Confidence:** {score}/100 ({MECHANICAL|HIGH_CONFIDENCE|MODERATE_CONFIDENCE|REQUIRES_DECISION})

**Location:** {source_file} > {source_section}

**Details:** {explanation with quotes from the spec}

**Impact:** {what goes wrong if this isn't fixed}

**Recommendation:** {specific action to fix}

---

{Repeat for each critical finding}

{For each `PROD-NNN` product finding in this severity, use this format instead. Product findings carry no Fix Confidence because they are never auto-fixed:}

### PROD-001: {Brief title}

**Dimension:** Product — {product sub-dimension(s)}

**Severity:** Critical

**Location:** {source_file} > {section_heading}

**Details:** {issue with quotes from the spec}

**Product Impact:** {what goes wrong for users if this isn't addressed}

**Recommendation:** {specific action}

{If related:} **Related:** {SPEC-NNN}

---

## Major Findings

{Same format as Critical}

## Minor Findings

{Same format, without Impact field. If Work Context capped a higher-severity finding into Minor, include `**Severity Note:** [Deprioritized — capped at Minor from {original_severity}]` immediately after the Severity line.}

## Dimension Details

### Coherence: {Score}

{2-3 sentence assessment}

**Strengths:**

- {what's consistent and well-aligned}

**Gaps:**

- {references to relevant SPEC-NNN findings}

{Repeat for each of the 8 dimensions}

## Product Dimension

{Include this section only when product mode ran. If product mode P1 skipped it, write only: `Product dimension: {PRODUCT_SKIP_REASON}.`}

**Product adjustments:** {If Work Type is Internal Tool or Documentation / Process: the adjustments applied, e.g. "Internal Tool adjustments: market fit analysis skipped"} {Otherwise: None — full product review applied.}

### Product Loop Context

{If STRATEGY.md found:} Strategy: {target users, active tracks, relevant metrics, non-goals, and any STALE markers}

{If pulse reports found:} Recent pulse signals: {usage, quality, errors, performance, customer signals, followups relevant to this spec}

{If missing:} MISSING PRODUCT CONTEXT: {which strategy or pulse artifacts were unavailable}

### Product Assessment

{2-3 sentence assessment of the spec's product quality. Does it solve the right problem for the right users? Is it scoped to deliver value?}

| Product sub-dimension | Assessment | Findings |
| --- | --- | --- |
| Target User Clarity | {Clear/Vague/Missing} | {PROD-NNN list} |
| Problem/Solution Fit | {Strong/Weak/Missing} | {PROD-NNN list} |
| User State Modeling | {Thorough/Partial/Missing} | {PROD-NNN list} |
| Critical Moments Coverage | {Thorough/Partial/Missing} | {PROD-NNN list} |
| Scope Correctness | {Right-sized/Too broad/Too narrow} | {PROD-NNN list} |
| Success Criteria Quality | {Measurable/Vague/Missing} | {PROD-NNN list} |
| Prioritization and Decision Quality | {Clear/Fuzzy/Missing} | {PROD-NNN list} |
| Strategy and Pulse Alignment | {Aligned/Conflicting/Unavailable} | {PROD-NNN list} |

### Open Questions

- {product questions the spec doesn't address}

### Assumptions Used

- {only include when the reviewer inferred target user, value, why-now, or non-goals from incomplete specs}

### Product Strengths

- {what the plan does well from a product perspective}

## Sections Present vs. Expected

| Section                        | Status                       | Notes        |
| ------------------------------ | ---------------------------- | ------------ |
| Overview/objectives            | {Present/Missing/Incomplete} | {brief note} |
| Scope and audience             | {Present/Missing/Incomplete} | {brief note} |
| Success criteria               | {Present/Missing/Incomplete} | {brief note} |
| Requirements and constraints   | {Present/Missing/Incomplete} | {brief note} |
| Design decisions               | {Present/Missing/Incomplete} | {brief note} |
| Implementation tasks           | {Present/Missing/Incomplete} | {brief note} |
| Testing/verification checklist | {Present/Missing/Incomplete} | {brief note} |
| Edge cases and considerations  | {Present/Missing/Incomplete} | {brief note} |
| Out of scope                   | {Present/Missing/Incomplete} | {brief note} |
