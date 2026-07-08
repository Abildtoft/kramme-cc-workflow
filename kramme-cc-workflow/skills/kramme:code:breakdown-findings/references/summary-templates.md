# Summary templates

Load this during Phase 5 and use the matching summary shape verbatim.

## Findings-mode summary

```text
PR Plan Generation Complete

Sources: {source file(s) or description(s)}
Findings processed: N
Sources processed: S
Plans generated: M
Findings excluded: X

PLANS GENERATED:
  PR_PLAN_INDEX.md
  PR_PLAN_REJECTIONS.md
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_1}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_2}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  ...

THINGS I DIDN'T TOUCH:
  - The source findings file(s) or dialogue excerpt(s) (read-only for this skill)
  - Findings listed under "Excluded" in the index and `PR_PLAN_REJECTIONS.md`

POTENTIAL CONCERNS:
  - {Any conflicting-findings CONFUSION markers that remained unresolved}
  - {Any inferred severities, impact values, or leverage values flagged UNVERIFIED}
  - {If none, state: "None"}

Recommended first PR: PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md -- {one-line rationale including what it unblocks and why its leverage/impact comes first}
```

## Pre-clustered handoff summary

```text
PR Plan Generation Complete

Source: {source file or description}
Themes processed: N
Plans generated: M
Themes included: N

PLANS GENERATED:
  PR_PLAN_INDEX.md
  PR_PLAN_REJECTIONS.md
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_1}.md -- {execution label} {theme name} (1 delegated theme; {parallel in W## / blocked by W##L / blocks W##L})
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_2}.md -- {execution label} {theme name} (1 delegated theme; {parallel in W## / blocked by W##L / blocks W##L})
  ...

THINGS I DIDN'T TOUCH:
  - The source handoff file or dialogue excerpt
  - Theme boundaries supplied by the delegating workflow
  - Rejection decisions recorded in `PR_PLAN_REJECTIONS.md`

POTENTIAL CONCERNS:
  - {Any unusual theme size or dependency question surfaced as MISSING REQUIREMENT}
  - {If none, state: "None"}

Recommended first PR: PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md -- {one-line rationale including what it unblocks and why its leverage/impact comes first}
```
