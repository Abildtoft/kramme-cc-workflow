# Summary templates

Load this during Phase 5 and use the matching summary shape verbatim. Both shapes end with the `LAUNCH SHEET:` block; follow **Launch sheet rules** below when filling it.

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

LAUNCH SHEET:
  Start now (no prerequisites; one workspace each):
    {W##L}  $kramme:code:plan-to-pr PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md --ship  -- {one-line rationale: leverage/impact and what it unblocks}
  Waiting:
    {W##L}  after {exact blocker labels} land  -- $kramme:code:plan-to-pr PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md --ship
  Another workspace: attach the plan file and pass its .context/attachments/ path instead of the root filename. After a root run archives this set, pass the archived plan path that run reports.
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

LAUNCH SHEET:
  Start now (no prerequisites; one workspace each):
    {W##L}  $kramme:code:plan-to-pr PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md --ship  -- {one-line rationale: leverage/impact and what it unblocks}
  Waiting:
    {W##L}  after {exact blocker labels} land  -- $kramme:code:plan-to-pr PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md --ship
  Another workspace: attach the plan file and pass its .context/attachments/ path instead of the root filename. After a root run archives this set, pass the archived plan path that run reports.
```

## Launch sheet rules

These rules apply to the `LAUNCH SHEET:` block in both templates:

- List every generated plan exactly once.
- Under "Start now", list every plan without prerequisites in index order (leverage, impact, then lower risk).
- Under "Waiting", list every other plan by wave, naming its exact blocker labels.
- A plan that carries a shared `## Implementation Setup` block cannot run through `kramme:code:plan-to-pr`, whose validator rejects it. Replace its command with `implement in its own worktree per the plan's Implementation Setup` and follow the entry with one reconcile line: `$kramme:code:breakdown-findings --reconcile PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md [--worktree <path> | --source <ref>]`.
