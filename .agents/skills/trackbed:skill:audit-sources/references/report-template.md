# Report Template

Skeleton for the audit report written to `.context/skill-source-audit-<YYYYMMDD-HHMM>.md` in Phase 6.

Fill in placeholders surrounded by `{{ }}`. Omit empty sections (no "Errors: none" filler).

```markdown
# Skill Source Audit — {{YYYY-MM-DD HH:MM}}

**Scope:** {{argument the user passed, e.g. `trackbed:code:*` or `all`}} **Targets:** {{N skills processed}} **Upstreams:** {{U upstream groups checked}}

## Summary

| Skill | Sources | Changed | Unchanged | Moved or gone | Skipped | Errors | Bootstrapped |
| --- | --: | --: | --: | --: | --: | --: | :-: |
| {{trackbed:code:harden-security}} | {{3}} | {{1}} | {{2}} | {{0}} | {{0}} | {{0}} | {{—}} |
| {{trackbed:pr:product-review}} | {{2}} | {{0}} | {{2}} | {{0}} | {{0}} | {{0}} | {{✓}} |

Totals: {{X changed, Y unchanged, M moved or gone, S skipped, Z errors, B bootstrapped}} across {{U}} upstreams

---

## Changed upstreams

### {{OWASP Top 10 (2021)}} — {{2}} consuming skills

- **URLs:** {{https://owasp.org/www-project-top-ten/}} ({{trackbed:code:harden-security}} `{{owasp-top-10}}`, {{trackbed:code:audit-security}} `{{owasp-top-10}}`)
- **Change evidence:** {{for a hashed source: `sha256:abc...` → `sha256:def...`; for a GitHub-hosted source: commit history}}
- **Commit window:** {{GitHub-hosted sources only: `<baseline_commit>` (`recorded`, `pinned`, or `derived`) → `<head_commit>`}}
- **Upstream commits:** {{GitHub-hosted sources only: `commit_count`, or "at least `commit_count`; partial list" when `commits_truncated` is true, followed by one line per commit line from scripts/github_changes.py — short SHA, date, first message line}}

#### {{trackbed:code:harden-security}} — {{owasp-top-10}}, last reviewed {{2026-01-15}}

{{Original paraphrased model output from comparison-prompt.md for this skill: "Suggestion summary", "Specific additions", "Removals and reversals", "Conflicts with current skill text", "Already adopted", and "Notes", with source locations. Never include source excerpts.}}

#### {{trackbed:code:audit-security}} — {{owasp-top-10}}, last reviewed {{2026-03-02}}

{{Nothing actionable.}}

---

## {{trackbed:code:harden-security}}

### Changed sources

- {{owasp-top-10}} ({{OWASP Top 10 (2021)}}) — see "Changed upstreams → {{OWASP Top 10 (2021)}}"

### Unchanged sources

- {{cwe-top-25}} ({{CWE Top 25}}) — last reviewed {{2026-01-15}}
- {{snyk-vuln-db}} ({{Snyk Vulnerability DB}}) — last reviewed {{2026-01-15}}

### Moved or gone sources

{{Omit this subsection if none. These sources were not compared and their baselines stay unchanged. Otherwise:}}

- {{source-id}} — {{`moved`, path `missing`; candidates: `skills/wizard/SKILL.md`}}

### Skipped

{{Omit this subsection if none. Vendored runtime libraries are not fetched, hashed, or compared, and their baselines stay unchanged. Otherwise:}}

- {{source-id}} — {{vendored runtime library, version `7.0.1`; review its releases and advisories as a dependency}}

### Errors

{{Omit this subsection if no errors. Otherwise:}}

- {{source-id}} — {{fetch failed: 503 from origin}}

---

## {{trackbed:pr:product-review}}

### Bootstrapped

Manifest created at `trackbed/skills/pr:product-review/references/sources.yaml` with {{N}} sources. No baselines yet — first audit will populate them.

Proposed sources:

- {{nielsen-heuristics}} — {{https://www.nngroup.com/articles/ten-usability-heuristics/}}
- {{laws-of-ux}} — {{https://lawsofux.com/}}

{{Continue per skill...}}

---

## Next steps

1. Open this report, read each changed upstream once, and decide which per-skill suggestions to fold into each skill.
2. To apply a specific suggestion, hand the relevant section back to Claude with:
   > Apply the suggestion under "## Changed upstreams → {{OWASP Top 10 (2021)}} → {{trackbed:code:harden-security}}" to that skill.
3. After accepting changes, re-run `/trackbed:skill:audit-sources <skill>` and confirm "update baselines" to lock in the new state.
```

## Notes for the audit skill

- Render the summary table even when only one skill is in scope.
- Write each changed upstream once under "Changed upstreams", with one subsection per consuming skill whose entry changed; per-skill sections only point to it.
- For sources where the bootstrap was skipped, list under a "Skipped" subsection with the user's stated reason if any.
- Keep findings paraphrased in original language and point to source headings, links, or upstream commit short SHAs. Commit lines from `scripts/github_changes.py` are upstream metadata, not source excerpts. Never include copied source excerpts in the report.
- If the entire audit produced no changed sources and no bootstraps, still write the report (a clean run is a useful artifact) — short body is fine.
