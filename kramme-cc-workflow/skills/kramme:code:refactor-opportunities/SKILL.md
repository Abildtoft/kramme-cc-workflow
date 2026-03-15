---
name: kramme:code:refactor-opportunities
description: "(experimental) Scan the entire codebase (or a specified scope) for refactoring candidates. Use when the user asks to find refactor opportunities, audit code quality, identify tech debt, or wants a codebase health check."
disable-model-invocation: false
user-invocable: true
argument-hint: [scope — e.g. src/api, or omit for full codebase]
---

# Refactor Opportunities

Systematically scan the codebase for refactoring candidates, categorize findings by severity, and produce a prioritized report.

## Inputs

- **Scope** (optional): a directory, glob pattern, or file list to limit the scan. Defaults to the full codebase.
- If the user specifies a scope, respect it. If they say "everything" or give no scope, scan all source directories (skip `node_modules`, `dist`, build artifacts, generated files, lock files, and vendored code).

## Workflow

### Phase 1 — Orientation

1. Use the Read tool to examine `package.json` / `pyproject.toml` / build config to understand the stack and directory layout.
2. If a `CLAUDE.md` file exists in the project root, read it to understand project-specific conventions.
3. Determine the effective scan scope. List the source directories and file types that will be scanned.
4. Count files in scope — report the count to the user before proceeding.

### Phase 2 — Parallel Scan

Read `references/checklist.md` for the full checklist of categories and recording format.

Launch parallel Explore agents to cover the codebase efficiently. Split work by **category group**, not by directory, so each agent builds cross-cutting expertise:

- **Agent 1 — Structure & Dead Code**: categories 1 (Dead Code), 8 (Coupling & Dependencies), 9 (Structural & Architectural)
- **Agent 2 — Logic & Complexity**: categories 3 (Complexity), 4 (Abstraction Issues), 7 (Error Handling)
- **Agent 3 — Duplication & Types**: categories 2 (Duplication), 6 (Type & Safety Issues), 10 (Performance Candidates)
- **Agent 4 — Readability**: category 5 (Naming & Readability) — only if the user explicitly asks for naming/readability review, otherwise skip this agent.

Each agent must:
- Read the checklist reference file for its assigned categories.
- Scan all files in scope for findings in those categories.
- Record each finding with: location, category, severity, description, suggested fix.
- Return findings as a structured list.

### Phase 3 — Synthesis

1. Collect all agent findings.
2. Deduplicate (same location + same issue = one finding).
3. Assign final severity. Promote findings that appear in 3+ locations to at least medium.
4. Group related findings into **themes** — patterns that share a root cause or would benefit from a coordinated fix.
5. Determine a **recommended refactor order** considering:
   - High-severity items first
   - Quick wins (small blast radius, high clarity gain) early
   - Dependencies between findings (fix A before B)
   - Group thematically related changes together

### Phase 4 — Report

1. Read `assets/report-template.md` for the output format.
2. Produce the report following that template.
3. Write the report to `REFACTOR_OPPORTUNITIES_OVERVIEW.md` in the project root.
4. Present a summary to the user with:
   - Total findings by severity
   - Top 3 themes
   - Recommended first refactor to tackle

## Guidelines

- **Evidence over speculation.** Every finding must reference a concrete file and line range. Do not flag hypothetical issues.
- **Respect project conventions.** If the project intentionally uses a pattern (documented in project files or established by consistent usage), do not flag it. Check for a CLAUDE.md or similar convention file in the project root using the Read tool.
- **No false positives over completeness.** It is better to miss a low-severity issue than to report something that isn't actually a problem.
- **Be specific.** "This function is too complex" is not a finding. "Function `processOrder` (src/orders.ts:45-120) has 8 branches and 3 levels of nesting — extract validation into a separate function" is.
- **Do not perform the refactors.** This skill identifies opportunities. The user decides what to act on. If they want to proceed, they can use `kramme:code:refactor-pass` on specific findings.
