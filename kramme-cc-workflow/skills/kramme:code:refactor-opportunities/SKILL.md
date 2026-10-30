---
name: kramme:code:refactor-opportunities
description: "Scan the full codebase, current PR, a path, or a feature for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, wants a codebase health check, or asks what to refactor before a planned change (--for). Flags themes over 500 combined lines as automation candidates. User-only --ranked runs a multi-agent audit that ranks the biggest maintainability, readability, and correctness weaknesses into CODEBASE_WEAKNESS_REPORT.md."
disable-model-invocation: false
user-invocable: true
argument-hint: "[--subagent-model <model>] [full | pr | path <file-or-folder> | feature <name>] [--for <spec-file | description>] [--ranked [--solo] [--output <path>] [--max-findings N] [--base <ref>]]"
kramme-platforms: [claude-code, codex]
---

# Refactor Opportunities

Systematically scan the codebase for refactoring candidates, categorize findings by severity, and produce a prioritized report.

With `--ranked`, it instead ranks the biggest weaknesses into `CODEBASE_WEAKNESS_REPORT.md`. With `--for`, it asks what would make a planned change easy to build and reports only the refactors that would.

**Arguments:** "$ARGUMENTS"

**Subagent models.** Before parsing other arguments, read and apply `${CLAUDE_PLUGIN_ROOT}/shared/pr-review/references/model-selection.md`, using its `## Non-Review Subagent Roles` section with the Phase 2 scan agents and, under `--ranked`, every research reviewer and the challenge reviewer named as lens or scan roles. It parses and removes `--subagent-model <model>` (a model flag, not a scope selector), reads `KRAMME_REVIEW_SUBAGENT_LEVEL`, and keeps the default `same` when neither is set. Report the selected model and its source before launching, set it on every launch, and record it in the resumable fan-out `subagent_model` key slot.

## Inputs

- **Scope selector** (optional): the skill resolves arguments to exactly one of `full`, `pr`, `path`, or `feature`. Defaults to `full`, or with `--for` to the planned change's area.
- **Full codebase**: omit arguments, say `full`, `full codebase`, `repo`, `everything`, or `all`, or pass `--scope full`. Scan all source directories.
- **Current PR**: say `pr`, `current PR`, `diff`, or `changes`, or pass `--scope pr`. Scan the files changed by the current branch against the resolved base branch, plus staged, unstaged, and untracked files. Changed files are context; active findings must be caused by the PR changes, not merely pre-existing debt in touched files.
- **Named path**: pass `path <file-or-folder>`, `--scope path <file-or-folder>`, or a bare path-shaped argument that resolves to an existing file, folder, glob match, or file list. Scan only the matching files.
- **Named feature**: pass `feature <name>`, `--scope feature <name>`, or `--feature <name>`. A bare argument that is neither a reserved keyword nor path-shaped is also treated as a feature name; use the explicit `feature <name>` form when the feature name collides with a reserved keyword (`full`, `full codebase`, `repo`, `everything`, `all`, `pr`, `current PR`, `diff`, `changes`). Resolve the feature to its implementation, tests, routes, schemas, docs, and adjacent modules before scanning.
- **Planned change** (optional): `--for <spec-file | description>` names a change the user is about to build, as a spec, plan, or issue file, or a quoted description. The scan then answers "what would make this change easy?" instead of surveying general debt. `--for` is context, not a scope selector: with no scope selector the scan covers the change area resolved in Phase 1, and with `full`, `path`, or `feature` it scans that scope. In both cases only findings that ease the planned change stay active. Use it for requests such as "what should we refactor before building X?".
- **Ranked weakness audit**: `--ranked` runs the ranked mode in `references/ranked-mode.md` over the `full`, `path`, or `feature` scope with optional `--solo`, `--output <path>`, `--max-findings N`, and `--base <ref>`, and writes `CODEBASE_WEAKNESS_REPORT.md` instead of `REFACTOR_OPPORTUNITIES_OVERVIEW.md`. In ranked full, path, and feature scopes, `--base <ref>` is history context: resolve it to a commit before scanning, use it for churn and co-change signals, and pass it to the ranked reviewers; it does not change the selected file scope. `--ranked` and its options are mode flags, not scope selectors.
- **Disambiguation** (apply in order; first match wins):
  1. A typed mode form (`--scope <mode>`, `--feature <name>`, `path <…>`, `feature <…>`) selects that mode directly.
  2. A bare argument that exactly matches a reserved full-codebase alias (`full`, `full codebase`, `repo`, `everything`, `all`) or PR alias (`pr`, `current PR`, `diff`, `changes`) selects the corresponding mode. To name a feature whose name collides with a reserved keyword, use the explicit `feature <name>` form.
  3. A bare argument is _path-shaped_ when it contains `/`, `.`, or a glob meta-character (`*`, `?`, `[`); a path-shaped argument that resolves selects `path`, and one that does not resolve triggers a clarification ask (do not fall back to `feature`).
  4. Any other bare argument is treated as a feature name.
- If two distinct scope selectors are provided (e.g. `--scope pr` plus a bare path, or `path <…>` plus `feature <…>`), pause and ask which single scope to use. `--base <ref>` (context for PR or ranked history) and `--for` (the planned change) are not selectors and do not trigger this rule.

**User-only `--ranked`.** Ranked mode launches nine research reviewers and a challenge reviewer and is this skill's most expensive path. Honor `--ranked` only when the user's own message typed `--ranked` or explicitly asked in this session for a ranked weakness audit. A model-initiated invocation, including Gate 4 of `kramme:pr:review-convergence` or any other skill, must never add `--ranked`; when one does without that user request, stop before launching any agent, say that ranked mode is user-only, and print the `/kramme:code:refactor-opportunities --ranked` command for the user to run.

## Prerequisites — When NOT to flag a refactor

Do not flag:

- **Code that is already clean.** Not every file needs changes. Skip files that read well and conform to the checklist.
- **Code you don't understand yet.** If a pattern looks wrong but you haven't traced its callers, tests, or history, it is not a finding. Read more, or leave it.
- **Performance-critical code where the alternatives are slower.** "Cleaner" does not override measured performance. Do not flag hot paths without evidence that the simpler form is at least as fast.
- **Code that is about to be rewritten.** If a larger rewrite is already planned or in progress for the same area, flagging its current state is noise. Surface the overlap instead. With `--for`, this includes code the planned change itself will replace.

These rejections are pre-filters — apply them before recording a finding, not during Synthesis.

## Workflow

### Phase 1 — Orientation

1. Remove `--for <value>` from `$ARGUMENTS` first so its value never feeds the scope rules. Then parse the rest per the **Inputs** section into a single `SCOPE_MODE`, applying the multi-selector rule from **Inputs** before resolving. The per-mode target is computed in _Resolve the effective scan scope_ below. When `--ranked` is honored, set `RANKED_MODE=true`; with a ranked `full`, `path`, or `feature` scope, resolve an explicit `--base <ref>` with `git rev-parse --verify --quiet --end-of-options "${BASE_ARG}^{commit}"` before scope scanning, store it as `HISTORY_BASE_REF`, and stop if it cannot be resolved. If no ranked base is supplied, use `HEAD`. With `pr` scope, stop with the rejection sentence in `references/ranked-mode.md`.

   When `--for` is present with `pr` scope or `--ranked`, stop with: `--for prepares a full, path, or feature scan for a planned change; drop pr or --ranked, or drop --for.` Otherwise store the planned change as `PLANNED_CHANGE`: the file's contents when the value resolves to an existing file, or the value itself as a description. Only a single path-shaped token with no spaces that does not resolve triggers a clarification ask; any other value, even with `.`, `/`, or `?` in it, is a description. With no scope selector, set `SCOPE_MODE=path`; step 7 resolves its files from the planned change.

2. Use the Read tool to examine `package.json` / `pyproject.toml` / build config to understand the stack and directory layout.
3. Discover project instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents) if present and read the relevant ones to understand project-specific conventions.
4. **Read accepted ADRs.** Look for `docs/decisions/` (or other common ADR locations: `doc/adr/`, `docs/adr/`, `architecture/decisions/`). If found, read every ADR whose status reads `ACCEPTED` (case-insensitive) and store their decisions as `KNOWN_ADRS` — title, status, and a one-line summary of what was decided and what was rejected. Skip ADRs marked `PROPOSED`, `SUPERSEDED`, or `DEPRECATED` — only accepted decisions are decision-of-record. These bound the design space the scan operates in. If no ADR directory exists, proceed silently with `KNOWN_ADRS = []`.
5. **Read project domain language.** If `UBIQUITOUS_LANGUAGE.md` (or similar: `GLOSSARY.md`, `docs/glossary.md`) exists at the project root, read it and store the canonical domain terms. When naming refactor candidates in Phase 4, prefer these terms over internal helper class names — "the Order intake module" is more useful than "the FooBarHandler". If no glossary file exists, proceed silently — do not flag its absence.
6. **Read prior rejections.** If `.out-of-scope/` exists at the project root, list its filenames and store them as `KNOWN_OUT_OF_SCOPE`. Do not open file bodies yet — that happens in Phase 3 only when a finding plausibly matches a slug. If no directory exists, proceed silently with `KNOWN_OUT_OF_SCOPE = []`. See `/kramme:docs:track-rejected-enhancements` for the storage skill.
7. Resolve the effective scan scope. Across all modes, exclude `node_modules`, `dist`, build artifacts, generated files, lock files, vendored code, and binary assets. Then per mode:
   - **Full**: list source directories from project structure. If the project is a git repository, rank in-scope files by commit frequency (for example `git log --since="12 months ago" --format= --name-only "${HISTORY_BASE_REF:-HEAD}" -- <source-dirs> | sort | uniq -c | sort -rn`) and store the top ~20 still-existing files as `HOT_SPOTS` — churn concentrates friction, so these files get scanned first. In ranked mode, anchor this history query to `HISTORY_BASE_REF`; otherwise use the current `HEAD`. If the ranking cannot be computed, proceed silently with `HOT_SPOTS = []`.
   - **PR**:
     1. Resolve the base ref in this order:
        - Explicit `--base <ref>`.
        - `gh pr view --json baseRefName,isCrossRepository` — if it returns metadata for a same-repo PR, use its base branch. For cross-repo PRs (`isCrossRepository == true`), ask for `--base <ref>` instead of guessing. If `gh` is not installed or reports no PR open for this branch, use the next fallback. Authentication, network, and API errors are blockers because the PR target remains unknown.
        - The repository's configured `kramme.baseBranch`, then a valid `CONDUCTOR_DEFAULT_BRANCH`, then `origin/HEAD`, `origin/main`, or `origin/master`. Do not select `development` or `main` merely because the branch exists.
     2. For an explicit `--base <ref>`, set `BASE_REF=$(git rev-parse --verify --quiet --end-of-options "${BASE_ARG}^{commit}")` using the supplied ref as `BASE_ARG`, then set `MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)`; stop if either fails. This accepts a local branch, tag, or commit without treating it as a remote branch. For a same-repo PR, pass its base branch through `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh --base <branch> --strict`; otherwise run that helper without `--base`. Use its `BASE_REF` and `MERGE_BASE`. If no base can be resolved, report the attempted refs and ask for `--base <ref>` — do not fall back to `full`.
     3. Build the file set from `git diff --name-only <resolved-base>...HEAD`, `git diff --cached --name-only`, `git diff --name-only`, and `git ls-files --others --exclude-standard`. Drop deleted files from the set unless a search of the current tree/worktree shows surviving references to the deleted symbols or paths.
     4. Build `PR_CHANGE_MAP` from `git diff --unified=0 <resolved-base>...HEAD`, `git diff --unified=0 --cached`, and `git diff --unified=0`. Record added/modified/deleted hunk ranges per file. Treat each untracked file's full content as added. Store the merge base as `PR_BASE_REF` for checking whether a candidate issue existed before the branch.
     5. Use changed files as scan context, but use `PR_CHANGE_MAP` as the finding boundary. Apply the **PR relevance gate** — a PR-mode finding must be tied to one of:
        - an added or modified hunk
        - a new or untracked file
        - deleted code with surviving references
        - an unchanged line within ~5 lines of a changed hunk with a concrete causal chain
        - unchanged code directly affected by a changed caller or API contract

        "The file was touched" is not enough. References to "the PR relevance gate" elsewhere in this skill mean exactly this list.

   - **Path**: validate that every named file/folder exists or every glob matches at least one file. If a value does not resolve, ask the user to clarify — do not fall back to `feature`. For folders, recursively include source files under the folder.
   - **Feature**: search for the feature name and project-glossary synonyms across directory names, module names, routes, package names, tests, docs, config, schemas, and user-facing copy. Include primary implementation files, matching tests, API/routes, data models, feature flags, fixtures, and docs that directly define the feature. If the name maps to multiple unrelated areas, or if no file's name, route, or schema contains the feature term, present the candidate file groups (or the empty result) and ask the user to confirm or rename. If the user confirms an empty result, terminate with a one-line message that the feature could not be located rather than producing a report.
   - **Planned change** (`--for`): locate the modules, routes, schemas, and files `PLANNED_CHANGE` names or implies, the way feature mode locates a feature, and store the files the change itself will edit as `CHANGE_TARGETS`. With no scope selector, the path scope is `CHANGE_TARGETS` plus their tests and their direct callers and callees. If nothing resolves, show what was searched and ask the user where the change lands. In every `--for` run, set `HOT_SPOTS` to the `CHANGE_TARGETS` inside the scan scope instead of the commit-frequency ranking, and name the planned change in `SCOPE_DESCRIPTION`.

8. **Collect co-change evidence** in full, path, and feature modes when the project is a git repository; skip this step in PR mode. Files in separate modules that keep changing in the same commits show low locality, the main lead for deepening candidates. In ranked mode, anchor this history query to `HISTORY_BASE_REF`; otherwise use the current `HEAD`. The pipeline below skips merge commits and commits touching more than 30 files, and treats nested directories as one module:

   ```bash
   git log --since="12 months ago" --no-merges --format='>>> %H' --name-only "${HISTORY_BASE_REF:-HEAD}" -- <in-scope source paths> |
     awk '
       function dir(path,  d) { d = path; if (!sub(/\/[^\/]*$/, "", d)) d = "."; return d }
       function nested(a, b) { return a == "." || b == "." || index(a "/", b "/") == 1 || index(b "/", a "/") == 1 }
       function flush(  i, j) {
         if (n >= 2 && n <= 30)
           for (i = 1; i < n; i++)
             for (j = i + 1; j <= n; j++)
               if (!nested(dir(f[i]), dir(f[j])))
                 print (f[i] < f[j] ? f[i] "\t" f[j] : f[j] "\t" f[i])
         n = 0
       }
       /^>>> / { flush(); next }
       NF { f[++n] = $0 }
       END { flush() }' |
     sort | uniq -c | sort -rn | awk '$1 >= 3' | head -40
   ```

   Store the pairs whose files both still exist as `CO_CHANGE` (count and the two paths). With `--for`, list pairs that include a `CHANGE_TARGETS` file first, because they show where the planned change will ripple. If the history is too short or the command fails, proceed silently with `CO_CHANGE = []`.

9. Build a human-readable `SCOPE_DESCRIPTION` covering mode, resolved target, file count, and source directories — for example `Full codebase (1,247 files across 8 source directories)`, `Current PR against origin/<base-branch> (14 files)`, `Path src/api (37 files)`, `Feature "billing exports" (22 files across API, UI, tests, and docs)`, or `Planned change "CSV invoice export" (19 files across billing, exports, and tests)`. Report it to the user before proceeding.
10. Record provenance before Phase 2 without requiring Git: use the full `git rev-parse HEAD`, or `none (not a git repository)` when Git metadata is unavailable; use `clean` or `dirty (N paths)` from `git status --porcelain`, or `none (not a git repository)` when unavailable; in PR scope also keep `BASE_REF` and `PR_BASE_REF`.

When `RANKED_MODE=true`, read `references/ranked-mode.md` now and follow it in place of Phases 2-4. Phase 1's `KNOWN_ADRS`, `KNOWN_OUT_OF_SCOPE`, `HOT_SPOTS`, `CO_CHANGE`, and provenance carry into it.

Ranked mode uses these shared resources; resolve their paths here and pass them through the adapter to reviewers as needed:

- `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-workflow.md` — team and solo audit execution, filtering, ranking, and reporting.
- `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-rubric.md` — evidence standards and scoring.
- `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/assets/report-template.md` — the weakness report schema.
- `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md` — the provenance and finding-data contract the report follows.

**Resumable fan-out.** Agent-launching modes use `${CLAUDE_PLUGIN_ROOT}/shared/agents/references/resumable-fanout.md` with skill slug `code-refactor-opportunities`; ranked `--solo` bypasses fan-out and keeps no run directory. For fan-out modes, compute the tree with `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-tree-id.sh --exclude <each report output path this skill can write>` (including both default reports and any resolved custom `--output` path). Resolve re-entry now, before Phase 2 or the ranked workflow. Key inputs: `SCOPE_MODE`, the sorted resolved file list, the feature name, the `PLANNED_CHANGE` text with `--for`, `PR_BASE_REF` in PR scope, whether the readability agent was requested, `RANKED_MODE`, the resolved report output path, and in ranked mode the execution mode (`team` or `solo`), `--max-findings`, and the resolved `--base` commit. In Phase 2, each scan agent is a stage 1 roster entry whose `launch` records its category group and any scope slice.

### Phase 2 — Parallel Scan

Read `references/checklist.md` for the full checklist of categories and recording format. For findings in the Structural & Architectural and Coupling & Dependencies categories — anywhere depth, seams, wrappers, speculative indirection, or scattered concepts are at issue — read `${CLAUDE_PLUGIN_ROOT}/shared/architecture/references/architecture-language.md` and use that vocabulary in the finding. Specifically, before flagging a wrapper as shallow, apply the **deletion test**; before flagging an interface as a speculative seam, apply the **adapter-count rule** ("one adapter = hypothetical seam, two adapters = real seam"); before proposing a **deepening candidate**, gather the scattering evidence and interface sketch the glossary requires. A finding that does not satisfy these tests is not yet a finding.

Launch parallel Explore agents to cover the codebase efficiently. Launch each with the model selected under **Subagent models**. If the host has no subagent mechanism, scan the category groups one after another in the main thread. Split work by **category group**, not by directory, so each agent builds cross-cutting expertise:

- **Agent 1 — Structure & Dead Code**: categories 1 (Dead Code), 8 (Coupling & Dependencies), 9 (Structural & Architectural). Pass it `CO_CHANGE` and the resolved glossary path; it treats each co-change pair as a deepening-candidate lead to confirm or reject from the code.
- **Agent 2 — Logic & Complexity**: categories 3 (Complexity), 4 (Abstraction Issues), 7 (Error Handling)
- **Agent 3 — Duplication & Types**: categories 2 (Duplication), 6 (Type & Safety Issues), 10 (Performance Candidates)
- **Agent 4 — Readability**: category 5 (Naming & Readability) — only if the user explicitly asks for naming/readability review, otherwise skip this agent.

When `PLANNED_CHANGE` is set, pass it to every agent.

Each agent must:

- Read the checklist reference file for its assigned categories.
- Scan all files in scope for findings in those categories. When `HOT_SPOTS` is non-empty, scan those files first and with extra depth; the rest of the scope is still required, hot spots reorder the scan rather than shrink it.
- Apply the When-NOT-to-flag pre-filter before recording.
- Record each finding with: location, category, severity, confidence, effort, description, suggested fix.
- When `SCOPE_MODE=pr`, include `PR relevance: <why this is caused by the PR>` on every finding, naming which of the five categories from the **PR relevance gate** (defined in Phase 1) the finding satisfies. "The file was touched" is not enough.
- When `SCOPE_MODE=pr`, do not record repository-wide cleanup themes just because the changed file reveals them. If the fix would primarily modify untouched files or address a problem that existed unchanged in `PR_BASE_REF`, emit it as `NOTICED BUT NOT TOUCHING` with `Why skipping: pre-existing / outside PR scope`.
- When `PLANNED_CHANGE` is set, include the checklist's `Change relevance` line on every finding. Emit a finding that would not ease the planned change as `NOTICED BUT NOT TOUCHING` with `Why skipping: does not ease the planned change`.
- When the agent spots something outside its assigned categories, emit a `NOTICED BUT NOT TOUCHING` entry instead of silently re-categorizing into its own bucket:

  ```
  NOTICED BUT NOT TOUCHING: <file:line — what was seen>
  Why skipping: outside assigned category group
  ```

  These entries are collected in Synthesis and surfaced in the report as uncategorized observations, not folded into the agent's findings.

- Return findings as a structured list.

### Phase 3 — Synthesis

1. Collect all agent findings and `NOTICED BUT NOT TOUCHING` entries.
2. Deduplicate (same location + same issue = one finding). If one category dominates, spot-check a sample of its findings against the When-NOT-to-flag rejections; do not trim findings to fit a ratio.
3. **Apply the scope's relevance gate** before severity assignment. Full, path, and feature runs without `--for` skip this step.

   **With `PLANNED_CHANGE` set, apply the change relevance gate.** Keep findings whose `Change relevance` names a concrete way the fix eases the planned change, and move the rest to `Noticed But Not Touching`. If none survive, report that the planned change needs no preparatory refactor; do not fill the report with general cleanup.

   **With `SCOPE_MODE=pr`, apply the PR relevance gate.** Cross-reference each candidate against `PR_CHANGE_MAP` and `PR_BASE_REF`:
   - Keep findings that satisfy the PR relevance gate defined in Phase 1.
   - Filter findings in files outside the PR file set, findings on unchanged lines with no PR-caused call-chain evidence, findings whose problem existed unchanged in the base tree, findings whose suggested fix is mainly broad cleanup in untouched files, and findings whose only relevance is "this file changed."
   - Move filtered material to the report's PR-scope observations section, or to `NOTICED BUT NOT TOUCHING` if the report template has no dedicated section. Do not include filtered PR-scope observations in severity tables, themes, or recommended refactor order.
   - If every candidate is filtered, report that there are no PR-scoped refactor opportunities. Do not widen the scan to full-repo cleanup.

4. **Filter against `KNOWN_OUT_OF_SCOPE`.** For each finding, check whether its concept plausibly matches a slug in `KNOWN_OUT_OF_SCOPE`. If yes, read that file and either drop the finding (clean concept match, no new evidence) or annotate it as `_"matches .out-of-scope/<slug>.md (decided <date>) — re-evaluate?"_` when concrete new evidence has accumulated. Default is silent skip; the annotation is the exception. Symmetric to the ADR filter below.
5. **Filter against `KNOWN_ADRS`.** For each finding, check whether it contradicts an accepted ADR. If the contradiction is theoretical (the ADR rejected this exact refactor and no concrete new evidence has emerged), drop the finding silently — the ADR is decision-of-record. Surface as `_"contradicts ADR-NNNN — but worth reopening because <concrete new evidence>"_` only when real friction has accumulated since the ADR was accepted. The default is silent skip; the annotation is the exception.
6. Assign final severity. Promote findings that appear in 3+ locations to at least medium. Then assign `RO-001`, `RO-002`, ... to every surviving finding and deepening candidate, sorted by severity (high first) and then location. A deepening candidate takes the severity of the strongest finding it absorbs, or `suggestion`, with Category `Deepening candidate`.
7. Group related findings into **themes** — patterns that share a root cause or would benefit from a coordinated fix.
8. **Rule of 500 — automation trigger.** For any theme whose combined blast radius exceeds **500 lines**, mark the theme as an automation candidate and recommend a codemod, AST transform, or batch refactor tool instead of manual per-file fixes. Hand edits at that size drift between call sites and produce a diff too large to review line by line.
9. Determine a **recommended refactor order** considering:
   - With `PLANNED_CHANGE` set, the refactors that most shrink the planned change first
   - High-severity items first
   - Quick wins (small blast radius, high clarity gain) early
   - Dependencies between findings (fix A before B)
   - Group thematically related changes together
   - Automation-candidate themes (≥500 lines) separated from manual fixes in the order

### Phase 4 — Report

1. Read `assets/report-template.md` and `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md` for the output format.
2. Produce the report following that template. In the "Patterns & Themes" section, mark each theme's total line count and flag themes ≥500 lines as **automation candidates**. Write `## Report Provenance` and one `## Breakdown-Ready Finding Data` block per `RO-NNN` item; in PR scope put the PR relevance sentence in **Scope notes**, and with `--for` put the change relevance sentence there.
3. In PR mode, include `PR relevance` for every active finding using the PR-only table column described in the template, and include the count of filtered PR-scope observations in the summary. In non-PR scopes, omit PR relevance entirely. With `--for`, include `Change relevance` the same way in the template's `Change Relevance` column. Filtered observations must not be described as findings.
4. **Depth/seam findings carry extra fields.** Any finding whose category is Structural or Coupling and whose vocabulary comes from the shared glossary must include a one-line **deletion test** result (e.g., "inlining at the 1 call site removes 4 lines, no caller becomes harder to read") and an **adapter count** when claiming a seam is speculative. Deepening candidates carry the glossary's deepening fields instead — evidence, proposed interface, what moves behind it, tests, and benefit — and go in the report's Deepening Candidates section. Findings missing these fields are not yet ready and should be dropped at this point, not paper-clipped together.
5. **Names follow the project glossary.** When `UBIQUITOUS_LANGUAGE.md` was read in Phase 1, use the canonical domain terms in finding titles and descriptions. Default helper-class language is a tell that the scan didn't read the project's own vocabulary.
6. Write the report to `REFACTOR_OPPORTUNITIES_OVERVIEW.md` in the project root. Overwrite any prior report — the file represents the latest scan only. Then mark the run complete.
7. End the run with `Agents launched: N` — the exact number of scan agents launched in Phase 2, or `0` when the scan ran in the main thread — so an orchestrator can account for review cost. When results were reused, add the `Agents reused:` line from the resumable fan-out contract.
8. Present a summary to the user with:
   - Total findings by severity
   - Top 3 themes (with automation-candidate flag if applicable)
   - Recommended first refactor to tackle; with `--for`, the refactor that would make the planned change easiest, or that the change needs none

   When nothing in scope is worth changing, say so plainly rather than promoting low-confidence findings to fill the summary.

9. **Close the rejection loop.** If the user declines a recommended candidate with a load-bearing reason, offer to record the rejection — `/kramme:docs:track-rejected-enhancements` for scoped enhancements, or `/kramme:docs:adr` when the rejection is an architectural decision a future maintainer might re-propose. Recorded rejections are what the Phase 3 `KNOWN_OUT_OF_SCOPE` and `KNOWN_ADRS` filters read, so future scans skip the candidate automatically.
10. **Hand off one item.** Unless another skill invoked this one, such as the refactor gate in review convergence, end by asking the user which `RO-NNN` item, if any, to take forward, then stop. Do not design or implement it in this run. Work on one item per session, and pass the next step only that item's report blocks and the report's `## Report Provenance` section, not the whole report. Route the chosen item by kind:
    - **Deepening candidate:** use `kramme:discovery:interview --decision-tree` to settle its constraints, what moves behind the seam, which tests survive, and the shape of its interface, or `kramme:code:api-design --design-twice` to compare interface shapes. Record the decision in a spec or issue before implementing it.
    - **Narrow, behavior-preserving fix:** offer `/kramme:code:refactor-pass` on that finding's files.
    - **Item to schedule for later:** offer `/kramme:code:breakdown-findings` for a local PR plan or `/kramme:linear:breakdown-findings` for a Linear issue, passing the report's `## Report Provenance` section followed by that item's `## Breakdown-Ready Finding Data` block as the source, so the breakdown can still check the scanned commit and working tree.

    To schedule every remaining item instead, the user can run either breakdown skill with the whole report as the source.

## Guidelines

- **Evidence over speculation.** Every finding must reference a concrete file and line range. Do not flag hypothetical issues.
- **Respect project conventions.** If the project intentionally uses a pattern (documented in project instruction files or established by consistent usage), do not flag it.
- **Be specific.** "This function is too complex" is not a finding. "Function `processOrder` (src/orders.ts:45-120) has 8 branches and 3 levels of nesting — extract validation into a separate function" is.
- **Do not perform the refactors.** This skill identifies opportunities. The user decides what to act on, and Phase 4 step 10 routes the item they pick.
