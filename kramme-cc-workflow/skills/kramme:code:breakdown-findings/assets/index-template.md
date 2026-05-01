# PR Plan Index

**Generated:** {{date}}
**Source:** {{source file or description}}
**Total findings:** {{N}} | **Plans generated:** {{M}} | **Excluded:** {{X}}

---

## Plans

| Label | File | Plan Name | Findings | Sequencing | Summary |
|-------|------|-------|----------|------------|---------|
| `{{W##L}}` | `PR_PLAN_{{EXECUTION_LABEL}}_{{SLUG}}.md` | {{W##L theme-name (parallel in W## / blocked by W##L / blocks W##L)}} | {{count}} | {{parallel in W## / blocked by W##L / blocks W##L}} | {{2-4 sentence summary}} |

## Recommended Implementation Order

{{Ordered list grouped by wave. Plans in the same wave can run in parallel; later waves must name the earlier execution labels they are blocked by. Consider: dependencies between plans, risk reduction, quick wins, and logical sequencing.}}

1. **Wave W01 (parallel where multiple plans are listed)** -- {{why this wave starts first}}
   - `{{W01A}}` **`PR_PLAN_{{EXECUTION_LABEL}}_{{SLUG}}.md`** -- {{theme-name}}: {{rationale and what this plan blocks}}
2. **Wave W02 (blocked by {{W01A / W01A, W01B}})** -- {{why this wave comes after W01}}
   - `{{W02A}}` **`PR_PLAN_{{EXECUTION_LABEL}}_{{SLUG}}.md`** -- {{theme-name}}: {{rationale and exact blocker labels}}

## Dependency Map

{{Text representation of which labeled plans depend on which labeled blockers. Include independent same-wave plans explicitly.}}

```
W01A PR_PLAN_W01A_DEFINE_ERROR_TYPES.md (blocks W02A)
  +-- W02A PR_PLAN_W02A_ADOPT_TYPED_ERRORS.md (blocked by W01A)
W01B PR_PLAN_W01B_REMOVE_DEAD_EXPORTS.md (parallel in W01; independent)
```

## Excluded Findings

{{If any findings were excluded from all plans, list each one on its own line with the marker prefix and reason.}}

NOTICED BUT NOT TOUCHING: {{description}} -- {{why excluded: duplicate / already resolved / not actionable / ambiguous}}

{{If no findings were excluded, write: "All findings were included in plans."}}
