---
name: kramme:discovery:interview
description: Conduct an in-depth interview about a topic/proposal to uncover requirements, priorities, and non-goals, then create a comprehensive plan
argument-hint: "[file-path or topic description]"
disable-model-invocation: true
user-invocable: true
---

# Deep Exploration Interview

Conduct a structured, in-depth interview about the presented topic, files, proposal, or feature. Use the AskUserQuestion tool throughout to gather decisions and uncover requirements. Conclude by writing a comprehensive plan.

## Process Overview

1. **Initial Analysis**: Examine the topic/files/proposal presented
2. **Autonomous Framing**: Draft the likely target user, problem, why-now, and non-goals before asking questions
3. **Topic Classification**: Determine the type of exploration needed
4. **Multi-Round Interview**: Ask probing questions via AskUserQuestion only where meaningful uncertainty remains
5. **Progress Tracking**: Monitor coverage across dimensions
6. **Synthesis**: Write an adaptive plan markdown file

## Step 1: Autonomous Framing

Before starting the interview, write down a working hypothesis for:
- Who the user or stakeholder is
- What job they are trying to get done
- Why this matters now
- What is likely out of scope or intentionally deprioritized

Treat these as assumptions to validate, not excuses to ask generic setup questions.

## Step 2: Topic Classification

After drafting the working hypothesis, classify the topic into one of these categories:

| Type | Indicators | Focus Areas |
|------|------------|-------------|
| **Software Feature** | New functionality, UI changes, API additions | Architecture, data model, UX flows, integration |
| **Process/Workflow** | Team processes, approval flows, automation | Steps, roles, triggers, exceptions, tooling |
| **Architecture Decision** | Technology choice, pattern selection, migration | Options, tradeoffs, constraints, reversibility |
| **Documentation/Proposal** | RFC, design doc, specification review | Gaps, clarity, feasibility, actionability |

Use AskUserQuestion to confirm the topic type if unclear.

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
- **Non-Goals**: deferred work, excluded edge cases, follow-up issues

#### For Process/Workflow
- **User / Why Now**: who is blocked today, urgency, business reason
- **Triggers**: What initiates the process, frequency, urgency
- **Steps**: Sequence, parallelism, dependencies
- **Roles**: Who does what, handoffs, approvals
- **Exceptions**: What can go wrong, escalation paths
- **Tooling**: Systems involved, automation opportunities
- **Metrics**: Success criteria, monitoring needs
- **Non-Goals**: what process complexity should stay out of scope for now

#### For Architecture Decisions
- **Decision Ownership**: what is a product/business decision vs architecture decision
- **Options**: What alternatives exist, pros/cons of each
- **Constraints**: Non-negotiables, deadlines, budget
- **Tradeoffs**: What you gain/lose with each option
- **Reversibility**: How hard to change course later
- **Migration**: Path from current to target state
- **Risk**: What could go wrong, mitigation strategies

#### For Documentation/Proposal Review
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

### Adaptive Templates

Select the appropriate template based on topic type:

---

### Template: Software Feature

```markdown
# [Feature Name] - Implementation Plan

## Overview
Brief description of what we're building and the problem it solves.

## Why Now
Why this deserves attention now and what outcome matters.

## Non-Goals
- What this plan explicitly does not attempt in this pass

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| [Area] | [What we decided] | [Why, tradeoff accepted] |

## Technical Design

### Data Model
Entities, relationships, key fields, constraints.

### API Contracts
Endpoints, request/response shapes, error codes.

### State Management
How state flows through the application, ownership.

### Error Handling
Strategy for different error scenarios.

## User Experience

### Primary Flow
Step-by-step user journey for the main use case.

### Edge Cases & Error States
How we handle unusual scenarios and failures.

## Implementation Phases

### Phase 1: [Name]
- [ ] Task 1
- [ ] Task 2

### Phase 2: [Name]
- [ ] Task 1
- [ ] Task 2

## Testing Strategy
What needs testing, approach for each layer.

## Open Questions
Items requiring further investigation.

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
```

---

### Template: Process/Workflow

```markdown
# [Process Name] - Design Plan

## Overview
What this process accomplishes and why it's needed.

## Why Now
Why changing this process matters now.

## Non-Goals
- What process complexity or follow-on changes are explicitly deferred

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|

## Process Design

### Trigger
What initiates this process, frequency, urgency levels.

### Steps
1. **[Step Name]** - [Actor]: [Description]
2. **[Step Name]** - [Actor]: [Description]

### Roles & Responsibilities
| Role | Responsibilities | Handoff Points |
|------|------------------|----------------|

### Exception Handling
| Exception | Detection | Resolution Path |
|-----------|-----------|-----------------|

## Tooling & Automation
Systems involved, automation opportunities, integration points.

## Success Metrics
How we measure if this process is working.

## Rollout Plan
How to transition from current state.

## Open Questions
Items requiring further discussion.
```

---

### Template: Architecture Decision

```markdown
# [Decision Topic] - Architecture Decision Record

## Context
Why this decision is needed now.

## Decision Boundaries
What is being decided here, and what is intentionally left to product or implementation teams.

## Options Considered

### Option 1: [Name]
- **Pros**:
- **Cons**:
- **Effort**:
- **Reversibility**:

### Option 2: [Name]
- **Pros**:
- **Cons**:
- **Effort**:
- **Reversibility**:

## Decision
What we chose and why.

## Tradeoffs Accepted
What we're sacrificing with this choice.

## Constraints & Assumptions
Non-negotiables that shaped this decision.

## Migration Plan
How to get from current state to target.

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|

## Success Criteria
How we'll know this was the right choice.

## Review Date
When to revisit this decision.
```

---

### Template: Documentation/Proposal Review

```markdown
# [Document Name] - Review Summary

## Overview
What was reviewed and its purpose.

## Why This Matters Now
Why the document needs action now.

## Key Findings

### Strengths
What the document does well.

### Gaps
What's missing or underspecified.

### Concerns
Feasibility issues, risks, or unclear areas.

## Recommendations

### Must Address
Critical items before proceeding.

### Should Address
Important improvements.

### Nice to Have
Optional enhancements.

## Clarifying Questions
Questions the document should answer.

## Next Steps
Recommended actions with owners.
```

---

## Important Guidelines

1. **Craft real alternatives** - Every option should be a legitimate choice someone might make
2. **Listen for implicit concerns** - Users often hint at worries; probe deeper
3. **Connect answers** - Show how different decisions interact
4. **Challenge diplomatically** - "Have you considered X?" not "X is wrong"
5. **Depth over breadth** - Better to deeply explore key areas than superficially cover everything

## Starting the Interview

**Handling $ARGUMENTS:**
- `$ARGUMENTS` contains everything the user typed after `/kramme:discovery:interview`
- If it looks like file path(s): Read and analyze them first
- If it's free text: Use as the topic description
- If empty: Ask user what they want to explore using AskUserQuestion

**Process:**
1. Parse and analyze any files or context provided via $ARGUMENTS
2. Draft the autonomous framing hypotheses (target user, why-now, non-goals) before asking questions
3. Classify the topic type
4. Confirm classification with user if ambiguous
5. Ask your first round of probing questions, starting with the highest-uncertainty assumptions
