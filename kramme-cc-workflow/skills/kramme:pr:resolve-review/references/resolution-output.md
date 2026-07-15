# Resolution Output

## Manual findings

Use this format for every finding routed through Step 2d's manual-proposal flow, including `Action class: manual` findings and process-level external or legacy findings without an action class.

Extend the existing internal- or external-review entry with the proposal-field suffix below. Append each field inside the existing entry while preserving that entry's field marker and indentation; the bold field names below are semantic placeholders, not a replacement layout. Do not replace an external comment entry with the internal finding template.

**Manual blocker:** [Preserved from the review when present]

**Next human decision:** [Preserved from the review when present]

**Recommended resolution:** [Concrete recommendation answering the next human decision — what to change, where, and why this option wins]

**Alternatives:** (omit when no genuinely distinct option exists)

- [Option — one-line trade-off versus the recommendation]

End the suffix with exactly one next-step field that matches who can act:

**To proceed:** [For a user-selectable code or process decision: reply naming this finding and the chosen option, then rerun `/kramme:pr:resolve-review`. Code changes enter implementation; accepted process decisions transition to `Selected resolution` and `Process handoff`.]

**Process handoff:** [For an accepted process decision: record `Selected resolution`, then name the exact command or workflow that applies it; keep deferred until completion is confirmed.]

**Waiting on:** [For a decision the user cannot supply: the required owner, approval, or access; do not invite the user to choose an option or rerun.]

A selected code resolution becomes retry-eligible implementation state, not another pending decision. Before implementation, remove the decision-pending fields (`Manual blocker`, `Next human decision`, `Recommended resolution`, `Alternatives`, `To proceed`, and `Waiting on`) and record **Selected resolution**. If implementation or validation fails, retain **Selected resolution**, keep **Resolution status: open**, and record the failed attempt in **Action taken**. On the next run, retry that selected resolution without asking for the same decision again.

After the finding is completed, remove the decision-pending fields and any `Process handoff` or `Waiting on` field, retain or record:

**Selected resolution:** [The option or process decision that was chosen]

**Decision outcome:** [What was implemented or completed, including the relevant files or process action]

Do not leave proposal-only fields on an addressed or acknowledged finding.

## Summary

At the end, include:

- Summary of changes made.
- Count of findings: N addressed, M deferred as out-of-scope, R open selected-resolution retries or blocked implementations, A manual findings awaiting a user decision, P accepted process handoffs awaiting completion, and X manual findings waiting on an external owner, approval, or access.
- Any breaking changes to API contracts or config behavior.
- Areas that need manual verification due to potential edge cases or risk.
