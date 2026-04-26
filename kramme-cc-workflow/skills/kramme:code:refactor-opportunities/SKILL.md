---
name: kramme:code:refactor-opportunities
description: "Scan the entire codebase (or a specified scope) for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, or wants a codebase health check. Flags themes whose combined blast radius exceeds 500 lines as automation candidates."
disable-model-invocation: false
user-invocable: true
argument-hint: [scope — e.g. src/api, or omit for full codebase]
---

# Refactor Opportunities

Systematically scan the codebase for refactoring candidates, categorize findings by severity, and produce a prioritized report.

**Arguments:** "$ARGUMENTS"

## Inputs

- **Scope** (optional): a directory, glob pattern, or file list to limit the scan. Defaults to the full codebase.
- If the user specifies a scope, respect it. If they say "everything" or give no scope, scan all source directories (skip `node_modules`, `dist`, build artifacts, generated files, lock files, and vendored code).

## Prerequisites — When NOT to flag a refactor

A high-signal report rejects more than it reports. Do not flag:

- **Code that is already clean.** Not every file needs changes. Skip files that read well and conform to the checklist.
- **Code you don't understand yet.** If a pattern looks wrong but you haven't traced its callers, tests, or history, it is not a finding. Read more, or leave it.
- **Performance-critical code where the alternatives are slower.** "Cleaner" does not override measured performance. Do not flag hot paths without evidence that the simpler form is at least as fast.
- **Code that is about to be rewritten.** If a larger rewrite is already planned or in progress for the same area, flagging its current state is noise. Surface the overlap instead.

These rejections are pre-filters — apply them before recording a finding, not during Synthesis.

## Workflow

### Phase 1 — Orientation

1. Parse the optional scope path from `$ARGUMENTS`. If non-empty, store it as `TARGET_SCOPE`. Otherwise set `TARGET_SCOPE` to the repo root.
2. Use the Read tool to examine `package.json` / `pyproject.toml` / build config to understand the stack and directory layout.
3. Discover project instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents) if present and read the relevant ones to understand project-specific conventions.
4. **Read accepted ADRs.** Look for `docs/decisions/` (or other common ADR locations: `doc/adr/`, `docs/adr/`, `architecture/decisions/`). If found, read every accepted ADR and store their decisions as `KNOWN_ADRS` — title, status, and a one-line summary of what was decided and what was rejected. These bound the design space the scan operates in. If no ADR directory exists, proceed silently with `KNOWN_ADRS = []`.
5. **Read project domain language.** If `UBIQUITOUS_LANGUAGE.md` (or similar: `GLOSSARY.md`, `docs/glossary.md`) exists at the project root, read it and store the canonical domain terms. When naming refactor candidates in Phase 4, prefer these terms over internal helper class names — "the Order intake module" is more useful than "the FooBarHandler". If no glossary file exists, proceed silently — do not flag its absence.
5.5. **Read prior rejections.** If `.out-of-scope/` exists at the project root, list its filenames and store them as `KNOWN_OUT_OF_SCOPE`. Do not open file bodies yet — that happens in Phase 3 only when a finding plausibly matches a slug. If no directory exists, proceed silently with `KNOWN_OUT_OF_SCOPE = []`. See `/kramme:docs:out-of-scope` for the storage skill.
6. Determine the effective scan scope from `TARGET_SCOPE`. List the source directories and file types that will be scanned.
7. Count files in scope — report the count to the user before proceeding.

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
2.5. **Filter against `KNOWN_OUT_OF_SCOPE`.** For each finding, check whether its concept plausibly matches a slug in `KNOWN_OUT_OF_SCOPE`. If yes, read that file and either drop the finding (clean concept match, no new evidence) or annotate it as `_"matches .out-of-scope/<slug>.md (decided <date>) — re-evaluate?"_` when concrete new evidence has accumulated. Default is silent skip; the annotation is the exception. Symmetric to the ADR filter below.
3. **Filter against `KNOWN_ADRS`.** For each finding, check whether it contradicts an accepted ADR. If the contradiction is theoretical (the ADR rejected this exact refactor and no concrete new evidence has emerged), drop the finding silently — the ADR is decision-of-record. Surface as `_"contradicts ADR-NNNN — but worth reopening because <concrete new evidence>"_` only when real friction has accumulated since the ADR was accepted. The default is silent skip; the annotation is the exception.
4. Assign final severity. Promote findings that appear in 3+ locations to at least medium.
5. Group related findings into **themes** — patterns that share a root cause or would benefit from a coordinated fix.
6. **Rule of 500 — automation trigger.** For any theme whose combined blast radius exceeds **500 lines**, mark the theme as an automation candidate and recommend a codemod, AST transform, or batch refactor tool instead of manual per-file fixes. Addy's rule: *"If a refactoring would touch more than 500 lines, invest in automation."* Manual edits at that scale are error-prone and review-hostile.
7. Determine a **recommended refactor order** considering:
   - High-severity items first
   - Quick wins (small blast radius, high clarity gain) early
   - Dependencies between findings (fix A before B)
   - Group thematically related changes together
   - Automation-candidate themes (≥500 lines) separated from manual fixes in the order

### Phase 4 — Report

1. Read `assets/report-template.md` for the output format.
2. Produce the report following that template. In the "Patterns & Themes" section, mark each theme's total line count and flag themes ≥500 lines as **automation candidates**.
3. **Depth/seam findings carry extra fields.** Any finding whose category is Structural or Coupling and whose vocabulary comes from `references/architecture-language.md` must include a one-line **deletion test** result (e.g., "inlining at the 1 call site removes 4 lines, no caller becomes harder to read") and an **adapter count** when claiming a seam is speculative. Findings missing these fields are not yet ready and should be dropped at this point, not paper-clipped together.
4. **Names follow the project glossary.** When `UBIQUITOUS_LANGUAGE.md` was read in Phase 1, use the canonical domain terms in finding titles and descriptions. Default helper-class language is a tell that the scan didn't read the project's own vocabulary.
5. Write the report to `REFACTOR_OPPORTUNITIES_OVERVIEW.md` in the project root.
6. Present a summary to the user with:
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

- *"This feels inconsistent, probably worth flagging."* → Not a finding without evidence. A concrete inconsistency across 3+ locations is a finding; a vague feeling is not.
- *"I'll flag it at low severity just to be safe."* → Severity inflation in reverse. If it is not worth acting on, it is not worth recording.
- *"This pattern looks odd; the project probably wants it fixed."* → Check the project instruction files and existing usage first. Intentional patterns are not findings.
- *"I can't explain why it's wrong but it feels off."* → Not a finding. Read more, or leave it.
- *"This category has few findings; let me dig for more."* → No. A short category list is valid data. Padding with low-signal items degrades the whole report.

## Red Flags

If you notice any of these during the scan, stop and tighten the filter:

- Findings without a file and line range.
- More than ~30% of findings concentrated in one category — usually a sign the filter is too loose for that category.
- Severity inflation (low items promoted to medium without the 3+ locations rule).
- Themes recommended for manual refactor despite exceeding 500 lines — the Rule of 500 was missed.
- The report recommends changes that conflict with documented project conventions.
- `NOTICED BUT NOT TOUCHING` entries were silently folded into findings instead of surfaced separately.
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
- [ ] Every Structural / Coupling finding uses the architectural glossary and carries a deletion-test line; speculative-seam findings carry an adapter count.
- [ ] No finding contradicts a `KNOWN_ADRS` entry without an explicit `contradicts ADR-NNNN` annotation backed by concrete new evidence.

If any box is unchecked, fix the gap before writing the report.
