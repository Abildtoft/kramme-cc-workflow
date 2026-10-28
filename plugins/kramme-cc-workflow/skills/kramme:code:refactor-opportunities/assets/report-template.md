# Refactor Opportunities Report

**Project:** {{project}} **Date:** {{date}} **Scope:** {{scope description}} **Files scanned:** {{count}}

## Report Provenance

- **Producer:** kramme:code:refactor-opportunities ({{mode}})
- **Scope:** {{scope description}}
- **Scanned commit:** {{full git rev-parse HEAD at scan start, or none (not a git repository)}}
- **Working tree:** {{clean / dirty (N paths) / none (not a git repository)}}
- **Base branch:** {{PR scope: base ref and merge-base commit; otherwise none}}
- **Generated:** {{YYYY-MM-DD}}
- **Schema:** breakdown-ready-findings v1

---

## Executive Summary

{{1-3 sentences: overall health, biggest themes, recommended starting point}}

---

{{Severity tables: In Current PR scope only, add a `PR Relevance` column between `Location` and `Description` and populate it for every active finding. In full, path, and feature scopes, omit PR relevance entirely.}}

## High Severity

| ID     | Category | Location      | Description | Suggested Fix |
| ------ | -------- | ------------- | ----------- | ------------- |
| RO-001 | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

## Medium Severity

| ID     | Category | Location      | Description | Suggested Fix |
| ------ | -------- | ------------- | ----------- | ------------- |
| RO-001 | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

## Low Severity

| ID     | Category | Location      | Description | Suggested Fix |
| ------ | -------- | ------------- | ----------- | ------------- |
| RO-001 | {{cat}}  | {{file:line}} | {{desc}}    | {{fix}}       |

---

## Patterns & Themes

{{Group findings that share a root cause or would benefit from a single coordinated fix. For each theme, list the finding IDs it covers and the combined line count. Mark any theme whose combined blast radius exceeds 500 lines as an **automation candidate** (codemod / AST transform / batch refactor).}}

| Theme     | Findings              | Combined lines | Automation candidate? |
| --------- | --------------------- | -------------- | --------------------- |
| {{theme}} | {{RO-001, RO-002, …}} | {{count}}      | {{yes / no}}          |

## Deepening Candidates

{{One block per deepening candidate, strongest evidence first. Write "None found." when the scan produced none. Name each candidate with the project's domain terms.}}

### {{RO-NNN}}: {{candidate name}}

- **Files involved:** {{paths}}
- **Evidence:** {{co-change counts, or the files one ordinary change has to touch}}
- **Proposed interface:** {{what callers would call}}
- **What moves behind it:** {{files, helpers, or caller logic that become implementation}}
- **Tests:** {{tests that move to the new interface; old tests on the shallow pieces that get deleted}}
- **Benefit:** {{locality or leverage gained}}

## Recommended Refactor Order

{{Ordered list of refactors to tackle first, considering: risk, blast radius, dependency between findings, and quick wins. Separate automation-candidate themes (≥500 lines) from manual fixes.}}

## Breakdown-Ready Finding Data

{{One block per `RO-NNN` finding and deepening candidate, in ID order, following the shared breakdown-ready findings schema. Write "None." when there are no active findings. Never include Noticed But Not Touching entries or filtered PR-scope observations.}}

### RO-001: {{title}}

- **Severity:** {{high / medium / low / suggestion}}
- **Confidence:** {{HIGH / MED / LOW}}
- **Locations:** {{path:line or path:start-end; …}}
- **Evidence:** {{one to three sentences of concrete evidence}}
- **Suggested fix:** {{smallest useful first fix}}
- **Effort:** {{S / M / L}}
- **Category:** {{category, or Deepening candidate}}
- **Scope notes:** {{PR scope only: PR relevance sentence; omit otherwise}}

## Noticed But Not Touching

{{Observations agents recorded outside their assigned category group. Not findings — surface them here so the user can decide whether to request a follow-up scan.}}

## Filtered PR-Scope Observations

{{Only include this section when Scope is Current PR. List observations that were considered but filtered because they were pre-existing, outside the PR relevance gate, or required broad cleanup in untouched files. These are not findings and must not appear in severity totals, themes, or recommended order.}}
