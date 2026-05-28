# Fix Confidence Rubric

Use this rubric whenever an agent (standard or team-mode auditor, or the cross-reviewer) reports a provisional `Fix Confidence` for a finding, and again when the lead recomputes the final `Fix Confidence` during post-processing.

## Four-condition scoring (0-25 each, sum to 0-100)

For each finding, score how deterministic a fix would be against these four sub-scores:

1. **Determinism of fix** (0-25) — Is there exactly one correct edit, or is the right shape a judgment call?
2. **Information availability in spec** (0-25) — Does the spec already contain everything the fix needs, or must the implementer go elsewhere?
3. **Meaning preservation** (0-25) — Will the edit leave the spec's intent intact, or does it require re-interpreting requirements?
4. **Absence of alternatives** (0-25) — Are there competing plausible fixes? Reduce the score when alternatives exist.

Sum the four sub-scores into a provisional 0-100 value before applying the guardrails and safety caps below.

Technical Design findings are typically lower confidence than Coherence or Clarity findings because the fix depth and meaning preservation are more subjective.

## Tier boundaries

Apply these to the provisional 0-100 score:

- **90-100** → `MECHANICAL`
- **75-89** → `HIGH_CONFIDENCE`
- **50-74** → `MODERATE_CONFIDENCE`
- **0-49** → `REQUIRES_DECISION`

## Provisional guardrails

Before reporting the score, apply this guardrail:

- If **any** sub-score is below 15, set the provisional score to `0 (REQUIRES_DECISION)` regardless of the four-sub-score sum.

## Safety caps

Set the provisional score to `0 (REQUIRES_DECISION)` if any of the following apply:

- Critical finding in **Completeness**, **Scope**, or **Value Proposition**.
- Recommendation uses decision-signal language: `consider`, `decide whether`, `choose between`, `discuss with`, `evaluate options`.
- The finding adds or removes scope.
- The finding defines success-criteria substance (rather than just measurability of an existing criterion).

## Recomputation rules

When the lead recomputes the final `Fix Confidence` after consolidation and severity assignment:

- Re-score the consolidated finding against the same four sub-scores using the merged details and final recommendation. Do **not** average prior agent scores.
- Re-apply the tier boundaries, sub-score guardrails, and safety caps against the **final** severity.
- Do **not** clear a safety cap that applied before a Work Context downgrade. If `original_severity=Critical` was recorded for a Completeness, Scope, or Value Proposition finding that was later capped to Minor, keep the final `Fix Confidence` at `0/100 (REQUIRES_DECISION)` and preserve its `Severity Note` so downstream auto-fix passes still treat it as safety-capped.
