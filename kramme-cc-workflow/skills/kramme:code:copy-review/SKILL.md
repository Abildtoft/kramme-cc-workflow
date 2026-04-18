---
name: kramme:code:copy-review
description: "Scan the codebase (or a specified scope) for unnecessary, redundant, or duplicative UI text. Identifies labels, descriptions, placeholders, tooltips, and instructions that could be removed because the UI already communicates the same information through its structure."
argument-hint: "[scope — e.g. src/components, or omit for full codebase]"
disable-model-invocation: false
user-invocable: true
---

# Copy Review — Codebase Scan

Scan the codebase for unnecessary UI text. Finds labels, descriptions, placeholders, tooltips, and instructions that duplicate what the UI already communicates through structure, icons, or interaction patterns.

**Arguments:** "$ARGUMENTS"

## Inputs

- **Scope** (optional): a directory, glob pattern, or file list to limit the scan. Defaults to the full codebase.
- If the user specifies a scope, respect it. If they say "everything" or give no scope, scan all source directories (skip `node_modules`, `dist`, build artifacts, generated files, lock files, and vendored code).

## Workflow

### Phase 1 — Orientation

1. Parse the optional scope path from `$ARGUMENTS`. If non-empty, store it as `TARGET_SCOPE`. Otherwise set `TARGET_SCOPE` to the repo root.
2. Read `package.json` / build config to understand the stack and directory layout.
3. Discover project instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents) and read the relevant ones for project conventions and target audience.
4. Determine the effective scan scope from `TARGET_SCOPE`. Filter to UI-relevant files only:
   - **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
   - **Templates**: `*.html`, `*.hbs`, `*.ejs`, `*.pug`
   - **Views/Pages**: Files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
   - **i18n/translations**: `*.json` files in `locales/`, `i18n/`, `translations/` directories
5. Count files in scope — report the count to the user before proceeding.

### Phase 2 — Scan

Launch **kramme:copy-reviewer** in audit mode via the Task tool with:
- The list of UI-relevant files in scope
- Project conventions from the discovered instruction files and established UI patterns
- Instruction: **"You are in audit mode. Scan all provided files for copy redundancy. Flag all issues regardless of when they were introduced."**

If scope exceeds 50 files, split into batches and launch multiple Task agents in parallel, each scanning a subset.

### Phase 3 — Synthesis

1. Collect all findings from agent(s).
2. Deduplicate (same file + same line + same issue = one finding).
3. Group findings by category to identify systemic patterns (e.g., "12 instances of placeholder-label mirror across form components").
4. Promote findings appearing in 3+ locations to at least Important severity (systemic pattern).

### Phase 4 — Report

Write report to `COPY_REVIEW_OVERVIEW.md` in the project root:

```markdown
# Copy Review — Codebase Audit

**Date:** {date}
**Scope:** {scope description}
**Files scanned:** {count}

## Executive Summary
{1-3 sentences: overall copy hygiene, biggest patterns, recommended starting point}

## Findings by Category

### {Category Name} ({count} findings)

| # | File:Line | Issue | Severity | Recommendation |
|---|-----------|-------|----------|----------------|
| 1 | `path:42` | {desc} | Important | {fix} |

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

- **Evidence over speculation.** Every finding must reference a concrete file and line. Do not flag hypothetical issues.
- **Respect project conventions.** If the project intentionally uses a content strategy (documented in project instruction files or established by consistent usage), do not flag it.
- **No false positives over completeness.** It is better to miss a borderline case than to suggest removing text that serves a purpose.
- **Do not perform the removals.** This skill identifies opportunities. The user decides what to act on.
