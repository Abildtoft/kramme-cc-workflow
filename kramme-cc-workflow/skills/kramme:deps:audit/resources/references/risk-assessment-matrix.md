# Risk Assessment Matrix

Scoring rubric for dependency update risk assessment.

## Factor 1: Breaking Change Likelihood

| Update Type | Score | Rationale |
|---|---|---|
| Patch (x.x.PATCH) | 1 — Minimal | Bug fixes only, should be safe |
| Minor (x.MINOR.x) | 2 — Low | New features, backwards compatible |
| Major (MAJOR.x.x) | 4 — High | Breaking changes expected |
| Major + deprecated APIs used | 5 — Critical | Known breaking changes affect this project |

## Factor 2: Ecosystem Impact

Count how many files import the package:

| Import Count | Score | Label |
|---|---|---|
| 0-2 files | 1 | Isolated |
| 3-10 files | 2 | Moderate |
| 11-30 files | 3 | Widespread |
| 30+ files | 4 | Pervasive |

## Factor 3: Test Coverage

| Coverage | Score | Label |
|---|---|---|
| Affected areas well-tested | 1 | Covered |
| Partial test coverage | 2 | Partial |
| No tests for affected areas | 3 | Uncovered |

## Overall Risk Calculation

```
risk_score = breaking_likelihood + ecosystem_impact + test_coverage
```

| Total Score | Risk Level |
|---|---|
| 3-4 | **Low** — safe to update |
| 5-7 | **Medium** — update with testing |
| 8-10 | **High** — plan carefully, test thoroughly |
| 11-12 | **Critical** — dedicated migration effort |

## Override Rules

- Any package with a **Critical or High severity CVE** → automatically Critical risk
- Patch updates with no CVE → always Low risk (regardless of other factors)
- Grouped packages (e.g., all `@angular/*`) → assess as a single unit at the group's highest risk

## Examples

| Package | Update | Imports | Tests | Score | Risk |
|---|---|---|---|---|---|
| lodash | 4.17→4.18 (patch) | 12 files | Good | 1+3+1=5 | Medium |
| @angular/core | 17→18 (major) | 45 files | Good | 4+4+1=9 | High |
| tiny-util | 1.0→2.0 (major) | 1 file | None | 4+1+3=8 | High |
| eslint | 8→9 (major) | 3 files | N/A (dev) | 4+2+1=7 | Medium |
| express | 4→5 (major, CVE) | 8 files | Partial | — | Critical (CVE override) |
