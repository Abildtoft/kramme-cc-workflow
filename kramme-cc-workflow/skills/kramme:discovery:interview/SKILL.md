---
name: kramme:discovery:interview
description: Conduct an in-depth interview about a topic/proposal to uncover requirements, priorities, and non-goals, then create a comprehensive plan. Pass --ideate (or use a vague topic) to run a divergent pre-stage that generates variations before converging.
argument-hint: "[file-path or topic description] [--ideate]"
disable-model-invocation: true
user-invocable: true
---

# Deep Exploration Interview

Conduct a structured, in-depth interview about the presented topic, files, proposal, or feature. Use the AskUserQuestion tool throughout to gather decisions and uncover requirements. Conclude by writing a comprehensive plan.

## Process Overview

1. **Initial Analysis**: Examine the topic/files/proposal presented
2. **Autonomous Framing**: Draft the likely target user, problem, why-now, and non-goals before asking questions
3. **Topic Classification**: Determine the type of exploration needed
4. **Phase 0 (optional) — Divergent**: If the framing is vague or `--ideate` is set, generate variations via lenses and converge before interviewing
5. **Multi-Round Interview**: Ask probing questions via AskUserQuestion only where meaningful uncertainty remains
6. **Progress Tracking**: Monitor coverage across dimensions
7. **Synthesis**: Write an adaptive plan markdown file

## Output Markers

Use these markers in user-facing output to keep downstream tooling parseable:

- `CONFUSION` — when the working hypothesis doesn't fit the user's framing and you need to flag it before continuing.
- `MISSING REQUIREMENT` — when a question cannot be answered from the provided artifact and needs user input.
- `UNVERIFIED` — when you assert something you haven't confirmed (e.g., a feasibility guess during Phase 0 convergence).
- `FRAMING` — the label applied when Phase 0 converges on the concrete problem statement that will feed the interview.
- `PLAN` — the label applied to the synthesized plan document at hand-off.

## Step 1: Autonomous Framing

Before starting the interview, write down a working hypothesis for:
- Who the user or stakeholder is
- What job they are trying to get done
- Why this matters now
- What is likely out of scope or intentionally deprioritized

Treat these as assumptions to validate, not excuses to ask generic setup questions.

If the hypothesis doesn't seem to match the user's framing, emit `CONFUSION:` and ask a clarifying question before continuing.

## Step 2: Topic Classification

After drafting the working hypothesis, classify the topic into one of these categories:

| Type | Indicators | Focus Areas |
|------|------------|-------------|
| **Software Feature** | New functionality, UI changes, API additions | Architecture, data model, UX flows, integration |
| **Process/Workflow** | Team processes, approval flows, automation | Steps, roles, triggers, exceptions, tooling |
| **Architecture Decision** | Technology choice, pattern selection, migration | Options, tradeoffs, constraints, reversibility |
| **Documentation/Proposal** | RFC, design doc, specification review | Gaps, clarity, feasibility, actionability |

Use AskUserQuestion to confirm the topic type if unclear.

## Phase 0: Divergent (Optional)

Run Phase 0 **only** when one of the following is true:

- The user passed `--ideate` in `$ARGUMENTS`.
- The framing is **vague** — it names an area but not a concrete ask. Heuristics: "improve X", "do something about Y", "help me think through Z", or a topic that can't be mapped to a specific outcome after Step 1 framing.

If the framing is concrete (e.g., "Add email-based 2FA to the login flow"), **skip Phase 0** and proceed to Step 3.

### Entry notice

When Phase 0 is triggered by auto-detection (not by `--ideate`), display a one-line notice before running it:

```text
CONFUSION: The framing is broad. Running a short divergent pass (7 variation lenses, 3 stress-test axes) before the interview. Skip with "just interview me".
```

If the user responds with "just interview me" or similar, skip Phase 0 and proceed to Step 3 with the framing as-is.

### Generate variations

Read `references/variation-lenses.md` and apply 4–7 lenses to the topic. Produce 5–8 candidate variations. Not every lens fits every topic — pick the lenses most likely to surface meaningfully distinct framings.

### Converge with stress-test axes

For each surviving variation, note:

- `{painkiller|vitamin}` — user value axis
- `{first-failure-mode}` — feasibility axis (if you can't name one, mark it `UNVERIFIED` and record what evidence you'd need)
- `{differentiator}` — what this does that existing alternatives don't

Drop variations where the differentiator is "nothing distinct" or the feasibility story is unknowable without weeks of research.

### Pick a concrete framing

Present the 2–4 strongest variations via AskUserQuestion. If the user picks one, restate it as a concrete problem statement and emit:

```text
FRAMING: Interview will proceed on the following framing — {chosen variation restated concretely}.
```

If the user picks "None of these", apply 2 fresh lenses and re-run convergence. If they still don't land on anything, fall back to the original framing and proceed with the interview.

Feed the chosen framing into Step 3 as the working topic.

## Step 3: Interview Approach

### Question Philosophy

Craft questions that:
- **Challenge assumptions** - Present alternatives the user may not have considered
- **Expose edge cases** - Surface scenarios that could break the design
- **Reveal dependencies** - Uncover hidden connections to existing systems
- **Quantify tradeoffs** - Make abstract concerns concrete
- **Force prioritization** - Clarify what should not be done in this pass
- **Separate decision ownership** - Distinguish product calls from implementation choices
- **Plan the learning loop** - Ask how the team will know quickly if the approach is working

**Avoid obvious questions.** Never ask "What is the feature?" or "Why do you want this?"
If the artifact already answers a question, do not ask it again. Instead, present the inferred answer and ask only for confirmation or correction.

If a dimension requires information the artifact doesn't contain and the user hasn't provided, emit `MISSING REQUIREMENT:` before asking the user to fill the gap.

### Using AskUserQuestion Correctly

The AskUserQuestion tool requires **2-4 predefined options** per question. Users can always select "Other" to provide free-text input.

**Tool structure:**
- `header`: Short label (max 12 chars) shown as chip/tag, e.g., "Error handling"
- `question`: The full question text
- `options`: 2-4 choices, each with `label` (short) and `description` (explains tradeoff)
- `multiSelect`: Set `true` when choices aren't mutually exclusive

### Question Context Pattern

For **every question**, provide context before asking:

1. **Why this matters** — 1-2 sentences on relevance, impact, and what could go wrong
2. **Recommendation** — Your suggested approach with brief rationale, or "No strong preference—depends on your priorities" if genuinely neutral

This transforms the interview from interrogation into collaborative exploration.

**Example - Complete question with context:**
```
**Why this matters:** Rate limiting strategy directly affects both user experience and
system stability. Getting this wrong could either frustrate users with unnecessary
failures or overwhelm downstream services during traffic spikes.

**Recommendation:** For user-facing operations, I'd lean toward graceful degradation—
partial success is usually better than total failure. However, if data consistency is
critical (e.g., financial transactions), fail-fast with clear messaging may be safer.

Question: "How should the system handle rate limit exhaustion?"
Options:
- Queue requests and retry (preserves all actions, adds latency)
- Fail immediately with clear error (fast feedback, user retries)
- Degrade gracefully by skipping non-essential operations (partial success)
```

**Craft thoughtful options that represent real alternatives, not straw men.**

**Example - Bad (no context, weak options):**
```
Question: "Should we handle errors?"
Options:
- Yes, handle errors (obviously correct)
- No, crash the application (straw man)
- Maybe (meaningless)
```

### Question Dimensions by Topic Type

#### For Software Features
- **User / Why Now**: target user, job-to-be-done, urgency, business value
- **Architecture**: Component boundaries, data flow, state ownership
- **Data Model**: Entities, relationships, constraints, migrations
- **API Design**: Endpoints, payloads, versioning, error responses
- **User Experience**: Flows, edge cases, loading states, error recovery
- **Integration**: Existing features affected, backward compatibility
- **Performance**: Scale expectations, caching needs, async operations
- **Security**: Authentication, authorization, data sensitivity
- **Non-Goals**: deferred work, excluded edge cases, follow-up issues, and why each is excluded

#### For Process/Workflow
- **User / Why Now**: who is blocked today, urgency, business reason
- **Triggers**: What initiates the process, frequency, urgency
- **Steps**: Sequence, parallelism, dependencies
- **Roles**: Who does what, handoffs, approvals
- **Exceptions**: What can go wrong, escalation paths
- **Tooling**: Systems involved, automation opportunities
- **Metrics**: Success criteria, monitoring needs
- **Non-Goals**: what process complexity should stay out of scope for now, and why

#### For Architecture Decisions
- **Decision Ownership**: what is a product/business decision vs architecture decision
- **Options**: What alternatives exist, pros/cons of each
- **Constraints**: Non-negotiables, deadlines, budget
- **Tradeoffs**: What you gain/lose with each option
- **Reversibility**: How hard to change course later
- **Migration**: Path from current to target state
- **Risk**: What could go wrong, mitigation strategies

#### For Documentation/Proposal
- **Clarity**: What's ambiguous or underspecified
- **Completeness**: What's missing that should be addressed
- **Feasibility**: What seems unrealistic or risky
- **Actionability**: Can someone implement this as-is?
- **Assumptions**: What's implied but not stated

## Step 4: Interview Execution

### Round Structure

Ask **1-4 questions per round** using AskUserQuestion. Mix questions across different dimensions.

After receiving answers, provide a brief synthesis before the next round:
```
"Based on your answers: [key insight]. This raises follow-up questions about [area]..."
```

### Adaptive Follow-Up Behavior

After each round, analyze the answers and adapt your next questions:

**Dig deeper when:**
- An answer reveals unexpected complexity ("Tell me more about...")
- The user mentions a constraint or concern in passing
- A decision has significant downstream implications

**Pivot when:**
- Answers reveal the problem is different than assumed
- A previously unexplored dimension becomes critical
- The user's priorities shift from initial assumptions

**Clarify when:**
- An answer is ambiguous or contradictory
- The user selects "Other" with a response that needs unpacking
- Technical terms or domain concepts need definition

**Don't just check boxes** — the goal is understanding, not coverage.
If the remaining gaps are low-value or implementation-level only, stop the interview and move to synthesis.

### Progress Tracking

After each round, display coverage status using dimensions relevant to the topic type:

**Software Feature:**
```
Coverage: [Architecture: 70%] [Data Model: 60%] [API: 40%] [UX: 80%] [Integration: 20%]
```

**Process/Workflow:**
```
Coverage: [Triggers: 80%] [Steps: 60%] [Roles: 40%] [Exceptions: 20%] [Metrics: 0%]
```

**Architecture Decision:**
```
Coverage: [Options: 90%] [Tradeoffs: 70%] [Constraints: 50%] [Migration: 30%]
```

**Documentation Review:**
```
Coverage: [Clarity: 80%] [Completeness: 60%] [Feasibility: 40%] [Actionability: 20%]
```

Adjust percentages based on how thoroughly each dimension has been explored.

### Completion Criteria

Stop interviewing when:
- All relevant dimensions show 80%+ coverage
- No major unknowns remain for the topic type
- User indicates satisfaction with exploration depth
- Enough information exists to write a comprehensive plan
- **Simple topics**: 1-2 rounds may suffice. Don't artificially extend the interview.

## Step 5: Output Plan Document

### File Naming
Suggest a filename based on the topic, e.g., `user-auth-redesign-plan.md` or `deployment-process-plan.md`. Ask user for preferred location.

### Template Selection

Pick the template matching the topic type classified in Step 2:

| Topic Type | Template File |
|------------|---------------|
| Software Feature | `assets/template-feature.md` |
| Process/Workflow | `assets/template-process.md` |
| Architecture Decision | `assets/template-architecture.md` |
| Documentation/Proposal | `assets/template-doc-review.md` |

Read the matching template, fill in the interview findings, and write the populated result to the user-chosen location. Emit `PLAN:` as the hand-off label:

```text
PLAN: Written to {path}. Ready for review.
```

If a required section cannot be filled because the interview didn't cover it, leave the placeholder in place and add `MISSING REQUIREMENT: {dimension}` above it so the gap is explicit.

## Important Guidelines

1. **Craft real alternatives** - Every option should be a legitimate choice someone might make
2. **Listen for implicit concerns** - Users often hint at worries; probe deeper
3. **Connect answers** - Show how different decisions interact
4. **Challenge diplomatically** - "Have you considered X?" not "X is wrong"
5. **Depth over breadth** - Better to deeply explore key areas than superficially cover everything

## Starting the Interview

**Handling $ARGUMENTS:**
- `$ARGUMENTS` contains everything the user typed after `/kramme:discovery:interview`
- Parse for the `--ideate` flag. If present, set `force_ideate=true` and remove from the argument list.
- If the remaining text looks like file path(s): Read and analyze them first
- If it's free text: Use as the topic description
- If empty: Ask user what they want to explore using AskUserQuestion

**Process:**
1. Parse and analyze any files or context provided via $ARGUMENTS
2. Draft the autonomous framing hypotheses (target user, why-now, non-goals) before asking questions
3. Classify the topic type
4. Confirm classification with user if ambiguous
5. If `force_ideate=true` or the framing is vague, run Phase 0 before starting the interview
6. Ask your first round of probing questions, starting with the highest-uncertainty assumptions

## Epilogue

### Common Rationalizations

- *"The topic is already clear enough to skip Phase 0."* — Sometimes true. But if you can't state the concrete outcome in one sentence, the framing is vague and Phase 0 will save rounds.
- *"The user will correct me if I'm wrong."* — They often won't, because they don't know what they don't know. Use `CONFUSION:` to surface mismatches early.
- *"Coverage at 80% across all dimensions means I'm done."* — Coverage is a proxy, not a goal. Stop when no major unknowns remain, even if a dimension sits at 60%.
- *"The template handles all topic types, so classification doesn't matter."* — It does. The template shapes what questions to ask; picking the wrong one produces a flabby plan.

### Red Flags

- Asking a question whose answer is already in the artifact. Stop and re-read the artifact.
- Generating a plan before the user has confirmed the classification or chosen a Phase 0 framing.
- Running Phase 0 on a concrete topic the user already scoped. Skip it.
- Filling in a plan section from assumption rather than interview data. Emit `MISSING REQUIREMENT:` instead.
- The interview drifts into implementation minutiae before the problem statement is settled.

### Verification

Before writing the plan, confirm:

- [ ] The working hypothesis from Step 1 has been either validated or explicitly corrected during the interview.
- [ ] The topic type from Step 2 matches what the user actually cares about (not what the artifact happens to contain).
- [ ] If Phase 0 ran, the chosen framing was restated as a concrete problem statement and the user confirmed it.
- [ ] Every dimension either has interview-grounded content or an explicit `MISSING REQUIREMENT:` marker.
- [ ] If the chosen template includes a non-goals section, each entry includes a rationale instead of a bare placeholder.
- [ ] The `PLAN:` marker is present at hand-off.
