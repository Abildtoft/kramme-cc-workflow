# Product Mode (`--product`)

Use this when `PRODUCT_MODE=true`, and read P7 even when it is false if the report being replaced holds `PROD-NNN` findings. Product mode adds the **Product** dimension to the audit: product judgment about whether the specification proposes the right product for the right users. The eight readiness dimensions still run unchanged; Rationale Documentation keeps checking only whether product rationale is documented, while the Product dimension judges whether that rationale is right.

Product findings use `PROD-NNN` IDs in the same report as `SPEC-NNN` findings. They are judgment calls: they carry no `Fix Confidence`, are never auto-applied by `--apply` or `$kramme:siw:apply-spec-audit-fixes`, and route to `$kramme:siw:resolve-audit` or SIW issue creation.

`SKILL.md` names the step where each section below runs.

## P1: Work Context Gate (Step 2.3)

If `work_context.work_type` is **Prototype** or **Refactor**, the Product dimension evaluates user-facing concerns that may not apply.

- If `AUTO_MODE=true`, set `PRODUCT_MODE=false`, record `PRODUCT_SKIP_REASON="Skipped — {work_type} Work Context"`, and continue the readiness audit.
- Otherwise ask the user directly in chat:

Ask the user directly in chat:
Question label: Work Context: {work_type}
Question: This spec's Work Context is '{work_type}'. The Product dimension evaluates user-facing concerns that may not apply. Run it anyway?
Suggested options:
- Skip Product dimension — Run only the readiness dimensions
- Proceed anyway — Run the full Product dimension regardless
If the user skips, set `PRODUCT_MODE=false` and `PRODUCT_SKIP_REASON="Skipped by user — {work_type} Work Context"`. Show the skip reason in the report's Product row and in the summary.

For all other work types, continue to P2.

## P2: Load Strategy and Pulse Context (Step 2.3)

Load optional product-loop context:

- If repo-root `STRATEGY.md` exists, read it and extract target problem, approach, who it is for, key metrics, active tracks, milestones if present, and non-goals.
- If its `last_updated` frontmatter is older than 90 days, mark relevant context as `STALE:` in the report.
- If `docs/pulse-reports/` exists, read the 1-3 most recent reports and extract usage, quality, error, performance, customer-signal, and followup highlights that relate to the audited spec.
- If neither exists, continue. Missing strategy or pulse coverage is report context, not a finding by itself unless the spec makes broad product-direction claims that cannot be evaluated without that context.

Store the result as `PRODUCT_LOOP_CONTEXT` for the reviewer agent and the report.

## P3: Extract Product Elements (Step 2.3)

Read `references/product-element-extraction.md`, then identify and extract every listed product element from each spec file. Capture source file, heading hierarchy, and a brief content summary for each element. Add these lines to the Step 2.3 extraction summary:

```
Product elements identified: {count}
Target user defined: {yes/no}
Problem statement found: {yes/no}
Why now documented: {yes/no}
Non-goals documented: {yes/no}
User flows documented: {count}
```

If the spec has no clear product elements, proceed anyway; the absence of product elements is itself a finding.

## P4: Launch the Product Reviewer (Step 3)

1. Compute `previous_max_prod_id` as the highest `PROD-NNN` number found in either the previous report at the Step 5.1 target path (every appended run) or a `siw/issues/` filename containing `PROD-NNN`. IDs are never reused, even when a report replace dropped the finding that first used one. If a previous report exists, parse its active run's `### PROD-NNN:` findings and note which findings are resolved (marked addressed, linked to an existing `siw/issues/` file through `Existing issue:`, or no longer applicable) versus still open. Pass the resolved ones as `{previous findings}` so the reviewer does not re-report them; use `None - first audit` when there are none.
2. Read `references/product-reviewer-prompt.md` and fill its placeholders, including `PRODUCT_LOOP_CONTEXT` and the work-context block (include it only for Internal Tool or Documentation / Process work types).
3. Launch one product-reviewer pass in the same message as the Step 3 readiness agents so it runs in parallel. Use the host runtime's subagent mechanism when it exposes the `kramme:product-reviewer` reviewer; otherwise perform the same review inline in the main thread after the readiness agents return.

## P5: Classify Product Findings (Step 4)

1. Drop reviewer findings whose confidence is below 70, the product reviewer's report threshold.
2. Assign final severity to the rest:

| Severity | Criteria |
| --- | --- |
| **Critical** | Would lead to building the wrong thing or shipping something users can't use. Missing target user, solution doesn't fit problem, no error recovery, undeliverable scope. |
| **Major** | Risks a poor user experience or significant rework. Missing states, weak success criteria, phasing that delays value, gaps in critical moments. |
| **Minor** | Low-risk product concerns. Missing edge states, suboptimal naming, cosmetic flow issues. |

3. Merge product findings that several product sub-dimensions flagged for the same issue and list every affected sub-dimension. Do not merge a `PROD-NNN` finding into a `SPEC-NNN` finding, or the reverse, even when they share a root cause; add `Related: {other-id}` to both instead, so mechanical spec fixes stay separate from product decisions.
4. Assign IDs: still-open findings from P4 keep their `PROD-NNN` IDs; new findings get sequential IDs from `previous_max_prod_id + 1` (or `PROD-001` when there is no previous report), ordered Critical, Major, then Minor.
5. Product findings are exempt from Work Context severity caps (Step 4.3.5) and from Fix Confidence scoring and normalization (Step 4.3.6).
6. Score the **Product** row with the Step 4.4 Strong / Adequate / Weak / Missing rule over `PROD-NNN` findings, using Missing when the spec has no product elements at all. Also assess each product sub-dimension for the report's Product Dimension section.
7. Count product findings in the report's severity totals and overall assessment: any Critical product finding rules out `Ready for implementation`.
8. Cross-reference existing SIW issues in Step 4.5 for product findings exactly as for spec findings.

## P6: Report and Downstream Handling

- Write product findings into the same report using the Product sections of `assets/spec-audit-report-format.md`; product findings appear in the Critical, Major, and Minor sections with `**Dimension:** Product — {sub-dimension}`.
- `--apply` and the **Apply now** choice never edit specs for product findings. After the auto-fix procedure finishes, report the open product findings as left for `$kramme:siw:resolve-audit {report_path}`.
- SIW issue creation treats product findings like spec findings under the same selection rules; `references/issue-creation.md` defines their file name and template differences.

## P7: Carry Product Findings Forward (Step 5.2)

Run this when `PRODUCT_MODE=false` (not requested, or skipped by P1) and the active run of the report at the Step 5.1 target path contains `### PROD-NNN:` findings. It applies to Replace, Append, and inline output, so a readiness-only run never drops product findings that resolve-audit still needs.

1. Copy every `PROD-NNN` finding from the previous active run into the new report unchanged, including `Existing issue:` annotations and `Related:` links, in the matching severity sections.
2. Copy the previous Product Dimension section unchanged and add `Carried from the product pass dated {previous report date}; re-run with --product to refresh.` at its top.
3. Show the Product row from the previous run with `(carried {date})` after its score.
4. Keep the carried findings in severity totals and the overall assessment exactly as P5 step 7 requires.

## Failure Handling

- If the product reviewer returns incomplete results, mark the Product row `Incomplete analysis` and name the affected sub-dimensions.
- If it times out, report that the Product dimension did not complete and suggest re-running with `--product`. Do not fail the readiness audit.
