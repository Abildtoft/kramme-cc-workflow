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

Read `references/confidence-framework.md` for dimension definitions and scoring rubrics.

In **Decision-Tree mode**, also read `references/decision-tree-mode.md`, then replace the initial confidence dashboard with:

1. Identify the root decision.
2. List first-level dependencies that must be resolved before downstream questions are meaningful.
3. Mark any branch that the codebase or target spec already answers, with file references where available.
4. Keep unresolved confidence dimensions visible so synthesis still produces the normal SIW artifact.

### Greenfield

Start all 7 dimensions at **Low**, unless the topic hint is rich enough to justify Medium on specific dimensions.

### Refinement

Map spec content to confidence dimensions using the mapping table in the framework reference. Score each:

- Section missing → Low
- Section present but vague → Medium
- Section concrete and specific → High
- Confident requires interview validation — never start higher than High from spec alone

### Apply Work Context

If Work Context exists, apply the adjustments from the framework reference:

- Mark critical dimensions (must reach Confident)
- Mark deprioritized dimensions (only need Medium)
- Normal dimensions must reach High

### Display Initial Dashboard

In Coverage mode, show the confidence dashboard (format in `references/confidence-framework.md`) with initial scores and overall percentage. In Decision-Tree mode, show the root decision, unresolved dependency branches, and any confidence dimensions that still need coverage before synthesis.

## Step 4: Discovery Interview Loop

Read `references/probing-techniques.md` for the technique library and selection guide.

Use **Coverage mode** by default. Use **Decision-Tree mode** when selected in Step 1.5.

### Evidence Ledger Rule

Use the evidence ledger in `references/confidence-framework.md` for every active dimension. The synthesis floor is: critical dimensions need direct validation plus a stress probe; normal dimensions need direct validation unless fully answered by artifacts and immaterial to tradeoffs; deprioritized dimensions need source evidence or one direct answer. The interview must include a priority/scope tradeoff, negative-space probe, and late restatement challenge before synthesis. If the user stops early, preserve uncovered ledger items as `MISSING REQUIREMENT:` instead of treating them as resolved.

### Codebase-as-Answer-Source Rule

Before asking any question in either mode, decide whether the answer can be found by exploring the workspace, target spec, existing SIW docs, or provided artifacts.

- If yes, explore first, report the finding with the source, and ask only for confirmation or correction if meaningful uncertainty remains.
- If no, ask the user.
- Skip exploration when the question is genuinely preference-, priority-, or business-context-based and no artifact could answer it.

### ADR-Offer Hook

After each resolved decision in either mode, evaluate the ADR test. Offer `/kramme:docs:adr` only when it is installed in this environment (skip the hook entirely otherwise) and all three are true:

1. The decision is hard to reverse.
2. It would be surprising later without context.
3. It came from a real tradeoff, not a default.

Prompt once: "This looks ADR-worthy because it is hard to reverse, surprising without context, and tradeoff-driven. Record it via `/kramme:docs:adr`?" Do not author the ADR inside this skill.

### Coverage Mode Loop

Repeat until confidence target is met (see "When to Stop" in framework reference):

#### 4.1 Select Focus

Pick the 1-2 highest-value focus dimensions, weighted by coverage gaps before confidence score:

1. Critical dimensions missing direct validation or a stress probe
2. Normal dimensions missing direct validation
3. Dimensions whose evidence contradicts another answer or artifact
4. Critical dimensions below Confident
5. Normal dimensions below High
6. Deprioritized dimensions below Medium or missing any evidence (only if others are satisfied)

#### 4.2 Select Technique

Use the technique selection guide to pick 1-2 techniques appropriate for the focus dimensions.

Early rounds (1-3): prefer **Solution Stripping**, **Why Chain**, and **Minimum Viable Test** — these establish the foundation.

Middle rounds (4-6): prefer **Forced Tradeoff**, **Negative Space**, and **Constraint Removal** — these sharpen boundaries.

Late rounds (7+): prefer **Restatement Challenge**, **Inversion**, and **Stakeholder Lens** — these validate and stress-test understanding.

#### 4.3 Ask Questions

Use AskUserQuestion. Ask 1-3 high-value questions per round; default to 2 when the questions are independent, and 1 when the answer changes the next question. Keep rounds small, but do not compress discovery into one broad batch. For each question:

- Apply the Codebase-as-Answer-Source Rule before asking.
- **State why you're asking** (1 sentence — which dimension this targets)
- **Include your current assumption** (what you think the answer is, so the user can correct rather than explain from scratch)
- **Offer concrete options** when forcing tradeoffs (2-4 options + "Other")
- **Use freeform** when probing for narrative or motivation
- For high-stakes questions where the answer shapes the next question, ask only one question in the round.
- If a round would only ask confirmation questions, replace one with a stress probe unless the coverage floor is already satisfied.

When the technique calls for it, deliberately restate something the user said earlier — slightly differently — to test whether your model matches theirs.

#### 4.4 Process Answers

After each round:

1. Map answers to confidence dimensions
2. Check for stated vs. actual want divergence:
   - Answer contradicts earlier answer → emit `CONFUSION:` and probe
   - Implementation details without problem statement → apply Solution Stripping next round
   - Enthusiasm doesn't match stated priority → name the discrepancy
3. If divergence detected, reset affected dimension to at most Medium until reconciled
4. Update the evidence ledger. Mark a stress probe only when the answer tested a tradeoff, boundary, inversion, past failure, why-chain, or restatement challenge; a simple "yes, correct" does not count.
5. Update confidence levels using rubric indicators and ledger coverage.
6. If a dimension remains unanswerable because the required information isn't in the spec or the user's answers, emit `MISSING REQUIREMENT:` before asking the targeted follow-up.
7. Run the ADR-Offer Hook for any resolved decision.

#### 4.5 Display Updated Dashboard

Show the confidence dashboard with updated scores. Mark focus areas for next round with ◄. Include round number and overall percentage.

If confidence dropped on any dimension (due to contradiction or revelation), note it:

```text
⚠ Scope Boundaries dropped from High to Medium — your answer about [X] suggests the scope is wider than the spec indicates.
```

#### 4.6 Check Stop Conditions

**Stop when:**

- All critical dimensions at Confident (90%+)
- All normal dimensions at High (70%+)
- All deprioritized dimensions at Medium (40%+)
- The coverage ledger floor is satisfied
- Last 2 rounds produced confirmations, not revelations, after the required stress probes have already run

**Also stop when:**

- User explicitly says "that's enough" or "I think you've got it"
- 10+ rounds completed (suggest stopping, don't force — offer to continue if user wants)

**Continue when:**

- Any critical dimension below Confident
- Any critical dimension lacks direct validation or a stress probe
- Any normal dimension lacks direct validation and materially affects scope, outcome, constraints, risk, or priority
- A contradiction was just discovered
- Stated and actual wants haven't been reconciled
- The interview has not yet forced a priority/scope tradeoff, tested negative space, and run a restatement challenge

### Decision-Tree Mode Loop

Read `references/decision-tree-mode.md` for the detailed process. Then repeat until the active decision tree is resolved or remaining gaps are independent enough for Coverage mode:

#### 4D.1 Pick Next Branch

Choose the highest-dependency unresolved branch: the decision that unlocks the most downstream choices. Do not ask about downstream branches until their prerequisite decision is settled.

#### 4D.2 Resolve One Question

Ask one question at a time by default. Batch only routine sibling questions that are independent and low-stakes. Apply the Codebase-as-Answer-Source Rule before asking.

#### 4D.3 Process the Answer

Record:

- The decision or non-decision
- The dependencies it unlocks or invalidates
- The tradeoff accepted
- Any confidence dimensions affected

If the answer changes the root decision, redraw the active dependency tree before asking again.

#### 4D.4 Check ADR and Mode Exit

Run the ADR-Offer Hook for each resolved durable decision. Exit Decision-Tree mode when the coupled branch is resolved; continue in Coverage mode for independent confidence gaps and any unmet evidence-ledger floor.

### Interview Pacing

- Rounds 1-2: broad, establishing. Cover Problem Understanding and Outcome Vision first.
- Rounds 3-5: sharpening. Focus on Scope Boundaries, Priority Alignment, and Constraint Awareness.
- Rounds 6+: validating. Stress-test with Restatement Challenge and Inversion. Fill remaining gaps.
- If a round produces a surprise, pause the plan and follow the surprise — it's higher signal than the next planned question.
- Greenfield discovery should rarely synthesize before 4 rounds unless the user stops early. Refinement should rarely synthesize before 2 rounds unless the target artifacts already answer most dimensions and the interview only validates narrow gaps.

## Step 5: Synthesize Findings

In either mode, if a dimension remains unanswered, keep the relevant placeholder in the generated artifact and insert `MISSING REQUIREMENT: {dimension}` immediately above that section so unresolved gaps survive the hand-off artifact.

### Greenfield Mode → DISCOVERY_BRIEF.md

Create `siw/` if it does not already exist. Then read `assets/discovery-brief-template.md`, populate it from the interview, and write the result to `siw/DISCOVERY_BRIEF.md`. Emit `PLAN: Written to siw/DISCOVERY_BRIEF.md.` at hand-off.

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
