---
name: kramme:code:refactor-opportunities
description: "Scan the full codebase, current PR, a named file/folder, or a named feature for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, or wants a codebase health check. Flags themes whose combined blast radius exceeds 500 lines as automation candidates."
disable-model-invocation: false
user-invocable: true
argument-hint: "[full | pr | path <file-or-folder> | feature <name>]"
kramme-platforms: [claude-code]
---

# Refactor Opportunities

Systematically scan the codebase for refactoring candidates, categorize findings by severity, and produce a prioritized report.

**Arguments:** "$ARGUMENTS"

## Inputs

- **Scope selector** (optional): the skill resolves arguments to exactly one of `full`, `pr`, `path`, or `feature`. Defaults to `full`.
- **Full codebase**: omit arguments, say `full`, `full codebase`, `repo`, `everything`, or `all`, or pass `--scope full`. Scan all source directories.
- **Current PR**: say `pr`, `current PR`, `diff`, or `changes`, or pass `--scope pr`. Scan the files changed by the current branch against the resolved base branch, plus staged, unstaged, and untracked files. Changed files are context; active findings must be caused by the PR changes, not merely pre-existing debt in touched files.
- **Named path**: pass `path <file-or-folder>`, `--scope path <file-or-folder>`, or a bare path-shaped argument that resolves to an existing file, folder, glob match, or file list. Scan only the matching files.
- **Named feature**: pass `feature <name>`, `--scope feature <name>`, or `--feature <name>`. A bare argument that is neither a reserved keyword nor path-shaped is also treated as a feature name; use the explicit `feature <name>` form when the feature name collides with a reserved keyword (`full`, `full codebase`, `repo`, `everything`, `all`, `pr`, `current PR`, `diff`, `changes`). Resolve the feature to its implementation, tests, routes, schemas, docs, and adjacent modules before scanning.
- **Disambiguation** (apply in order; first match wins):
  1. A typed mode form (`--scope <mode>`, `--feature <name>`, `path <…>`, `feature <…>`) selects that mode directly.
  2. A bare argument that exactly matches a reserved full-codebase alias (`full`, `full codebase`, `repo`, `everything`, `all`) or PR alias (`pr`, `current PR`, `diff`, `changes`) selects the corresponding mode. To name a feature whose name collides with a reserved keyword, use the explicit `feature <name>` form.
  3. A bare argument is _path-shaped_ when it contains `/`, `.`, or a glob meta-character (`*`, `?`, `[`); a path-shaped argument that resolves selects `path`, and one that does not resolve triggers a clarification ask (do not fall back to `feature`).
  4. Any other bare argument is treated as a feature name.
- If two distinct scope selectors are provided (e.g. `--scope pr` plus a bare path, or `path <…>` plus `feature <…>`), pause and ask which single scope to use. `--base <ref>` is a PR-mode parameter, not a selector, and does not trigger this rule.

## Prerequisites — When NOT to flag a refactor

A high-signal report rejects more than it reports. Do not flag:

- **Code that is already clean.** Not every file needs changes. Skip files that read well and conform to the checklist.
- **Code you don't understand yet.** If a pattern looks wrong but you haven't traced its callers, tests, or history, it is not a finding. Read more, or leave it.
- **Performance-critical code where the alternatives are slower.** "Cleaner" does not override measured performance. Do not flag hot paths without evidence that the simpler form is at least as fast.
- **Code that is about to be rewritten.** If a larger rewrite is already planned or in progress for the same area, flagging its current state is noise. Surface the overlap instead.

These rejections are pre-filters — apply them before recording a finding, not during Synthesis.

## Workflow

### Phase 1 — Orientation

1. Parse `$ARGUMENTS` per the **Inputs** section into a single `SCOPE_MODE`, applying the multi-selector rule from **Inputs** before resolving. The per-mode target is computed in _Resolve the effective scan scope_ below.
2. Use the Read tool to examine `package.json` / `pyproject.toml` / build config to understand the stack and directory layout.
3. Discover project instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents) if present and read the relevant ones to understand project-specific conventions.
4. **Read accepted ADRs.** Look for `docs/decisions/` (or other common ADR locations: `doc/adr/`, `docs/adr/`, `architecture/decisions/`). If found, read every ADR whose status reads `ACCEPTED` (case-insensitive) and store their decisions as `KNOWN_ADRS` — title, status, and a one-line summary of what was decided and what was rejected. Skip ADRs marked `PROPOSED`, `SUPERSEDED`, or `DEPRECATED` — only accepted decisions are decision-of-record. These bound the design space the scan operates in. If no ADR directory exists, proceed silently with `KNOWN_ADRS = []`.
5. **Read project domain language.** If `UBIQUITOUS_LANGUAGE.md` (or similar: `GLOSSARY.md`, `docs/glossary.md`) exists at the project root, read it and store the canonical domain terms. When naming refactor candidates in Phase 4, prefer these terms over internal helper class names — "the Order intake module" is more useful than "the FooBarHandler". If no glossary file exists, proceed silently — do not flag its absence.
6. **Read prior rejections.** If `.out-of-scope/` exists at the project root, list its filenames and store them as `KNOWN_OUT_OF_SCOPE`. Do not open file bodies yet — that happens in Phase 3 only when a finding plausibly matches a slug. If no directory exists, proceed silently with `KNOWN_OUT_OF_SCOPE = []`. See `/kramme:docs:out-of-scope` for the storage skill.
7. Resolve the effective scan scope. Across all modes, exclude `node_modules`, `dist`, build artifacts, generated files, lock files, vendored code, and binary assets. Then per mode:
   - **Full**: list source directories from project structure.
   - **PR**:
     1. Resolve the base ref in this order:
        - Explicit `--base <ref>`.
        - `gh pr view --json baseRefName,isCrossRepository` — if it returns metadata for a same-repo PR, use `origin/<baseRefName>`. For cross-repo PRs (`isCrossRepository == true`), ask for `--base <ref>` instead of guessing. If `gh` is not installed, not authenticated, or reports no PR open for this branch, skip to the next fallback without erroring.
        - Configured upstream, but skip it when it points at `origin/<current-branch>`.
        - `origin/main`, `origin/master`, `main`, then `master`.
     2. If no base can be resolved, report the attempted refs and ask for `--base <ref>` — do not fall back to `full`.
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
8. Build a human-readable `SCOPE_DESCRIPTION` covering mode, resolved target, file count, and source directories — for example `Full codebase (1,247 files across 8 source directories)`, `Current PR against origin/main (14 files)`, `Path src/api (37 files)`, or `Feature "billing exports" (22 files across API, UI, tests, and docs)`. Report it to the user before proceeding.

### Phase 2 — Parallel Scan

Read `references/checklist.md` for the full checklist of categories and recording format. For findings in the Structural & Architectural and Coupling & Dependencies categories — anywhere depth, seams, wrappers, or speculative indirection are at issue — read `references/architecture-language.md` and use that vocabulary in the finding. Specifically, before flagging a wrapper as shallow, apply the **deletion test**; before flagging an interface as a speculative seam, apply the **adapter-count rule** ("one adapter = hypothetical seam, two adapters = real seam"). A finding that does not satisfy these tests is not yet a finding.

Launch parallel Explore agents to cover the codebase efficiently. Split work by **category group**, not by directory, so each agent builds cross-cutting expertise:

- **Agent 1 — Structure & Dead Code**: categories 1 (Dead Code), 8 (Coupling & Dependencies), 9 (Structural & Architectural)
- **Agent 2 — Logic & Complexity**: categories 3 (Complexity), 4 (Abstraction Issues), 7 (Error Handling)
- **Agent 3 — Duplication & Types**: categories 2 (Duplication), 6 (Type & Safety Issues), 10 (Performance Candidates)
- **Agent 4 — Readability**: category 5 (Naming & Readability) — only if the user explicitly asks for naming/readability review, otherwise skip this agent.

Each agent must:

- Read the checklist reference file for its assigned categories.
- Scan all files in scope for findings in those categories.
- Apply the When-NOT-to-flag pre-filter before recording.
- Record each finding with: location, category, severity, description, suggested fix.
- When `SCOPE_MODE=pr`, include `PR relevance: <why this is caused by the PR>` on every finding, naming which of the five categories from the **PR relevance gate** (defined in Phase 1) the finding satisfies. "The file was touched" is not enough.
- When `SCOPE_MODE=pr`, do not record repository-wide cleanup themes just because the changed file reveals them. If the fix would primarily modify untouched files or address a problem that existed unchanged in `PR_BASE_REF`, emit it as `NOTICED BUT NOT TOUCHING` with `Why skipping: pre-existing / outside PR scope`.
- When the agent spots something outside its assigned categories, emit a `NOTICED BUT NOT TOUCHING` entry instead of silently re-categorizing into its own bucket:

  ```
  NOTICED BUT NOT TOUCHING: <file:line — what was seen>
  Why skipping: outside assigned category group
  ```

  These entries are collected in Synthesis and surfaced in the report as uncategorized observations, not folded into the agent's findings.

- Return findings as a structured list.

### Phase 3 — Synthesis

1. Collect all agent findings and `NOTICED BUT NOT TOUCHING` entries.
2. Deduplicate (same location + same issue = one finding).
3. **Apply the PR relevance gate when `SCOPE_MODE=pr`.** Cross-reference each candidate against `PR_CHANGE_MAP` and `PR_BASE_REF` before severity assignment:
   - Keep findings that satisfy the PR relevance gate defined in Phase 1.
   - Filter findings in files outside the PR file set, findings on unchanged lines with no PR-caused call-chain evidence, findings whose problem existed unchanged in the base tree, findings whose suggested fix is mainly broad cleanup in untouched files, and findings whose only relevance is "this file changed."
   - Move filtered material to the report's PR-scope observations section, or to `NOTICED BUT NOT TOUCHING` if the report template has no dedicated section. Do not include filtered PR-scope observations in severity tables, themes, or recommended refactor order.
   - If every candidate is filtered, report that there are no PR-scoped refactor opportunities. Do not widen the scan to full-repo cleanup.
4. **Filter against `KNOWN_OUT_OF_SCOPE`.** For each finding, check whether its concept plausibly matches a slug in `KNOWN_OUT_OF_SCOPE`. If yes, read that file and either drop the finding (clean concept match, no new evidence) or annotate it as `_"matches .out-of-scope/<slug>.md (decided <date>) — re-evaluate?"_` when concrete new evidence has accumulated. Default is silent skip; the annotation is the exception. Symmetric to the ADR filter below.
5. **Filter against `KNOWN_ADRS`.** For each finding, check whether it contradicts an accepted ADR. If the contradiction is theoretical (the ADR rejected this exact refactor and no concrete new evidence has emerged), drop the finding silently — the ADR is decision-of-record. Surface as `_"contradicts ADR-NNNN — but worth reopening because <concrete new evidence>"_` only when real friction has accumulated since the ADR was accepted. The default is silent skip; the annotation is the exception.
6. Assign final severity. Promote findings that appear in 3+ locations to at least medium.
7. Group related findings into **themes** — patterns that share a root cause or would benefit from a coordinated fix.
8. **Rule of 500 — automation trigger.** For any theme whose combined blast radius exceeds **500 lines**, mark the theme as an automation candidate and recommend a codemod, AST transform, or batch refactor tool instead of manual per-file fixes. Addy's rule: _"If a refactoring would touch more than 500 lines, invest in automation."_ Manual edits at that scale are error-prone and review-hostile.
9. Determine a **recommended refactor order** considering:
   - High-severity items first
   - Quick wins (small blast radius, high clarity gain) early
   - Dependencies between findings (fix A before B)
   - Group thematically related changes together
   - Automation-candidate themes (≥500 lines) separated from manual fixes in the order

### Phase 4 — Report

1. Read `assets/report-template.md` for the output format.
2. Produce the report following that template. In the "Patterns & Themes" section, mark each theme's total line count and flag themes ≥500 lines as **automation candidates**.
3. In PR mode, include `PR relevance` for every active finding using the PR-only table column described in the template, and include the count of filtered PR-scope observations in the summary. In non-PR scopes, omit PR relevance entirely. Filtered observations must not be described as findings.
4. **Depth/seam findings carry extra fields.** Any finding whose category is Structural or Coupling and whose vocabulary comes from `references/architecture-language.md` must include a one-line **deletion test** result (e.g., "inlining at the 1 call site removes 4 lines, no caller becomes harder to read") and an **adapter count** when claiming a seam is speculative. Findings missing these fields are not yet ready and should be dropped at this point, not paper-clipped together.
5. **Names follow the project glossary.** When `UBIQUITOUS_LANGUAGE.md` was read in Phase 1, use the canonical domain terms in finding titles and descriptions. Default helper-class language is a tell that the scan didn't read the project's own vocabulary.
6. Write the report to `REFACTOR_OPPORTUNITIES_OVERVIEW.md` in the project root. Overwrite any prior report — the file represents the latest scan only.
7. Present a summary to the user with:
   - Total findings by severity
   - Top 3 themes (with automation-candidate flag if applicable)
   - Recommended first refactor to tackle

## Guidelines

- **Evidence over speculation.** Every finding must reference a concrete file and line range. Do not flag hypothetical issues.
- **Respect project conventions.** If the project intentionally uses a pattern (documented in project instruction files or established by consistent usage), do not flag it.
- **No false positives over completeness.** It is better to miss a low-severity issue than to report something that isn't actually a problem.
- **Be specific.** "This function is too complex" is not a finding. "Function `processOrder` (src/orders.ts:45-120) has 8 branches and 3 levels of nesting — extract validation into a separate function" is.
- **Do not perform the refactors.** This skill identifies opportunities. The user decides what to act on. If they want to proceed, they can use `kramme:code:refactor-pass` on specific findings.

---

## Common Rationalizations

These are how a scan turns from high-signal into noise. Each has a correct response:

- _"This feels inconsistent, probably worth flagging."_ → Not a finding without evidence. A concrete inconsistency across 3+ locations is a finding; a vague feeling is not.
- _"I'll flag it at low severity just to be safe."_ → Severity inflation in reverse. If it is not worth acting on, it is not worth recording.
- _"This pattern looks odd; the project probably wants it fixed."_ → Check the project instruction files and existing usage first. Intentional patterns are not findings.
- _"I can't explain why it's wrong but it feels off."_ → Not a finding. Read more, or leave it.
- _"This category has few findings; let me dig for more."_ → No. A short category list is valid data. Padding with low-signal items degrades the whole report.

## Red Flags

If you notice any of these during the scan, stop and tighten the filter:

- Findings without a file and line range.
- More than ~30% of findings concentrated in one category — usually a sign the filter is too loose for that category.
- Severity inflation (low items promoted to medium without the 3+ locations rule).
- Themes recommended for manual refactor despite exceeding 500 lines — the Rule of 500 was missed.
- The report recommends changes that conflict with documented project conventions.
- `NOTICED BUT NOT TOUCHING` entries were silently folded into findings instead of surfaced separately.
- In PR mode, a finding is in a touched file but fails the PR relevance gate defined in Phase 1.
- In PR mode, a theme requires broad edits in untouched files but is presented as a PR-scoped finding.
- A wrapper flagged as "unnecessary abstraction" without a deletion-test result attached — the test is what distinguishes a pass-through from a real consolidator.
- A finding re-surfaces a refactor that was already considered and rejected in an accepted ADR, with no concrete new evidence — the ADR is decision-of-record; only re-open when the trade-off has actually shifted.

## Verification

Before writing the report, self-check:

- [ ] Every finding has a file path and line range.
- [ ] Every finding passed the When-NOT-to-flag pre-filter (not clean code, not uncomprehended, not hot-path-without-evidence, not about-to-be-rewritten).
- [ ] No finding contradicts a documented project convention.
- [ ] Themes exceeding 500 lines are marked automation candidates.
- [ ] `NOTICED BUT NOT TOUCHING` entries are surfaced as a separate section, not mixed into findings.
- [ ] The report has fewer findings than the raw agent output (filtering and deduplication actually happened).
- [ ] In PR mode, every active finding has a concrete `PR relevance` line and passed the PR relevance gate.
- [ ] In PR mode, filtered pre-existing or out-of-scope observations are not counted in severity totals, themes, or recommended order.
- [ ] Every Structural / Coupling finding uses the architectural glossary and carries a deletion-test line; speculative-seam findings carry an adapter count.
- [ ] No finding contradicts a `KNOWN_ADRS` entry without an explicit `contradicts ADR-NNNN` annotation backed by concrete new evidence.

If any box is unchecked, fix the gap before writing the report.
