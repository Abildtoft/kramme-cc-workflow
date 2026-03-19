# Skill Expansion Roadmap

## Overview

This document defines the roadmap for the next skill expansion of `kramme-cc-workflow`.

The goals are:

1. Add deeper product-focused review capabilities.
2. Add a reusable browser foundation for live product inspection.
3. Add a structured QA layer on top of browser capabilities.
4. Add a final PR readiness step that orchestrates existing and new skills.

This roadmap explicitly does **not** include a retrospective skill.

## Sources Of Inspiration

This roadmap is intentionally inspired by selected workflow ideas from the `gstack` repository reviewed during planning.

The main inspirations are:

- the dedicated browser-operator concept behind gstack's `browse` skill
- the diff-aware, evidence-first testing model behind gstack's `qa` skill
- the idea of focused workflow entry points instead of one broad, generic command
- the split between planning-time review, change-scoped review, and broader product review
- the concept of a final workflow step that helps determine whether work is ready to move forward

This roadmap does **not** aim to copy gstack literally.

Instead, it adapts the underlying ideas to fit `kramme-cc-workflow`:

- reuse existing agents and review infrastructure already in this repo
- prefer MCP-based browser orchestration over custom browser infrastructure
- keep naming and workflow structure aligned with existing `pr:` and `siw:` conventions
- treat `pr:finalize` as orchestration around existing skills, not as a one-command shipping pipeline

More specifically:

- `/kramme:browse` takes inspiration from gstack's dedicated browser skill, but should be implemented as a wrapper around available browser MCP tools rather than a custom compiled browser runtime.
- `/kramme:qa` takes inspiration from gstack's QA workflow, especially the emphasis on screenshots, evidence, and changed-flow validation, but should be smaller and more incremental in V1.
- `/kramme:pr:product-review`, `/kramme:siw:product-audit`, and `/kramme:product:review` take inspiration from gstack's use of different cognitive modes for different kinds of review, but should be expressed as a shared product-review family integrated into this repo's existing skill structure.
- `/kramme:pr:finalize` is conceptually inspired by gstack's end-of-workflow automation, but should remain PR-centered and compositional rather than trying to own merge or deploy behavior.

## Skills In Scope

| Skill | Purpose | Primary Context | Depends On |
|---|---|---|---|
| `/kramme:pr:product-review` | Deep product review of branch and local changes | Pull requests / local diffs | Shared product-review core |
| `/kramme:siw:product-audit` | Product critique of specs and SIW plans before implementation | SIW / spec review | Shared product-review core |
| `/kramme:browse` | Browser operator skill for inspecting and interacting with a live app | Live product / debugging / QA | Browser MCP availability |
| `/kramme:qa` | Structured QA testing with evidence and reports | Live product / branch validation | `/kramme:browse` |
| `/kramme:product:review` | Whole-product review across flows and surfaces | Live product / broader experience review | Shared product-review core + `/kramme:browse` |
| `/kramme:pr:finalize` | Final PR readiness orchestration | Pull requests | Existing PR skills + `/kramme:pr:product-review` + `/kramme:qa` |

## Out Of Scope

- `/kramme:retro:weekly`
- A custom browser binary or external browser daemon
- Automated merge-to-main or deploy-to-production behavior inside `pr:finalize`
- Replacing existing `pr:create`, `pr:fix-ci`, `pr:code-review`, or `pr:ux-review`

## Guiding Design Principles

### 1. Shared Core, Focused Entry Points

The product-review family should share one underlying rubric and one agent foundation, but expose separate commands for separate contexts:

- PR review is diff-scoped and execution-oriented.
- SIW review is plan/spec-scoped and pre-implementation.
- Product audit is live-experience-scoped and cross-flow.

The repo should not contain three unrelated product-review implementations.

### 2. Orchestration Over Duplication

`/kramme:pr:finalize` should orchestrate existing skills and only add decision logic where needed.

It must not become:

- a second PR creation skill
- a second CI fixer
- a second broad code review skill

### 3. Browser MCP Wrapper, Not Custom Infrastructure

`/kramme:browse` should standardize usage of available browser MCP tools already supported by the broader workflow, instead of introducing a bespoke browser runtime.

The skill should:

- detect available browser tooling
- normalize the operating pattern
- fail clearly when no browser MCP is available

### 4. Evidence Before Assertions

All live-product skills should prefer screenshots, page inspection, console output, and explicit reproduction steps over vague conclusions.

### 5. Incremental Rollout

The roadmap should land in an order that produces value early and minimizes dependency risk.

The recommended order is:

1. `pr:product-review`
2. `siw:product-audit`
3. `browse`
4. `qa`
5. `product:review`
6. `pr:finalize`

## Existing Components To Reuse

The roadmap should build on existing assets already in the repo:

- `agents/kramme:product-reviewer.md`
- `skills/kramme:pr:ux-review/SKILL.md`
- `skills/kramme:verify:run/SKILL.md`
- `skills/kramme:pr:code-review/SKILL.md`
- `skills/kramme:pr:generate-description/SKILL.md`
- `skills/kramme:pr:create/SKILL.md`
- `skills/kramme:pr:fix-ci/SKILL.md`
- existing README skill catalog structure
- existing Bats-based test harness in `tests/`

## Shared Foundations

Before or during Phase 1, introduce a shared product-review foundation.

### Shared Product-Review Rubric

The rubric should cover:

- target user clarity
- problem/solution fit
- core flow completeness
- empty, loading, success, and error states
- discoverability and affordances
- defaults and first-run behavior
- copy clarity and expectation-setting
- trust, safety, and irreversible actions
- edge cases and recovery paths
- post-action experience: what happens after the main action completes
- rollout and adoption implications

### Shared Output Shape

The product-review family should use a predictable structure:

- summary
- critical findings
- important findings
- open questions
- strengths
- recommended next actions

Artifacts should be context-specific:

- `PRODUCT_REVIEW_OVERVIEW.md` for PR review
- `siw/PRODUCT_AUDIT.md` for SIW/spec review
- `PRODUCT_AUDIT_OVERVIEW.md` for whole-product review

### Shared Threshold Philosophy

The product-review skills should use a higher-confidence bar than brainstorming tools, but lower than pure security review.

The intent is:

- specific, actionable product findings
- minimal vague product commentary
- explicit distinction between blockers and suggestions

## Phase 1: `/kramme:pr:product-review`

### Objective

Create a focused product-review command for branch and local changes that goes deeper than the existing broad UX review workflow.

### Why This Phase Comes First

- The repo already has the core product reviewer agent.
- The PR use case has immediate value.
- It does not depend on browser tooling.
- It creates the first version of the shared product-review rubric.

### Implementation Goals

- Add `skills/kramme:pr:product-review/SKILL.md`
- Expand `agents/kramme:product-reviewer.md` to support explicit PR mode
- Reuse base branch detection and diff scoping patterns already used by `pr:ux-review`
- Review committed, staged, unstaged, and untracked changes
- Focus only on product concerns, not general UX/a11y/visual heuristics
- Produce a dedicated output artifact, not a UX artifact

### Review Dimensions

The PR-specific command should evaluate:

- whether the changed flow makes sense from a user-value standpoint
- missing states introduced by the change
- incomplete journey transitions
- broken or awkward success path after the primary action
- copy or defaults that create wrong expectations
- permission/role behavior from a product perspective
- regressions to adjacent flows and user mental model
- whether the change solves a real user problem or only a technical proxy

### Deliverables

- New skill file
- Updated product reviewer agent
- README updates for the new command
- Changelog entry
- Initial test coverage for skill presence and output contract

### Success Criteria

- The skill produces findings that are meaningfully different from `pr:ux-review`
- The output is scoped to the PR and local changes
- The skill can explain why an issue is a product issue rather than a generic UX issue

## Phase 2: `/kramme:siw:product-audit`

### Objective

Create a product review command for SIW/spec workflows that critiques plans before implementation begins.

### Why This Phase Comes Second

- It reuses the same rubric introduced in Phase 1
- It complements the current SIW/spec audit stack without requiring browser tooling
- It improves proposal quality before implementation cost is incurred

### Implementation Goals

- Add `skills/kramme:siw:product-audit/SKILL.md`
- Reuse the shared product-review core in a plan/spec mode
- Accept SIW spec files or current `siw/` context as the primary input
- Evaluate product risks in plans, not code diffs
- Optionally recommend SIW issues or TODOs when product gaps are found

### Review Dimensions

The SIW-specific command should evaluate:

- whether the plan solves the right user problem
- whether the target user is explicit enough
- whether user states and transitions are fully modeled
- whether the plan omits critical moments in the experience
- whether scope is too narrow, too broad, or incorrectly sequenced
- whether success criteria are product-meaningful
- what is explicitly not in scope but probably expected by users

### Deliverables

- New skill file
- Shared agent/rubric updates if needed
- README updates
- Optional integration points with SIW docs if appropriate

### Success Criteria

- The skill can review a spec without requiring code
- The output improves product quality before implementation starts
- Findings can be translated into concrete SIW follow-up work

## Phase 3: `/kramme:browse`

### Objective

Introduce a reusable browser skill that gives the workflow a standardized live-product inspection capability.

### Why This Phase Comes Third

- It enables both `qa` and `product:review`
- It should be treated as infrastructure, not as a one-off utility
- It is the largest new capability in the roadmap

### Implementation Goals

- Add `skills/kramme:browse/SKILL.md`
- Detect available browser MCP tooling at runtime
- Establish a consistent interaction pattern:
  navigate, inspect, screenshot, interact, verify, capture evidence
- Clearly fail when no browser MCP is available
- Document supported workflows and fallback behavior

### V1 Capability Goals

The first version should support:

- opening a URL
- taking a page snapshot
- taking a screenshot
- clicking/filling/selecting when browser tooling allows it
- reading console and network signals when available
- running lightweight verification flows

### Non-Goals For V1

- custom browser binaries
- complex multi-tab orchestration
- recording video
- deep state persistence beyond what MCP tooling already provides

### Deliverables

- New browse skill
- README updates and usage guidance
- Test coverage for detection/failure messaging where possible

### Success Criteria

- The skill gives the agent a dependable live-app inspection path
- Users understand quickly whether the environment supports it
- Later skills can treat it as a foundation

## Phase 4: `/kramme:qa`

### Objective

Build a structured QA layer on top of `browse`.

### Why This Phase Comes Fourth

- It depends directly on browse
- It provides the strongest practical validation layer before `pr:finalize`
- It creates a reusable evidence artifact for PR readiness

### Implementation Goals

- Add `skills/kramme:qa/SKILL.md`
- Build on the `browse` workflow rather than duplicating browser instructions
- Generate a structured QA report with evidence
- Support a small, focused V1 mode set

### Recommended V1 Modes

- `quick` for smoke checks
- `diff-aware` for changed flows and pages
- `targeted` for a user-specified route, page, or journey

Do **not** attempt an exhaustive full-site crawler in V1.

### QA Output Goals

Each QA run should capture:

- tested scope
- screenshots
- repro steps
- severity or priority
- notable console/network issues
- recommended top fixes

### Deliverables

- New QA skill
- Report template if needed
- README updates
- Integration plan for `pr:finalize`

### Success Criteria

- The skill produces evidence, not just impressions
- It can validate changed flows with reasonable operator consistency
- Its artifacts are useful inputs to `pr:finalize`

## Phase 5: `/kramme:product:review`

### Objective

Create a whole-product review command for broader product experience analysis across the live application.

### Why This Phase Comes Fifth

- It depends on both the shared product-review core and browse capability
- It is a broader, more expensive command than PR/spec review
- It is easiest to do well after the narrower product-review modes exist

### Implementation Goals

- Add `skills/kramme:product:review/SKILL.md`
- Require a URL, running app, or equivalent live context
- Review the broader product experience, not just one branch diff
- Reuse the shared rubric but adapt the emphasis to system-wide experience

### Audit Dimensions

The audit should evaluate:

- navigation and IA coherence
- feature discoverability
- onboarding and first-run flow
- consistency across related flows
- dead ends and abandoned transitions
- repeated friction points
- trust and safety cues
- copy and expectation management across the product

### Deliverables

- New skill file
- Updated docs
- Optional artifact template for audit reports

### Success Criteria

- The command reveals broader product issues that branch review would miss
- It can analyze a live product in a structured way
- It produces output that product or engineering leads can act on

## Phase 6: `/kramme:pr:finalize`

### Objective

Create a final PR readiness command that coordinates the existing workflow and the new skills.

### Why This Phase Comes Last

- It depends on the other new capabilities
- Its value is highest after the building blocks exist
- It should be designed around orchestration, not invention

### Implementation Goals

- Add `skills/kramme:pr:finalize/SKILL.md`
- Reuse existing skills rather than embedding their logic
- Produce a final “ready / not ready / ready with caveats” outcome
- Be explicit about blockers versus optional polish

### Expected Orchestration Responsibilities

Depending on context, `pr:finalize` should coordinate:

- `/kramme:verify:run`
- `/kramme:pr:code-review`
- `/kramme:pr:product-review`
- `/kramme:pr:ux-review` when UI/UX review is relevant
- `/kramme:qa` when UI-facing changes are detected
- `/kramme:pr:generate-description`

### Explicit Non-Goals

`pr:finalize` should not:

- create the PR itself
- fix CI loops
- merge code
- replace detailed review commands
- silently mutate the branch without clear user awareness

### Output Goals

The command should tell the user:

- what is blocking PR readiness
- what is recommended but optional
- whether UI-specific validation was run
- whether the PR description is in good shape
- the next best command to run if not ready

### Deliverables

- New skill file
- README updates
- Documentation on how it fits the PR lifecycle

### Success Criteria

- It shortens the final “is this branch ready?” decision
- It does not duplicate the behavior of `pr:create` or `pr:fix-ci`
- It clearly branches based on whether the change is UI-heavy or not

## Cross-Phase Testing Strategy

The repository currently has strong hook and converter tests but limited skill-level contract testing.

As part of this roadmap:

- add lightweight smoke validation for new skill presence
- add tests that converted plugin output still contains the new skills
- add minimal contract tests for artifact naming and invocation shape where practical
- avoid trying to build a massive E2E prompt test harness in the first pass

The test strategy should be proportional to current repository norms.

## Documentation Requirements

For each phase:

- update `kramme-cc-workflow/README.md`
- update `kramme-cc-workflow/CHANGELOG.md`
- ensure new skills appear in any generated or converted plugin output
- document relationships between overlapping skills to reduce confusion

The README should explain the intended lifecycle:

- product thinking before implementation
- live inspection and QA during validation
- final PR readiness at the end

## Naming Decisions

### Recommended Final Names

- `/kramme:pr:product-review`
- `/kramme:siw:product-audit`
- `/kramme:browse`
- `/kramme:qa`
- `/kramme:product:review`
- `/kramme:pr:finalize`

### Naming Notes

`siw:product-audit` is recommended over `plan:product-review` because it matches the existing SIW namespace and makes the context obvious.

If broader non-SIW plan review becomes important later, a `plan:` alias can be added without changing the shared implementation.

## Key Risks

- Browser MCP availability may vary between environments, which can make `browse`, `qa`, and `product:review` feel inconsistent unless failure behavior is very clear.
- `pr:finalize` can become bloated if it starts absorbing logic that should remain in `verify`, `review`, or `qa`.
- `pr:product-review` may overlap with `pr:ux-review` unless the product-review rubric is kept sharply focused on product value and flow logic.
- `siw:product-audit` can drift into generic spec audit behavior unless its product lens remains explicit.

## Open Decisions

- Whether `pr:finalize` should automatically invoke `qa` only for UI-relevant changes, or always ask first.
- Whether `product:review` should support screenshots as an alternative to live browser review in V1.
- Whether `qa` should write one standard artifact name or support user-specified output paths immediately.

## Recommended Next Step

Start with Phase 1 only:

1. deepen the shared product-review foundation
2. implement `/kramme:pr:product-review`
3. implement `/kramme:siw:product-audit`

This creates immediate user value, establishes the common rubric, and keeps early delivery independent of browser tooling.
