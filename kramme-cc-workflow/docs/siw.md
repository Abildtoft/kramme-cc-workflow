# Structured Implementation Workflow (SIW) Reference

Detailed documentation for the Structured Implementation Workflow. See the [README](../README.md#structured-implementation-workflow-siw) for a summary.

## Table of Contents

- [What SIW Is](#what-siw-is)
- [When to Use SIW](#when-to-use-siw)
- [Quick Start](#quick-start)
- [Overall Workflow](#overall-workflow)
- [Document System](#document-system)
- [Issue Conventions](#issue-conventions)
- [Status Lifecycle](#status-lifecycle)
- [Skill Reference](#skill-reference)
- [Common Workflows](#common-workflows)
- [Design Philosophy](#design-philosophy)
- [Tips & Troubleshooting](#tips--troubleshooting)

## What SIW Is

SIW is a local, file-based workflow for planning, tracking, and implementing complex features. Everything lives in a `siw/` directory as markdown files — no external services required. It tracks issues, decisions, and progress alongside your code, all versioned in git.

The core idea: a **specification** is the permanent source of truth. Issues, logs, and audit reports are temporary artifacts that exist only while work is in progress. When the project closes, decisions flow back into the spec and temporary files are removed.

## When to Use SIW

**Good for:**
- Multi-issue features requiring planning and decision tracking
- Projects spanning multiple sessions where continuity matters
- Work without Linear or when you want local-only tracking
- Technical designs, API documentation, or system architecture

**Not for:**
- Small bug fixes (< 1 day of work)
- Trivial updates or simple refactoring
- Single-file changes with obvious scope

## Quick Start

```
/kramme:siw:init my-feature-spec.md     # Set up workflow from existing spec
/kramme:siw:generate-phases             # Break spec into phase-based issues
/kramme:siw:issue-implement P1-001      # Implement first issue
/kramme:siw:close                       # Generate docs and clean up
```

Or start from scratch with an interactive interview:

```
/kramme:siw:init discover               # Interview-driven spec creation
```

## Overall Workflow

```
/kramme:siw:init
    │
    ├─── Optional spec refinement ──────────────────────┐
    │                                                    │
    │    /kramme:siw:discovery      Strengthen weak specs│
    │    /kramme:siw:spec-audit     8-dimension quality  │
    │                               check                │
    │◄───────────────────────────────────────────────────┘
    │
    ▼
/kramme:siw:generate-phases
    │   (or /kramme:siw:issue-define for ad-hoc issues)
    │
    ▼
┌─► /kramme:siw:issue-implement ◄──────────────────────┐
│       │                                               │
│       │   Repeat for each issue:                      │
│       │   READY → IN PROGRESS → DONE                  │
│       │                                               │
│       ▼                                               │
│   /kramme:siw:implementation-audit                    │
│       │   (verify spec conformance)                   │
│       │                                               │
│       ▼                                               │
│   /kramme:siw:resolve-audit ──────────────────────────┘
│       (triage findings → create new issues)
│
│   /kramme:siw:issues-reindex  (clean up DONE issues mid-workflow)
│
└── Iterate until complete
        │
        ▼
    ┌───────────────────────────────────────────┐
    │ /kramme:siw:close   Generate permanent    │
    │                     docs, remove temp      │
    │                     files                  │
    │                                           │
    │ /kramme:siw:reset   Preserve spec, clear  │
    │                     issues/log for new     │
    │                     iteration              │
    │                                           │
    │ /kramme:siw:remove  Delete all SIW files  │
    │                     without generating     │
    │                     docs                   │
    └───────────────────────────────────────────┘
```

## Document System

### File Overview

| Document | Purpose | Persistence |
|----------|---------|-------------|
| `siw/[YOUR_SPEC].md` | Main specification — single source of truth | **Permanent** |
| `siw/supporting-specs/*.md` | Detailed specs by domain (data model, API, UI) | **Permanent** |
| `siw/LOG.md` | Session progress, decision log, guiding principles | Temporary |
| `siw/OPEN_ISSUES_OVERVIEW.md` | Issue tracking table | Temporary |
| `siw/issues/ISSUE-*.md` | Individual issue files | Temporary |
| `siw/AUDIT_IMPLEMENTATION_REPORT.md` | Implementation audit output | Temporary |
| `siw/AUDIT_SPEC_REPORT.md` | Spec quality audit output | Temporary |
| `siw/SPEC_STRENGTHENING_PLAN.md` | Discovery output | Temporary |

### Typical Directory Layout

```
siw/
├── FEATURE_SPECIFICATION.md          ← Permanent (name chosen at init)
├── supporting-specs/                 ← Permanent (optional, for large projects)
│   ├── 01-data-model.md
│   ├── 02-api-specification.md
│   └── 03-ui-specification.md
├── LOG.md                            ← Temporary
├── OPEN_ISSUES_OVERVIEW.md           ← Temporary
├── AUDIT_IMPLEMENTATION_REPORT.md    ← Temporary (created by audit)
├── AUDIT_SPEC_REPORT.md              ← Temporary (created by audit)
└── issues/                           ← Temporary
    ├── ISSUE-G-001-setup.md
    ├── ISSUE-P1-001-core-feature.md
    ├── ISSUE-P1-002-api-endpoint.md
    └── ISSUE-P2-001-ui-integration.md
```

### Decision Flow

Decisions flow **one way**: from implementation through the log into the spec.

```
Issues → LOG.md → Spec
```

- Decisions made during implementation are recorded in `siw/LOG.md`
- Before marking an issue complete, decisions are synced to the spec (or relevant supporting spec)
- The spec never references temporary documents — it remains self-contained and permanent

### Supporting Specs

Use `siw/supporting-specs/` when:
- The main spec exceeds ~500 lines
- Multiple distinct domains exist (data model, API, UI, user stories)
- You want targeted reading during implementation

**Naming convention:** `NN-descriptor.md` (e.g., `01-data-model.md`, `02-api-specification.md`)

The main spec references supporting specs via a table of contents. During decision sync (step 10 of `issue-implement`), decisions are routed to the appropriate supporting spec by topic.

### Generated Documentation

When closing a project with `/kramme:siw:close`, permanent documentation is generated in `docs/<feature>/`:

```
docs/<feature>/
├── README.md          Project summary
├── decisions.md       Architecture decision records
└── architecture.md    Technical design (if applicable)
```

## Issue Conventions

### Naming

Issues use prefix-based numbering:

| Prefix | Usage | Example |
|--------|-------|---------|
| `G-XXX` | General issues — standalone, cross-cutting | `G-001`, `G-002` |
| `P1-XXX` | Phase 1 issues | `P1-001`, `P1-002` |
| `P2-XXX` | Phase 2 issues | `P2-001`, `P2-002` |
| `P{N}-XXX` | Phase N issues | `P3-001` |

**File naming:** `ISSUE-{prefix}-{number}-{short-description}.md`

Examples: `ISSUE-G-001-setup.md`, `ISSUE-P1-001-core-data-model.md`

### Issue Structure

Each issue file contains:

- **Problem** — What needs to be done
- **Context** — Background and motivation
- **Scope** — What's in and out of scope
- **Acceptance Criteria** — Measurable conditions for completion
- **Technical Notes** — Implementation guidance (optional)
- **Resolution** — Added when complete, documenting what was done

### Creating Issues

- `/kramme:siw:generate-phases` decomposes a spec into phase-based issues automatically, with subagent review for atomicity and testability
- `/kramme:siw:issue-define` creates individual issues through a guided interview process

## Status Lifecycle

```
Created              In Progress           Review              Completed
   │                      │                   │                    │
   ▼                      ▼                   ▼                    ▼
┌─────────┐          ┌─────────┐        ┌─────────┐          ┌─────────┐
│  READY  │ ───────► │IN PROG  │ ─────► │IN REVIEW│ ───────► │  DONE   │
└─────────┘          └─────────┘        └─────────┘          └─────────┘
```

- **READY** — Defined, waiting to be picked up
- **IN PROGRESS** — Currently being implemented
- **IN REVIEW** — Work complete, awaiting review/approval
- **DONE** — Resolved and documented

### Atomic Status Updates

Every status change must update **all three files** simultaneously:

1. **Issue file** (`siw/issues/ISSUE-*.md`) — the `**Status:**` line
2. **Overview** (`siw/OPEN_ISSUES_OVERVIEW.md`) — the issue's table row
3. **Log** (`siw/LOG.md`) — the "Current Progress" section

This is treated as a single atomic operation. Skipping any file leaves tracking inconsistent.

### Phase Completion

When all issues in a phase reach DONE, the phase header in `OPEN_ISSUES_OVERVIEW.md` is marked with `(DONE)` — e.g., `## Phase 2: Core Features (DONE)`.

## Skill Reference

### Initialization & Setup

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:init` | `[spec-file(s) \| folder \| discover]` | Initialize workflow. Accepts existing spec files, a folder of specs, or `discover` for interview-driven spec creation. Creates `siw/` directory with spec, LOG.md, overview, and issues folder. |
| `/kramme:siw:continue` | — | Entry point for resuming. Auto-triggers when SIW files are detected. Reads LOG.md for current state and suggests next action. |

### Specification Refinement

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:discovery` | `[spec-path(s) \| 'siw'] [--apply]` | Targeted interview to strengthen weak specs. Identifies quality gaps and produces concrete improvements. Use `--apply` to auto-update specs with findings. |
| `/kramme:siw:spec-audit` | `[spec-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Audit spec quality across 8 dimensions: coherence, completeness, clarity, scope, actionability, testability, value proposition, technical design. Produces a structured report and optionally creates SIW issues. |
| `/kramme:siw:reverse-engineer-spec` | `[branch \| folder \| file(s)] [--base main] [--model opus\|sonnet\|haiku]` | Generate a spec from existing code. Analyzes git diffs, folders, or files using parallel agents. Produces an SIW-compatible spec. Useful for documenting shipped features or bootstrapping SIW from existing work. |

### Issue Management

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:issue-define` | `[issue-id] or [description and/or file paths]` | Create or improve issues with a guided interview. Supports both new issue creation and refinement of existing issues. Explores the codebase to identify relevant patterns. |
| `/kramme:siw:generate-phases` | `[spec-file-path]` | Decompose a spec into atomic, phase-based issues (`P1-001`, `P2-001`, `G-001`). Each issue is self-contained with tests/validation. Reviews breakdown with a subagent before creating files. |
| `/kramme:siw:issues-reindex` | — | Remove DONE issues and renumber remaining issues from 001 within each prefix group. Verifies DONE issues are captured in the spec before deletion. |

### Implementation

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:issue-implement` | `<G-001 \| P1-001 \| ISSUE-G-XXX>` | Implement an issue with extensive planning before coding. Explores the codebase, asks clarifying questions, creates a technical plan, then offers three execution modes: **Guided** (step-by-step with verification), **Context-only** (you drive, agent prepares), **Autonomous** (agent implements end-to-end). Includes spec sync (step 10) to align decisions back to the spec. |

### Auditing & Quality

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:implementation-audit` | `[spec-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Adversarial, exhaustive audit of code against spec. Pass A checks requirement-by-requirement conformance. Pass B scans for undocumented extensions. Includes conflict reconciliation and coverage gates. |
| `/kramme:siw:resolve-audit` | `[audit-report-path] [finding-id(s)]` | Resolve audit findings one at a time. For each finding: executive summary, alternatives, recommended option, then user choice. Creates SIW issues for findings that need work. |

### Lifecycle Management

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:close` | — | Generate permanent documentation in `docs/<feature>/` (README, decisions, architecture), then remove temporary workflow files. Terminal command for completed projects. |
| `/kramme:siw:reset` | — | Preserve the spec, migrate log decisions into it, then clear issues and LOG.md for a fresh iteration. Use when starting a new round of work on the same project. |
| `/kramme:siw:remove` | — | Delete all SIW files. Uses `trash` for recoverability. No documentation generated. |

### Team Variants

These variants run multiple agents in parallel. They require Agent Teams in Claude Code (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) or a Codex runtime with `multi_agent` enabled.

| Skill | Arguments | Description |
|-------|-----------|-------------|
| `/kramme:siw:spec-audit:team` | `[spec-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Team-based spec audit with parallel dimension analysis. |
| `/kramme:siw:implementation-audit:team` | `[spec-path(s) \| 'siw'] [--model opus\|sonnet\|haiku]` | Team-based implementation audit with simultaneous conformance + extension passes and a dedicated reconciler for conflict resolution. |
| `/kramme:siw:issue-implement:team` | `<G-001 \| P1-001 \| ISSUE-G-XXX>` | Team-based implementation with parallel exploration and planning agents. |

## Common Workflows

### Greenfield Feature

Full lifecycle from spec to completion:

```
/kramme:siw:init my-feature-spec.md          # Link existing spec
/kramme:siw:spec-audit                        # Validate spec quality
/kramme:siw:discovery --apply                 # Fill quality gaps
/kramme:siw:generate-phases                   # Create phase-based issues
/kramme:siw:issue-implement P1-001            # Implement first issue
/kramme:siw:issue-implement P1-002            # Continue through phase
/kramme:siw:issue-implement P2-001            # Move to phase 2
/kramme:siw:implementation-audit              # Verify spec conformance
/kramme:siw:resolve-audit                     # Triage audit findings
/kramme:siw:issues-reindex                    # Clean up DONE issues
/kramme:siw:close                             # Generate docs, clean up
```

### Reverse-Engineering Existing Code

Document shipped features or bootstrap SIW from an existing implementation:

```
/kramme:siw:reverse-engineer-spec feature-branch --base main
/kramme:siw:discovery --apply                 # Fill open questions
/kramme:siw:spec-audit                        # Validate generated spec
/kramme:siw:generate-phases                   # Plan remaining work (if any)
```

### Iterative Refinement

Multiple rounds of implementation with spec evolution:

```
# Round 1
/kramme:siw:init discover                     # Interview-driven spec
/kramme:siw:generate-phases                   # Initial issue breakdown
/kramme:siw:issue-implement P1-001            # Implement
/kramme:siw:issue-implement P1-002
/kramme:siw:reset                             # Preserve spec, clear issues

# Round 2
/kramme:siw:generate-phases                   # New issues from updated spec
/kramme:siw:issue-implement P1-001            # Next round of work
/kramme:siw:close                             # Done
```

### Ad-hoc Issue Tracking

Use SIW as a lightweight local issue tracker without phases:

```
/kramme:siw:init                              # Quick setup
/kramme:siw:issue-define "Fix auth timeout"   # Create G-001
/kramme:siw:issue-define "Add rate limiting"  # Create G-002
/kramme:siw:issue-implement G-001             # Work on issues
```

## Design Philosophy

- **Local-first** — Everything versioned in git, no external services required
- **Spec as source of truth** — The permanent document that outlives all workflow artifacts
- **Progressive refinement** — Specs get hardened through discovery, audits, and implementation feedback
- **Atomic operations** — Status updates touch all three tracking files together; each skill does one thing
- **Decision preservation** — Decisions flow from LOG.md to spec before temporary files are removed
- **Exhaustive auditing** — Implementation audits are adversarial, not perfunctory — they look for both missing implementations and undocumented extensions
- **Self-contained output** — `siw:close` generates documentation that stands alone without SIW context

## Tips & Troubleshooting

**Resuming after context loss:** Read `siw/LOG.md` first (the "Current Progress" section), then check `siw/OPEN_ISSUES_OVERVIEW.md` to see issue statuses. The `siw:continue` skill does this automatically.

**Choosing between close, reset, and remove:**
- `siw:close` — Project is done, you want permanent docs. Generates `docs/<feature>/`, then removes temp files.
- `siw:reset` — Project needs another iteration. Migrates decisions to spec, clears issues and log, keeps spec.
- `siw:remove` — Just delete everything. No docs generated.

**Spec getting large:** Move domain-specific content to `siw/supporting-specs/` with naming like `01-data-model.md`. The main spec should reference them via a table of contents.

**Team skills not working:** Team variants require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled in Claude Code, or `multi_agent` enabled in a Codex runtime.

**Audit seems too clean:** The implementation audit automatically triggers a second pass (Pass B2) for large specs with suspiciously few extension findings — this is a built-in guardrail.

**Spec references temporary files:** This violates a core SIW rule. The spec must be self-contained and never reference `siw/LOG.md`, `siw/issues/`, or other temporary documents. Code comments and error messages should also avoid referencing SIW artifacts.
