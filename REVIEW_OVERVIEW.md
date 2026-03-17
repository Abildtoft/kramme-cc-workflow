#### Comment #1: Avoid unconditional `--auto` in pr:create Step 7

**File:** `kramme-cc-workflow/skills/kramme:pr:create/SKILL.md:227`

**Reviewer's comment:**

> Unconditional `--auto` in Step 7 bypasses non-auto safety expectations.

**Assessment:** Agree

**Rationale:** In the current `pr:generate-description` semantics, `--auto` may update an existing PR directly. Using it unconditionally in `pr:create` would let interactive runs mutate the PR before Step 8 confirmation, which breaks the intended confirmation boundary.

**Action taken:** Changed Step 7 to branch on `AUTO_MODE`: auto runs still call `kramme:pr:generate-description --auto`, while non-auto runs call `kramme:pr:generate-description` without args.

**Draft reply:**

> Good catch. I changed Step 7 so only `AUTO_MODE=true` uses `--auto`; interactive runs now invoke `kramme:pr:generate-description` without args so Step 8 remains the guard before PR mutation.

---

### Summary

- Summary of changes made: fixed the `pr:create` Step 7 control flow so interactive runs no longer unconditionally forward `--auto` to `pr:generate-description`.
- Count of findings: 1 addressed, 0 deferred as out-of-scope.
- Note any breaking changes to API contracts or config behavior: none.
- Flag areas that need manual verification due to potential edge cases or risk: none beyond normal review of the updated skill text.
