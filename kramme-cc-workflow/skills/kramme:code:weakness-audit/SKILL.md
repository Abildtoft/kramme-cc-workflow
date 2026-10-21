---
name: kramme:code:weakness-audit
description: "Identify the biggest codebase weaknesses across maintainability, readability, and correctness using a multi-agent audit team by default, then write a ranked CODEBASE_WEAKNESS_REPORT.md. Use when the user asks for top weaknesses, codebase health risks, maintainability/readability/correctness audit, or where to invest cleanup effort. Use --solo only for a faster single-threaded fallback. Not for PR-only review, implementation, security-specific audits, or broad refactor opportunity inventories."
argument-hint: "[full | path <file-or-folder> | feature <name>] [--output <path>] [--max-findings N] [--solo]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Codebase Weakness Audit

Identify the highest-leverage weaknesses in a codebase across maintainability, readability, and correctness, then produce a ranked report.

**Arguments:** "$ARGUMENTS"

**What it touches:** writes one report file, `CODEBASE_WEAKNESS_REPORT.md` by default. Read-only otherwise. Do not modify implementation code.

## Execution Mode

Team mode is the standard workflow. Set `AUDIT_MODE=solo` when `$ARGUMENTS` contains `--solo`, otherwise `AUDIT_MODE=team`. Remove optional `--team` and `--solo` flags before scope parsing. Use `--solo` only for small scopes, constrained runtimes, or when multi-agent execution is unavailable. In team mode, read `references/team-mode.md` and check its host prerequisites before continuing.

## Inputs

- **Scope selector**: defaults to `full`. Accept `full`, `path <file-or-folder>`, `feature <name>`, `--scope full`, `--scope path <file-or-folder>`, or `--scope feature <name>`.
- **Output path**: optional `--output <path>`. Default is `CODEBASE_WEAKNESS_REPORT.md` in the project root. Refuse paths outside the working tree unless the user explicitly confirms.
- **Finding cap**: optional `--max-findings N`. Default is `20`; cap at `30` unless the user explicitly asks for a broader inventory. Team mode should collect a broader raw candidate pool before final filtering; this cap applies only to active ranked findings in the final report.
- **Base branch**: optional `--base <ref>` only for change-history context. This skill is not PR scoped; use `/kramme:pr:code-review` for PR-only review.
- **Team mode**: default. Optional `--team` is accepted as a no-op compatibility flag and removed before parsing.
- **Solo mode**: optional `--solo`. Handled by the Execution Mode section above and removed before normal input parsing.

If the arguments contain multiple scope selectors, pause and ask for one scope. If a path-shaped argument does not resolve, ask for clarification instead of treating it as a feature name.

## Workflow

Orientation and scope resolution apply to both team and solo runs.

### 1. Orient

1. Parse arguments into `SCOPE_MODE`, `SCOPE_TARGET`, `OUTPUT_PATH`, and `MAX_FINDINGS`.
2. Detect project stack and layout by reading the root config files that exist: `package.json`, `tsconfig.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, framework configs, test configs, lint configs, and CI workflow files.
3. Read relevant project instructions (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, or equivalents) and apply their conventions during the audit.
4. Read accepted architecture decisions from common ADR locations (`docs/decisions/`, `docs/adr/`, `doc/adr/`, `architecture/decisions/`). Store accepted decisions as `KNOWN_ADRS` constraints. Do not flag a weakness that merely contradicts an accepted decision unless new evidence shows the trade-off has shifted.
5. Read project glossary files when present (`UBIQUITOUS_LANGUAGE.md`, `GLOSSARY.md`, `docs/glossary.md`) and use canonical domain terms in finding titles.

### 2. Resolve Scope

1. Build the file set for the requested scope. Exclude generated files, vendored code, lock files, binary assets, build outputs, coverage outputs, `.git`, `.context`, `node_modules`, virtualenvs, and framework build caches.
2. For `full`, scan the main source, test, configuration, and documentation entry points. Avoid spending audit budget on examples, fixtures, and snapshots unless they drive production behavior.
3. For `path`, include only the resolved files or files under the resolved directory.
4. For `feature`, search route names, package names, module names, schemas, tests, docs, flags, and user-facing copy. If the feature maps to multiple unrelated areas or cannot be located, present the candidate groups and ask before continuing.
5. Pass the resolved scope, stack, conventions, `KNOWN_ADRS`, and glossary terms into the shared audit workflow. It gathers quantitative signals and reports the scope before scanning.

### 3. Audit and Report

Read `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-workflow.md` and follow it with the selected `AUDIT_MODE`. Resolve these supporting paths here for that workflow and its reviewer prompts:

- `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-rubric.md` — evidence standards and scoring.
- `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/assets/report-template.md` — the weakness report schema, including Team Review metadata only in team mode.

In team mode, create the multi-agent session `codebase-weakness-audit` using delegate mode before launching reviewers. Shut it down when the workflow finishes or stops early. The orchestrator writes the report.

## Artifact Lifecycle

- **Produces/updates:** `CODEBASE_WEAKNESS_REPORT.md` by default, or the path passed with `--output`.
- **Consumed by:** the user for prioritization; `/kramme:code:breakdown-findings` for PR-sized implementation planning; future runs for comparison context.
- **Refresh trigger:** re-run this skill after major refactors, architecture changes, test investments, or before planning a maintenance cycle.
- **Retired by:** `/kramme:workflow-artifacts:cleanup` when the report is no longer useful, or manual deletion.
