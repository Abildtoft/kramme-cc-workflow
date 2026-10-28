# SIW Mode

Use this reference only when SIW mode is active. SIW mode runs this skill's interview against a tracked SIW (Structured Implementation Workflow) initiative and writes `siw/` artifacts instead of a standalone plan.

Use it when:

- **Greenfield** (no spec yet): the user wants to think a project through before committing to a spec.
- **Refinement** (spec exists): the spec feels incomplete, vague, or disconnected from the real goal.
- **Realignment**: mid-project, the spec and the actual need have drifted apart.

Do not use it for implementation planning or issue definition (use `$kramme:siw:generate-phases`), or spec quality auditing (use `$kramme:siw:spec-audit`).

## Artifact Readiness Contract

Use this shared vocabulary when synthesizing handoff artifacts:

- `product-only`: the artifact clarifies problem, users, desired outcomes, or strategy fit, but lacks testable requirements.
- `requirements-only`: scope, boundaries, and success criteria are present, but the artifact still needs SIW planning before execution.
- `planning-ready`: discovery has resolved enough product and technical uncertainty for `$kramme:siw:init` or `$kramme:siw:generate-phases` to create tracked implementation work.
- `implementation-ready`: an issue-level artifact is scoped for execution with dependencies and verification. Discovery never produces implementation-ready artifacts directly.

If unresolved `MISSING REQUIREMENT` items remain, classify the output as `product-only` or `requirements-only` and route to another discovery/refinement pass instead of implementation.

## Resolve SIW Context

Run this before Step 1 framing. First classify the current `siw/` state:

- `has_spec_files`: `siw/*.md` excluding the synced SIW spec-exclusion contract. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
- `has_discovery_brief`: `siw/DISCOVERY_BRIEF.md` exists
- `has_strengthening_plan`: `siw/SPEC_STRENGTHENING_PLAN.md` exists

Set the SIW sub-mode:

- **Greenfield** when no SIW spec, discovery brief, or strengthening plan exists.
- **Refinement** when explicit artifact paths are supplied, or `--siw` (or the bare `siw` keyword) arrives without topic text and SIW artifacts exist.
- **Realignment** is the Realignment sub-mode of Refinement, used when the user says the in-flight work and actual need have drifted apart.

Resolve ambiguity and pending state before framing:

- Topic text plus existing specs or `DISCOVERY_BRIEF.md`: ask whether to refine existing work or start separately. Refine targets the existing SIW artifacts; a separate thread must use another workspace or archive/remove the current SIW files. Never overwrite the brief.
- Any unresolved `SPEC_STRENGTHENING_PLAN.md`: stop before a new refinement pass and ask the user to apply, archive, or remove it. Do not offer to refine existing work when it is the only SIW artifact.

Resolve inputs:

- Greenfield: store topic text as `topic_hint`; if absent, ask what the user is building.
- Refinement/Realignment: prefer explicit paths, then existing SIW spec files plus `siw/supporting-specs/*.md` and `siw/contracts/*.md`, then `siw/DISCOVERY_BRIEF.md`; switch to Greenfield if none exist.
- For matching `.out-of-scope/` slugs, read the record and ask whether to honor the prior rejection or continue. Record an overridden rejection in synthesis.
- If `siw/AUDIT_SPEC_REPORT.md` exists, treat every matching missing, vague, or contradictory section as Low-confidence source evidence.
- Parse any `## Work Context` table for Work Type, Priority Dimensions, and Deprioritized dimensions. Use the closest Work Context profile; default to Production Feature, and treat legacy dimension lists as ordering hints only.

## Interview Settings

- Use the **evidence-confidence** profile with a 90% target and the resolved Work Context profile: read `references/confidence-framework.md` and use its Initial Confidence Assessment for the Greenfield or Refinement sub-mode, evidence ledger, dashboard, and stop rules. When a decision tree closes but independent dimensions remain below 90%, return to this profile.
- When Decision-Tree mode is active, treat high-stakes architecture, data-model shape, refactor sequencing, and migration approach as strong decision-tree candidates, and mark branches already answered by SIW specs or planning artifacts with their file references.

## Interview Result

Before synthesis, assemble `INTERVIEW RESULT:` with all of:

- validated hypothesis and topic classification,
- decisions with rationales and, for artifact-backed refinement, an impact map from each decision to affected source file/section,
- non-goals with rationales and stated-vs-actual divergence (or explicit alignment),
- initial confidence, final confidence with overall percentage, and interview-round count,
- the evidence ledger for the evidence-confidence profile,
- unresolved `MISSING REQUIREMENT` items, risks, and source references.

SIW synthesis and `--apply` read from that result. If the user stops early, keep every missing field as a `MISSING REQUIREMENT:` item rather than filling it from assumption.

## Synthesize SIW Artifacts

Before writing or handing off, read `references/siw-synthesis-checklist.md`. Verify direct validation and stress-probe evidence exists for every critical dimension, preserve unresolved gaps, pair every non-goal with a rationale, and keep stated-vs-actual divergence visible.

In either sub-mode, if a dimension remains unanswered, keep the relevant placeholder in the generated artifact and insert `MISSING REQUIREMENT: {dimension}` immediately above that section so unresolved gaps survive the hand-off artifact.

For **Greenfield**, create `siw/` only after confirming `siw/DISCOVERY_BRIEF.md` does not exist. Read `assets/siw-discovery-brief-template.md`, populate it from the interview result, and write `siw/DISCOVERY_BRIEF.md`. Emit `PLAN: Written to siw/DISCOVERY_BRIEF.md.` and `Artifact readiness: <product-only|requirements-only|planning-ready> — <reason>`. Use `planning-ready` only for concrete scope, boundaries, success criteria, relevant technical context/dependencies, and no blocking gaps. Suggest `$kramme:siw:init siw/DISCOVERY_BRIEF.md` or a Refinement pass with `$kramme:discovery:interview --siw --apply`.

When the host runtime supports it (Claude Code), the Greenfield output is `planning-ready`, and the user wants to move directly into implementation planning rather than the SIW spec/issue workflow, offer to call `EnterPlanMode` so the brief becomes the seed of an interactive plan. Ask once by asking the user directly in chat (`Enter plan mode now` / `Stick with SIW`) and do not auto-trigger. If the runtime does not expose `EnterPlanMode`, skip this step silently. When `kramme:siw:init` invoked this run for its discover handoff, skip the plan-mode offer and the next-command suggestion; `kramme:siw:init` continues from the brief.

For **Refinement or Realignment**, read `assets/siw-spec-strengthening-plan-template.md`, populate it from the interview result, and write `siw/SPEC_STRENGTHENING_PLAN.md`. Emit `PLAN: Written to siw/SPEC_STRENGTHENING_PLAN.md.` and `Artifact readiness: <requirements-only|planning-ready> — <reason>`. Use `planning-ready` only when applying the plan would resolve enough scope, acceptance, and technical uncertainty to make the target spec planning-ready; never call the plan itself `implementation-ready`. When the target is `DISCOVERY_BRIEF.md`, reference its sections in the patch plan.

## Optional Apply

`--apply` has no effect in Greenfield (the brief is the output); if Greenfield was detected, tell the user the flag was ignored and continue. For Refinement or Realignment, when `apply_changes=true` passed the user-only check in SKILL.md, or the user asks in this session to apply the plan, read `references/siw-apply-protocol.md` and follow it exactly.
