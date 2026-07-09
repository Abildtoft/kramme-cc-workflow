---
name: kramme:prototype
description: "Builds a clearly throwaway logic/state or UI prototype to answer one design question before implementation hardens. Use when the user wants to sanity-check a state model, data shape, API surface, page layout, component direction, or interaction idea with disposable code. Not for production implementation, polished demos, visual diff reports, permanent routes, or broad design-system work."
argument-hint: "[design question or prototype goal]"
disable-model-invocation: true
user-invocable: true
---

# Prototype

A prototype is throwaway code that answers one design question. Keep the durable output as the answer and the decision, not the prototype code.

## Workflow

1. State the question before editing files.
   - Name the exact uncertainty the prototype must resolve.
   - Name the expected user or maintainer decision the prototype should make easier.
   - If the question is ambiguous and the user is not available, choose the branch that matches the surrounding code and state the assumption.

2. Select one branch.
   - For logic, state models, data shapes, API surfaces, or business rules, read `references/logic.md`.
   - For UI structure, page layout, component direction, or interaction feel, read `references/ui.md`.
   - Do not run both branches unless the user explicitly asks for separate prototypes.

3. Preflight existing prototype state.
   - Search for existing prototype files, routes, switchers, commands, and `?variant=` plumbing near the target surface before creating new ones.
   - Resume or update an existing matching prototype when the question is clearly the same.
   - Track which prototype artifacts existed before this run and which ones this run creates or modifies.
   - Ask before overwriting, replacing, or creating a duplicate route, command, switcher, or fixture store.

4. Mark every prototype artifact as throwaway.
   - Place prototype code near the host module, page, or workflow it informs when that improves context.
   - Use names that include `prototype`, `throwaway`, or another unmistakable marker.
   - Keep prototype code out of production paths unless the host project already has a safe convention for non-production experiments.

5. Make it runnable with one command.
   - Use the host project's existing task runner, route convention, or local script convention.
   - Do not add a new package manager, framework, server, database, or runtime just for the prototype.
   - Give the user the exact command or URL needed to try it.

6. Keep side effects disposable.
   - No persistence by default: use in-memory state unless the design question is explicitly about persistence.
   - If persistence is required, use only scratch storage with a name that says it can be wiped.
   - Do not call production mutation APIs, real payment flows, external delivery systems, or real customer data from prototype code.

7. Surface state and decision evidence.
   - Logic prototypes must show the full relevant state after each action.
   - UI prototypes must make the current variant visible and shareable.
   - Capture the observations that answer the original question.

8. Capture the answer and clean up explicitly.
   - Capture the answer in the conversation, issue, commit message, ADR, or a short `NOTES.md` next to the prototype when the user is away.
   - Treat `NOTES.md` as temporary unless the user explicitly chooses it as the durable decision record.
   - Delete only prototype artifacts created by this run after the answer is captured.
   - Ask before deleting or replacing prototype artifacts, routes, commands, switchers, or fixture stores that existed before this run. If the user is unavailable, leave an exact cleanup note instead of deleting them.
   - If the decision should become production code, stop with a handoff note. Implement the production change only after an explicit follow-up request using the normal implementation workflow.

## Artifact Lifecycle

Prototype artifacts are temporary by default.

- Produced by: this skill's branch workflow, using the host project's existing conventions.
- Consumed by: the user or implementer evaluating the design question.
- Refreshed by: editing or rerunning the prototype when the question changes before implementation.
- Retired by: deleting current-run prototype artifacts after the answer is captured. Resumed or pre-existing artifacts require confirmation before deletion, and production replacement happens in a separate implementation pass after an explicit user request.

Temporary `NOTES.md` files are produced only when the answer needs to survive until the user or implementer can act on it. They are refreshed with the prototype while the question is still open and retired by deleting them after the decision moves into the conversation, issue, commit message, ADR, or final implementation notes.

## Source Tracking

`references/sources.yaml` records upstream inspiration for this skill. Do not load it during normal use unless auditing or refreshing source attribution.
