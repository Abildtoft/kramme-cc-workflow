---
name: kramme:code:copy-review
description: "Scan the codebase (or a specified scope) for unnecessary, redundant, or duplicative UI text. Identifies labels, descriptions, placeholders, tooltips, and instructions that could be removed because the UI already communicates the same information through its structure."
argument-hint: "[scope — e.g. src/components, or omit for full codebase]"
disable-model-invocation: false
user-invocable: true
---

# Copy Review — Codebase Scan

Scan the codebase for unnecessary UI text using the shared rubric in `references/copy-review-rubric.md`.

**Arguments:** "$ARGUMENTS"

**Shared rubric:** Read `references/copy-review-rubric.md` before filtering files or launching reviewers. It defines UI-relevant file rules, redundancy categories, confidence/severity rules, finding format, and exclusions.

## Inputs

- **Scope** (optional): a directory, glob pattern, or file list to limit the scan. Defaults to the full codebase.
- If the user specifies a scope, respect it. If they say "everything" or give no scope, scan all source directories (skip `node_modules`, `dist`, build artifacts, generated files, lock files, and vendored code).

## Workflow

### Phase 1 — Orientation

1. Parse the optional scope path from `$ARGUMENTS`. If non-empty, store it as `TARGET_SCOPE`. Otherwise set `TARGET_SCOPE` to the repo root.
2. Read `package.json` / build config to understand the stack and directory layout.
3. Discover project instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents) and read the relevant ones for project conventions and target audience.
4. Determine the effective scan scope from `TARGET_SCOPE`. Filter files using the UI-relevant file rules in `references/copy-review-rubric.md`.
5. Count files in scope — report the count to the user before proceeding. If the count is zero, stop with a one-line "no UI-relevant files in scope" message instead of launching a reviewer.

### Phase 2 — Scan

Launch **kramme:copy-reviewer** in audit mode using the platform's agent-invocation primitive with:

- The loaded rubric from `references/copy-review-rubric.md`
- The list of UI-relevant files in scope
- Project conventions from the discovered instruction files and established UI patterns
- Instruction: **"You are in audit mode. Scan all provided files for copy redundancy. Flag all issues regardless of when they were introduced."**

If no separate agent runtime is available, perform the same scan directly in the main thread. If scope exceeds 50 files and an agent-invocation primitive supports parallelism, split into batches and launch multiple reviewer agents in parallel, each scanning a subset; otherwise scan the batches sequentially.

### Phase 3 — Synthesis

1. Collect all findings from agent(s).
2. Deduplicate (same file + same line + same issue = one finding).
3. Group findings by category to identify systemic patterns (e.g., "12 instances of placeholder-label mirror across form components").
4. Promote findings appearing in 3+ locations to at least Important severity (systemic pattern).

### Phase 4 — Report

Write report to `COPY_REVIEW_OVERVIEW.md` in the project root. Overwrite any prior `COPY_REVIEW_OVERVIEW.md` — the file represents the latest scan only.

```markdown
# Copy Review — Codebase Audit

**Date:** {date} **Scope:** {scope description} **Files scanned:** {count}

## Executive Summary

{1-3 sentences: overall copy hygiene, biggest patterns, recommended starting point}

## Findings by Category

### {Category Name} ({count} findings)

| #   | File:Line | Issue  | Severity  | Recommendation |
| --- | --------- | ------ | --------- | -------------- |
| 1   | `path:42` | {desc} | Important | {fix}          |

{repeat for each category with findings}

## Patterns & Themes

- {Systemic patterns — e.g., "The codebase consistently mirrors labels in placeholders across all form components"}

## Recommended Action Order

1. {Highest impact, lowest effort first}
2. {Systemic patterns fixable with a convention change}
3. {Individual fixes}
```

Present a summary to the user with:

- Total findings by severity
- Top patterns
- Recommended first action

Treat `COPY_REVIEW_OVERVIEW.md` as a working artifact — it should **not** be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`.

## Guidelines

- **Apply the shared rubric.** Use `references/copy-review-rubric.md` as the source of truth for categories, exclusions, confidence, severity, and finding format.
- **Evidence over speculation.** Every finding must reference a concrete file and line. Do not flag hypothetical issues.
- **Respect project conventions.** If the project intentionally uses a content strategy (documented in project instruction files or established by consistent usage), do not flag it.
- **No false positives over completeness.** It is better to miss a borderline case than to suggest removing text that serves a purpose.
- **Do not perform the removals.** This skill identifies opportunities. The user decides what to act on.
