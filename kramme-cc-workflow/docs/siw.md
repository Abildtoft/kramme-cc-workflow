# Structured Implementation Workflow (SIW)

SIW is the local preparation workflow for complex initiatives. It turns uncertain intent into reviewed specifications and an approved first issue set, then migrates those artifacts one way into Linear. Linear owns implementation, Pull Requests, and ongoing issue management after transfer.

## Workflow Boundary

```text
optional discovery
       │
       ▼
initialize SIW ──► audit and refine specs ──► define the first issue set
                                                       │
                                                       ▼
                                              transfer to Linear
                                                       │
                                                       ▼
                                            remove local SIW files
```

SIW does:

- discover and clarify requirements;
- create or link specifications;
- audit product and specification quality;
- apply mechanical audit fixes and turn decision findings into local issues;
- define individual issues or generate phased issue sets;
- migrate specifications, decisions, milestones, dependencies, and issues into Linear;
- explicitly remove local SIW artifacts after migration is verified.

SIW does not implement issues, prepare Pull Requests, maintain a long-running local backlog, or audit completed implementations. Use the Linear workflows after transfer.

For an initiative too foggy to fit in one planning session, start with `/kramme:discovery:wayfinder`. Wayfinder stores a temporary decision map under `.context/` and hands a planning-ready result into SIW or another workflow.

## Quick Start

```bash
/kramme:siw:discovery "build a notification system" # optional deep discovery
/kramme:siw:init siw/DISCOVERY_BRIEF.md             # create the SIW container and spec
/kramme:siw:product-audit                           # optional product-pressure test
/kramme:siw:spec-audit --apply                      # validate and safely fix the spec
/kramme:siw:generate-phases                         # create the initial phased issue set
/kramme:siw:transfer-to-linear --dry-run            # review the migration plan
/kramme:siw:transfer-to-linear                      # make Linear the source of truth
/kramme:siw:remove                                  # retire local files after verification
```

Use `/kramme:siw:issue-define` instead of `generate-phases` when one coherent issue is enough. Use `/kramme:siw:resolve-audit` when audit findings require decisions rather than mechanical edits.

## Files and Lifecycle

SIW keeps its tracked preparation state under `siw/`. During preparation, `siw:init` may leave authoritative linked source files elsewhere; those files remain the local source of truth until they are copied under `siw/` and their links are updated before transfer. The transfer gate must verify every linked source's disposition before Linear becomes authoritative.

```text
siw/
├── <SPEC>.md
├── supporting-specs/
├── contracts/
├── DISCOVERY_BRIEF.md
├── SPEC_STRENGTHENING_PLAN.md
├── AUDIT_SPEC_REPORT.md
├── PRODUCT_AUDIT.md
├── LOG.md
├── OPEN_ISSUES_OVERVIEW.md
└── issues/
    ├── ISSUE-G-001-*.md
    ├── ISSUE-P1-001-*.md
    └── ...
```

| Artifact | Purpose | Terminal handling |
| --- | --- | --- |
| Main and supporting specifications | Durable requirements and design context | Migrated as Linear Documents, then removed locally only after verification |
| Contract specifications | Referenced contracts selected for migration | Migrated as Linear Documents when selected |
| `LOG.md` | Preparation progress and decisions | Migrated as a Linear Document |
| `OPEN_ISSUES_OVERVIEW.md` and `issues/` | Initial issue set and dependency graph | Migrated to Linear milestones, issues, metadata, and relations |
| Discovery, strengthening, and audit reports | Temporary preparation evidence | Resolve or apply relevant findings before transfer; remove after migration |

Specifications must not depend on temporary SIW files. Put durable requirements and decisions in the specification itself; use the log as migration context, not as the only source of a requirement.

## Artifact Readiness

Retained SIW skills use four readiness states:

- `product-only`: clarifies the problem, users, or desired outcome but lacks testable requirements;
- `requirements-only`: defines scope and success criteria but still lacks planning detail;
- `planning-ready`: supports issue definition or phase decomposition;
- `implementation-ready`: an issue has bounded scope, dependencies, acceptance criteria, mode, and verification.

Discovery and audits move specifications toward `planning-ready`. `issue-define` and `generate-phases` produce `implementation-ready` local issues. Transfer preserves that issue context in Linear; it does not implement the work.

## Specification Refinement

### Discovery

`/kramme:siw:discovery` works before or after a specification exists:

- Greenfield mode writes `siw/DISCOVERY_BRIEF.md`.
- Refinement mode writes `siw/SPEC_STRENGTHENING_PLAN.md` and can apply approved changes with `--apply`.
- `--decision-tree` resolves tightly coupled decisions depth-first.

### Product audit

`/kramme:siw:product-audit` reviews target users, problem/solution fit, user states, critical moments, product scope, success criteria, prioritization, and strategy alignment. Use it when the question is whether the specification proposes the right product for the right users.

### Specification audit

`/kramme:siw:spec-audit` reviews coherence, completeness, clarity, implementation-scope consistency, actionability, testability, rationale documentation, and technical design. Use it when the question is whether implementation can proceed correctly without guessing. It checks that product rationale is explicit and internally consistent, but leaves product correctness, prioritization, and strategy judgment to `/kramme:siw:product-audit`.

- `--inline` returns a read-only report.
- `--apply` delegates mechanical fixes to the canonical safe-fix procedure.
- `--team` performs cross-validated multi-agent analysis when the runtime supports it.
- `--auto` selects the documented non-interactive behavior but does not bypass safety gates.

Use `/kramme:siw:apply-spec-audit-fixes` for deterministic report findings such as broken cross-references, terminology inconsistencies, numbering mistakes, formatting problems, and wording whose specific replacement already exists in the spec.

Use `/kramme:siw:resolve-audit` for findings requiring a choice. It presents an executive summary, alternatives, and a recommendation before creating the selected local SIW issue. Explicitly supplied legacy implementation-audit reports remain readable for migration recovery, but SIW no longer produces new implementation-audit reports.

## Initial Issue Definition

### One issue

`/kramme:siw:issue-define` creates or refines one `G-*` or `P*-*` issue through a guided interview and codebase exploration. It keeps the issue file, overview, and log synchronized.

### Phased issue set

`/kramme:siw:generate-phases` decomposes a planning-ready specification into atomic XS/S/M/L issues with acceptance criteria, verification, dependencies, parallelization guidance, and `AUTO` or justified `HITL` mode.

Issue IDs are stable after publication. Preserve gaps rather than renumbering; Linear identifiers become authoritative after transfer.

The new workflow normally transfers issues while they are `READY`. Legacy `IN PROGRESS`, `IN REVIEW`, and `DONE` states remain readable so existing SIW projects can still migrate safely.

## Transfer to Linear

`/kramme:siw:transfer-to-linear` is a one-way migration, not synchronization.

It can:

- create or reuse one Linear project;
- migrate the main spec, supporting specs, selected contracts, and log as Linear Documents;
- create or reuse milestones from phases;
- create Linear issues from SIW issue files;
- preserve dependencies as text and native relations when supported;
- rewrite SIW-local document and issue references;
- detect duplicate content before writes;
- write retry markers back to source issue files;
- verify created records and rewritten content before recommending cleanup.

The transfer checks for duplicate issue content before creating Linear issues, so retries cannot silently create parallel tickets for the same work.

Always review the generated migration plan. Use `--dry-run` for a no-write preview. If migration is partial, fix the reported unresolved items and resume with `--retry`; do not delete local files while required context remains local-only.

After a clean transfer:

```bash
/kramme:linear:issue-implement TEAM-123
# or
/kramme:linear:issue-to-pr TEAM-123 --ship
```

## Cleanup

`/kramme:siw:remove` is deliberately separate from transfer because deletion has a different permission boundary. It uses recoverable deletion when available, inventories the exact target set, and requires confirmation for permanent specification files.

When retiring a successfully transferred run, use it only after:

- transfer verification reports no failed writes;
- required specifications and selected contracts exist in Linear;
- required local references were rewritten or explicitly resolved;
- non-Markdown artifacts were relocated or uploaded;
- every created Linear issue has a retry marker in its source SIW issue file.

An explicitly abandoned preparation run may skip transfer and use `/kramme:siw:remove` directly under the same inventory, recoverable-deletion, and confirmation safeguards.

## Commands

| Skill | Arguments | Purpose |
| --- | --- | --- |
| `/kramme:siw:discovery` | `[topic \| spec paths \| siw] [--apply] [--decision-tree]` | Discover or strengthen requirements |
| `/kramme:siw:init` | `[spec paths \| folder \| discover] [--auto]` | Create the local preparation container |
| `/kramme:siw:product-audit` | `[spec paths \| siw] [--auto] [--inline]` | Pressure-test product quality |
| `/kramme:siw:spec-audit` | `[spec paths \| siw] [--auto] [--apply] [--inline] [--team] [--model opus\|sonnet\|haiku]` | Audit specification quality |
| `/kramme:siw:apply-spec-audit-fixes` | `[report] [--auto] [--dry-run] [--threshold 60-100] [--allow-dirty]` | Apply deterministic audit fixes |
| `/kramme:siw:resolve-audit` | `[report] [finding IDs] [--auto]` | Resolve decision findings into local issues |
| `/kramme:siw:issue-define` | `[issue ID \| description and context]` | Define or refine one local issue |
| `/kramme:siw:generate-phases` | `[spec path] [--auto]` | Generate the initial phased issue set |
| `/kramme:siw:transfer-to-linear` | `[siw-dir] [--project ...] [--team ...] [--dry-run] [--skip-done] [--skip-existing\|--retry]` | Migrate planning artifacts into Linear |
| `/kramme:siw:remove` | — | Retire local SIW files after transfer or abandonment |

## Migration from the Former Local Implementation Workflow

The local implementation lifecycle was removed on 2026-08-26. Update old commands as follows:

| Former command | Current route |
| --- | --- |
| `/kramme:siw:wayfinder` | `/kramme:discovery:wayfinder` |
| `/kramme:siw:continue` | Inspect `siw/LOG.md` and invoke the next retained preparation command directly |
| `/kramme:siw:issue-implement` | Transfer, then `/kramme:linear:issue-implement` |
| `/kramme:siw:issue-to-pr` | Transfer, then `/kramme:linear:issue-to-pr` |
| `/kramme:siw:implementation-audit` | No direct whole-initiative equivalent; use `/kramme:linear:issue-to-pr` for per-issue review convergence and final verification, or `/kramme:linear:review-pr` to audit an existing Pull Request against its issue |
| `/kramme:siw:issue-reindex` | Preserve stable local IDs and manage issues in Linear after transfer |
| `/kramme:siw:reset` | Start a separate SIW preparation run when a new initial issue set is required |
| `/kramme:siw:close` | Transfer durable context, then `/kramme:siw:remove` |
| `/kramme:siw:breakdown-findings` | `/kramme:siw:resolve-audit` |

See [the decision record](decisions/2026-08-26-siw-ends-at-linear-transfer.md) for the rationale and rejected alternatives.

## Troubleshooting

- **Existing SIW files:** read `siw/LOG.md` and `siw/OPEN_ISSUES_OVERVIEW.md`, then choose discovery/audit, issue definition, phase generation, or transfer directly.
- **Spec is not planning-ready:** run discovery or the relevant audit before issue creation.
- **Multiple spec candidates:** pass the intended main spec explicitly; auto mode stops rather than guessing.
- **Transfer interrupted:** keep the local SIW directory, re-authorize Linear if needed, and resume with `--retry` using the emitted ledger.
- **Migration cannot capture a document or artifact:** relocate or upload it and rerun verification before cleanup.
- **Need ongoing implementation tracking:** transfer to Linear; SIW intentionally has no local implementation path.
