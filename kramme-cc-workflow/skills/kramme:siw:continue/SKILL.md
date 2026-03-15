---
name: kramme:siw:continue
description: Structured Implementation Workflow (SIW) - Use a structured workflow with core specification, planning, and audit documents to plan, track, and implement work items. Triggers on "SIW", "structured workflow", or when siw/LOG.md and siw/OPEN_ISSUES_OVERVIEW.md files are detected.
disable-model-invocation: false
user-invocable: true
---

# Structured Implementation Workflow (SIW)

A local issue tracking system using markdown files to plan, track, and document implementations without requiring external services.

## When to Use

- Complex features requiring planning and decision tracking
- Multi-issue projects with multiple work items
- Projects without Linear or when you want local-only tracking
- Technical designs, API documentation, or system architecture

**NOT for:** Small bug fixes (<1 day), trivial updates, simple refactoring.

## Quick Start

```
/kramme:siw:init                    # Initialize workflow documents
/kramme:siw:discovery               # Strengthen spec quality before planning
/kramme:siw:issue-define "feature"  # Create a work item (G-001 format)
/kramme:siw:generate-phases         # Break spec into phase-based issues (P1-001, P2-001)
/kramme:siw:issue-implement G-001   # Start implementing
/kramme:siw:spec-audit               # Audit spec quality before implementation
/kramme:siw:implementation-audit    # Audit code against spec for discrepancies
/kramme:siw:resolve-audit           # Walk audit findings one-by-one and create SIW issues (--auto + report path to stay scoped)
/kramme:siw:issues-reindex          # Remove DONE issues, renumber within groups
/kramme:siw:reset                   # Reset for next iteration (keeps spec)
/kramme:siw:close                   # Generate docs and clean up
/kramme:siw:remove                  # Clean up when done (no docs)
```

## Issue Naming

Issues use prefix-based numbering:
- `G-XXX` — General issues (standalone, non-phase)
- `P1-XXX`, `P2-XXX`, etc. — Phase-specific issues

## Workflow Document System

| Document | Purpose | Persistence |
|----------|---------|-------------|
| **siw/[YOUR_SPEC].md** | Main specification (single source of truth) | **PERMANENT** |
| **siw/supporting-specs/*.md** | Detailed specifications by domain | **PERMANENT** |
| **siw/AUDIT_IMPLEMENTATION_REPORT.md** | Spec compliance audit findings from `/kramme:siw:implementation-audit` | Temporary |
| **siw/AUDIT_SPEC_REPORT.md** | Spec quality audit findings from `/kramme:siw:spec-audit` | Temporary |
| **siw/OPEN_ISSUES_OVERVIEW.md** + **siw/issues/*.md** | Work items to implement | Temporary |
| **siw/LOG.md** | Session progress + decision rationale | Temporary |

### What Each Document Contains

**Specification (PERMANENT):**
- Project overview and objectives
- Scope (in/out)
- Design decisions (migrated from siw/LOG.md)
- Success criteria

**Supporting Specs (PERMANENT, optional):**
- Detailed specifications organized by domain
- Examples: data model, API design, UI specs, user stories
- Named with ordering prefix: `00-overview.md`, `01-data-model.md`, etc.
- Main spec references these via TOC

**Issues (TEMPORARY):**
- Individual work items (features, bugs, improvements)
- Each issue has: problem, context, scope, acceptance criteria
- Deleted when implemented

**siw/LOG.md (TEMPORARY):**
- Current progress and status
- Decision log with rationale
- Session continuity between conversations

## Document Flow

```
┌──────────────────────────────────┐
│  /kramme:siw:issue-define        │  Create general work items (G-XXX)
│  /kramme:siw:generate-phases     │  Create phase-based issues (P1-XXX, P2-XXX)
│  → siw/issues/ISSUE-{prefix}-XXX-*.md │
└──────────────┬───────────────────┘
               │ Implementation
               ↓
┌──────────────────────────────────┐
│  /kramme:siw:issue-implement     │  Work on issues
│  → siw/LOG.md (progress + decisions) │
└──────────────┬───────────────────┘
               │ Decisions migrated
               ↓
┌──────────────────────────────────┐
│  siw/[YOUR_SPEC].md              │  ⚠️ PERMANENT - single source of truth
│  (updated via sync step)         │
└──────────────────────────────────┘
```

## Critical Rules

1. **Spec NEVER references temp docs** - It's self-contained and permanent
2. **NEVER reference temp docs in code** - Comments, docs, error messages must not mention siw/LOG.md or siw/issues
3. **Decisions flow one-way:** Issues → siw/LOG.md → siw/[YOUR_SPEC].md
4. **Sync before completion:** Always run Step 10 (Spec Sync) in implement-issue

---

## Commands Reference

| Command | Purpose |
|---------|---------|
| `/kramme:siw:init` | Initialize SIW documents (spec, siw/LOG.md, siw/issues) |
| `/kramme:siw:discovery` | Strengthen SIW spec quality with a targeted discovery interview and concrete patch plan (optional apply) |
| `/kramme:siw:issue-define` | Define a new work item with guided interview (creates `G-XXX` issues) |
| `/kramme:siw:generate-phases` | Break spec into atomic phase-based issues (`P1-XXX`, `P2-XXX`, `G-XXX`) |
| `/kramme:siw:issue-implement` | Start implementing a defined issue (accepts `G-001`, `P1-001`, etc.) |
| `/kramme:siw:product-review` | Product critique of specs/plans — evaluates target user, problem/solution fit, user state modeling, and scope correctness |
| `/kramme:siw:spec-audit` | Audit spec quality (coherence, completeness, clarity, scope, actionability, testability, value proposition, technical design) before implementation |
| `/kramme:siw:implementation-audit` | Audit codebase against spec for discrepancies, naming misalignments, and missing implementations |
| `/kramme:siw:resolve-audit` | Resolve audit findings one-by-one with executive summaries, alternatives, and SIW issue creation. Add `--auto` to let the model choose each resolution without pausing for confirmation. If both audit reports exist, pass the report path to keep the run scoped. |
| `/kramme:siw:issues-reindex` | Remove DONE issues and renumber remaining within each prefix group |
| `/kramme:siw:reset` | Reset workflow state (migrate log to spec, clear issues) |
| `/kramme:siw:close` | Close SIW project, generate docs in `docs/<feature>/`, remove temporary files |
| `/kramme:siw:remove` | Clean up all SIW files after completion |

---

## Working With Existing Files

When SIW files already exist, check the current state:

```bash
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/AUDIT_IMPLEMENTATION_REPORT.md siw/AUDIT_SPEC_REPORT.md siw/*SPEC*.md siw/*SPECIFICATION*.md siw/issues/ 2>/dev/null
```

### Entry Point Decision

| State | Action |
|-------|--------|
| **No files exist** | Run `/kramme:siw:init` to set up |
| **Files exist, resuming** | Read siw/LOG.md "Current Progress" section first |
| **Spec feels weak or underspecified** | Run `/kramme:siw:discovery` to strengthen spec quality before creating/implementing issues |
| **Need new work item** | Run `/kramme:siw:issue-define` |
| **Ready to implement** | Run `/kramme:siw:issue-implement {number}` |
| **Spec written, want product validation** | Run `/kramme:siw:product-review` to evaluate product thinking before implementation |
| **Spec written, not yet validated** | Run `/kramme:siw:spec-audit` to check spec quality before implementing |
| **Implementation done** | Run `/kramme:siw:implementation-audit` to verify spec compliance |
| **Audit report ready** | Run `/kramme:siw:resolve-audit` to triage findings and create issues one-by-one, or add `--auto` for a non-interactive pass. If both audit reports exist, pass the report path to avoid resolving both. |
| **Iteration complete** | Run `/kramme:siw:reset` to start fresh |
| **Project complete, want docs** | Run `/kramme:siw:close` to generate documentation and clean up |
| **Project complete** | Run `/kramme:siw:remove` to clean up |

### Resuming Work

When resuming a session with existing SIW files:

1. **Read siw/LOG.md first** - Check "Current Progress" section for:
   - What was last completed
   - What's next
   - Any blockers

2. **Check siw/OPEN_ISSUES_OVERVIEW.md** - See which issues are:
   - READY (not started)
   - IN PROGRESS (being worked on)
   - IN REVIEW (awaiting review/approval)
   - DONE (completed)

3. **Continue or start new** - Either:
   - Continue the in-progress issue
   - Pick up the next ready issue with `/kramme:siw:issue-implement`

---

## Issue Lifecycle

```
Created              In Progress           Review              Completed
   │                      │                   │                    │
   ▼                      ▼                   ▼                    ▼
┌─────────┐          ┌─────────┐        ┌─────────┐          ┌─────────┐
│  READY  │ ───────► │IN PROG  │ ─────► │IN REVIEW│ ───────► │  DONE   │
└─────────┘          └─────────┘        └─────────┘          └─────────┘
```

**Issue States:**
- **READY** - Defined, waiting to be picked up
- **IN PROGRESS** - Currently being implemented
- **IN REVIEW** - Work complete, awaiting review/approval
- **DONE** - Resolved and documented

When an issue is completed:
1. Resolution steps documented in the issue file's `## Resolution` section
2. Decisions logged in siw/LOG.md
3. Key decisions synced to spec (Step 10)
4. Status set to `IN REVIEW` (uncertain solution) or `DONE` (confident solution)
5. Row updated in siw/OPEN_ISSUES_OVERVIEW.md

---

## File Locations

All workflow files live in the `siw/` folder in the project root:

```
/
├── siw/
│   ├── [YOUR_SPEC].md              ⚠️ PERMANENT (name chosen at init)
│   ├── supporting-specs/           ⚠️ PERMANENT (optional, for large projects)
│   │   ├── 00-overview.md
│   │   ├── 01-data-model.md
│   │   ├── 02-api-specification.md
│   │   └── 03-ui-specification.md
│   ├── AUDIT_IMPLEMENTATION_REPORT.md            ⏳ Temporary (audit output)
│   ├── AUDIT_SPEC_REPORT.md            ⏳ Temporary (audit output)
│   ├── OPEN_ISSUES_OVERVIEW.md     ⏳ Temporary
│   ├── issues/                     ⏳ Temporary directory
│   │   ├── ISSUE-G-001-setup.md        # General issues
│   │   ├── ISSUE-G-002-docs.md
│   │   ├── ISSUE-P1-001-feature-a.md   # Phase 1 issues
│   │   ├── ISSUE-P1-002-feature-b.md
│   │   └── ISSUE-P2-001-bug-fix.md     # Phase 2 issues
│   └── LOG.md                      ⏳ Temporary
├── AGENTS.md                       (optional)
└── CLAUDE.md                       (optional)
```

### When to Use Supporting Specs

Use `siw/supporting-specs/` when:
- Main spec exceeds ~500 lines
- Multiple distinct domains (data model, API, UI, user stories)
- Different team members own different sections
- You want targeted reading during execution

**Naming convention:** `NN-descriptor.md` (e.g., `01-data-model.md`, `02a-cms-ui.md`)

---

## Templates Reference

When manually creating documents, use these templates from:
`skills/kramme:siw:continue/assets/`

| Document | Template |
|----------|----------|
| siw/[YOUR_SPEC].md | `assets/spec-guidance.md` |
| siw/LOG.md | `assets/log-template.md` |
| siw/issues | `assets/issues-template.md` |

**Tip:** Using `/kramme:siw:init` and `/kramme:siw:issue-define` is preferred over manual creation.

---

## Phase Resources

For detailed guidance on specific phases, read:

| Phase | Resource |
|-------|----------|
| Resuming existing work | `references/phase-0-resuming.md` |
| Planning from scratch | `references/phase-1-planning.md` |
| Handling blockers | `references/phase-2-investigation.md` |
| Executing tasks | `references/phase-3-execution.md` |
| Completing work | `references/phase-4-completion.md` |

---

## Guideline Keywords

- **ALWAYS/NEVER** — Mandatory (exceptions require explicit approval)
- **PREFER** — Strong recommendation (exceptions allowed)
- **CAN** — Optional, developer's discretion
- **NOTE** — Context or clarification
