# Product Audit

**Date:** {date}
**Spec Files Reviewed:** {list}

## Work Context

{If work_context found:}
Work Type: **{work_type}** — {adjustments applied, e.g. "Internal Tool adjustments: market fit analysis skipped"}

{If no work_context found:}
Not specified — full product review applied.

## Summary

{2-3 sentence overall assessment of the spec's product quality. Does it solve the right problem for the right users? Is it scoped to deliver value?}

| Dimension | Assessment |
|-----------|------------|
| Target User Clarity | {Clear/Vague/Missing} |
| Problem/Solution Fit | {Strong/Weak/Missing} |
| User State Modeling | {Thorough/Partial/Missing} |
| Critical Moments Coverage | {Thorough/Partial/Missing} |
| Scope Correctness | {Right-sized/Too broad/Too narrow} |
| Success Criteria Quality | {Measurable/Vague/Missing} |

| Severity | Count |
|----------|-------|
| Critical | {count} |
| Major | {count} |
| Minor | {count} |
| **Total** | **{total}** |

**Overall Assessment:** {Ready for implementation / Needs product revision / Significant product gaps}

## Critical Findings

### PROD-001: {title}

**Dimension:** {dimension}
**Severity:** Critical
**Location:** {spec_file} > {section_heading}
**Details:** {issue with quotes from the spec}
**Product Impact:** {what goes wrong for users if this isn't addressed}
**Recommendation:** {specific action}

---

{Repeat for each critical finding}

## Major Findings

{Same format as Critical}

## Minor Findings

{Same format as Critical}

## Open Questions

- {product questions the spec doesn't address}

## Strengths

- {what the plan does well from a product perspective}

## Recommended Next Actions

1. Address critical findings in the spec
2. Discuss open questions with stakeholders
3. Re-run after spec revisions: `/kramme:siw:product-audit`
4. If ready, proceed to implementation: `/kramme:siw:generate-phases`
