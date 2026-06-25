# Product Audit Summary Template

Use this during Step 8 to display the final summary after the report is written or prepared inline.

```text
Product Audit Complete

Report: {inline reply | report_path}
{If a prior report was replaced in auto mode:} Replaced previous audit dated {previous_date}.
Findings: {critical_count} Critical, {major_count} Major, {minor_count} Minor
Issues created: {count} (or "None")

Dimensions evaluated:
  - Target User Clarity: {assessed/not assessed}
  - Problem/Solution Fit: {assessed/not assessed}
  - User State Modeling: {assessed/not assessed}
  - Critical Moments Coverage: {assessed/not assessed}
  - Scope Correctness: {assessed/not assessed}
  - Success Criteria Quality: {assessed/not assessed}
  - Prioritization and Decision Quality: {assessed/not assessed}
  - Strategy and Pulse Alignment: {assessed/not assessed}

Suggested next steps:
  - If file output was used: `/kramme:siw:resolve-audit siw/PRODUCT_AUDIT.md`  (address findings)
  - If inline output was used: provide the inline report content to the follow-up workflow
  - /kramme:siw:spec-audit  (technical spec quality audit)
  - /kramme:siw:generate-phases  (when ready for implementation)
```
