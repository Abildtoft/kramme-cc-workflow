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

- Estimated >2 hours of work.
- Can't describe acceptance criteria in ≤3 bullets.
- Touches two or more subsystems.
- Title contains "and".

## Vertical vs horizontal slicing

- ❌ Horizontal: "Build entire DB schema → build all APIs → build all UI".
- ✅ Vertical: "User can create account (schema + API + UI, end-to-end)".

Each task is a vertical slice that delivers end-to-end value a reviewer can demo. Horizontal layer-by-layer tasks defer integration risk and produce undemoable intermediate states.

## Parallelization taxonomy

When Phase 3.4 annotates task groups, use these three categories:

- **Safe to parallelize**: independent slices, tests, docs.
- **Must be sequential**: migrations, shared-state changes.
- **Needs coordination**: shared API contract → define contract first, then parallelize consumers.
