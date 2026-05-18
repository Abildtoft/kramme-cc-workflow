# Review Resolution

Source: GitHub PR #336 inline review comments

#### Comment #1: Abort path skips rollback

**Location:** `kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:60`

**Reviewer's comment:**

> The "Abort" path says no rollback is needed, but this workflow stashes changes in Step 5 and also defines a general abort/rollback procedure (Step 10 in the main skill). Aborting here without rollback can leave the user on the modified branch with stashed changes still hidden, which contradicts the "changes remain local" message. Consider aligning this section to explicitly invoke the rollback procedure when any state-preservation steps may have run (or clarify when it's safe to skip rollback).

**Assessment:** Agree

**Rationale:** Step 8 runs after state preservation, so aborting from the confirmation path should use the main rollback handler rather than claiming rollback is unnecessary.

**Action taken:** Replaced the local abort message with an explicit instruction to execute Step 10: Abort and Rollback Handling from the main skill, restoring the original branch, original commit, and any Step 5 stash.

**Draft reply:**

> Addressed by routing the Step 8 abort path through the main skill's Step 10 abort and rollback handler, including original branch/commit restoration and stash restoration.

---

#### Comment #2: Draft preview and confirmation examples are ambiguous

**Location:** `kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:22`

**Reviewer's comment:**

> This preview example always shows the non-draft header/status, even though the surrounding text requires draft-specific substitutions when `DRAFT_MODE=true`. To avoid ambiguity for agents/users, either show both variants (draft vs ready) or annotate the example as the non-draft form and provide the draft form explicitly.

**Assessment:** Agree

**Rationale:** The reference is intended to be loaded independently at Step 8, so the examples should be self-contained for both draft and ready-for-review flows.

**Action taken:** Split the preview and confirmation examples into explicit `DRAFT_MODE=false` and `DRAFT_MODE=true` variants, including draft-specific header, status, question, label, and description text.

**Draft reply:**

> Addressed by making the Step 8 preview and confirmation examples explicit for both `DRAFT_MODE=false` and `DRAFT_MODE=true`, including draft-specific wording.

---

#### Comment #3: Product-audit placeholder names diverge

**Location:** `kramme-cc-workflow/skills/kramme:siw:product-audit/references/product-reviewer-prompt.md:24`

**Reviewer's comment:**

> The intro says to fill in `{previous findings}`, but the prompt template below uses a different placeholder (`{list of previously resolved PROD-NNN findings, or "None - first review"}`). Align the placeholder naming in the instructions with the template so it's clear what text should be substituted.

**Assessment:** Agree

**Rationale:** The launch instructions and prompt template should use the same placeholder name so callers know which value to substitute.

**Action taken:** Kept `{previous findings}` as the placeholder in both the intro and template, and documented that it should contain previously resolved `PROD-NNN` findings or `None - first review`.

**Draft reply:**

> Addressed by using `{previous findings}` consistently in the intro and prompt template, with the expected value described next to the placeholder.

---

## Summary

- Summary of changes made: clarified PR creation draft/ready examples, routed confirmation aborts through the main rollback handler, and aligned the SIW product-audit previous-findings placeholder.
- Count of findings: 3 addressed, 0 deferred as out-of-scope.
- Breaking changes: None.
- Manual verification: None required beyond the passing documentation and conversion checks.
