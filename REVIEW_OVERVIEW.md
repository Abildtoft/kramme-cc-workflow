#### Comment #1: Align discovery brief headings with import rules

**File:** `kramme-cc-workflow/skills/kramme:siw:discovery/assets/discovery-brief-template.md:24`

**Reviewer's comment:**

> The brief template nests `Objectives`, `Success Looks Like`, and `What You Don't Want` under `What You Actually Want`, but the import rules expect them as standalone sections.

**Assessment:** Agree

**Rationale:** The new template structure and the import instructions had drifted apart, which made the handoff contract ambiguous.

**Action taken:** Promoted those three headings to top-level `##` sections and documented backward-compatible extraction for older nested briefs in `kramme-cc-workflow/skills/kramme:siw:init/references/discovery-brief-import.md`.

**Draft reply:**

> Aligned the template and the import contract. The brief now emits those sections as top-level headings, and the import instructions explicitly handle older nested briefs as a compatibility path.

---

#### Comment #2: Standardize `AUDIT_*.md` exclusion in `issues-reindex`

**File:** `kramme-cc-workflow/skills/kramme:siw:issues-reindex/SKILL.md:204`

**Reviewer's comment:**

> `issues-reindex` still enumerates audit report filenames explicitly while `generate-phases` already uses the broader `AUDIT_.*\.md` pattern.

**Assessment:** Agree

**Rationale:** The explicit filenames would drift if more audit artifacts were introduced.

**Action taken:** Replaced the explicit audit filenames with `AUDIT_.*\.md` in `issues-reindex`.

**Draft reply:**

> Updated `issues-reindex` to use the same `AUDIT_.*\.md` exclusion pattern as the other SIW spec-detection paths.

---

#### Comment #3: Fix cleanup note vs. `siw:remove` behavior

**File:** `kramme-cc-workflow/skills/kramme:workflow-artifacts:cleanup/SKILL.md:12`

**Reviewer's comment:**

> The cleanup note says `/kramme:siw:remove` leaves discovery artifacts alone, but `siw:remove` actually deletes them.

**Assessment:** Agree With Modifications

**Rationale:** The inconsistency was real, but the right fix here is to clarify the two commands' roles rather than make `siw:remove` preserve artifacts by default.

**Action taken:** Updated the cleanup note to say this cleanup command preserves the handoff artifacts while `/kramme:siw:remove` deletes them as part of destructive SIW cleanup.

**Draft reply:**

> Clarified the command split: `workflow-artifacts:cleanup` preserves discovery handoff artifacts, while `siw:remove` is explicitly destructive and removes them.

---

#### Comment #4: Preserve `Deferred` scope during `siw:close`

**File:** `kramme-cc-workflow/skills/kramme:siw:close/SKILL.md:202`

**Reviewer's comment:**

> `siw:close` only documents extracting In Scope and Out of Scope, so the new `Deferred` subsection would be dropped.

**Assessment:** Agree

**Rationale:** The discovery-derived spec template already emits a three-way scope split, so close-out instructions and templates need to carry the same shape through.

**Action taken:** Updated `siw:close` to extract `Deferred` alongside In Scope and Out of Scope, and added a `Deferred` section to the close README template.

**Draft reply:**

> Added `Deferred` to the documented scope extraction in `siw:close` and to the generated close-out README template so the three-way split survives close.

---

#### Comment #5: Clarify `siw:remove` as destructive cleanup

**File:** `kramme-cc-workflow/skills/kramme:siw:remove/SKILL.md:9`

**Reviewer's comment:**

> `siw:remove` always deletes `SPEC_STRENGTHENING_PLAN.md`, which conflicts with `siw:close` allowing users to keep or move it.

**Assessment:** Agree With Modifications

**Rationale:** `siw:remove` is the wipe-the-workflow command, so duplicating `siw:close`'s preservation prompt would blur the distinction between the two skills.

**Action taken:** Documented `siw:remove` as the destructive cleanup path and explicitly directs users to `/kramme:siw:close` when they need to preserve or archive `SPEC_STRENGTHENING_PLAN.md`.

**Draft reply:**

> Kept `siw:remove` destructive by design, but made that contract explicit and now point preservation cases to `siw:close`, which is the workflow that offers keep/move/discard handling.

---

#### Comment #6: Use wildcard audit exclusions in `implementation-audit`

**File:** `kramme-cc-workflow/skills/kramme:siw:implementation-audit/SKILL.md:125`

**Reviewer's comment:**

> The exclusion list explicitly names audit files instead of using the broader `AUDIT_.*\.md` pattern.

**Assessment:** Agree

**Rationale:** The wildcard form is more maintainable and matches the rest of the SIW spec-detection guidance.

**Action taken:** Replaced the explicit audit exclusions with `AUDIT_.*\.md`.

**Draft reply:**

> Switched `implementation-audit` to the wildcard audit exclusion so it stays aligned with the other SIW spec-discovery rules.

---

#### Comment #7: Use wildcard audit exclusions in `spec-audit`

**File:** `kramme-cc-workflow/skills/kramme:siw:spec-audit/SKILL.md:104`

**Reviewer's comment:**

> `spec-audit` also lists audit files explicitly instead of using the broader `AUDIT_.*\.md` pattern.

**Assessment:** Agree

**Rationale:** This should match the other SIW commands that auto-detect spec files.

**Action taken:** Replaced the explicit audit exclusions with `AUDIT_.*\.md`.

**Draft reply:**

> Updated `spec-audit` to use the same wildcard audit exclusion pattern as the other SIW spec-detection steps.

---

#### Comment #8: Add a language hint to the confidence dashboard block

**File:** `kramme-cc-workflow/skills/kramme:siw:discovery/references/confidence-framework.md:142`

**Reviewer's comment:**

> Add a language specifier to the ASCII-art confidence dashboard code block.

**Assessment:** Agree

**Rationale:** This is a harmless readability improvement.

**Action taken:** Changed the opening fence to ` ```text ` for the dashboard sample.

**Draft reply:**

> Added a `text` language hint to the dashboard sample for cleaner Markdown rendering.
