# Routing Reference

Classify the plan before editing files. The route should be explainable from facts in the plan plus quick local context gathering.

## Route Selection

### Linear

Use `linear` when any of these are true:

- The plan names a Linear issue identifier such as `ABC-123`.
- The plan includes a Linear URL.
- The plan says the source of truth is Linear or that a Linear branch should be used.

Do not continue directly if the Linear issue is the authoritative tracker. Delegate to `kramme:linear:issue-implement` so branch setup, comments, metadata, and issue context are handled by the Linear workflow.

If the plan mentions Linear but no issue identifier or URL is present, stop with:

```
MISSING REQUIREMENT: Linear issue identifier is required before implementation.
```

### SIW

Use `siw` when any of these are true:

- The plan path is under `siw/`.
- The plan names an SIW issue identifier such as `ISSUE-G-001`, `G-001`, `ISSUE-P1-002`, or `P1-002`.
- The plan says the source of truth is an SIW spec, SIW issue, phase, or local structured workflow.

Delegate to `kramme:siw:issue-implement` so status updates, spec sync, and issue closeout stay consistent.

If the plan mentions SIW but no issue can be found or identified, stop with:

```
MISSING REQUIREMENT: SIW issue identifier or issue file is required before implementation.
```

### Recommend SIW

Use `recommend-siw` when the plan is not already tracked but has one or more of these properties:

- Multiple independent phases or waves.
- Multiple PR-sized themes.
- Cross-cutting changes across several subsystems.
- Open product, architecture, data model, migration, or rollout decisions.
- More than one reasonable implementation strategy needs comparison.
- Completion criteria require durable tracking across sessions.
- The plan says prerequisites are blocked or unknown.

Recommend the smallest next SIW action:

- `kramme:siw:init` when there is a spec or durable project to track.
- `kramme:siw:issue-define` when there is one coherent issue but it needs local tracking.
- `kramme:docs:feature-spec` when the plan lacks enough product or technical definition to become an issue.

Do not create SIW files as part of this adapter unless the user explicitly asks for that follow-up.

### Direct

Use `direct` only when all of these are true:

- The objective is clear.
- The plan is bounded to one coherent task.
- Affected files or modules are named or quickly discoverable.
- Acceptance or completion criteria are present.
- Verification commands are discoverable.
- No branch creation, PR creation, deployment, CI watching, or external system write is required.
- The work can finish in the current branch without creating a durable tracker.

Typical direct plans:

- Add one new skill or docs page from a concrete plan.
- Make a small implementation change with named files and tests.
- Apply a contained checklist where the route, scope, and verification are explicit.

### Blocked

Use `blocked` when the plan is contradictory or cannot be executed safely:

- The objective and non-goals conflict.
- The plan depends on an unlanded prerequisite and no safe fallback exists.
- A required file, issue, or external system is unavailable.
- Acceptance criteria are absent and the work changes user-facing behavior.
- Verification is impossible to discover and the plan changes production code.

Ask the minimum question needed to remove the blocker, or recommend a planning workflow if the gap is broad.

## Route Decision Output

Always show the route decision before file edits:

```
PLAN ROUTE: <linear|siw|recommend-siw|direct|blocked>
Reason: <one or two factual reasons>
Next step: <delegate, recommend, ask, or implement>
```

## Re-routing During Work

Re-route immediately if direct execution stops matching the plan:

- More files or subsystems are needed than the plan named.
- A hidden dependency changes the implementation strategy.
- Verification requires external services the user has not provided.
- A missing decision would force invented behavior.

When re-routing, stop and report the reason instead of continuing silently.
