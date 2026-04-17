# PR Plan Index

**Generated:** {{date}}
**Source:** {{source file or description}}
**Total findings:** {{N}} | **Plans generated:** {{M}} | **Excluded:** {{X}}

---

## Plans

| # | File | Theme | Findings | Summary |
|---|------|-------|----------|---------|
| {{order}} | `PR_PLAN_{{SLUG}}.md` | {{theme-name}} | {{count}} | {{2-4 sentence summary}} |

## Recommended Implementation Order

{{Ordered list with rationale for each position. Consider: dependencies between plans, risk reduction, quick wins, and logical sequencing.}}

1. **`PR_PLAN_{{SLUG}}.md`** -- {{theme-name}}: {{rationale for this position}}

## Dependency Map

{{Text representation of which plans depend on which.}}

```
PR_PLAN_DEFINE_ERROR_TYPES.md
  +-- PR_PLAN_ADOPT_TYPED_ERRORS.md (depends on error types)
PR_PLAN_REMOVE_DEAD_EXPORTS.md (independent)
```

## Excluded Findings

{{If any findings were excluded from all plans, list them here with the reason.}}

| Finding | Reason |
|---------|--------|
| {{description}} | {{why excluded: duplicate / already resolved / not actionable / ambiguous}} |

{{If no findings were excluded, write: "All findings were included in plans."}}
