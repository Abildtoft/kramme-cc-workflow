---
name: kramme:siw:discovery
description: Deep discovery interview that uncovers what you actually want, not what you think you should want. Works pre-spec or on existing specs until 90% confident. Pass --decision-tree, or ask to walk depth-first, to resolve tightly coupled decisions one at a time.
argument-hint: "[topic | spec-file(s) | 'siw'] [--apply] [--decision-tree]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# SIW Discovery

> "Interview me until you have 90% confidence about what I actually want, not what I think I should want."

Resolve SIW context, delegate interview mechanics to `kramme:discovery:interview`, then synthesize the result into SIW artifacts. Keep SIW mode detection, readiness vocabulary, templates, and apply behavior here; keep hypothesis framing, probing, confidence scoring, and decision-tree traversal in the shared interview engine.

## When to Use

- **Greenfield** (no spec yet): Starting a project and want to think it through before committing to a spec
- **Refinement** (spec exists): Spec feels incomplete, vague, or disconnected from the real goal
- **Realignment**: Mid-project, when the spec and the actual need have drifted apart

Do NOT use for: implementation planning (use `generate-phases`), issue definition (use `issue-define`), or spec quality auditing (use `spec-audit`).

## Artifact Readiness Contract

Use this shared vocabulary when synthesizing handoff artifacts:

- `product-only`: the artifact clarifies problem, users, desired outcomes, or strategy fit, but lacks testable requirements.
- `requirements-only`: scope, boundaries, and success criteria are present, but the artifact still needs SIW planning before execution.
- `planning-ready`: discovery has resolved enough product and technical uncertainty for `/kramme:siw:init`, `/kramme:siw:generate-phases`, or `/kramme:siw:issue-define` to create tracked implementation work.
- `implementation-ready`: an issue-level artifact is scoped for execution with dependencies and verification. Discovery never produces implementation-ready artifacts directly.

If unresolved `MISSING REQUIREMENT` items remain, classify the output as `product-only` or `requirements-only` and route to another discovery/refinement pass instead of implementation.

## Step 1: Resolve SIW Context

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--apply` is present, set `apply_changes=true` and remove from argument list. `--apply` has no effect in Greenfield mode (the brief is the output); if Greenfield mode is detected later, tell the user the flag was ignored and continue.
- If `--decision-tree` is present, set `decision_tree_requested=true` and remove from argument list.
- If remaining text includes trigger phrases like "walk the decision tree", "walk this depth-first", "resolve dependencies first", or "depth-first", set `decision_tree_requested=true` without removing the user's topic words unless the phrase is only an instruction.
- Treat remaining arguments as topic text, file paths, or the `siw` keyword.

Detect mode automatically. First classify the current `siw/` state:

- `has_spec_files`: `siw/*.md` excluding the synced SIW spec-exclusion contract. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
- `has_discovery_brief`: `siw/DISCOVERY_BRIEF.md` exists
- `has_strengthening_plan`: `siw/SPEC_STRENGTHENING_PLAN.md` exists

Set the SIW mode:

- **Greenfield** when no SIW spec, discovery brief, or strengthening plan exists.
- **Refinement** when explicit artifact paths are supplied, `siw` selects existing artifacts, or no arguments are supplied and SIW artifacts exist.
- **Realignment** is Refinement with `caller_mode=realignment` when the user says the in-flight work and actual need have drifted apart.

Resolve ambiguity and pending state before delegation:

- Plain topic text plus existing specs or `DISCOVERY_BRIEF.md`: ask whether to refine existing work or start separately. Refine targets `siw`; a separate thread must use another workspace or archive/remove the current SIW files. Never overwrite the brief.
- Any unresolved `SPEC_STRENGTHENING_PLAN.md`: stop before a new refinement pass and ask the user to apply, archive, or remove it. Do not offer to refine existing work when it is the only SIW artifact.

Resolve inputs:

- Greenfield: store topic text as `topic_hint`; if absent, ask what the user is building.
- Refinement/Realignment: prefer explicit paths, then existing SIW spec files plus `siw/supporting-specs/*.md` and `siw/contracts/*.md`, then `siw/DISCOVERY_BRIEF.md`; switch to Greenfield if none exist.
- For matching `.out-of-scope/` slugs, read the record and ask whether to honor the prior rejection or continue. Record an overridden rejection in synthesis.
- If `siw/AUDIT_SPEC_REPORT.md` exists, pass every matching missing, vague, or contradictory section as Low-confidence source evidence.
- Parse any `## Work Context` table for Work Type, Priority Dimensions, and Deprioritized dimensions. Pass the closest Work Context profile; default to Production Feature, and treat legacy dimension lists as ordering hints only.

## Step 2: Delegate the Interview

Invoke `kramme:discovery:interview` with an `INTERVIEW DELEGATION` brief containing:

- resolved topic text and artifact paths,
- `caller_mode`: greenfield, refinement, or realignment,
- `synthesis_owner`: `kramme:siw:discovery`,
- `synthesis_override`: the local templates, Artifact Readiness Contract, SIW output paths, and `PLAN` hand-off marker,
- `confidence_target`: 90% with the resolved Work Context profile,
- `interview_mode`: decision-tree when requested, otherwise coverage,
- `decision_tree_context`: treat high-stakes architecture, data-model shape, refactor sequencing, and migration approach as strong decision-tree candidates; mark branches answered by SIW specs or planning artifacts with their file references,
- audit and prior-rejection context found in Step 1.

The engine owns `UNVERIFIED` hypothesis framing, glossary and strategy priming, topic classification, probing techniques, codebase-as-answer-source checks, confidence assessment, evidence tracking, ADR offers, question pacing, and decision-tree traversal. Require an `INTERVIEW RESULT:` return payload containing every field defined by the engine's delegated-call contract, including initial/final confidence, overall percentage, interview-round count, stated-vs-actual divergence, profile-specific evidence or coverage, and an artifact impact map for Refinement/Realignment.

If the runtime cannot invoke another skill and no delegated interview has started, read the `kramme:discovery:interview` skill's `SKILL.md` plus the references it routes to and execute its delegated-call contract inline once. If invocation starts but errors, times out, or returns a payload without the `INTERVIEW RESULT:` marker or any required field, report the concrete delegation failure and stop without replaying the interview, writing an SIW artifact, or emitting `PLAN:`. If the pre-invocation inline fallback fails or returns an invalid payload, report that failure and stop under the same fail-closed rule. When a decision tree closes but independent dimensions remain below 90%, return to the engine's evidence-confidence profile.

## Step 3: Synthesize SIW Artifacts

In either mode, if a dimension remains unanswered, keep the relevant placeholder in the generated artifact and insert `MISSING REQUIREMENT: {dimension}` immediately above that section so unresolved gaps survive the hand-off artifact.

For **Greenfield**, create `siw/` only after confirming `siw/DISCOVERY_BRIEF.md` does not exist. Read `assets/discovery-brief-template.md`, populate it from the returned interview result, and write `siw/DISCOVERY_BRIEF.md`. Emit `PLAN: Written to siw/DISCOVERY_BRIEF.md.` and `Artifact readiness: <product-only|requirements-only|planning-ready> — <reason>`. Use `planning-ready` only for concrete scope, boundaries, success criteria, relevant technical context/dependencies, and no blocking gaps. Suggest `/kramme:siw:init siw/DISCOVERY_BRIEF.md` or another discovery pass with `--apply`.

When the host runtime supports it (Claude Code), the Greenfield output is `planning-ready`, and the user wants to move directly into implementation planning rather than the SIW spec/issue workflow, offer to call `EnterPlanMode` so the brief becomes the seed of an interactive plan. Ask once via AskUserQuestion (`Enter plan mode now` / `Stick with SIW`) and do not auto-trigger. If the runtime does not expose `EnterPlanMode`, skip this step silently.

For **Refinement or Realignment**, read `assets/spec-strengthening-plan-template.md`, populate it from the returned interview result, and write `siw/SPEC_STRENGTHENING_PLAN.md`. Emit `PLAN: Written to siw/SPEC_STRENGTHENING_PLAN.md.` and `Artifact readiness: <requirements-only|planning-ready> — <reason>`. Use `planning-ready` only when applying the plan would resolve enough scope, acceptance, and technical uncertainty to make the target spec planning-ready; never call the plan itself `implementation-ready`. When the target is `DISCOVERY_BRIEF.md`, reference its sections in the patch plan.

## Step 4: Optional Apply

If `apply_changes=true` or the user asks to apply, read `references/apply-protocol.md` and follow it exactly.

## Final Quality and Verification

Before writing or handing off, read `references/synthesis-checklist.md`. Verify the engine returned direct validation and stress-probe evidence for every critical dimension, preserve unresolved gaps, pair every non-goal with a rationale, and keep stated-vs-actual divergence visible.
