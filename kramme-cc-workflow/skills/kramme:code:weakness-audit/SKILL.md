---
name: kramme:code:weakness-audit
description: "Identify the biggest codebase weaknesses across maintainability, readability, and correctness, then write a ranked CODEBASE_WEAKNESS_REPORT.md. Use when the user asks for top weaknesses, codebase health risks, maintainability/readability/correctness audit, or where to invest cleanup effort. Use --team for multi-agent cross-validation. Not for PR-only review, implementation, security-specific audits, or broad refactor opportunity inventories."
argument-hint: "[full | path <file-or-folder> | feature <name>] [--output <path>] [--max-findings N] [--team]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Codebase Weakness Audit

Identify the highest-leverage weaknesses in a codebase across maintainability, readability, and correctness, then produce a ranked report.

**Arguments:** "$ARGUMENTS"

**What it touches:** writes one report file, `CODEBASE_WEAKNESS_REPORT.md` by default. Read-only otherwise. Do not modify implementation code.

## Team Mode

If `$ARGUMENTS` contains `--team`, remove that flag, read `references/team-mode.md`, and follow that workflow instead of the standard workflow below. Pass the remaining arguments through as the team-mode arguments.

## Inputs

- **Scope selector**: defaults to `full`. Accept `full`, `path <file-or-folder>`, `feature <name>`, `--scope full`, `--scope path <file-or-folder>`, or `--scope feature <name>`.
- **Output path**: optional `--output <path>`. Default is `CODEBASE_WEAKNESS_REPORT.md` in the project root. Refuse paths outside the working tree unless the user explicitly confirms.
- **Finding cap**: optional `--max-findings N`. Default is `12`; cap at `20` unless the user explicitly asks for a broader inventory.
- **Base branch**: optional `--base <ref>` only for change-history context. This skill is not PR scoped; use `/kramme:pr:code-review` for PR-only review.
- **Team mode**: optional `--team`. Handled by the Team Mode section above and removed before normal input parsing.

If the arguments contain multiple scope selectors, pause and ask for one scope. If a path-shaped argument does not resolve, ask for clarification instead of treating it as a feature name.

## Workflow

### 1. Orient

1. Parse arguments into `SCOPE_MODE`, `SCOPE_TARGET`, `OUTPUT_PATH`, and `MAX_FINDINGS`.
2. Detect project stack and layout by reading the root config files that exist: `package.json`, `tsconfig.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, framework configs, test configs, lint configs, and CI workflow files.
3. Read relevant project instructions (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, or equivalents) and apply their conventions during the audit.
4. Read accepted architecture decisions from common ADR locations (`docs/decisions/`, `docs/adr/`, `doc/adr/`, `architecture/decisions/`). Store accepted decisions as constraints. Do not flag a weakness that merely contradicts an accepted decision unless new evidence shows the trade-off has shifted.
5. Read project glossary files when present (`UBIQUITOUS_LANGUAGE.md`, `GLOSSARY.md`, `docs/glossary.md`) and use canonical domain terms in finding titles.
6. Detect prior report artifacts (`CODEBASE_WEAKNESS_REPORT.md`, `REFACTOR_OPPORTUNITIES_OVERVIEW.md`, `AGENT_NATIVE_AUDIT.md`, `REVIEW_OVERVIEW.md`) only as context. Do not copy findings without re-validating evidence in the current tree.

### 2. Resolve Scope

1. Build the file set for the requested scope. Exclude generated files, vendored code, lock files, binary assets, build outputs, coverage outputs, `.git`, `.context`, `node_modules`, virtualenvs, and framework build caches.
2. For `full`, scan the main source, test, configuration, and documentation entry points. Avoid spending audit budget on examples, fixtures, and snapshots unless they drive production behavior.
3. For `path`, include only the resolved files or files under the resolved directory.
4. For `feature`, search route names, package names, module names, schemas, tests, docs, flags, and user-facing copy. If the feature maps to multiple unrelated areas or cannot be located, present the candidate groups and ask before continuing.
5. Gather quick quantitative signals when available:
   - largest source files and functions
   - dependency cycles or unusually deep import chains
   - test coverage shape, not just existence
   - recent churn from git history, if the project is a git repository
   - recurring TODO/FIXME/temporary markers
   - repeated error-handling, validation, or state-management patterns
6. Report the resolved scope before scanning: mode, target, file count, primary languages, and output path.

### 3. Apply Rubric

Read `references/audit-rubric.md` before recording findings.

Scan through three lenses in the main thread. For multi-agent cross-validation, use `--team`.

- **Maintainability lens**: module boundaries, coupling, duplication, complexity, ownership clarity, change blast radius, operational friction, and testability.
- **Readability lens**: naming, local comprehension, control-flow clarity, domain language, file organization, comment quality, and traversability from entry points to implementation.
- **Correctness lens**: concrete failure paths, missing boundary validation, invariant breaks, state transitions, error propagation, concurrency/race risks, data integrity, and meaningful test gaps.

Each raw candidate must include:

- concrete file locations and line ranges
- lens: maintainability, readability, correctness, or mixed
- root cause, not only symptom
- evidence from code, tests, history, or project conventions
- likely user, operator, developer, or reviewer impact
- confidence level with reason
- smallest useful first fix
- validation check that would prove the fix worked
- rough effort and blast radius

### 4. Filter Hard

1. Drop candidates without concrete evidence. "Feels messy" is not a finding.
2. Drop style preferences that do not affect comprehension, correctness, or change cost.
3. Drop generic best-practice advice unless the current code shows actual risk or repeated friction.
4. Drop findings that are only missing tests unless the missing test maps to an important behavior, invariant, regression risk, or recently changed area.
5. Drop issues explained by documented project conventions, accepted ADRs, framework guarantees, generated-code contracts, or deliberate performance trade-offs.
6. Keep a candidate that is localized but correctness-critical even if it appears once.
7. Promote a maintainability or readability candidate only when it affects repeated work, important code paths, cross-module changes, onboarding/traversal, or review confidence.
8. Prefer fewer high-confidence findings over a complete inventory. If more than `MAX_FINDINGS` remain, keep only the top-ranked findings and list the rest as filtered or follow-up candidates.

### 5. Rank and Synthesize

1. Score every surviving finding using the scoring worksheet in `references/audit-rubric.md`.
2. Assign stable IDs `WA-001`, `WA-002`, ... after sorting.
3. Sort by priority score, then severity, then confidence.
4. Group related findings into themes. A theme should describe a shared root cause, not a bucket of vaguely similar symptoms.
5. Assign severity:
   - **Critical**: likely incorrect behavior, data loss, production breakage, or repeated failure in an important flow.
   - **High**: materially raises change risk, hides important logic, weakens a core invariant, or causes repeated developer friction.
   - **Medium**: meaningful maintainability/readability/correctness weakness with clear evidence but bounded impact.
   - **Low**: worth noting only as context; normally exclude low findings from the ranked list unless the codebase has no larger issues.
6. Build a recommended fix sequence that separates quick validation wins from larger design work. Do not prescribe a broad rewrite when targeted steps would reduce risk.

### 6. Write Report

1. Read `assets/report-template.md`.
2. Write the report to `OUTPUT_PATH`, overwriting any previous report at that path. Include the resolved scope and date in the header so an overwritten report remains understandable.
3. Include all required sections from the template. If no major weakness is found, write a short report explaining the scope, evidence reviewed, and residual risks instead of inventing findings.
4. Treat the report as a working artifact that should not be committed. It is consumed by the user, by `/kramme:code:breakdown-findings` when turning validated findings into implementation plans, and by follow-up audit runs for comparison.

### 7. Summarize

Reply with:

- report path
- number of findings by severity and lens
- top 3 weaknesses
- recommended first action
- any coverage limitations, skipped directories, or degraded analysis due to unavailable tools

## Artifact Lifecycle

- **Produces/updates:** `CODEBASE_WEAKNESS_REPORT.md` by default, or the path passed with `--output`.
- **Consumed by:** the user for prioritization; `/kramme:code:breakdown-findings` for PR-sized implementation planning; future runs for comparison context.
- **Refresh trigger:** re-run this skill after major refactors, architecture changes, test investments, or before planning a maintenance cycle.
- **Retired by:** `/kramme:workflow-artifacts:cleanup` when the report is no longer useful, or manual deletion.

## Discipline

- Evidence beats coverage. A short report with 5 defensible weaknesses is better than 20 speculative observations.
- Correctness findings must name a plausible failure path or missing invariant.
- Maintainability findings must explain how future changes become riskier or slower.
- Readability findings must explain what a maintainer would misunderstand or fail to find.
- Do not implement fixes. This skill ranks and explains weaknesses; separate implementation work belongs in follow-up tasks.
