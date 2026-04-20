# Task Sizing Grammar

`kramme:siw:generate-phases` reads this file during Phase 3.2 (Break Into Atomic Tasks) and Phase 4 (Subagent Review) to size each generated task against a shared grammar and to decide when a task must be decomposed further. The sizing vocabulary, the break-down triggers, and the vertical-vs-horizontal slicing rule below are load-bearing — they are what turn subjective "atomic" judgements into repeatable gates.

## Task Sizing

| Size | Scope | Notes |
|---|---|---|
| XS | 1 file, single function | |
| S | 1–2 files, one endpoint | |
| M | 3–5 files, one feature slice | |
| L | 5–8 files, multi-component | |
| **XL** | 8+ files | **"Too large — break it down further"** |

Every generated task must land at XS, S, M, or L. XL is never an acceptable final state — when a task sizes XL, decompose it further before Phase 5 user approval.

## Break-down triggers

A task must be broken down when any of the following are true:

- Estimated >1 focused day of work for one engineer.
- Can't describe acceptance criteria in ≤3 bullets.
- Bundles multiple independently reviewable outcomes into one task.
- Title contains "and" because it often signals multiple deliverables. Split unless both halves are inseparable.

## Vertical vs horizontal slicing

- For user-facing feature work:
  - ❌ Horizontal: "Build entire DB schema → build all APIs → build all UI".
  - ✅ Vertical: "User can create account (schema + API + UI, end-to-end)".
- For documentation, architecture, refactors, or process work:
  - ❌ Horizontal: "Document all data models → document all APIs → document all UI flows".
  - ✅ End-to-end: "Document account creation end-to-end, including constraints, API contract, and UI behavior".

Each task should leave behind the smallest reviewable end-to-end outcome for its work context. For feature work that usually means a vertical slice; for docs/refactors/process work it means one coherent deliverable that can be reviewed or demonstrated on its own. Horizontal layer-by-layer tasks still defer integration risk and should be avoided.

## Parallelization taxonomy

When Phase 3.4 annotates task groups, use these three categories:

- **Safe to parallelize**: independent slices, tests, docs.
- **Must be sequential**: migrations, shared-state changes.
- **Needs coordination**: shared API contract → define contract first, then parallelize consumers.
