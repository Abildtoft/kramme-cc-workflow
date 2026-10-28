# Source Intake

Load this reference after argument mode selection and the root hard-safety rules, before Phase 0. Follow it through prior-artifact handling, source resolution, normalization, and delegated-handoff validation.

## Phase 0: Check for Prior Artifacts

Before doing anything else, list every root-level `PR_PLAN_*.md` artifact, including `PR_PLAN_INDEX.md`, `PR_PLAN_REJECTIONS.md`, and `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` files.

- With `RECONCILE_MODE=true`, resolve the plan root from the reconcile scope using `references/reconcile-workflow.md`. Require `PR_PLAN_INDEX.md`; if absent, stop with: `No existing plan index found. Run this skill without --reconcile to generate plans first.` Then route directly to Phase 6.
- With `RESUME_MODE=true`, require `PR_PLAN_INDEX.md`; if absent, stop with: `No existing plan index found. Run this skill without --resume to generate plans first.` Continue to Phase 1 with the source recorded in the index unless the user supplied a source. Existing implementation-plan files are optional because an index-only set may be resumed.
- With neither mode and no existing artifacts, continue to Phase 1.
- With neither mode and any existing artifact, stop with this exact shape:

  ```text
  Prior PR plan artifacts found:
    {list of files}

  Re-running would risk silent overwrite of plans whose slugs match new themes, and would leave stale plans whose slugs do not match.
  Options:
    - cleanup — run `$kramme:workflow:cleanup-artifacts` to clear them, then re-run this skill
    - resume — regenerate only missing plan files after confirming these artifacts came from the same source set
    - reconcile — re-run this skill with `--reconcile` to classify drift, done/blocked status, and stale plans
  ```

For `--resume`, compare the resolved source description and available paths with the source set recorded in `PR_PLAN_INDEX.md`. Stop before writing and report both sets when they differ. If every expected plan exists, write nothing and report completion. Otherwise print a `RESUME:` block listing expected, existing, and missing files. Generate only missing plan files after explicit confirmation; `AUTO_MODE=true does not bypass the resume confirmation`. Change `PR_PLAN_INDEX.md` or `PR_PLAN_REJECTIONS.md` only after a second explicit confirmation naming the exact metadata changes.

Never delete or rename artifacts. Never overwrite existing artifacts except for explicitly confirmed resume metadata changes or the Phase 6 reconcile contract.

## Phase 1: Resolve Findings Sources

Follow **Resolve the source set**, **Check compatibility**, and **Normalize findings** in `${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/shared/findings/references/findings-intake.md`. Its **Auto-detect candidates** list and **Sibling worktree reports** discovery drive no-argument auto-detection, and a pre-clustered handoff found there is handled by **Pre-clustered Handoff** below.

Report: `Found N findings from M sources: {source set}. Proceeding to cluster.`

## Pre-clustered Handoff

Classify input as a pre-clustered handoff when it opens with `PRE-CLUSTERED HANDOFF`, or when it directly declares themes that each have a name, bounded file scope, and a `depends on`, `blocks`, or `parallel with` relationship instead of standalone findings. Any shared `## Implementation Setup` block must be part of that same source document.

- Set `HANDOFF_CONFIDENCE=marked` for the marker and `HANDOFF_CONFIDENCE=inferred` otherwise.
- Require every theme to include a name, file list or bounded scope, dependency relationship, rationale, and test or verification plan. Stop for corrected input rather than inventing missing structure.
- Capture every valid theme verbatim, including file lists and line counts, dependency relationship, rationale, and test plan. Do not parse per-finding metadata or invent severity.
- Capture one shared `## Implementation Setup` block when supplied and preserve it verbatim for generation.
- Do not re-cluster. Phase 2 owns the dependency graph, labels, and confirmation gate.
- Use theme vocabulary in all artifacts: `Source themes`, `Total themes`, `Themes processed`, and `Themes included`; write `All themes included.` in the index.

Report: `Found N pre-clustered themes from {source}. Proceeding to plan (no re-clustering).`
