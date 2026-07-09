# Task Sizing Grammar

`kramme:siw:generate-phases` reads this file during Phase 3.2 (Break Into Atomic Tasks) and Phase 4 (Subagent Review) to size each generated task against a shared grammar and to decide when a task must be decomposed further. The sizing vocabulary, the break-down triggers, and the vertical-vs-horizontal slicing rule below are load-bearing — they are what turn subjective "atomic" judgements into repeatable gates.

This file is the canonical local source for the Task Sizing Grammar. `SKILL.md` Phase 4 interpolates its contents into the subagent review prompt at runtime, and sibling SIW issue-definition prompts sync from it.

## Task Sizing

| Size | Scope | Notes |
| --- | --- | --- |
| XS | 1 file, single function |  |
| S | 1–2 files, one endpoint |  |
| M | 3–5 files, one feature slice |  |
| L | 6–8 files, multi-component |  |
| **XL** | 9+ files | **"Too large — break it down further"** |

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

## Wide-refactor exception

Wide refactors are the narrow exception to ordinary vertical slicing. A wide refactor is one behavior-preserving mechanical change whose blast radius crosses enough of the codebase that no normal end-to-end slice can land green on its own. Examples include renaming a shared column, replacing a shared type, or moving a contract symbol used by many consumers. Do not use this exception for feature bundles, uncertain redesigns, or opportunistic cleanup.

Sequence wide refactors as expand-contract work:

1. **Expand:** add the new form beside the old form, preserving behavior and keeping existing callers green.
2. **Migrate:** move callers in reviewable batches sized by blast radius, such as package, directory, domain, or consumer group. Each migrate issue is blocked by the expand issue and must keep the system green while both forms exist.
3. **Contract:** remove the old form after every migrate batch is complete. The contract issue is blocked by all migrate issues and must verify no old callers remain.

Batch sizing still obeys XS/S/M/L. If a migrate batch sizes XL or bundles independent caller groups, split it further. Choose batch boundaries by reviewability and blast radius, not by implementation layer.

Use a final integrate-and-verify fallback only when no individual migrate batch can remain green on the target branch. Keep the expand/migrate/contract map, allow the migrate batches to converge on an integration branch, and add a final integrate-and-verify issue blocked by all batches. Green is promised by that final issue, so mark the sequence `Must be sequential` or `Needs coordination`, never `Safe to parallelize`.

## Parallelization taxonomy

When Phase 3.4 annotates task groups, use these three categories:

- **Safe to parallelize**: independent slices, tests, docs.
- **Must be sequential**: migrations, shared-state changes.
- **Needs coordination**: shared API contract → define contract first, then parallelize consumers.

The frontier is the set of issues whose blockers are all done. Issues with `Blocked by: None - can start immediately` are frontier work at creation time; dependent issues enter the frontier only after every listed blocker is `DONE`. Do not mark blocked work as unconditionally `Safe to parallelize`; use `Safe to parallelize after <blocker>` when dependent issues are independent once their blockers clear. Use `Must be sequential` or `Needs coordination` when the blockers represent shared-state sequencing or coordination.
