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
    - cleanup — run `$kramme:workflow-artifacts:cleanup` to clear them, then re-run this skill
    - resume — regenerate only missing plan files after confirming these artifacts came from the same source set
    - reconcile — re-run this skill with `--reconcile` to classify drift, done/blocked status, and stale plans
  ```

For `--resume`, compare the resolved source description and available paths with the source set recorded in `PR_PLAN_INDEX.md`. Stop before writing and report both sets when they differ. If every expected plan exists, write nothing and report completion. Otherwise print a `RESUME:` block listing expected, existing, and missing files. Generate only missing plan files after explicit confirmation; `AUTO_MODE=true does not bypass the resume confirmation`. Change `PR_PLAN_INDEX.md` or `PR_PLAN_REJECTIONS.md` only after a second explicit confirmation naming the exact metadata changes.

Never delete or rename artifacts. Never overwrite existing artifacts except for explicitly confirmed resume metadata changes or the Phase 6 reconcile contract.

## Phase 1: Resolve Findings Sources

Resolve the remaining source arguments in this order:

1. If one or more arguments are present and every argument resolves as a file path, read the files as one ordered source set and assign `SRC-01`, `SRC-02`, and so on.
2. If resolvable paths are mixed with non-path prose, stop with: `Mixed source arguments are ambiguous: {arguments}. Provide only file paths, paste inline findings without path arguments, or save the inline findings to a file and pass all files together.`
3. Treat an unresolved token as a probable missing path when it contains `/`, begins with `.`, `~`, or an absolute-path prefix, ends in `.md`, `.txt`, `.json`, `.yaml`, or `.yml`, or exactly matches a candidate in `references/auto-detect-sources.md`. Stop with: `Findings source path not found: {argument}. Provide the correct path, paste the findings text, or rerun with no arguments for auto-detection.` Multi-line prose that cites paths remains inline findings.
4. Treat any other non-empty source text as one source named `inline findings`.
5. With no source argument, read `references/auto-detect-sources.md` and use every matching findings-mode report in candidate order. A detected pre-clustered handoff is exclusive and cannot be combined; ask for that handoff alone or a deliberately merged handoff.
6. If auto-detection finds nothing, inspect the current dialogue. Accept a recent bounded review, audit, scan, or QA set that includes enough structure to extract description, location, severity context, and suggested fix where available, or a valid pre-clustered handoff. Name one accepted dialogue source `current dialogue`; for multiple related findings-mode sets from the current request, preserve their order and assign dialogue `SRC-##` IDs. If candidates span unrelated tasks or include a handoff, list them and ask which compatible set to use. Vague issues, one triage topic, and raw bug ideas are not suitable findings.
7. If no source is suitable, stop with: `No findings source found. Provide one or more file paths (any markdown files with findings will work), paste findings as the next message, keep a structured findings set in the dialogue, or run report-producing skills first (for example $kramme:pr:code-review, $kramme:code:refactor-opportunities, $kramme:code:agent-readiness, $kramme:code:weakness-audit, $kramme:qa, or $kramme:siw:spec-audit).`

### Validate compatibility

- Findings-mode reports may be combined.
- A pre-clustered handoff must be the only source. Ask for one handoff or a new merged handoff when it is mixed with anything else.
- Stop and report mutually exclusive scopes, base commits, or generated-at contexts rather than blending them.

### Normalize findings

For every findings-mode source, extract one normalized list containing:

- source reference (`SRC-##` plus file, section, or line when available);
- full problem description and location;
- severity (`critical`, `high`, `medium`, `low`, or `suggestion`);
- impact (`critical`, `high`, `medium`, `low`, or `negligible`);
- category/type and suggested fix when present;
- effort (`S`, `M`, or `L`), fix risk (`LOW`, `MED`, or `HIGH`), confidence (`HIGH`, `MED`, or `LOW`), and leverage (`EXCEPTIONAL`, `HIGH`, `MED`, or `LOW`);
- suggested verification and scope notes.

Prefix inferred values with `UNVERIFIED:`. Prefer `Breakdown-Ready Finding Data` or `Breakdown-Ready Action Data` sections; use summary tables only to fill gaps. Merge duplicates when location and problem match, preserving all source references, strongest supported severity/impact, and most conservative effort/risk/confidence. Preserve contradictions and surface a `CONFUSION:` during clustering.

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
