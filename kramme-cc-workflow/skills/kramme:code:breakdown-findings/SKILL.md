---
name: "kramme:code:breakdown-findings"
description: Cluster validated findings into PR-sized themes and generate self-contained implementation plans. Use after review, audit, scan, or QA workflows that produce findings reports. Also accepts a pre-clustered handoff from a delegating skill, with themes already grouped one-to-one to plans and an optional shared implementation-setup block. Not for raw bug lists without severity or location structure, and not for triaging a single issue.
argument-hint: "[source-file-or-content] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Plan Findings into PRs

Cluster validated findings from reviews, audits, or scans into PR-sized themes. Generate a self-contained implementation plan for each theme and an index linking them all.

This skill generates PR plan **files**; for decision-ready analysis of audit findings without writing files, route to `kramme:siw:breakdown-findings`.

**Accepted sources**

- An auto-detected overview/audit report in the project root (see Phase 1)
- A path to any markdown file containing findings (non-standard names are fine)
- Inline findings text pasted as the argument
- Suitable findings already present in the current dialogue

**Arguments:** "$ARGUMENTS"

Parse `$ARGUMENTS` as shell-style arguments before Phase 0. If `--auto` is present, set `AUTO_MODE=true` and remove the flag from the remaining source text. `--auto` skips the clustering confirmation after a proposed plan is produced. It does not bypass prior-artifact protection, missing-source handling, multiple-source ambiguity, or conflict/open-question reporting.

## Workflow

### Phase 0: Check for Prior Artifacts

Before doing anything else, list any existing `PR_PLAN_*.md` files (including `PR_PLAN_INDEX.md`) in the project root.

- If none exist, proceed to Phase 1.
- If any exist, stop and tell the user:
  ```
  Prior PR plan artifacts found:
    {list of files}

  Re-running would risk silent overwrite of plans whose slugs match new themes, and would leave stale plans whose slugs do not match.
  Options:
    - cleanup — run `$kramme:workflow-artifacts:cleanup` to clear them, then re-run this skill
    - resume — regenerate only missing plan files after confirming these artifacts came from the same source
  ```
- On **resume**: require the existing `PR_PLAN_INDEX.md` to identify the same source. Re-run Phases 1-2 against that source, compare the expected filenames against existing plan files, keep existing plan files untouched, and generate only missing plan files. Do not modify `PR_PLAN_INDEX.md` unless the user explicitly confirms updating the index after seeing the missing-file list; if confirmation is not available, write no replacement index and report the stale index entries that need manual update.
- Do not delete, rename, or overwrite the files yourself.

### Phase 1: Locate Findings

1. Resolve the findings source from `$ARGUMENTS`:
   - **Resolvable file path** (resolves on disk, any filename): read it as the source.
   - **Non-empty, not a path**: treat the argument as inline findings text.
   - **Empty**: auto-detect by checking all candidates in `references/auto-detect-sources.md`. If exactly one candidate exists, use it. If multiple candidates exist, list all matches and ask which one to use — process exactly one source per run.
   - **Empty and nothing auto-detected**: inspect the existing dialogue for a suitable findings source before stopping. A suitable dialogue source is a recent, bounded set of review/audit/scan/QA findings with enough structure to extract description, location, severity or severity context, and suggested fix where available; or a pre-clustered handoff as defined below.
     - If exactly one suitable findings set is present, treat that dialogue excerpt as inline findings and use `current dialogue` as the source description.
     - If multiple suitable findings sets are present, list them briefly and ask which one to use — process exactly one source per run.
     - If the dialogue only contains vague issues, a single triage topic, or raw bug ideas without severity/location structure, do not treat it as a source.
   - **Empty, nothing auto-detected, and no suitable dialogue findings**: stop and tell the user: "No findings source found. Provide a file path (any markdown file with findings will work), paste findings as the next message, keep a structured findings set in the dialogue, or run a report-producing skill first (for example `$kramme:pr:code-review`, `$kramme:code:copy-review`, `$kramme:qa`, or `$kramme:siw:spec-audit`)."

2. Parse the findings source into a normalized list. For each finding, extract:
   - **Description** of the issue (the full problem statement, not a reference ID)
   - **Location** (file paths, line ranges, modules)
   - **Severity** (critical / high / medium / low / suggestion -- normalize to these levels)
   - **Category/type** (if tagged in the source)
   - **Suggested fix** (if present)

3. Count findings and report to the user before proceeding:
   ```
   Found N findings from {source}. Proceeding to cluster.
   ```

#### Pre-clustered handoff (delegated input)

A delegating skill (for example a PR split planner) may hand over work that is **already grouped into PR-sized themes** rather than a raw findings list. Treat the source as a pre-clustered handoff when it opens with the marker line `PRE-CLUSTERED HANDOFF` (a delegating skill sets this), or — absent the marker — when it declares the themes directly, each with a name, a file list, and a dependency relationship (`depends on` / `blocks` / `parallel with`) instead of standalone findings to be grouped. The shared `## Implementation Setup` block, if any, lives inside this same document.

When the source is a pre-clustered handoff:

- **Skip the per-finding parse in step 2.** Capture each declared theme verbatim: its name, file list (with line counts if given), dependency relationship, rationale, and test plan. Do not invent severities — a delegated theme is a unit of work, not a finding.
- **Capture the shared Implementation Setup block, if present.** A handoff may include one `## Implementation Setup` block meant for every plan (e.g. worktree / reference-branch instructions). Hold it for Phase 3; do not alter its wording.
- **Do not re-cluster** — the canonical handoff rule lives in Phase 2.
- **Adapt the findings vocabulary to themes.** A handoff has no findings and no exclusions. In Phase 3 use theme-based plan metadata, in Phase 4 write `All themes included.` in the index's Excluded or Included Scope section, and in Phase 5 report theme counts (not "findings processed"/"findings excluded") and name the delegated handoff as the source.
- Report the theme count: `Found N pre-clustered themes from {source}. Proceeding to plan (no re-clustering).`

### Phase 2: Cluster into Themes

**Pre-clustered handoff:** if Phase 1 identified the source as a pre-clustered handoff, do **not** re-cluster — the themes are already the intended PR seams, and re-grouping would destroy the caller's analysis. Skip the clustering rules and clustering process below, **including the file-count sizing grammar and the 9-file XL gate**: the caller sized these seams deliberately (often by review time, not file count), so do not split or merge a theme. If a theme looks unusually large, note it as an open question in that plan rather than re-cutting it. Still build the dependency graph from the declared `depends on` / `blocks` / `parallel with` relationships and assign execution labels (clustering-process steps 3–5). Print the 1:1 mapping (the `PLAN:`-prefixed block) for visibility, but do **not** block on the `Proceed? (yes / adjust)` prompt — a pre-clustered handoff has already been confirmed by its caller and has no clustering left to adjust. (The Phase 0 artifact guard still applies.)

Otherwise, group findings into PR-sized themes. A theme is a set of findings that should be fixed together because they share one or more of:

- **Root cause** -- same underlying problem manifesting in multiple places
- **Affected area** -- same file, module, or subsystem
- **Implementation dependency** -- fixing one requires or enables fixing another
- **Conceptual cohesion** -- same type of change (e.g., "add error handling to all API endpoints")

#### Clustering rules

1. **Target size**: each theme should map to a realistic single PR (roughly 1-8 findings, touching a bounded set of files). If a theme grows beyond what a single PR can cover, split it into a short series and note the dependency.

   Apply this sizing grammar when sizing themes:

   | Size   | Scope                              |
   | ------ | ---------------------------------- |
   | XS     | 1 file, single finding             |
   | S      | 1–2 files                          |
   | M      | 3–5 files                          |
   | L      | 6–8 files                          |
   | **XL** | **9+ files — split into a series** |

   Aim for S/M themes. Any theme that sizes XL MUST split before generating plans.

2. **Avoid overlap**: every finding belongs to exactly one theme. If a finding could fit multiple themes, assign it to the one where it shares the strongest implementation dependency.

3. **Singleton themes are fine**: if a finding does not cluster with others, it becomes its own single-finding theme.

4. **Exclusions**: if any finding should be excluded from all plans (e.g., duplicates, already resolved, not actionable), record it with a reason. These go into the index under "Excluded or Included Scope" as one marker-prefixed line per finding. If nothing is excluded, write a plain sentence with no marker.

5. **Conflicts**: if two findings contradict each other (e.g., "add abstraction" vs. "remove abstraction" for the same code), flag the conflict as an open question in the relevant plan(s) and do not assume a resolution.

#### Clustering process

1. Read all findings. Identify natural groupings by scanning for shared files, shared root causes, and shared fix patterns.
2. Draft theme names using the pattern `verb-noun` in kebab-case (e.g., `add-api-error-handling`, `consolidate-config-parsing`, `remove-dead-code`).
3. Build a dependency graph across themes before naming files:
   - A dependency exists when a theme cannot start until another theme lands, or when landing one theme materially reduces risk for another.
   - A blocker exists when a theme must land before one or more downstream themes.
   - Themes with no direct or transitive dependency between them are parallel candidates.
   - If dependency direction is unclear, add an open question and choose the most conservative ordering.
4. Assign every theme an execution label before generating files:
   - Use `W##L` where `##` is a zero-padded wave number and `L` is an uppercase lane letter, such as `W01A`, `W01B`, `W02A`.
   - Same wave number means the plans can run in parallel.
   - A later wave number means the plan is blocked by at least one earlier-wave plan, and the exact blocker labels must be named in the plan title, index, and summary.
   - Independent single-plan work still receives `W01A`.
5. Keep the theme slug separate from the execution label: derive `{SLUG}` from the theme name only, then prefix it with `{EXECUTION_LABEL}` only in the final filename. Example: execution label `W01A` plus theme slug `define-error-types` becomes `PR_PLAN_W01A_DEFINE_ERROR_TYPES.md`.
6. Verify no theme is too large (touches 9+ files per the sizing grammar above). Split if needed.
7. Verify no two themes overlap in affected files without an explicit dependency note.

Present the clustering to the user before generating files. Prefix the block with the `PLAN:` output marker so downstream tooling can parse the proposed clustering:

```
PLAN: Proposed themes
  Wave W01 (parallel):
    W01A add-api-error-handling (4 findings, size M) -- blocks W02A -- files: src/api/*.ts
    W01B remove-dead-exports (2 findings, size S) -- independent -- files: src/lib/*.ts
  Wave W02:
    W02A consolidate-config-parsing (3 findings, size S) -- blocked by W01A -- files: src/config/*, src/utils/config.ts
  0 excluded findings

Proceed? (yes / adjust)
```

Wait for user confirmation. If the user requests adjustments, re-cluster accordingly.

If `AUTO_MODE=true`, do not ask for confirmation. Print the same `PLAN:` block, add `AUTO: proceeding with the proposed clustering`, and continue directly to Phase 3. Still stop before Phase 3 if the plan contains an unresolved contradiction that would make the generated plan misleading rather than merely conservative.

### Phase 3: Generate Plans

For each confirmed theme:

1. Read the plan template from `assets/plan-template.md`.
2. Fill in all sections. Every plan must be **fully self-contained** -- an engineer who has never read any prior document must understand the problem, context, and solution from the plan alone.
3. Write the file to `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` in the project root. Use UPPER_SNAKE_CASE for the slug in the filename (e.g., `PR_PLAN_W01A_DEFINE_ERROR_TYPES.md`).
4. Create a plan display name using this pattern: `{execution label} {theme name} ({parallel / blocked-by / blocks summary})`.
5. Include the full plan display name in the plan title:
   - Independent or parallel plan: `# PR Plan W01A: define-error-types (parallel in W01; independent)`
   - Blocker plan: `# PR Plan W01A: define-error-types (blocks W02A)`
   - Blocked plan: `# PR Plan W02A: adopt-typed-errors (blocked by W01A; blocks W03A)`
   - Use multiple labels when needed, e.g. `blocked by W01A, W01B`.
6. Keep the title, filename, Dependencies and Sequencing section, index row, dependency map, and final summary aligned. The same blocker/dependent labels must appear in all of them.
7. **If Phase 1 captured a shared Implementation Setup block** (delegated handoff), render it verbatim as the template's `## Implementation Setup` section in **every** plan — same wording in each, with any branch names or paths the caller already resolved left exactly as given. When no block was supplied, omit that section entirely.
8. **If the source is a pre-clustered handoff**, replace all finding-count language in the template with theme language: `Source themes: 1 delegated theme mapped to this plan`, index statistics as `Total themes` / `Plans generated`, and summary lines as `Themes processed` / `Themes included`. Do not write `Source findings`, `Findings processed`, `Findings excluded`, or inferred severities for handoff-mode output.

#### Plan content requirements

Populate every section in the template — no empty headings, no "N/A". The template's inline guidance covers what each section needs. A few non-obvious points that the template cannot enforce:

- **Problem Statement**: Restate the full problem in the plan's own words. Do NOT reference finding IDs, report names, or prior documents — the plan must be readable in isolation.
- **Dependencies and Sequencing**: Name the execution label, the parallel wave, the exact blocker labels, and the exact dependent labels. Describe both the labels and the content of each dependency so the relationship is clear without cross-reading other plans.
- **Test and Verification Plan**: Match verification to the work. Include automated tests when code changes; use manual validation, re-runs of the source audit/review, docs/build checks, or screenshots when the work is non-code.

### Phase 4: Generate Index

1. Read the index template from `assets/index-template.md`.
2. Write `PR_PLAN_INDEX.md` in the project root with:
   - **Plan listing**: execution label, filename, full plan display name, blocking status, parallel group, and a 2-4 sentence summary for each plan.
   - **Recommended implementation order**: ordered by wave and dependency, with rationale (dependencies, risk reduction, quick wins first). Explicitly group same-wave plans as parallel.
   - **Dependency map**: which labeled plans depend on which labeled blockers, and which plans are independent.
   - **Excluded or included scope**: for findings-mode input, list any findings not included in any plan with the reason. Emit each excluded entry on its own line prefixed with `NOTICED BUT NOT TOUCHING:` so downstream tooling can parse it reliably. If there are no exclusions, write `All findings were included in plans.` with no marker line. For handoff-mode input, write `All themes included.`
   - **Source**: the findings source file or description used as input.
   - **Statistics**: total findings, plans generated, findings per plan, excluded count. For a pre-clustered handoff, use total themes, plans generated, themes per plan, and included theme count instead.

### Phase 5: Summary

For findings-mode input, report to the user using this end-of-turn template:

```
PR Plan Generation Complete

Source: {source file or description}
Findings processed: N
Plans generated: M
Findings excluded: X

PLANS GENERATED:
  PR_PLAN_INDEX.md
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_1}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_2}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  ...

THINGS I DIDN'T TOUCH:
  • The source findings file (read-only for this skill)
  • Findings listed under "Excluded" in the index

POTENTIAL CONCERNS:
  • {Any conflicting-findings CONFUSION markers that remained unresolved}
  • {Any inferred severities flagged UNVERIFIED}
  • {If none, state: "None"}

Recommended first PR: PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md -- {one-line rationale including what it unblocks}
```

For a pre-clustered handoff, use this theme-based variant:

```
PR Plan Generation Complete

Source: {source file or description}
Themes processed: N
Plans generated: M
Themes included: N

PLANS GENERATED:
  PR_PLAN_INDEX.md
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_1}.md -- {execution label} {theme name} (1 delegated theme; {parallel in W## / blocked by W##L / blocks W##L})
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_2}.md -- {execution label} {theme name} (1 delegated theme; {parallel in W## / blocked by W##L / blocks W##L})
  ...

THINGS I DIDN'T TOUCH:
  • The source handoff file or dialogue excerpt
  • Theme boundaries supplied by the delegating workflow

POTENTIAL CONCERNS:
  • {Any unusual theme size or dependency question surfaced as MISSING REQUIREMENT}
  • {If none, state: "None"}

Recommended first PR: PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md -- {one-line rationale including what it unblocks}
```

## Edge Cases

- **Single finding**: create one plan and one index. Do not skip sections.
- **Single theme**: create one plan. The index still lists it with order and summary.
- **No actionable findings**: if all findings are duplicates, resolved, or not actionable, write no plan files. Report this and stop.
- **Large input (30+ findings)**: cluster aggressively. Aim for 5-10 themes maximum. Split oversized themes into a series with sequencing notes.
- **Conflicting findings**: do not pick a side. Flag the conflict as an open question and present both positions.
- **Ambiguous severity**: infer from context (security = critical, style = low). State the inference in the plan.
- **Pre-clustered handoff**: follow the canonical rule in Phase 2; skip severity inference.

## Guidelines

- **Self-contained plans above all.** Every plan must be readable in isolation. Never write "as described in the review" or "see finding #3."
- **Actionable specificity.** "Improve error handling" is not a plan step. "Add try-catch to `fetchUser()` in `src/api/users.ts:45` that catches `NetworkError` and returns a typed error result" is.
- **Conservative sizing.** No theme should land at XL. When in doubt, size down — a focused M theme (200-line PR) is better than a stretched L that inches toward an 800-line sprawl.
- **Dependency-readable naming.** Plan titles, filenames, index rows, and the final summary must make sequencing obvious without reading the full plan. Use `W01A`/`W01B` for parallel first-wave plans, higher wave numbers for blocked follow-up plans, and explicit `blocked by`/`blocks` labels wherever a dependency exists.
- **Respect the source.** Do not add findings that were not in the input. Do not reinterpret findings. If a finding is unclear, flag it as an open question.
- **Match verification to the work.** Do not force code-only requirements onto documentation, copy, QA, audit, or workflow changes. Generated plans should require the evidence that actually proves the theme is complete.
- **Clean output files.** The generated markdown files are working artifacts. They can be cleaned up with `$kramme:workflow-artifacts:cleanup`.

Before Phase 5, run the concise verification checklist in `references/generation-checks.md`. Load that file only after files have been generated or when debugging a failed generation pass.

## Output Markers

Use these markers as prefixes when surfacing specific kinds of information so output stays parseable across the plugin:

- `UNVERIFIED:` — use in Phase 1 parsing when severity (or any other field) is inferred from context rather than stated in the source.
- `CONFUSION:` — use when two findings conflict and both positions are surfaced as open questions in the generated plan(s).
- `MISSING REQUIREMENT:` — use for any open question added to a plan that must be answered before implementation.
- `NOTICED BUT NOT TOUCHING:` — prefix each excluded-finding entry in the index.
- `PLAN:` — prefix the Phase 2 proposed-themes block.
- `PLANS GENERATED / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` — end-of-turn triplet used in Phase 5 Summary.

Use these markers verbatim where applicable. Do not invent alternate spellings or rename them — downstream tooling matches the exact strings.
