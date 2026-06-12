# Question Mechanics and Dimensions

Mid-interview reference for Step 3 (Interview Approach) and Step 4 (Interview Execution): how to structure AskUserQuestion calls, the context pattern every question needs, and the per-topic-type dimension catalogs that drive coverage tracking.

## Using AskUserQuestion Correctly

The AskUserQuestion tool requires **2-4 predefined options** per question. Users can always select "Other" to provide free-text input.

**Tool structure:**

- `header`: Short label (max 12 chars) shown as chip/tag, e.g., "Error handling"
- `question`: The full question text
- `options`: 2-4 choices, each with `label` (short) and `description` (explains tradeoff)
- `multiSelect`: Set `true` when choices aren't mutually exclusive

## Question Context Pattern

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

## Question Dimensions by Topic Type

### For Software Features

- **User / Why Now**: target user, job-to-be-done, urgency, business value
- **Architecture**: Component boundaries, data flow, state ownership
- **Data Model**: Entities, relationships, constraints, migrations
- **API Design**: Endpoints, payloads, versioning, error responses
- **User Experience**: Flows, edge cases, loading states, error recovery
- **Integration**: Existing features affected, backward compatibility
- **Performance**: Scale expectations, caching needs, async operations
- **Security**: Authentication, authorization, data sensitivity
- **Non-Goals**: deferred work, excluded edge cases, follow-up issues, and why each is excluded

### For Process/Workflow

- **User / Why Now**: who is blocked today, urgency, business reason
- **Triggers**: What initiates the process, frequency, urgency
- **Steps**: Sequence, parallelism, dependencies
- **Roles**: Who does what, handoffs, approvals
- **Exceptions**: What can go wrong, escalation paths
- **Tooling**: Systems involved, automation opportunities
- **Metrics**: Success criteria, monitoring needs
- **Non-Goals**: what process complexity should stay out of scope for now, and why

### For Architecture Decisions

- **Decision Ownership**: what is a product/business decision vs architecture decision
- **Options**: What alternatives exist, pros/cons of each
- **Constraints**: Non-negotiables, deadlines, budget
- **Tradeoffs**: What you gain/lose with each option
- **Reversibility**: How hard to change course later
- **Migration**: Path from current to target state
- **Risk**: What could go wrong, mitigation strategies

### For Documentation/Proposal

- **Clarity**: What's ambiguous or underspecified
- **Completeness**: What's missing that should be addressed
- **Feasibility**: What seems unrealistic or risky
- **Actionability**: Can someone implement this as-is?
- **Assumptions**: What's implied but not stated
