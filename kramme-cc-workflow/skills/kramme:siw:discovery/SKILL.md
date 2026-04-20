---
name: kramme:siw:discovery
description: Deep discovery interview that uncovers what you actually want, not what you think you should want. Works pre-spec (greenfield) or on existing specs (strengthening). Interviews until 95% confident.
argument-hint: "[topic | spec-file(s) | 'siw'] [--apply]"
disable-model-invocation: false
user-invocable: true
---

# SIW Discovery

> "Interview me until you have 95% confidence about what I actually want, not what I think I should want."

The gap between what someone says they want and what they actually need is where most failed projects begin. This skill makes the AI the interviewer — probing, challenging, and digging until it genuinely understands the work before a single line of spec or code is written.

## When to Use

- **Greenfield** (no spec yet): Starting a project and want to think it through before committing to a spec
- **Refinement** (spec exists): Spec feels incomplete, vague, or disconnected from the real goal
- **Realignment**: Mid-project, when the spec and the actual need have drifted apart

Do NOT use for: implementation planning (use `generate-phases`), issue definition (use `issue-define`), or spec quality auditing (use `spec-audit`).

## Process Overview

```text
/kramme:siw:discovery [topic | spec-file(s) | 'siw'] [--apply]
    │
    ▼
[Step 1: Detect mode & resolve context]
    │
    ▼
[Step 2: Autonomous framing — draft hypothesis before asking anything]
    │
    ▼
[Step 3: Initial confidence assessment across 7 dimensions]
    │
    ▼
[Step 4: Discovery interview loop]
    │   ├─ Pick lowest-confidence dimensions
    │   ├─ Select probing technique
    │   ├─ Ask 1-3 questions
    │   ├─ Update confidence scores
    │   ├─ Display confidence dashboard
    │   └─ Repeat until 95% overall
    │
    ▼
[Step 5: Synthesize findings]
    │   ├─ Greenfield → siw/DISCOVERY_BRIEF.md
    │   └─ Refinement → siw/SPEC_STRENGTHENING_PLAN.md
    │
    ▼
[Step 6: Optional apply (--apply or user request)]
```

## Output Markers

Use these markers in user-facing output to keep downstream tooling parseable:

- `CONFUSION` — when the working hypothesis doesn't match the user's framing, or when answers contradict earlier ones.
- `MISSING REQUIREMENT` — when a confidence dimension can't be answered from the spec or artifact and needs user input.
- `UNVERIFIED` — when you assert something you haven't confirmed (e.g., a hypothesis still awaiting validation).
- `PLAN` — the label applied to the synthesized brief or strengthening plan at hand-off.

## Step 1: Detect Mode & Resolve Context

### 1.1 Parse Arguments and Flags

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--apply` is present, set `apply_changes=true` and remove from argument list.
- Treat remaining arguments as topic text, file paths, or the `siw` keyword.

### 1.2 Mode Detection

Detect mode automatically. First classify the current `siw/` state:

- `has_spec_files`: `siw/*.md` excluding `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `AUDIT_*.md`, `SPEC_STRENGTHENING_PLAN.md`, and `DISCOVERY_BRIEF.md`
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
  4. If no explicit files were provided and spec files exist, include `siw/*.md` except LOG.md, OPEN_ISSUES_OVERVIEW.md, AUDIT_*.md, SPEC_STRENGTHENING_PLAN.md, DISCOVERY_BRIEF.md. Include `siw/supporting-specs/*.md`.
  5. If no explicit files were provided, no spec files exist, but `siw/DISCOVERY_BRIEF.md` does, target that brief so no-argument reruns resume the saved discovery output.
  6. If nothing is found, switch to greenfield mode.
- If `siw/AUDIT_SPEC_REPORT.md` exists, read it for input signals.

### 1.4 Extract Work Context (Refinement only)

Look for `## Work Context` section in spec files:
1. Parse the markdown table for Work Type, Priority Dimensions, Deprioritized dimensions
2. Normalize `Work Type` to the closest Work Context profile using the mapping in `references/confidence-framework.md`
3. Treat legacy `Priority Dimensions` and `Deprioritized` values from `siw:init` as interview-ordering hints only
4. If not found, default to Production Feature (all dimensions active)
5. Store as `work_context`

## Step 2: Autonomous Framing

**Before asking a single question**, draft a working hypothesis based on available context:

**Greenfield:** Use the topic hint to infer:
- Who the likely user/stakeholder is
- What job they're trying to get done
- Why this matters now
- What's probably out of scope
- What the stated want likely is vs. what the actual need might be

**Refinement:** Read the spec and infer:
- What the spec says the project is about
- What the spec actually focuses energy on (which may differ)
- Where the spec is confident vs. hand-wavy
- What's conspicuously absent

Present the hypothesis to the user:

```text
Here's my initial read on what you're building:

[2-4 sentence hypothesis]

I'll use this as a starting point and validate/correct it during the interview. Let me know if I'm wildly off before we begin, or we can let the interview surface the corrections naturally.
```

Proceed immediately — don't wait for a response unless the user offers one. The hypothesis is a conversation opener, not a gate.

If the hypothesis clearly clashes with the user's framing, prefix it with `CONFUSION:` and name what doesn't fit.

## Step 3: Initial Confidence Assessment

Read `references/confidence-framework.md` for dimension definitions and scoring rubrics.

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

Show the confidence dashboard (format in `references/confidence-framework.md`) with initial scores and overall percentage.

## Step 4: Discovery Interview Loop

Read `references/probing-techniques.md` for the technique library and selection guide.

### Core Loop

Repeat until confidence target is met (see "When to Stop" in framework reference):

#### 4.1 Select Focus

Pick the 1-2 lowest-confidence dimensions, weighted by criticality:
1. Critical dimensions below Confident (always first)
2. Normal dimensions below High
3. Deprioritized dimensions below Medium (only if others are satisfied)

#### 4.2 Select Technique

Use the technique selection guide to pick 1-2 techniques appropriate for the focus dimensions.

Early rounds (1-3): prefer **Solution Stripping**, **Why Chain**, and **Minimum Viable Test** — these establish the foundation.

Middle rounds (4-6): prefer **Forced Tradeoff**, **Negative Space**, and **Constraint Removal** — these sharpen boundaries.

Late rounds (7+): prefer **Restatement Challenge**, **Inversion**, and **Stakeholder Lens** — these validate and stress-test understanding.

#### 4.3 Ask Questions

Use AskUserQuestion. Ask 1-3 high-value questions per round. For each question:

- **State why you're asking** (1 sentence — which dimension this targets)
- **Include your current assumption** (what you think the answer is, so the user can correct rather than explain from scratch)
- **Offer concrete options** when forcing tradeoffs (2-4 options + "Other")
- **Use freeform** when probing for narrative or motivation

When the technique calls for it, deliberately restate something the user said earlier — slightly differently — to test whether your model matches theirs.

#### 4.4 Process Answers

After each round:

1. Map answers to confidence dimensions
2. Check for stated vs. actual want divergence:
   - Answer contradicts earlier answer → emit `CONFUSION:` and probe
   - Implementation details without problem statement → apply Solution Stripping next round
   - Enthusiasm doesn't match stated priority → name the discrepancy
3. If divergence detected, reset affected dimension to at most Medium until reconciled
4. Update confidence levels using rubric indicators
5. If a dimension remains unanswerable because the required information isn't in the spec or the user's answers, emit `MISSING REQUIREMENT:` before asking the targeted follow-up.

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
- Last 2 rounds produced confirmations, not revelations

**Also stop when:**
- User explicitly says "that's enough" or "I think you've got it"
- 10+ rounds completed (suggest stopping, don't force — offer to continue if user wants)

**Continue when:**
- Any critical dimension below Confident
- A contradiction was just discovered
- Stated and actual wants haven't been reconciled

### Interview Pacing

- Rounds 1-2: broad, establishing. Cover Problem Understanding and Outcome Vision first.
- Rounds 3-5: sharpening. Focus on Scope Boundaries, Priority Alignment, and Constraint Awareness.
- Rounds 6+: validating. Stress-test with Restatement Challenge and Inversion. Fill remaining gaps.
- If a round produces a surprise, pause the plan and follow the surprise — it's higher signal than the next planned question.

## Step 5: Synthesize Findings

### Greenfield Mode → DISCOVERY_BRIEF.md

Create `siw/` if it does not already exist. Then read `assets/discovery-brief-template.md`, populate it from the interview, and write the result to `siw/DISCOVERY_BRIEF.md`. Emit `PLAN: Written to siw/DISCOVERY_BRIEF.md.` at hand-off.

After writing, suggest next steps:
- `/kramme:siw:init siw/DISCOVERY_BRIEF.md` — to bootstrap a full SIW workflow from this brief
- `/kramme:siw:discovery siw/DISCOVERY_BRIEF.md --apply` — to iterate on the brief and fold clarified decisions back into it

### Refinement Mode → SPEC_STRENGTHENING_PLAN.md

Read `assets/spec-strengthening-plan-template.md`, populate it from the interview, and write the result to `siw/SPEC_STRENGTHENING_PLAN.md`. Emit `PLAN: Written to siw/SPEC_STRENGTHENING_PLAN.md.` at hand-off.

If the refinement target is `siw/DISCOVERY_BRIEF.md`, reference sections from the brief in the patch plan and treat the brief as the target document for optional apply.
Treat `siw/SPEC_STRENGTHENING_PLAN.md` as a temporary handoff artifact: it should remain only while waiting for review or manual application, and it should be removed once the plan has been applied.

## Step 6: Optional Apply

If `apply_changes=true` or the user asks to apply:

**Refinement mode:**
1. Edit the target document(s) using decisions from Step 4
2. Target documents may be SIW spec files or `siw/DISCOVERY_BRIEF.md`
3. Preserve structure — add missing sections, don't scatter content
4. If a full SIW workflow exists, update `siw/LOG.md` Decision Log with:
   - Summary of discovery session
   - Key decisions and rationale
   - Remaining open questions
5. After the target documents and optional log updates are complete, delete or trash `siw/SPEC_STRENGTHENING_PLAN.md` so future runs do not treat the applied plan as unresolved state

**Greenfield mode:**
- Apply is not applicable (the brief IS the output)
- Suggest `/kramme:siw:init siw/DISCOVERY_BRIEF.md` for full workflow setup

## Output Quality Bar

Every finding must be:
- Tied to a specific confidence dimension
- Grounded in something the user said (quote or paraphrase)
- Actionable — either a decision made or a question that needs answering
- Distinguishing stated want from actual want when they diverge

Do NOT finish with generic advice like "improve clarity" or "add more detail." If you can't point to a specific gap grounded in the interview, it's not a real finding.

## Usage

```
/kramme:siw:discovery
# Auto-detect mode: greenfield if no spec, refinement if spec exists

/kramme:siw:discovery build a notification system for our platform
# Greenfield discovery with topic hint

/kramme:siw:discovery siw
# Refinement: strengthen existing SIW specs

/kramme:siw:discovery siw/FEATURE_SPEC.md
# Refinement: focus on one spec file

/kramme:siw:discovery siw --apply
# Refinement: discover and directly apply spec improvements
```

## Epilogue

### Common Rationalizations

- *"Confidence is high enough to stop."* — High confidence means nothing if it's high on the wrong dimensions. Re-check which dimensions are Critical for the current Work Context before stopping.
- *"The user agreed with my hypothesis, so we're aligned."* — Agreement is cheap. Restatement Challenge is cheaper than re-doing the project. Verify at least once mid-interview.
- *"Stated and actual wants are the same here."* — They rarely are. If you haven't surfaced *any* divergence by round 4, you probably haven't probed hard enough.
- *"The spec covers it, so the dimension is Confident."* — A section can exist and still be vague. Score on specificity and actionability, not presence.

### Red Flags

- The user answers every question with "yes, that's right" and never corrects you. Likely you're asking leading questions or they're deferring. Force a tradeoff.
- You're about to write the brief and can't quote a single surprising thing the user said. The interview didn't do its job.
- You're defaulting a dimension to a guess instead of asking. Emit `MISSING REQUIREMENT:` and ask.
- The "What You Don't Want" list is empty or has no rationales. Non-goals without reasons become scope creep later.
- You're continuing past round 10 without a signal that anything new will surface. Suggest stopping.

### Verification

Before writing the brief or strengthening plan, confirm:

- [ ] All critical dimensions reached Confident; all normal dimensions reached High; all deprioritized dimensions reached Medium.
- [ ] Stated-vs-actual divergence was either surfaced and documented, or explicitly ruled out during the interview.
- [ ] Every entry in "What You Don't Want" has a rationale.
- [ ] Every unanswered dimension in the output carries a `MISSING REQUIREMENT:` marker, not a fabricated answer.
- [ ] The `PLAN:` marker is present at hand-off.
