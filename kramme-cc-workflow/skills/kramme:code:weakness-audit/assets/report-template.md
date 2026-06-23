# Codebase Weakness Report Template

Use this structure when writing `CODEBASE_WEAKNESS_REPORT.md` or a custom `--output` path. Replace all placeholders.

```markdown
# Codebase Weakness Report

**Date:** {YYYY-MM-DD} **Project:** {project} **Scope:** {scope description} **Files reviewed:** {count} **Output:** {path}

## Executive Summary

{Two to four sentences covering overall health, the biggest weakness theme, and the recommended first action.}

## Scorecard

| Lens | Findings | Highest Severity | Summary |
| --- | ---: | --- | --- |
| Maintainability | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Readability | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Correctness | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |
| Mixed | {N} | {Critical/High/Medium/Low/None} | {one-line summary} |

## Top Weaknesses

| ID | Score | Severity | Lens | Theme | Primary Location | Why It Matters | First Move |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| WA-001 | {score} | {severity} | {lens} | {theme} | {file:line} | {impact summary} | {first fix} |

## Detailed Findings

### WA-001: {Finding title}

- **Severity:** {Critical / High / Medium / Low}
- **Lens:** {Maintainability / Readability / Correctness / Mixed}
- **Priority score:** {score}
- **Locations:** {file:line-range list}
- **Root cause:** {why the weakness exists}
- **Evidence:** {specific code/test/history evidence}
- **Impact:** {future change cost, likely misunderstanding, or failure path}
- **Recommended fix:** {smallest useful first fix}
- **Validation:** {test, check, or review step that proves improvement}
- **Effort / blast radius:** {small / medium / large; files or areas affected}

{Repeat for each finding.}

## Cross-Cutting Themes

| Theme | Findings | Root Cause | Suggested Direction |
| --- | --- | --- | --- |
| {theme} | {WA-001, WA-004} | {shared cause} | {direction} |

## Recommended Fix Sequence

1. **{First action}** — {why first, expected validation, related finding IDs}
2. **{Second action}** — {why next, dependencies, related finding IDs}
3. **{Later action}** — {why later or larger, related finding IDs}

## Filtered Candidates and Near Misses

{Briefly list important observations that were not promoted because evidence was weak, impact was low, the issue contradicted accepted project conventions, or the item belongs in a narrower follow-up audit.}

## Coverage Notes

- **Included:** {scope summary}
- **Skipped:** {generated/vendor/build directories, unavailable tools, areas intentionally excluded}
- **Confidence limits:** {anything that could change the findings, such as missing test commands, unavailable git history, or unresolved feature mapping}
```

If no major weakness is found, keep the same header, scorecard, filtered candidates, and coverage notes. Replace the findings sections with: `No major weaknesses met the evidence bar in this scope.`
