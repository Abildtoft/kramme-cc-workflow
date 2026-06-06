---
name: kramme:product:strategy
description: Create or update repo-root STRATEGY.md as a concise product anchor covering target problem, approach, users, metrics, active tracks, milestones, and non-goals. Use when starting a product, revisiting direction, grounding discovery/spec/SIW work, or resolving product-context drift. Not for one-off feature specs, roadmaps, or implementation plans.
argument-hint: "[optional: section or notes to revisit, e.g. 'metrics', 'active tracks']"
disable-model-invocation: true
user-invocable: true
---

# Product Strategy

Create or maintain `STRATEGY.md` at the repository root. This document is a short durable product anchor, not a roadmap, requirements doc, or implementation plan.

## Workflow

1. **Resolve the repository root.**
   - Prefer `git rev-parse --show-toplevel`; fall back to the current working directory if no git root exists.
   - Store the target path as `STRATEGY.md` in that root.

2. **Parse the focus hint.**
   - Treat `$ARGUMENTS` as an optional section or topic hint.
   - Recognize section hints: `problem`, `approach`, `users`, `metrics`, `tracks`, `milestones`, `non-goals`.
   - If no hint is provided, let the existing file state determine create vs update mode.

3. **Read existing product context.**
   - If `STRATEGY.md` exists, read it completely.
   - If `docs/pulse-reports/` exists, read the 1-3 most recent pulse reports only when they are relevant to the update. Use them as evidence, not as automatic strategy changes.
   - If the file has `last_updated` frontmatter older than 90 days, mark the context with `STALE:` in user-facing summaries.

4. **Choose the mode.**
   - **Create mode:** no `STRATEGY.md` exists.
   - **Update mode:** `STRATEGY.md` exists.
   - In update mode, preserve strong sections. Update only the requested section, sections contradicted by new evidence, or sections the user confirms are weak.

5. **Interview only for missing product decisions.**
   - Ask one focused question at a time.
   - Prefer free-form questions for target problem, approach, and users.
   - Use short choice questions only for routing decisions, such as which section to revisit.
   - Do not ask about facts already grounded in the existing strategy, supplied notes, or recent pulse reports.

6. **Keep the document strategic.**
   - Include: target problem, approach, who it is for, key metrics, active tracks, optional milestones, and non-goals.
   - Exclude: issue schedules, task lists, implementation phases, UI copy, API details, and release checklists.
   - If the user tries to add delivery sequencing, capture only the strategic principle and point them to the appropriate planning workflow for the schedule.

7. **Mark confidence honestly.**
   - Prefix inferred claims with `UNVERIFIED:`.
   - Prefix old-but-still-used context with `STALE:`.
   - Prefix absent product context with `MISSING PRODUCT CONTEXT:`.
   - Do not remove these markers unless the user supplies confirming evidence.

8. **Write the strategy document.**
   - Read `assets/strategy-template.md` and populate the template.
   - Include `last_updated: {YYYY-MM-DD}` frontmatter.
   - Keep the finished file short enough to scan in a few minutes.
   - Before overwriting an existing `STRATEGY.md`, summarize the intended changes and ask for confirmation unless the user explicitly requested a direct update.

9. **Report the result.**
   - State whether the skill created or updated `STRATEGY.md`.
   - List the sections changed.
   - Call out any remaining `UNVERIFIED`, `STALE`, or `MISSING PRODUCT CONTEXT` markers.
   - Suggest the next workflow only when it follows from the user's current goal, for example discovery, feature spec, SIW init, or product pulse.

## Section Guidance

### Target Problem

Name the user pain or product opportunity. Avoid describing a feature as the problem.

### Approach

Describe the product stance and operating principles that should guide tradeoffs. Keep it higher level than implementation.

### Who It Is For

Name primary users first, then secondary stakeholders. If there are multiple audiences, state which one wins conflicts.

### Key Metrics

Prefer outcome metrics over activity metrics. Include a measurement caveat when the metric source is unavailable.

### Active Tracks

List the few product tracks that should shape prioritization now. These are not a backlog.

### Milestones

Use only durable product milestones. Omit or keep sparse when the team does not have milestones.

### Non-Goals

List decisions that prevent scope creep. Include why each non-goal is currently out of scope when that context is known.

## Verification

Before claiming completion:

1. `STRATEGY.md` exists at the repository root.
2. Required sections are present and contain no angle-bracket placeholders.
3. The file does not contain implementation plans or issue schedules.
4. Inferred, stale, and missing context is marked.
5. Existing strong sections were preserved unless the user approved changes.
