# Refactor Opportunities Report

**Project:** {{project}}
**Date:** {{date}}
**Scope:** {{scope description}}
**Files scanned:** {{count}}

---

## Executive Summary

{{1-3 sentences: overall health, biggest themes, recommended starting point}}

---

## High Severity

| # | Category | Location | Description | Suggested Fix |
|---|----------|----------|-------------|---------------|
| 1 | {{cat}}  | {{file:line}} | {{desc}} | {{fix}} |

## Medium Severity

| # | Category | Location | Description | Suggested Fix |
|---|----------|----------|-------------|---------------|
| 1 | {{cat}}  | {{file:line}} | {{desc}} | {{fix}} |

## Low Severity

| # | Category | Location | Description | Suggested Fix |
|---|----------|----------|-------------|---------------|
| 1 | {{cat}}  | {{file:line}} | {{desc}} | {{fix}} |

---

## Patterns & Themes

{{Group findings that share a root cause or would benefit from a single coordinated fix. For each theme, list the finding numbers it covers and the combined line count. Mark any theme whose combined blast radius exceeds 500 lines as an **automation candidate** (codemod / AST transform / batch refactor).}}

| Theme | Findings | Combined lines | Automation candidate? |
|-------|----------|----------------|-----------------------|
| {{theme}} | {{#1, #2, …}} | {{count}} | {{yes / no}} |

## Recommended Refactor Order

{{Ordered list of refactors to tackle first, considering: risk, blast radius, dependency between findings, and quick wins. Separate automation-candidate themes (≥500 lines) from manual fixes.}}

## Noticed But Not Touching

{{Observations agents recorded outside their assigned category group. Not findings — surface them here so the user can decide whether to request a follow-up scan.}}
