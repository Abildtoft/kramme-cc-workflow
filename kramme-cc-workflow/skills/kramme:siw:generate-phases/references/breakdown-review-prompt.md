# Breakdown Review Prompt

Before running the review pass, read `references/task-sizing.md` and substitute its full contents for the `{task_sizing_grammar}` placeholder. The reviewer must receive the grammar inline; it cannot rely on a working-directory-relative read.

```text
Review this phase/task breakdown for a software project or adjacent documentation/process deliverable.

Before evaluating the plan, use this Task Sizing Grammar as the source of truth for task sizing, break-down triggers, slicing shape, and parallelization categories.

Task Sizing Grammar:

{task_sizing_grammar}

Work Context: {work_context.work_type}
- Verify phase count and granularity match the work type
- For prototypes, do not flag broad task scope or missing test tasks
- For refactors, verify each task has rollback safety
- For documentation/process work, interpret "end-to-end" as the smallest reviewable deliverable for that workflow rather than schema + API + UI

Evaluate:

1. Atomicity: Is each task truly independent and committable on its own?
2. Testability: Does each task have clear, verifiable acceptance criteria?
3. Dependencies: Are dependencies correctly identified? Any missing?
4. Completeness: Are any tasks missing to achieve the phase goals?
5. Phase coherence: Does each phase result in a demoable or reviewable outcome that matches the work context?
6. Sizing (hard gate): apply the XS/S/M/L grammar and the XL-is-not-acceptable rule from the Task Sizing Grammar above. Flag any XL task explicitly.
7. Slicing shape: apply the vertical-vs-horizontal rule and wide-refactor exception from the Task Sizing Grammar above for the declared Work Context. Flag layer-by-layer tasks, tasks that bundle multiple independent deliverables, wide mechanical refactors forced into ordinary vertical slices instead of expand-contract sequencing, and ordinary feature work using expand-contract sequencing to avoid a proper vertical slice.
8. Parallelization: Are parallelization categories (Safe / Must be sequential / Needs coordination) correctly assigned? Flag any safely-parallel work serialized unnecessarily, or any shared-state change marked parallel.
9. Mode (AUTO vs HITL): The default is AUTO; HITL is the exception. Does every task carry a Mode label? Does every HITL task include a one-line reason naming a concrete human-input requirement (unsettled architectural decision, design review, genuine judgment call, non-automatable manual testing, external-system access)? Flag any unlabeled task, any HITL-without-reason, and any task marked HITL whose reason is weak or speculative rather than a real blocking requirement (it should be AUTO). Also flag the reverse: a task that genuinely needs human input but is marked AUTO (e.g., requires manual UAT).
10. Prefactoring-first: Does the breakdown hide behavior-preserving prep work inside a feature task? Flag any case where a first prefactoring slice or blocker is needed to avoid an L/XL task, duplicated implementation work, broad cross-module edits, or hidden refactor scope.

For each issue found, provide:
- What's wrong
- Specific suggestion to fix it

If the breakdown looks good, confirm it's ready.
```
