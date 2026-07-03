## Review Resolution Overview

#### Finding #1: OWASP source manifest still points at the generic project page

**Location:** `kramme-cc-workflow/skills/kramme:code:harden-security/SKILL.md:142`

**Issue:** The harden-security skill now maps `references/owasp-top-10.md` to OWASP Top 10:2025, but the source manifest still pointed at the generic OWASP Top Ten project page with an old review date.

**Resolution status:** addressed

**Action taken:** Updated the OWASP source manifest to the specific Top 10:2025 URL, refreshed the review date and baseline hash, added the normalized OWASP 2025 source snapshot, and removed the now-obsolete empty-hash allowance from the synced-contracts config.

---

#### Finding #2: MarkItDown sources were broadened but the baselines were not refreshed

**Location:** `kramme-cc-workflow/skills/kramme:docs:to-markdown/references/sources.yaml:5`

**Issue:** The docs-to-markdown skill added Azure Content Understanding guidance from current MarkItDown sources, but the source manifest kept stale dates and hashes.

**Resolution status:** addressed

**Action taken:** Refreshed the MarkItDown README and CLI source manifest dates and hashes, and updated both normalized source snapshots to match the current upstream content.

---

## Summary

- Addressed 2 findings.
- Deferred 0 findings as out of scope.
- Validation passed:
  - `make -C kramme-cc-workflow skill-contracts`
  - `make -C kramme-cc-workflow skill-security-changed SKILLSPECTOR_FAIL_ON=high`
  - `git diff --check HEAD`
- No API contract or config behavior breaking changes.
- Manual verification: none required.
