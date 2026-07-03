---
name: kramme:code:work-from-plan
description: "Routes and executes a standalone markdown implementation plan. Use when the user provides a PR_PLAN_*.md file, pasted plan, or one-off implementation checklist that is not already a Linear or SIW issue. Detects when to delegate to kramme:linear:issue-implement or kramme:siw:issue-implement, gathers codebase context, surfaces MISSING REQUIREMENT blockers, and proceeds directly only for bounded current-branch work. Not for planning from scratch, PR creation, CI watching, or large multi-phase initiatives that should become SIW."
argument-hint: "[plan path | inline plan]"
disable-model-invocation: true
user-invocable: true
---

# Work From Plan

Route a standalone implementation plan into the right existing workflow, then execute only when the work is bounded enough for direct current-branch implementation.

This skill is an adapter, not a full autonomous pipeline. It does not create branches, create Pull Requests, watch CI, push commits, or turn unclear plans into invented requirements.

## Process Overview

1. Parse the plan input.
2. Read `references/routing.md`, classify artifact readiness, and classify the plan route.
3. Gather enough codebase context to validate the route.
4. Delegate to Linear or SIW when the plan is already tracked there.
5. Recommend SIW or spec hardening when the artifact is not implementation-ready.
6. Read `references/direct-execution.md` and proceed directly only for bounded current-branch work.
7. Verify and close out with changes, verification, and remaining risks.

## Step 1: Parse Arguments

`$ARGUMENTS` must contain either a markdown plan path or inline plan text.

If `$ARGUMENTS` is empty, ask the user for a plan path or pasted plan. Do not infer a plan from recent conversation unless the user confirms that is the intended source.

If `$ARGUMENTS` names an existing file:

1. Read the file.
2. Treat the file path as the plan source.
3. Preserve the plan's stated title, dependencies, non-goals, test plan, and completion criteria.

If `$ARGUMENTS` does not name an existing file:

1. Treat it as inline plan text.
2. Preserve the full text as the plan source.
3. If the inline text is only a one-line task and lacks acceptance criteria, use Step 4 missing-requirement handling before editing code.

## Step 2: Extract Plan Facts

Build a concise plan intake summary:

- Source: file path or inline.
- Title or objective.
- Current status or dependencies.
- In-scope changes.
- Non-goals.
- Affected files, modules, or systems.
- Acceptance or completion criteria.
- Verification plan.
- Open questions, risks, and blockers.
- Artifact readiness: `product-only`, `requirements-only`, `planning-ready`, or `implementation-ready`.

Do not fill missing fields with guesses. Mark missing fields that affect safe execution as `MISSING REQUIREMENT`.

### Artifact Readiness Vocabulary

Classify the source artifact before choosing a route:

- `product-only`: explains the desired outcome, users, problem, or opportunity, but lacks testable scope, success criteria, or implementation constraints.
- `requirements-only`: defines objective, scope, boundaries, and success criteria, but lacks issue-level decomposition, dependencies, affected areas, or an executable verification plan.
- `planning-ready`: has stable requirements and enough technical/contextual detail to generate SIW phases or define issues, but is not itself an implementation issue.
- `implementation-ready`: names a bounded unit of work with clear scope, dependencies, affected modules or files, acceptance criteria, and local verification.

Only `implementation-ready` artifacts can route to `direct` or `siw` implementation. `product-only` and `requirements-only` artifacts must be rejected for direct execution and routed to `/kramme:docs:feature-spec`, `/kramme:siw:discovery`, or another spec-hardening step depending on the missing layer. `planning-ready` artifacts route to `recommend-siw` unless they are already an executable SIW issue; for tracked SIW specs, recommend the next planning step (`/kramme:siw:generate-phases` for phased work or `/kramme:siw:issue-define` for one coherent issue).

## Step 3: Route The Plan

Read `references/routing.md`, classify artifact readiness, then classify the plan as exactly one of:

- `linear`: the plan references a Linear issue and should be delegated.
- `siw`: the plan is already part of SIW or references an SIW issue.
- `recommend-siw`: the plan is large, multi-phase, ambiguous, or durable enough to need local tracking before implementation.
- `direct`: the plan is bounded enough to implement on the current branch.
- `blocked`: required context is missing or contradictory.

If the source is `product-only` or `requirements-only`, do not choose `direct`, even if the requested change sounds small. Explain the missing readiness layer and recommend the smallest hardening step instead. If the source is `planning-ready` but lacks issue-level scope or verification, choose `recommend-siw` even when the artifact already lives under `siw/`; a tracked spec still needs `/kramme:siw:generate-phases` or `/kramme:siw:issue-define` before `/kramme:siw:issue-implement`.

Show the route decision before editing files:

```
PLAN ROUTE: direct
Reason: single bounded docs skill addition, clear affected files, local verification available.
```

If the route is `linear`, invoke `kramme:linear:issue-implement` with the detected issue identifier when that skill is available. If the Linear MCP server or issue identifier is missing, stop with `MISSING REQUIREMENT`.

If the route is `siw`, invoke `kramme:siw:issue-implement` with the detected issue identifier when that skill is available. If the SIW issue cannot be found, stop with `MISSING REQUIREMENT`.

If the route is `recommend-siw`, explain what makes the work too large for direct execution and recommend the smallest next SIW step. Do not create SIW files unless the user explicitly asks.

If the route is `blocked`, list the blocker and ask only the minimum question needed to continue.

## Step 4: Validate Direct Execution Preconditions

Use this step only when Step 3 returns `direct`.

Before editing code:

1. Check the current branch and dirty state.
2. Confirm the plan does not require branch creation, PR creation, pushing, deployment, or CI watching.
3. Confirm the source artifact is `implementation-ready`.
4. Confirm the planned work fits the affected files and completion criteria.
5. Confirm verification commands are discoverable from project instructions, package scripts, Makefile, CI, or existing test patterns.
6. Identify at least one similar local pattern when the plan adds or changes workflow behavior.

If uncommitted changes exist, inspect whether they overlap with the plan's files. Continue only when the changes are related or the user confirms it is acceptable to work alongside them.

If any precondition fails, stop with `MISSING REQUIREMENT` and the smallest useful follow-up.

## Step 5: Execute Direct Work

Read and follow `references/direct-execution.md`.

During execution:

- Keep the implementation bounded to the plan's stated scope.
- Use existing project patterns before adding abstractions.
- Run focused verification for each meaningful slice when possible.
- Invoke `kramme:verify:run` for final verification when available; otherwise run the discovered project commands directly.
- Stop and re-route to SIW if the work expands beyond the original bounded plan.

## Step 6: Closeout

Return a concise closeout:

```
CHANGES MADE:
- <what changed>

VERIFICATION:
- <command>: PASS|FAIL|SKIPPED

THINGS I DIDN'T TOUCH:
- <relevant non-goals or adjacent work>

POTENTIAL CONCERNS:
- <remaining risks, unresolved questions, or none>
```

If implementation was delegated, summarize the handoff route and do not duplicate the delegated skill's full workflow.
