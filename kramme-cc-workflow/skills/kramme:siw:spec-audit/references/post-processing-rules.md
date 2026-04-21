# Post-Processing Rules

## Merged Findings

- When a merged finding spans both deprioritized and non-deprioritized dimensions, treat the non-deprioritized dimension as authoritative for severity capping. Only findings whose affected dimensions are entirely deprioritized may be capped to Minor in `Step 4.3.5`.
- When you merge duplicate findings, keep a single `Fix Confidence` field for the merged entry. Re-score the merged finding against the same four-condition rubric using the consolidated details and recommendation, then re-apply the same tier boundaries, four sub-score guardrails, and safety caps before writing the provisional merged value. Do not average the original agent scores.

## Final Fix Confidence

After final severity assignment and any Work Context downgrades, recompute each finding's final `Fix Confidence` using the same four-condition rubric on the consolidated details and final recommendation.

- Re-apply the shared tier boundaries, four sub-score guardrails, and safety caps against the **final** severity, but do **not** clear a safety cap that already applied before a Work Context downgrade.
- If `Step 4.3.5` recorded `original_severity=Critical` for a Completeness, Scope, or Value Proposition finding, keep its final `Fix Confidence` at `0/100 (REQUIRES_DECISION)` and preserve the `Severity Note` so downstream auto-fix passes still treat it as safety-capped.
- Replace any earlier provisional score if severity, recommendation wording, or merged details changed during consolidation.
- Track `preserved_critical_caps_count`: the number of final Minor findings whose `Severity Note` says `capped at Minor from Critical`.
- Use this normalized value and `preserved_critical_caps_count` in the report output and downstream issue/summary logic.

## Overall Assessment After Severity Caps

- Any dimension that contains a final Minor finding with `**Severity Note:** [Deprioritized — capped at Minor from Critical]` is still `Weak`, even though the displayed severity is Minor.
- Any report with `preserved_critical_caps_count > 0` must not be assessed as `Ready for implementation`.

## Issue-Eligible Findings

Before creating issue files, determine the selected findings set:

- **Critical and major only** → include all visible Critical and Major findings, plus any Minor finding with `**Severity Note:** [Deprioritized — capped at Minor from Critical]` or `**Severity Note:** [Deprioritized — capped at Minor from Major]`
- **All findings** → include every finding
- **Let me select** → present all findings, and clearly label Minor findings with preserved Critical or Major severity so their original urgency is not lost during selection
