# Clustering rules and process

Load this during Phase 2 for findings-mode input. For a pre-clustered handoff, use only the dependency graph, execution-label, and `PLAN:` mapping guidance; do not apply sizing flags or split/merge themes.

## Rules

1. **Target size**: each theme should map to a realistic single PR (roughly 1-8 findings, touching a bounded set of files). If a theme grows beyond what a single PR can cover, split it into a short series and note the dependency.

   Apply this sizing grammar when sizing themes:

   | Size   | Scope                              |
   | ------ | ---------------------------------- |
   | XS     | 1 file, single finding             |
   | S      | 1-2 files                          |
   | M      | 3-5 files                          |
   | L      | 6-8 files                          |
   | **XL** | **9+ files - split into a series** |

   Aim for S/M themes. Any theme that sizes XL MUST split before generating plans.

2. **Avoid overlap**: every finding belongs to exactly one theme. If a finding could fit multiple themes, assign it to the one where it shares the strongest implementation dependency.
3. **Singleton themes are fine**: if a finding does not cluster with others, it becomes its own single-finding theme.
4. **Exclusions**: if any finding should be excluded from all plans (e.g., duplicates, already resolved, not actionable), record it with a reason. These go into the index under "Excluded or Included Scope" as one marker-prefixed line per finding. If nothing is excluded, write a plain sentence with no marker.
5. **Conflicts**: if two findings contradict each other (e.g., "add abstraction" vs. "remove abstraction" for the same code), flag the conflict as an open question in the relevant plan(s) and do not assume a resolution.
6. **Prioritization metadata**: every theme must receive a normalized Impact and Leverage value. Use the highest confirmed impact among included findings, then adjust leverage by effort, fix risk, confidence, dependency value, and whether the theme unblocks later work. If the value is inferred, prefix it with `UNVERIFIED:`.

## Process

1. Read all findings. Identify natural groupings by scanning for shared files, shared root causes, and shared fix patterns.
2. Draft theme names using the pattern `verb-noun` in kebab-case (e.g., `add-api-error-handling`, `consolidate-config-parsing`, `remove-dead-code`).
3. Build a dependency graph across themes before naming files:
   - A dependency exists when a theme cannot start until another theme lands, or when landing one theme materially reduces risk for another.
   - A blocker exists when a theme must land before one or more downstream themes.
   - Themes with no direct or transitive dependency between them are parallel candidates.
   - If dependency direction is unclear, add an open question and choose the most conservative ordering.
4. Assign impact/leverage values and use them to order independent themes within each wave:
   - Put dependency blockers first.
   - Among independent same-wave themes, prefer higher leverage, then higher impact, then lower risk/effort.
   - Do not let leverage ordering override a real dependency.
5. Assign every theme an execution label before generating files:
   - Use `W##L` where `##` is a zero-padded wave number and `L` is an uppercase lane letter, such as `W01A`, `W01B`, `W02A`.
   - Same wave number means the plans can run in parallel.
   - A later wave number means the plan is blocked by at least one earlier-wave plan, and the exact blocker labels must be named in the plan title, index, and summary.
   - Independent single-plan work still receives `W01A`.
6. Keep the theme slug separate from the execution label: derive `{SLUG}` from the theme name only, then prefix it with `{EXECUTION_LABEL}` only in the final filename. Example: execution label `W01A` plus theme slug `define-error-types` becomes `PR_PLAN_W01A_DEFINE_ERROR_TYPES.md`.
7. Verify no theme is too large (touches 9+ files per the sizing grammar above). Split if needed.
8. Verify no two themes overlap in affected files without an explicit dependency note.

## User confirmation block

Present the clustering to the user before generating files. Prefix the block with the `PLAN:` output marker so downstream tooling can parse the proposed clustering:

```text
PLAN: Proposed themes
  Wave W01 (parallel):
    W01A add-api-error-handling (4 findings, size M, impact HIGH, leverage HIGH) -- blocks W02A -- files: src/api/*.ts
    W01B remove-dead-exports (2 findings, size S, impact LOW, leverage MED) -- independent -- files: src/lib/*.ts
  Wave W02:
    W02A consolidate-config-parsing (3 findings, size S, impact MED, leverage HIGH) -- blocked by W01A -- files: src/config/*, src/utils/config.ts
  0 excluded findings

Proceed? (yes / adjust)
```

Wait for user confirmation. If the user requests adjustments, re-cluster accordingly.

If `AUTO_MODE=true`, do not ask for confirmation. Print the same `PLAN:` block, add `AUTO: proceeding with the proposed clustering`, and continue directly to Phase 3. Still stop before Phase 3 if the plan contains an unresolved contradiction that would make the generated plan misleading rather than merely conservative.
