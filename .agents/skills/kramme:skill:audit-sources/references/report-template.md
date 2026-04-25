# Report Template

Skeleton for the audit report written to `.context/skill-source-audit-<YYYYMMDD-HHMM>.md` in Phase 6.

Fill in placeholders surrounded by `{{ }}`. Omit empty sections (no "Errors: none" filler).

```markdown
# Skill Source Audit — {{YYYY-MM-DD HH:MM}}

**Scope:** {{argument the user passed, e.g. `kramme:code:*` or `all`}}
**Targets:** {{N skills processed}}

## Summary

| Skill | Sources | Changed | Unchanged | Errors | Bootstrapped |
|---|---:|---:|---:|---:|:---:|
| {{kramme:code:harden-security}} | {{3}} | {{1}} | {{2}} | {{0}} | {{—}} |
| {{kramme:pr:ux-review}} | {{2}} | {{0}} | {{2}} | {{0}} | {{✓}} |

Totals: {{X changed, Y unchanged, Z errors, B bootstrapped}}

---

## {{kramme:code:harden-security}}

### Changed sources

#### {{owasp-top-10}} — {{OWASP Top 10 (2021)}}

- **URL:** {{https://owasp.org/www-project-top-ten/}}
- **Last reviewed:** {{2026-01-15}}
- **Hash:** `{{sha256:abc...}}` → `{{sha256:def...}}`

{{Verbatim model output from comparison-prompt.md, including the "Suggestion summary", "Specific additions", and "Notes" sections.}}

### Unchanged sources

- {{cwe-top-25}} ({{CWE Top 25}}) — last reviewed {{2026-01-15}}
- {{snyk-vuln-db}} ({{Snyk Vulnerability DB}}) — last reviewed {{2026-01-15}}

### Errors

{{Omit this subsection if no errors. Otherwise:}}

- {{source-id}} — {{fetch failed: 503 from origin}}

---

## {{kramme:pr:ux-review}}

### Bootstrapped

Manifest created at `kramme-cc-workflow/skills/kramme:pr:ux-review/references/sources.yaml` with {{N}} sources. No baselines yet — first audit will populate them.

Proposed sources:

- {{nielsen-heuristics}} — {{https://www.nngroup.com/articles/ten-usability-heuristics/}}
- {{laws-of-ux}} — {{https://lawsofux.com/}}

{{Continue per skill...}}

---

## Next steps

1. Open this report and decide which suggestions to fold into each `SKILL.md`.
2. To apply a specific suggestion, hand the relevant section back to Claude with:
   > Apply the suggestion under "## {{kramme:code:harden-security}} → {{owasp-top-10}}" to the corresponding `SKILL.md`.
3. After accepting changes, re-run `/kramme:skill:audit-sources <skill>` and confirm "update baselines" to lock in the new state.
```

## Notes for the audit skill

- Render the summary table even when only one skill is in scope.
- For sources where the bootstrap was skipped, list under a "Skipped" subsection with the user's stated reason if any.
- Keep verbatim excerpts inside the model's output — do not paraphrase or summarize them in the report.
- If the entire audit produced no changed sources and no bootstraps, still write the report (a clean run is a useful artifact) — short body is fine.
