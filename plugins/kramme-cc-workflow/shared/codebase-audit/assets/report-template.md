# Codebase Weakness Report Template

Use this structure when writing `CODEBASE_WEAKNESS_REPORT.md` or a custom `--output <path>`. Replace all placeholders.

```markdown
# Codebase Weakness Report

{Team mode only; omit this block for --solo runs.}

## Team Review

- **Mode:** Team
- **Reviewers:** {active research reviewer names}, Challenge
- **Research breadth:** {raw candidates N, reviewed-and-cleared areas N, coverage gaps N}
- **Cross-validation:** {kept N, dropped N, merged N, disputed N, added N, coverage-gapped N}
- **Coverage status:** {complete | degraded with reason}

**Date:** {YYYY-MM-DD} **Project:** {project} **Scope:** {scope description} **Files reviewed:** {count} **Output:** {path}

## Report Provenance

- **Producer:** kramme:code:refactor-opportunities --ranked {plus --solo when used}
- **Scope:** {scope description}
- **Scanned commit:** {full git rev-parse HEAD at scan start, or none (not a git repository)}
- **Working tree:** {clean / dirty (N paths) / none (not a git repository)}
- **Base branch:** none
- **Generated:** {YYYY-MM-DD}
- **Schema:** breakdown-ready-findings v1

## Executive Summary

{Two to four sentences covering overall health, the biggest weakness theme, and the recommended first action.}

## Scorecard

| Lens | Findings | Highest Severity | Summary |
| --- | --: | --- | --- |
| Maintainability | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Readability | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Correctness | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Mixed | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |

## Top Weaknesses

| ID | Score | Severity | Lens | Theme | Primary Location | Why It Matters | First Move |
| --- | --: | --- | --- | --- | --- | --- | --- |
| WA-001 | {score} | {severity} | {lens} | {theme} | {file:line} | {impact summary} | {first fix} |

## Breakdown-Ready Finding Data

### WA-001: {Finding title}

- **Severity:** {critical / high / medium / low} (native: {Critical / High / Medium / Low})
- **Confidence:** {HIGH / MED / LOW}
- **Locations:** {path:line or path:start-end; …}
- **Evidence:** {specific code/test/history evidence}
- **Suggested fix:** {smallest useful first fix}
- **Effort:** {S / M / L}
- **Category:** {Maintainability / Readability / Correctness / Mixed}
- **Impact:** {future change cost, likely misunderstanding, or failure path}
- **Verification:** {test, check, or review step that proves improvement}
- **Priority score:** {score}
- **Root cause:** {why the weakness exists}
- **Blast radius:** {files or areas affected}

{Repeat for each finding.}

## Cross-Cutting Themes

| Theme   | Findings         | Root Cause     | Suggested Direction |
| ------- | ---------------- | -------------- | ------------------- |
| {theme} | {WA-001, WA-004} | {shared cause} | {direction}         |

## Recommended Fix Sequence

1. **{First action}** — {why first, expected validation, related finding IDs}
2. **{Second action}** — {why next, dependencies, related finding IDs}
3. **{Later action}** — {why later or larger, related finding IDs}

## Filtered Candidates and Near Misses

{Briefly list important observations that were not promoted because evidence was weak, impact was low, the issue contradicted accepted project conventions, or the item belongs in a narrower follow-up audit.}

## Impressions (Unverified)

{Every off-rubric impression reported by reviewers, unfiltered. These answer "what did the rubric not ask about" and "one sentence to the owner"; they are exempt from the evidence bar by design. Treat them as leads for an outside-view run or a rubric amendment, not as ranked findings.}

- **{Reviewer lens or role}:** {impression} — _One sentence to the owner:_ {sentence}

## Coverage Notes

- **Included:** {scope summary}
- **Skipped:** {generated/vendor/build directories, unavailable tools, areas intentionally excluded}
- **Confidence limits:** {anything that could change the findings, such as missing test commands, unavailable git history, or unresolved feature mapping}
```

If no major weakness is found, keep the same header, provenance, scorecard, filtered candidates, impressions, and coverage notes, and write `None.` under `## Breakdown-Ready Finding Data`. Replace the other findings sections with: `No major weaknesses met the evidence bar in this scope.`
