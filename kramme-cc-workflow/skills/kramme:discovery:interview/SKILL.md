---
name: kramme:discovery:interview
description: Conduct an in-depth interview about a topic/proposal to uncover requirements, priorities, and non-goals, then create a comprehensive plan. Pass --ideate for divergent framing, --decision-tree / depth-first language to resolve tightly coupled decisions one question at a time, or --research to launch topic-specific research agents before the interview.
argument-hint: "[file-path or topic description] [--ideate] [--decision-tree] [--research]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Deep Exploration Interview

Conduct a structured, in-depth interview about the presented topic, files, proposal, or feature. Use the AskUserQuestion tool throughout to gather decisions and uncover requirements. Conclude by writing a comprehensive plan.

**When not to use:** for standalone discovery that produces a one-off plan file, use this skill. For discovery inside a tracked SIW (Structured Implementation Workflow) initiative — where the output feeds `siw/` planning documents — use `kramme:siw:discovery` instead.

## Process Overview

1. **Initial Analysis**: Examine the topic/files/proposal presented
2. **Mode and Glossary Setup**: Detect `--decision-tree`, `--research`, or depth-first trigger phrases; read `UBIQUITOUS_LANGUAGE.md` if present
3. **Autonomous Framing**: Draft the likely target user, problem, why-now, and non-goals before asking questions
4. **Topic Classification**: Determine the type of exploration needed
5. **Phase 0 (optional) — Divergent**: If the framing is vague, pause for an explicit skip-or-continue choice before generating variations. If `--ideate` is set, treat that as an explicit request to run Phase 0 and proceed directly into the divergent pass.
6. **Final Classification Check**: If Phase 0 changed the framing or the topic type is ambiguous, reclassify/confirm before research.
7. **Phase R (optional) — Research**: When `--research` is set or the topic names external libraries, frameworks, or cross-cutting concerns, launch parallel research agents tailored to the confirmed topic classification, then run a brief check-in before the interview.
8. **Post-Research Classification Check**: If Phase R changes the framing or classification, repeat topic classification before interviewing.
9. **Interview**: Use coverage rounds by default or decision-tree mode for coupled decisions.
10. **Progress Tracking**: Monitor coverage across dimensions or resolved branches.
11. **Synthesis**: Write an adaptive plan markdown file.

## Output Markers

Use these markers in user-facing output to keep downstream tooling parseable:

- `CONFUSION` — when the working hypothesis doesn't fit the user's framing and you need to flag it before continuing.
- `MISSING REQUIREMENT` — when a question cannot be answered from the provided artifact and needs user input.
- `UNVERIFIED` — when you assert something you haven't confirmed (e.g., a feasibility guess during Phase 0 convergence).
- `FRAMING` — the label applied when Phase 0 converges on the concrete problem statement that will feed the interview.
- `PLAN` — the label applied to the synthesized plan document at hand-off.

## Step 0: Inputs, Mode, and Glossary

Parse `$ARGUMENTS` as shell-style arguments so quoted paths stay intact.

- If `--ideate` is present, set `force_ideate=true` and remove from argument list.
- If `--decision-tree` is present, set `decision_tree_requested=true` and remove from argument list.
- If `--research` is present, set `research_requested=true` and remove from argument list.
- If remaining text includes trigger phrases like "walk the decision tree", "walk this depth-first", "resolve dependencies first", or "depth-first", set `decision_tree_requested=true` without removing meaningful topic words unless the phrase is only an instruction.
- If the remaining text looks like file path(s), read and analyze them first. If a path cannot be read, report the exact path and ask (via AskUserQuestion) whether to treat the input as a free-text topic instead of proceeding on a missing artifact.
- If it is free text, use it as the topic description.
- If it is empty, ask the user what they want to explore using AskUserQuestion.

If `UBIQUITOUS_LANGUAGE.md` exists at the project root, read it before framing and use its canonical terms throughout the interview and plan. If the user uses a term that conflicts with the glossary, ask one targeted question to resolve the conflict. If the file does not exist, proceed silently.

Use **Decision-Tree mode** when `decision_tree_requested=true`; otherwise use the default topic-classified coverage flow. Read `references/decision-tree-mode.md` only when Decision-Tree mode is active.

## Step 1: Autonomous Framing

Before starting the interview, write down a working hypothesis for:

- Who the user or stakeholder is
- What job they are trying to get done
- Why this matters now
- What is likely out of scope or intentionally deprioritized

Treat these as assumptions to validate, not excuses to ask generic setup questions.

**Frame the underlying problem, not the proposed solution.** When the input includes a proposed approach ("let's add X", "we should switch to Y"), separate the problem the proposal is meant to solve from the proposal itself. The proposal may be correct, but the framing — and any research in Phase R — must be about the problem so that alternatives stay visible.

If the hypothesis doesn't seem to match the user's framing, emit `CONFUSION:` and ask a clarifying question before continuing.

## Step 2: Topic Classification

After drafting the working hypothesis, classify the topic into one of these categories:

| Type | Indicators | Focus Areas |
| --- | --- | --- |
| **Software Feature** | New functionality, UI changes, API additions | Architecture, data model, UX flows, integration |
| **Process/Workflow** | Team processes, approval flows, automation | Steps, roles, triggers, exceptions, tooling |
| **Architecture Decision** | Technology choice, pattern selection, migration | Options, tradeoffs, constraints, reversibility |
| **Documentation/Proposal** | RFC, design doc, specification review | Gaps, clarity, feasibility, actionability |

Use AskUserQuestion to confirm the topic type if unclear.

Treat this classification as provisional whenever Phase 0 may still run. If Phase 0 changes the framing or turns a vague topic into a different kind of concrete ask, repeat Step 2 on the chosen framing before starting Step 3. The final topic type controls the interview dimensions, coverage labels, and template selection in Step 5.

## Phase 0: Divergent (Optional)

Run Phase 0 **only** when one of the following is true:

- The user passed `--ideate` in `$ARGUMENTS`.
- The framing is **vague** — it names an area but not a concrete ask. Heuristics: "improve X", "do something about Y", "help me think through Z", or a topic that can't be mapped to a specific outcome after Step 1 framing.

If the framing is concrete (e.g., "Add email-based 2FA to the login flow") and the user did **not** pass `--ideate`, **skip Phase 0** and proceed to Step 3. If the user explicitly passed `--ideate`, treat that as an intentional request to explore alternatives first and run Phase 0 anyway.

### Entry notice

When Phase 0 is triggered by auto-detection (not by `--ideate`), display a one-line notice and then pause for an explicit user choice before running it:

```text
CONFUSION: The framing is broad. Running a short divergent pass (7 variation lenses, 3 stress-test axes) before the interview. Skip with "just interview me".
```

Immediately follow that notice with AskUserQuestion using two options:

- `Run divergent pass` — continue with Phase 0
- `Just interview me` — skip Phase 0 and proceed with the current framing

Do not start generating variations until the user has answered. If they pick "Just interview me" (or respond with equivalent free text), skip Phase 0 and proceed with the current framing.

### Generate, converge, and pick a framing

Read `references/variation-lenses.md` and follow it to generate 5–8 candidate variations (4–7 lenses), converge with the three stress-test axes, and run the convergence protocol. When presenting the strongest variations via AskUserQuestion, reserve one option slot for `None of these — let's iterate.` and keep the total within AskUserQuestion's 2-4 option limit. Emit the `FRAMING:` marker on the chosen framing. If the user keeps rejecting candidates, fall back to the original framing and proceed.

Then feed the chosen framing into Step 2 and reclassify before Step 3. If the topic type changes, tell the user which type is now in force before you continue.

## Phase R: Research Pre-pass (Optional)

Run Phase R when **either** is true:

- The user passed `--research` in `$ARGUMENTS`.
- The framing names an **external library, framework, vendor service, or cross-cutting concern** (auth, observability, schema migration, deployment, performance) whose details the codebase or docs likely already answer. Heuristic: if you'd otherwise ask the user a question whose answer is sitting in the repo or in the framework's docs, run research first.

If the framing is purely about priorities, ownership, or business context — answers only the user can give — **skip Phase R**. Research can't replace human input on those.

### Entry notice

When Phase R is auto-triggered (not by `--research`), display a one-line notice and pause for an explicit choice via AskUserQuestion:

```text
The framing names {library / framework / cross-cutting concern}. Running parallel research agents (codebase + docs) before the interview will let questions skip what's already answered. Skip with "just interview me".
```

Two options: `Run research pre-pass` or `Just interview me`. Do not launch agents until the user has answered.

### Launch parallel agents

Read `references/research-agents.md` for the per-classification agent prompt templates. Pick the agent set matching the topic type from Step 2:

- **Software Feature** → Codebase + Docs + UX agents
- **Architecture Decision** → Codebase + Docs + Dependencies agents
- **Process/Workflow** → Codebase agent only
- **Documentation/Proposal** → Codebase + Docs agents

Spawn them via the Task tool with `subagent_type: Explore` (or `general-purpose` when the agent needs WebSearch / WebFetch / Context7 MCP). Each agent's prompt comes from the reference file.

**Research the problem, not the proposal.** If the input includes a proposed solution, every agent should investigate the underlying problem independently before evaluating the proposal.

Each agent must return: what it found, where it found it (file paths or URLs), and key snippets.

### Post-research check-in

After agents return, summarize the key finding in 2-3 sentences and surface anything that:

- contradicts the working hypothesis from Step 1
- materially shifts the topic type from Step 2
- shows the proposed solution is unnecessary, more complex than needed, or solves the wrong problem

Use AskUserQuestion to present a specific choice about how to proceed — not a generic "does this make sense?". Examples:

- "Codebase already has `useDebouncedSearch` doing 80% of this. Do you want to extend it, or build separately?"
- "Tanstack Query v5 deprecated the API the proposal uses. Switch to suspense queries, or pin to v4?"

If the research surfaces nothing surprising, name that briefly and proceed. If it changes the framing or classification, repeat Step 2 before Step 3.

If an agent fails or returns no usable findings, do not block the interview: name which coverage area is therefore still user-answered (rather than research-answered) and continue. Never present a failed agent's absence as a confirmed finding.

### Pass research findings into the interview

Carry research findings forward as context for Step 3. Apply the existing **Codebase-as-Answer-Source Rule** more aggressively now: any question whose answer is in the research output should be presented as `"Research found {finding} at {path}. Confirm or correct?"` instead of asked open-ended.

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

**Avoid obvious questions.** Never ask "What is the feature?" or "Why do you want this?" If the artifact or codebase already answers a question, do not ask it again. Explore first, present the inferred answer with the source, and ask only for confirmation or correction.

If a dimension requires information the artifact doesn't contain and the user hasn't provided, emit `MISSING REQUIREMENT:` before asking the user to fill the gap.

### Codebase-as-Answer-Source Rule

Before each question in either coverage or decision-tree mode, decide whether the workspace, provided files, or existing docs can answer it.

- Explore instead of asking when the answer is discoverable.
- Ask only for confirmation or correction if the source is stale, ambiguous, or incomplete.
- Skip exploration when the question is about priorities, appetite, ownership, or other context only the user can provide.

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

### Mode Selection

Use the default coverage rounds unless `decision_tree_requested=true`.

In **Decision-Tree mode**, read `references/decision-tree-mode.md`, identify the root decision for the topic type, map first-level dependencies, and resolve branches depth-first. Ask one question at a time by default; batch only routine independent sibling questions. When the active tree is resolved, return to coverage rounds for any remaining question dimensions that are independent of the decisions already settled.

### Round Structure

Ask **1-4 questions per round** using AskUserQuestion. Mix questions across different dimensions.

For high-stakes or dependency-shaping decisions, ask one question in the round. Apply the Codebase-as-Answer-Source Rule before every question.

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

**Don't just check boxes** — the goal is understanding, not coverage. If the remaining gaps are low-value or implementation-level only, stop the interview and move to synthesis.

### ADR-Offer Hook

After each resolved decision, offer `/kramme:docs:adr` only when all three criteria are true:

1. The decision is hard to reverse.
2. It would be surprising later without context.
3. It came from a real tradeoff, not a default.

Prompt once and state the three criteria inline. Do not author the ADR inside this skill.

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

**Documentation/Proposal:**

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

Suggest a filename based on the topic, e.g., `user-auth-redesign-plan.md` or `deployment-process-plan.md`. Ask user for preferred location. Before writing, check whether the target path already exists; if it does, confirm overwrite or pick a new name via AskUserQuestion rather than clobbering a prior plan silently.

### Template Selection

Pick the template matching the final topic type in force after Step 2 and any Phase 0 or Phase R reclassification:

| Topic Type             | Template File                     |
| ---------------------- | --------------------------------- |
| Software Feature       | `assets/template-feature.md`      |
| Process/Workflow       | `assets/template-process.md`      |
| Architecture Decision  | `assets/template-architecture.md` |
| Documentation/Proposal | `assets/template-doc-review.md`   |

Read the matching template, fill in the interview findings, and write the populated result to the user-chosen location. Emit `PLAN:` as the hand-off label:

```text
PLAN: Written to {path}. Ready for review.
```

If a required section cannot be filled because the interview didn't cover it, leave the placeholder in place and add `MISSING REQUIREMENT: {dimension}` above it so the gap is explicit.

### Optional plan-mode handoff

When the host runtime supports it (Claude Code) and the user wants to move directly into implementation planning, offer to call `EnterPlanMode` so the synthesized plan becomes the seed of an interactive plan. Ask once via AskUserQuestion (`Enter plan mode now` / `Stop here, I'll review first`) — don't auto-trigger. If the runtime doesn't expose `EnterPlanMode`, skip this step silently.

## Important Guidelines

1. **Craft real alternatives** - Every option should be a legitimate choice someone might make
2. **Listen for implicit concerns** - Users often hint at worries; probe deeper
3. **Connect answers** - Show how different decisions interact
4. **Challenge diplomatically** - "Have you considered X?" not "X is wrong"
5. **Depth over breadth** - Better to deeply explore key areas than superficially cover everything

## Epilogue

### Common Rationalizations

- _"The topic is already clear enough to skip Phase 0."_ — Sometimes true. But if you can't state the concrete outcome in one sentence, the framing is vague and Phase 0 will save rounds.
- _"The user will correct me if I'm wrong."_ — They often won't, because they don't know what they don't know. Use `CONFUSION:` to surface mismatches early.
- _"Coverage at 80% across all dimensions means I'm done."_ — Coverage is a proxy, not a goal. Stop when no major unknowns remain, even if a dimension sits at 60%.
- _"The template handles all topic types, so classification doesn't matter."_ — It does. The template shapes what questions to ask; picking the wrong one produces a flabby plan.

### Red Flags

- Asking a question whose answer is already in the artifact. Stop and re-read the artifact.
- Generating a plan before the user has confirmed the classification or chosen a Phase 0 framing.
- Auto-running Phase 0 on a concrete topic the user already scoped when `--ideate` was not requested. Skip it.
- Auto-running Phase R on a pure-priorities or business-context topic where research can't help. Skip it.
- Letting Phase R findings sit unread because they don't fit the original hypothesis. Surface contradictions before the interview, not after.
- Filling in a plan section from assumption rather than interview data. Emit `MISSING REQUIREMENT:` instead.
- Letting a Phase 0 framing change stand without reclassifying the topic type and template choice.
- The interview drifts into implementation minutiae before the problem statement is settled.

### Verification

Before writing the plan, confirm:

- [ ] The working hypothesis from Step 1 has been either validated or explicitly corrected during the interview.
- [ ] The topic type from Step 2 matches what the user actually cares about (not what the artifact happens to contain), and was reclassified if Phase 0 or Phase R changed the framing.
- [ ] If Phase 0 ran, the chosen framing was restated as a concrete problem statement and the user confirmed it.
- [ ] If Phase 0 was auto-triggered, the user was given an explicit skip-or-continue choice before variations were generated.
- [ ] If Phase R ran, the post-research check-in surfaced any contradictions before the interview began, and the chosen template's `Sources` section is populated with the file paths and URLs each agent returned.
- [ ] Every dimension either has interview-grounded content or an explicit `MISSING REQUIREMENT:` marker.
- [ ] If the chosen template includes a non-goals section, each entry includes a rationale instead of a bare placeholder.
- [ ] If the chosen template has a `Risks & Mitigations` (or equivalent) section, each risk is concrete (e.g., "this adds an N+1 query on every page load") rather than vague ("this could be slow").
- [ ] The `PLAN:` marker is present at hand-off.
