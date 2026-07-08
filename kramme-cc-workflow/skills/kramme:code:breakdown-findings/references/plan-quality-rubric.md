# Plan Quality Rubric

Load this after drafting all plans and before writing final `PR_PLAN_*.md` files, or when diagnosing weak generated plans.

## Product and Quality Gate

Every plan must pass this gate before it is written. If a draft fails, revise it or stop with the blocking question instead of emitting a low-quality plan.

### Product grounding

- The plan names the user, operator, reviewer, maintainer, or workflow that benefits.
- The plan states the observable behavior, reliability, security, maintainability, or workflow outcome that improves.
- The plan distinguishes what changes from what must remain stable.
- The plan explains how a reviewer will know the outcome is better, not just different.
- If impact or value is inferred rather than sourced from findings, strategy, user context, or repo evidence, it is prefixed with `UNVERIFIED:` and names the missing evidence.

### Implementation quality

- Each implementation step names exact files, modules, functions, commands, or artifacts.
- No step relies on vague work such as "clean up", "improve", "harden", "refactor related code", or "make consistent" without concrete scope and verification.
- The plan's **In Scope** list is the complete allowed edit surface; **Out of Scope** names likely temptations and why they are excluded.
- Risks cover the actual blast radius: compatibility, migration, data integrity, security, performance, rollback, rollout, or reviewer confusion when relevant.
- The plan does not turn optional polish into required scope unless the source finding or product context justifies it.

### Reviewability

- The planned PR is small enough for focused review, or it is split/blocked with explicit sequencing.
- The grouping rationale explains why the findings belong together and why adjacent work was left out.
- Public APIs, persisted data, auth/session behavior, billing, permissions, user-visible UX, release tooling, and generated artifacts receive stricter scope and validation notes.
- Dependencies are readable from the plan title, index row, dependency map, and Dependencies section without cross-reading every plan.

### Validation quality

- Verification targets the risk, not only the easiest command to run.
- Code behavior changes include tests or a named verification gap with a concrete manual fallback.
- User-visible changes include manual QA, screenshots, accessibility checks, copy checks, or workflow validation as appropriate.
- Plans generated from audit/review/QA findings include a rerun or targeted re-check of the source workflow when feasible.
- Completion criteria are machine-checkable where possible and include scope compliance.

## Discovery For Open Questions

Use repo recon and current-state inspection before asking the user questions. If a blocking product or quality question remains and the answer is user-owned, discovery is allowed during plan formulation.

Use `kramme:discovery:interview` when at least one of these is true:

- The plan's product outcome, non-goals, or success signal cannot be inferred from the findings source set or repo context.
- Multiple plausible implementation paths have meaningfully different user or business tradeoffs.
- The plan would otherwise contain a `MISSING REQUIREMENT:` that blocks implementation.
- The plan touches user-visible UX, workflow semantics, policy, permissions, billing, data retention, rollout, or public API behavior and the intended outcome is unclear.

Discovery protocol:

1. Write a concise discovery brief with the theme name, source findings, current assumptions, and the exact decisions needed.
2. Ask the user whether to run `$kramme:discovery:interview` on that brief, unless they already requested discovery for the run.
3. If discovery runs, incorporate its answers into Product / Quality Bar, Goals, Non-Goals, Scope, Risks, Open Questions, and verification.
4. If discovery is declined or unavailable and the answer blocks implementation, keep the plan blocked with `MISSING REQUIREMENT:` instead of inventing a product decision.
5. If the question is non-blocking, document the default assumption and the evidence that would change it.

Do not use discovery for questions the codebase can answer, for implementation details the executor can decide safely, or for single-finding mechanical fixes with clear source evidence.

## Stop Conditions

Stop and revise before writing final artifacts if any draft has:

- No clear beneficiary or quality outcome.
- Product claims with no source, repo evidence, or `UNVERIFIED:` marker.
- Generic implementation steps without exact files/symbols.
- Acceptance criteria that do not prove the risk was reduced.
- Open questions that are implementation blockers but are treated as optional notes.
- A validation plan that omits tests or manual QA for user-visible behavior.
- A scope that would let the executor touch unrelated files without triggering a STOP condition.
