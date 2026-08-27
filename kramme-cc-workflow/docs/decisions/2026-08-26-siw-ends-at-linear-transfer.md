# SIW Ends at Linear Transfer

- Status: ACCEPTED
- Date: 2026-08-26
- Deciders: repository maintainers

## Context

SIW originally covered the full local lifecycle: discovery, specification, issue definition, implementation, implementation auditing, iteration, Pull Request preparation, and final archival. The maintainer now uses SIW only to reach a satisfactory first specification and issue set, then moves that work permanently into Linear.

The local 30-day usage report collected on 2026-08-26 recorded no SIW skill invocations. The retained preparation and transfer skills still define the desired workflow, while the local implementation and tracker-maintenance skills duplicate the Linear path and make routing ambiguous.

## Decision

SIW is the local preparation and migration workflow. It owns discovery, initialization, product and specification audits, safe audit fixes, audit resolution, local issue definition, phase generation, one-way transfer to Linear, and explicit local cleanup. Once transfer succeeds, Linear is the source of truth for implementation, Pull Requests, and ongoing issue management.

Remove these SIW entry points:

- `kramme:siw:continue`
- `kramme:siw:issue-implement`
- `kramme:siw:issue-to-pr`
- `kramme:siw:implementation-audit`
- `kramme:siw:issue-reindex`
- `kramme:siw:reset`
- `kramme:siw:close`
- `kramme:siw:breakdown-findings`

Rename `kramme:siw:wayfinder` to `kramme:discovery:wayfinder` because it produces pre-SIW decision maps and can hand off to SIW or another execution workflow.

The migration routes are:

| Removed entry point | Replacement |
| --- | --- |
| `kramme:siw:continue` | Invoke the next retained preparation command directly. |
| `kramme:siw:issue-implement` | Transfer first, then use `kramme:linear:issue-implement`. |
| `kramme:siw:issue-to-pr` | Transfer first, then use `kramme:linear:issue-to-pr`. |
| `kramme:siw:implementation-audit` | No direct whole-initiative equivalent; use `kramme:linear:issue-to-pr` for per-issue review convergence and final verification, or `kramme:linear:review-pr` to audit an existing Pull Request against its issue. |
| `kramme:siw:issue-reindex` | Preserve stable local IDs until transfer; manage the resulting issues in Linear. |
| `kramme:siw:reset` | Start a separate SIW preparation run only when a new initial issue set is needed. |
| `kramme:siw:close` | Transfer durable specifications and decisions to Linear, then use `kramme:siw:remove`. |
| `kramme:siw:breakdown-findings` | Use `kramme:siw:resolve-audit`, which already provides decision-ready analysis and issue creation. |
| `kramme:siw:wayfinder` | Use `kramme:discovery:wayfinder`. |

## Consequences

Positive:

- SIW has one clear terminal handoff instead of competing local and Linear implementation paths.
- The public catalog loses obsolete orchestration, maintenance, and post-implementation surfaces.
- Local specifications and initial issue breakdowns remain available before the external write boundary.

Negative:

- Existing callers of removed command names must update immediately.
- SIW no longer offers offline implementation after issue generation.
- Whole-initiative implementation conformance auditing is no longer a standalone SIW phase.

## Alternatives Considered

### Keep local implementation as an alternative to Linear

Rejected because the maintainer has chosen Linear as the implementation source of truth, and maintaining two complete execution lifecycles creates routing and maintenance cost without current use.

### Remove all SIW audit and issue-definition skills

Rejected because the maintainer still wants to refine the first specification and issue set locally before creating external records.

### Keep Wayfinder in the SIW namespace

Rejected because Wayfinder runs before SIW exists, stores its own `.context` artifacts, and can hand off outside SIW.
