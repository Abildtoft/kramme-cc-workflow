# Review Result Parsing

Use this after review overview files are produced.

## Code Review Overview

Parse `REVIEW_OVERVIEW.md` as follows:

- Count findings by severity: critical, important, suggestion.
- Inspect each critical/important code-review finding's action class and structured `Location` field:
  - Prefer the explicit `Location:` field from the structured finding schema.
  - If `Location:` is missing, fall back to inline `[location]` text only for legacy reports.
  - `Action class: gated_auto` with `path/to/file:line` = code-backed finding, eligible for `/kramme:pr:resolve-review`.
  - `Action class: manual` = manual follow-up, even when the finding has a file location.
  - `Action class: advisory` on a critical/important finding = invalid review schema; treat as manual follow-up and record a `COULD NOT AUTO-FIX: invalid action class` caveat.
  - `review-scope` or any broader non-file scope label = process-level blocker, manual follow-up.
  - Missing action class in a legacy report = manual follow-up unless the finding is explicitly identified as auto-resolvable.
  - Missing location after both explicit-field and legacy-inline parsing = manual follow-up; record `COULD NOT AUTO-FIX: missing Location`.
- Keep separate tallies for eligible `gated_auto` code-backed vs manual/process-level critical/important code-review findings.
- Store each eligible `gated_auto` finding as `ELIGIBLE_REVIEW_FIXES` with `Finding ID` as source id, severity, location, finding text, action class, owner, confidence, and evidence.
- If an eligible finding has no `Finding ID`, do not invent one from position or prose. Treat it as manual follow-up and record `COULD NOT AUTO-FIX: missing Finding ID`.
- Critical findings = blockers.

## Product Review and UX Review Overviews

For `PRODUCT_REVIEW_OVERVIEW.md` and `UX_REVIEW_OVERVIEW.md`:

- Count findings by severity: critical, important, suggestion.
- Critical findings = blockers.
