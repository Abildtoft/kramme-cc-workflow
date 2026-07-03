# Quality Gates

## Important Guidelines

1. **Demoable phases** - Each phase must result in a demoable or reviewable outcome appropriate to the work type
2. **Atomic tasks** - Each task is one commit, one focused change
3. **Testable criteria** - Every task has verifiable acceptance criteria
4. **Clear dependencies** - Explicit about what blocks what
5. **Appropriate sizing** - All tasks XS/S/M/L (XL decomposed). See `references/task-sizing.md`.
6. **Review before create** - Always use subagent review and user approval
7. **Stable identifiers** - Preserve existing issue IDs after files are written; use `/kramme:siw:issue-reindex` for intentional renumbering
8. **Risk-triggered deepening** - Run the Phase 4.5 confidence deepening gate only when risk signals are present

## Output Markers

Use these markers as prefixes when surfacing specific kinds of information so output stays parseable across the plugin:

- `STACK DETECTED:` — prefix Phase 2.1 Work Context extraction results (e.g., `STACK DETECTED: Work Type = Prototype / Spike`).
- `MISSING REQUIREMENT:` — use in Phase 2.3 when a required element (overview, scope, success criteria, technical design) is absent from the spec.
- `CONFUSION:` — use in Phase 2 when the spec is internally inconsistent or ambiguous in a way that blocks decomposition.
- `UNVERIFIED:` — use whenever an assumption is made because the spec is incomplete; surface explicitly so the user can correct it.
- `NOTICED BUT NOT TOUCHING:` — use for out-of-scope observations (e.g., spec mentions related work this skill won't decompose).
- `PLAN:` — prefix the full Phase 5 proposed-structure block.
- `FILES CREATED / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` — end-of-turn triplet used in Phase 7 Summary.

Adopt all markers or none — mixed marker vocabularies degrade downstream parseability.

## Common Rationalizations

Watch for these justifications that signal you are about to skip a hard gate:

- "These tasks feel atomic, sizing is overkill." — If sizing is skipped, the next reviewer has no objective basis to flag drift. Apply XS/S/M/L every time.
- "One XL task is fine, the implementer will figure it out." — No. XL means "break it down further." Letting one through breaks the gate for all future tasks.
- "Horizontal slicing is faster for the AI to generate." — It is, and it produces a plan that defers integration risk. Every task should ship the smallest end-to-end slice appropriate to its work context.

## Red Flags

Stop and recheck the workflow if any of these appear:

- Phase 4 subagent returns "no findings" on the first pass — likely under-reviewing, not a clean breakdown. (Distinct from a missing or malformed response, which is handled by the Subagent failure stanza in `SKILL.md` Phase 4.)
- Every task lands at size L — likely under-decomposed.
- Sizing labels were assigned after the structure was drafted instead of during Phase 3.2 — the grammar did not drive decomposition.
- Parallelization categories are all "Must be sequential" — likely missed safely-parallel slices.
- Existing issue IDs are renumbered during append, refinement, splitting, deletion, or deepening — this breaks references that should survive ordinary plan evolution.
- A risky plan skips Phase 4.5 because Phase 4 already ran — the deepening gate checks sequencing, hidden dependencies, and risk treatment beyond the hard atomicity/sizing review.

## Verification

Before reporting Phase 7, verify:

- Any task title containing the word "and" is justified because both halves are inseparable; otherwise split it.
- Every task carries an explicit size; no XL survived Phase 4.
- Phase 4 subagent prompt ran with all ten criteria (including Vertical slicing, Parallelization, Mode coverage, and Prefactoring-first) against the final plan after any Phase 4.5 changes.
- Parallelization categories are recorded for each task group.
- The Phase 5 `PLAN:` block shows every issue size and every group-level `Parallelization:` note.
- Existing append-mode issue IDs were preserved, with new work assigned to the next unused number in each prefix group.
- Risk signals were checked; Phase 4.5 ran when triggered, did not run unconditionally for small, clear plans, and looped back through Phase 4 if it changed, split, deleted, or reordered tasks.
- Generated issue files preserve each issue's approved size, Mode, and parallelization guidance. For tracker schema rules (modern 7-column, pre-Mode 6-column, legacy 5-column) see Phase 6.2 in `SKILL.md`.
- Generated issue files use repo-relative paths for affected files, tests, and pattern references.
