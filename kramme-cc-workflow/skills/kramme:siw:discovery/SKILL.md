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

The gap between what someone says they want and what they actually need is where most failed projects begin. This skill makes the AI the interviewer — probing, challenging, and digging until it genuinely understands the work before a single line of spec or code is written.

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

## Process Overview

The executable flow is Step 1 through Step 6 below:

1. Detect mode and resolve context.
2. Frame an `UNVERIFIED:` hypothesis before asking questions.
3. Assess confidence or map the decision tree.
4. Run the interview loop until confidence or decision-tree closure.
5. Synthesize a discovery brief or strengthening plan.
6. Optionally apply refinement changes.

Read `references/process-overview.md` only when you need the visual flow diagram or usage examples.

## Output Markers

Use these markers in user-facing output to keep downstream tooling parseable:

- `CONFUSION` — when the working hypothesis doesn't match the user's framing, or when answers contradict earlier ones.
- `MISSING REQUIREMENT` — when a confidence dimension can't be answered from the spec or artifact and needs user input.
- `UNVERIFIED` — when you assert something you haven't confirmed (e.g., a hypothesis still awaiting validation).
- `STALE` — when repo-level strategy context exists but its `last_updated` value is old enough to verify before relying on it.
- `MISSING PRODUCT CONTEXT` — when strategy grounding would materially improve discovery but no `STRATEGY.md` exists.
- `PLAN` — the label applied to the synthesized brief or strengthening plan at hand-off.

## Step 1: Detect Mode & Resolve Context

### 1.1 Parse Arguments and Flags

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--apply` is present, set `apply_changes=true` and remove from argument list. `--apply` has no effect in Greenfield mode (the brief is the output); if Greenfield mode is detected later, tell the user the flag was ignored and continue.
- If `--decision-tree` is present, set `decision_tree_requested=true` and remove from argument list.
- If remaining text includes trigger phrases like "walk the decision tree", "walk this depth-first", "resolve dependencies first", or "depth-first", set `decision_tree_requested=true` without removing the user's topic words unless the phrase is only an instruction.
- Treat remaining arguments as topic text, file paths, or the `siw` keyword.

### 1.2 Mode Detection

Detect mode automatically. First classify the current `siw/` state:

- `has_spec_files`: `siw/*.md` excluding the synced SIW spec-exclusion contract. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
- `has_discovery_brief`: `siw/DISCOVERY_BRIEF.md` exists
- `has_strengthening_plan`: `siw/SPEC_STRENGTHENING_PLAN.md` exists

Before branching into Greenfield vs Refinement, handle the ambiguous case explicitly:

- If remaining arguments are plain topic text while spec files or `siw/DISCOVERY_BRIEF.md` already exist, ask whether the user wants to refine the existing SIW documents or start a separate discovery thread.
- If they choose "refine existing", continue in **Refinement mode** and treat the target as `siw`.
- If they choose "start separate", do NOT write a new brief into the current `siw/` directory. Tell them to archive/remove the existing SIW files first or use a different workspace, then stop. Never overwrite an existing `siw/DISCOVERY_BRIEF.md`.
- If `siw/SPEC_STRENGTHENING_PLAN.md` exists without spec files or `siw/DISCOVERY_BRIEF.md`, do not offer a "refine existing" branch. Treat it as an unresolved strengthening artifact that must be applied, archived, or removed before starting another discovery pass.

**Greenfield mode** when:

- No `siw/` directory exists, OR
- `siw/` exists but contains neither spec files, `siw/DISCOVERY_BRIEF.md`, nor `siw/SPEC_STRENGTHENING_PLAN.md`

**Refinement mode** when:

- Explicit file paths are provided, OR
- `siw` keyword is used and spec files, `siw/DISCOVERY_BRIEF.md`, or `siw/SPEC_STRENGTHENING_PLAN.md` exist, OR
- No arguments are given and spec files, `siw/DISCOVERY_BRIEF.md`, or `siw/SPEC_STRENGTHENING_PLAN.md` exist

### 1.3 Resolve Inputs

**Greenfield:**

- If remaining arguments contain text (not file paths), store as `topic_hint`
- If no arguments, ask for topic using AskUserQuestion:

```yaml
header: "What are you building?"
question: "Describe the project, problem, or idea you want to explore. Don't worry about being precise — that's what this interview is for."
freeform: true
```

**Refinement:**

- Resolve target documents using this order:
  1. If explicit file paths include `siw/DISCOVERY_BRIEF.md` and `siw/SPEC_STRENGTHENING_PLAN.md` also exists, stop. Tell the user to apply, archive, or discard the pending strengthening plan before running another refinement interview against the brief.
  2. Explicit file paths from arguments (SIW spec files or `siw/DISCOVERY_BRIEF.md`)
  3. If no explicit files were provided and `siw/SPEC_STRENGTHENING_PLAN.md` exists in the workspace, read that plan, tell the user there is already an unresolved strengthening artifact in this workspace, and stop. They should apply, archive, or remove it before starting another discovery pass.
  4. If no explicit files were provided and spec files exist, include `siw/*.md` except the synced SIW spec-exclusion contract from mode detection. Also include `siw/supporting-specs/*.md` and `siw/contracts/*.md`.
  5. If no explicit files were provided, no spec files exist, but `siw/DISCOVERY_BRIEF.md` does, target that brief so no-argument reruns resume the saved discovery output.
  6. If nothing is found, switch to greenfield mode.
- Check `.out-of-scope/` for prior matches against the topic. Two-step protocol: (a) list filenames in `.out-of-scope/` (skip silently if the directory is absent or empty); (b) read the body of any file whose slug plausibly matches `topic_hint` (greenfield) or the resolved spec scope (refinement). When a match is found, surface as "This is similar to `.out-of-scope/<slug>.md` (decided <date>) — we rejected this before because <one-line summary>. Continue, or honor the prior rejection?" and route the answer through AskUserQuestion. If the user honors the prior rejection, stop; otherwise continue and note the prior rejection in the discovery brief output. If `/kramme:docs:out-of-scope` is installed in this environment, mention it as the storage skill; omit the mention otherwise.
- If `siw/AUDIT_SPEC_REPORT.md` exists, read it and lower the matching confidence dimension to Low for every section the audit flagged as missing, vague, or contradictory before starting the interview.

### 1.4 Extract Work Context (Refinement only)

Look for `## Work Context` section in spec files:

1. Parse the markdown table for Work Type, Priority Dimensions, Deprioritized dimensions
2. Normalize `Work Type` to the closest Work Context profile using the mapping in `references/confidence-framework.md`
3. Treat legacy `Priority Dimensions` and `Deprioritized` values from `siw:init` as interview-ordering hints only
4. If not found, default to Production Feature (all dimensions active)
5. Store as `work_context`

### 1.5 Select Interview Mode

- If `decision_tree_requested=true`, use **Decision-Tree mode** and read `references/decision-tree-mode.md` before Step 3.
- Otherwise use **Coverage mode** and keep the existing confidence-dimensional flow.
- If the user switches mid-session with a phrase like "walk this depth-first", finish the current answer processing, then switch to Decision-Tree mode for the coupled decisions in flight.
- If Decision-Tree mode exhausts the dependency branch but independent confidence gaps remain, switch back to Coverage mode for those gaps.

### 1.6 Prime Ubiquitous Language

Before Step 2, check for `UBIQUITOUS_LANGUAGE.md` at the project root:

- If it exists, read it and use canonical terms throughout the interview and output artifacts.
- If the user uses a term that conflicts with the glossary, pause with one targeted question: "Your glossary defines `{term}` as {canonical meaning}, but you seem to mean {observed meaning}. Which meaning should I use?"
- If it does not exist, proceed silently. Do not mention the missing file or suggest creating it.

### 1.7 Prime Product Strategy

Before Step 2, check for `STRATEGY.md` at the project root:

- If it exists, read it and extract target problem, approach, who it is for, key metrics, active tracks, milestones if present, and non-goals.
- Store this as `STRATEGY_CONTEXT` and use it as product grounding for the interview and synthesized artifact.
- If its `last_updated` frontmatter is older than 90 days, mark relevant strategy context as `STALE:` in the initial hypothesis and treat it as a question to verify.
- If no `STRATEGY.md` exists, proceed silently for narrow refinement. For greenfield product discovery or broad repo-level direction work, emit `MISSING PRODUCT CONTEXT:` once; if `/kramme:product:strategy` is installed in this environment, suggest it as an optional precursor without blocking discovery, and omit the suggestion otherwise.

## Step 2: Autonomous Framing

**Before asking a single question**, draft a working hypothesis based on available context:

**Greenfield:** Use the topic hint to infer:

- Who the likely user/stakeholder is
- What job they're trying to get done
- Why this matters now
- How the topic fits or conflicts with `STRATEGY_CONTEXT`, when present
- What's probably out of scope
- What the stated want likely is vs. what the actual need might be

**Refinement:** Read the spec and infer:

- What the spec says the project is about
- What the spec actually focuses energy on (which may differ)
- Where the spec is confident vs. hand-wavy
- What's conspicuously absent
- Whether the spec aligns with target users, active tracks, key metrics, and non-goals from `STRATEGY_CONTEXT`, when present

Present the hypothesis to the user, prefixed with `UNVERIFIED:` so downstream readers know it is a working assumption awaiting interview validation:

```text
UNVERIFIED: Here's my initial read on what you're building:

[2-4 sentence hypothesis]

I'll use this as a starting point and validate/correct it during the interview. Let me know if I'm wildly off before we begin, or we can let the interview surface the corrections naturally.
```

Proceed immediately — don't wait for a response unless the user offers one. The hypothesis is a conversation opener, not a gate.

If the hypothesis clearly clashes with the user's framing, additionally prefix it with `CONFUSION:` and name what doesn't fit.

If `STRATEGY_CONTEXT` exists and the target work appears to conflict with an active track, target user, metric, or non-goal, name the conflict in the hypothesis. This is a product-alignment prompt, not a blocker; the user may confirm that strategy should change.

## Step 3: Initial Assessment

Read `references/confidence-framework.md` and use its dimension definitions, scoring rubrics, Work Context mapping, dashboard format, evidence ledger, and stop/continue rules.

- **Coverage mode:** run the initial confidence assessment from the framework. Greenfield starts all dimensions Low unless the topic hint justifies Medium; refinement maps spec sections to dimensions and never starts above High from spec alone.
- **Decision-Tree mode:** also read `references/decision-tree-mode.md`, identify the root decision, list prerequisite branches, mark branches answered by artifacts with file references, and keep unresolved confidence dimensions visible for synthesis.

## Step 4: Discovery Interview Loop

Use **Coverage mode** by default. Use **Decision-Tree mode** when selected in Step 1.5.

Read `references/probing-techniques.md` for the technique library, question-round contract, answer-processing rules, Codebase-as-Answer-Source Rule, ADR-Offer Hook, and interview pacing.

In Coverage mode, repeat the coverage loop from `references/probing-techniques.md` until the stop conditions in `references/confidence-framework.md` are met or the user stops early. Keep the confidence dashboard visible after each round.

In Decision-Tree mode, follow `references/decision-tree-mode.md`: resolve the highest-dependency branch first, ask one question at a time unless siblings are routine and independent, update the tree after each answer, run the ADR hook for durable tradeoffs, and return to Coverage mode for independent confidence gaps.

## Step 5: Synthesize Findings

In either mode, if a dimension remains unanswered, keep the relevant placeholder in the generated artifact and insert `MISSING REQUIREMENT: {dimension}` immediately above that section so unresolved gaps survive the hand-off artifact.

### Greenfield Mode → DISCOVERY_BRIEF.md

Create `siw/` if it does not already exist. Before writing, check whether `siw/DISCOVERY_BRIEF.md` exists. If it exists, stop and ask whether to refine the existing brief. If the user wants a separate discovery thread, tell them to archive/remove the existing SIW files first or use a different workspace, then stop. Never overwrite an existing `siw/DISCOVERY_BRIEF.md`.

If `siw/DISCOVERY_BRIEF.md` does not exist, read `assets/discovery-brief-template.md`, populate it from the interview, and write the result to `siw/DISCOVERY_BRIEF.md`. Emit `PLAN: Written to siw/DISCOVERY_BRIEF.md.` at hand-off.

Also emit `Artifact readiness: <product-only|requirements-only|planning-ready> — <one-line reason>`. Use `planning-ready` only when the brief has concrete scope, boundaries, success criteria, relevant technical context/dependencies or planning detail, and no blocking `MISSING REQUIREMENT` markers.

After writing, suggest next steps:

- `/kramme:siw:init siw/DISCOVERY_BRIEF.md` — to bootstrap a full SIW workflow from this brief
- `/kramme:siw:discovery siw/DISCOVERY_BRIEF.md --apply` — to iterate on the brief and fold clarified decisions back into it

### Optional plan-mode handoff

When the host runtime supports it (Claude Code), the output is `planning-ready`, and the user wants to move directly into implementation planning rather than the SIW spec/issue workflow, offer to call `EnterPlanMode` so the brief becomes the seed of an interactive plan. Ask once via AskUserQuestion (`Enter plan mode now` / `Stick with SIW`) — don't auto-trigger. If the runtime doesn't expose `EnterPlanMode`, skip this step silently.

### Refinement Mode → SPEC_STRENGTHENING_PLAN.md

Read `assets/spec-strengthening-plan-template.md`, populate it from the interview, and write the result to `siw/SPEC_STRENGTHENING_PLAN.md`. Emit `PLAN: Written to siw/SPEC_STRENGTHENING_PLAN.md.` at hand-off.

Also emit `Artifact readiness: requirements-only` unless the plan clearly resolves enough scope, acceptance, and technical uncertainty to make the target spec `planning-ready` after apply. Never label the strengthening plan itself `implementation-ready`.

If the refinement target is `siw/DISCOVERY_BRIEF.md`, reference sections from the brief in the patch plan and treat the brief as the target document for optional apply. Treat `siw/SPEC_STRENGTHENING_PLAN.md` as a temporary handoff artifact: it should remain only while waiting for review or manual application, and it should be removed once the plan has been applied.

## Step 6: Optional Apply

If `apply_changes=true` or the user asks to apply, read `references/apply-protocol.md` and follow it exactly.

## Final Quality and Verification

Before writing the brief, strengthening plan, or final hand-off, read `references/synthesis-checklist.md` and apply its output quality bar, red flags, and verification checklist.
