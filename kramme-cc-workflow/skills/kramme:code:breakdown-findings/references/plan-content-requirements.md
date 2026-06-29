# Plan content requirements

Load this before filling `assets/plan-template.md`.

Populate every section in the template. Do not leave empty headings or write "N/A". The template's inline guidance covers what each section needs; these requirements cover the non-obvious points the template cannot enforce.

- **Problem Statement**: Restate the full problem in the plan's own words. Do NOT reference finding IDs, report names, or prior documents -- the plan must be readable in isolation.
- **Repo Context and Tradeoffs**: Include relevant conventions, architecture boundaries, product/strategy constraints, ADRs, rejected approaches, and verification commands discovered during Phase 1.5. Cite concrete files/lines when available. If a source finding conflicts with a documented tradeoff, surface the conflict as `CONFUSION:` or `MISSING REQUIREMENT:`.
- **Impact and Leverage**: Include normalized Impact and Leverage values plus the rationale. If either value is inferred, prefix it with `UNVERIFIED:` and explain what evidence would firm it up.
- **Executor Instructions and Drift Check**: Include `PLANNED_AT_SHA`, a scoped working-tree-aware drift check (`git diff --stat <sha> -- <in-scope paths>` plus `git status --short -- <in-scope paths>`), and an explicit expected result. The in-scope path list must match the Scope section.
- **Current State**: Re-open every cited file yourself before writing the plan. Inline short current-code excerpts or concrete current-state descriptions with `file:line` markers. Source report line numbers are leads, not facts. If the current state includes secrets, cite only the file/line and secret type, never the value.
- **Commands You Will Need**: Use exact commands discovered from the repo or source report. Include expected success results. Do not invent a typecheck/test/lint command; if a command is absent, name the verification gap.
- **Scope**: Split scope into explicit **In Scope** and **Out of Scope** lists. Anything likely to tempt executor scope creep belongs in Out of Scope with a reason.
- **Finding metadata**: Carry source effort, fix risk, confidence, suggested verification, and scope notes into the plan. Use the most conservative value when grouped findings disagree, and explain the conflict in Risks or Open Questions.
- **Dependencies and Sequencing**: Name the execution label, the parallel wave, the exact blocker labels, and the exact dependent labels. Describe both the labels and the content of each dependency so the relationship is clear without cross-reading other plans.
- **Implementation Plan**: Each step must name exact files/symbols and end with a verification command plus expected result. Avoid open-ended instructions such as "clean up related code."
- **Test and Verification Plan**: Match verification to the work. Include automated tests when code changes; use manual validation, re-runs of the source audit/review, docs/build checks, or screenshots when the work is non-code.
- **Completion Criteria**: Make criteria machine-checkable where possible, including `git status --short` scope compliance.
- **STOP Conditions**: Include plan-specific STOP conditions: drift mismatch, repeated verification failure, need to touch out-of-scope files, missing prerequisites, and any fragile assumption unique to the plan.
- **Maintenance and Review Notes**: Tell reviewers what to scrutinize and which follow-ups were deliberately deferred.
