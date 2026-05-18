# Refactor Opportunities Report

**Project:** {{project}} **Date:** {{date}} **Scope:** {{scope description}} **Files scanned:** {{count}}

---

## Executive Summary

{{1-3 sentences: overall health, biggest themes, recommended starting point}}

---

{{Severity tables: In Current PR scope only, add a `PR Relevance` column between `Location` and `Description` and populate it for every active finding. In full, path, and feature scopes, omit PR relevance entirely.}}

## High Severity

| #   | Category | Location      | Description | Suggested Fix |
| --- | -------- | ------------- | ----------- | ------------- |
| 1   | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

## Medium Severity

| #   | Category | Location      | Description | Suggested Fix |
| --- | -------- | ------------- | ----------- | ------------- |
| 1   | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

## Low Severity

| #   | Category | Location      | Description | Suggested Fix |
| --- | -------- | ------------- | ----------- | ------------- |
| 1   | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

---

## Patterns & Themes

{{Group findings that share a root cause or would benefit from a single coordinated fix. For each theme, list the finding numbers it covers and the combined line count. Mark any theme whose combined blast radius exceeds 500 lines as an **automation candidate** (codemod / AST transform / batch refactor).}}

| Theme     | Findings      | Combined lines | Automation candidate? |
| --------- | ------------- | -------------- | --------------------- |
| {{theme}} | {{#1, #2, …}} | {{count}}      | {{yes / no}}          |

## Recommended Refactor Order

{{Ordered list of refactors to tackle first, considering: risk, blast radius, dependency between findings, and quick wins. Separate automation-candidate themes (≥500 lines) from manual fixes.}}

## Noticed But Not Touching

{{Observations agents recorded outside their assigned category group. Not findings — surface them here so the user can decide whether to request a follow-up scan.}}

## Filtered PR-Scope Observations

{{Only include this section when Scope is Current PR. List observations that were considered but filtered because they were pre-existing, outside the PR relevance gate, or required broad cleanup in untouched files. These are not findings and must not appear in severity totals, themes, or recommended order.}}
