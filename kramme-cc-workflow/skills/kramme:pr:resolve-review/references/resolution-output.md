# Resolution Output

## Review file routing and lifecycle

Write resolutions to the appropriate file in the project root:

- If the source review was `UX_REVIEW_OVERVIEW.md` → update `UX_REVIEW_OVERVIEW.md` in place
- If the source review was `PRODUCT_REVIEW_OVERVIEW.md` → update `PRODUCT_REVIEW_OVERVIEW.md` in place
- If the source review was `COPY_REVIEW_OVERVIEW.md` → update `COPY_REVIEW_OVERVIEW.md` in place
- If the source review was `CONVENTION_REVIEW_OVERVIEW.md` → update `CONVENTION_REVIEW_OVERVIEW.md` in place
- Otherwise → create or update `REVIEW_OVERVIEW.md`

Updates are **in place**: for each processed finding, replace or add its `Resolution status:` and `Action taken:` fields inside the existing entry. When a reopened manual finding is completed, apply the completed-decision replacement required by Step 2d. Findings present in the source but not addressed in this run (severity-filtered, out-of-scope, already processed, or unrelated) stay verbatim — never delete entries. If the source did not exist (review came from chat or `gh`), create a fresh `REVIEW_OVERVIEW.md` containing every processed finding.

## External review template

Use this format for each comment:

#### Comment #N: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Reviewer's comment:**

> [Quote the original review comment]

**Assessment:** Agree / Agree With Modifications / Disagree

**Rationale:** [Why you agree or disagree with this feedback]

**Resolution status:** open | addressed | deferred | acknowledged | skipped

**Action taken:** [Description of the fix implemented, deferral/acknowledgement/skip, or why the finding remains open]

**Draft reply:**

> [Suggested response to post to the reviewer]

---

## Internal review template

Use this simplified format for each finding:

#### Finding #N: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Issue:** [Description of the issue]

**Resolution status:** open | addressed | deferred | acknowledged | skipped

**Action taken:** [Description of the fix implemented, deferral/acknowledgement/skip, or why the finding remains open]

---

## Out-of-scope template

If any findings were identified as scope creep, document them:

#### Deferred: [Brief description]

**Location:** `path/to/file.ts:123` or `review-scope`

**Finding:**

> [Quote the original finding/comment]

**Resolution status:** deferred

**Reason deferred:** [Why this is out of scope for this PR]

**Action taken:** Deferred — out of scope.

**Recommendation:** [Suggested follow-up: create a separate PR, open an issue, discuss with team, etc.]

---

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
