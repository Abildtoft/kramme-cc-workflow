# Resolution Output

## Manual findings

Use this format for every finding deferred by `Action class: manual`.

Extend the existing internal- or external-review entry with the proposal-field suffix below. Keep the entry shape already defined for that review type; do not replace an external comment entry with the internal finding template.

**Manual blocker:** [Preserved from the review when present]

**Next human decision:** [Preserved from the review when present]

**Recommended resolution:** [Concrete recommendation answering the next human decision — what to change, where, and why this option wins]

**Alternatives:** (omit when no genuinely distinct option exists)

- [Option — one-line trade-off versus the recommendation]

End the suffix with exactly one next-step field that matches who can act:

**To proceed:** [For a user-selectable code change: reply naming this finding and the chosen option, then rerun `/kramme:pr:resolve-review`.]

**Process handoff:** [For an accepted process decision: the exact command or workflow that applies the decision; keep deferred until completion is confirmed.]

**Waiting on:** [For a decision the user cannot supply: the required owner, approval, or access; do not invite the user to choose an option or rerun.]

After the finding is completed, remove the proposal suffix above and record:

**Selected resolution:** [The option or process decision that was chosen]

**Decision outcome:** [What was implemented or completed, including the relevant files or process action]

Do not leave proposal-only fields on an addressed or acknowledged finding.

## Summary

At the end, include:

- Summary of changes made.
- Count of findings: N addressed, M deferred as out-of-scope, K manual findings awaiting a decision (each with a recommended resolution).
- Any breaking changes to API contracts or config behavior.
- Areas that need manual verification due to potential edge cases or risk.
