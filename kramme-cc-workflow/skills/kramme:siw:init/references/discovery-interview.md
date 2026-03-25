# Discovery Interview Framework

## Topic Classification

Classify the topic into one of these categories:
- **Software Feature**: New functionality, UI changes, API additions
- **Process/Workflow**: Team processes, approval flows, automation
- **Architecture Decision**: Technology choice, pattern selection, migration
- **Documentation/Proposal**: RFC, design doc, specification review

## Autonomous Framing

Before asking anything, draft a working hypothesis for:
- Who the user or stakeholder is
- What job they are trying to get done
- Why this matters now
- What is intentionally out of scope or deferred

Treat these as assumptions to validate, not an excuse to ask generic setup questions.

## Interview Approach

Conduct multi-round interview using AskUserQuestion:
- Ask probing questions with 2-4 predefined options per question
- Only ask when meaningful uncertainty remains after reading the available context
- For each question, provide context (why it matters) and a recommendation
- Track coverage across relevant dimensions
- Adapt questions based on answers (dig deeper, pivot, clarify)
- Stop when the remaining gaps are low-value or implementation-level only
- Continue until 80%+ coverage on all dimensions or no major unknowns remain
- Ensure the interview yields enough material to fill the SIW sections for Overview, Why Now, Objectives, Out of Scope / Non-Goals, Success Criteria, Key Decisions, Decision Boundaries (when relevant), Open Questions, and Risks

## Question Dimensions by Topic Type

For Software Features: User / Why Now, Objectives / Desired Outcome, Success Criteria, Architecture, Data Model, API Design, User Experience, Integration, Performance, Security, Non-Goals, Decision Boundaries

For Process/Workflow: User / Why Now, Objectives / Desired Outcome, Success Criteria, Triggers, Steps, Roles, Exceptions, Tooling, Metrics, Non-Goals, Decision Boundaries

For Architecture Decisions: Decision Ownership, Objectives / Desired Outcome, Success Criteria, Options, Constraints, Tradeoffs, Reversibility, Migration, Risk

For Documentation Review: Why Now, Desired Outcome, Success Criteria, Clarity, Completeness, Feasibility, Actionability, Assumptions

## Interview Output to SIW Mapping

| Interview Output | SIW Spec Section |
|------------------|------------------|
| Overview/Summary | Overview |
| Why Now / urgency | Why Now |
| Objectives / desired outcome | Objectives |
| Non-Goals / deferred work | Scope > Out of Scope / Non-Goals |
| Assumptions / Inferred Context | Assumptions Used |
| Key Decisions | Design Decisions |
| Decision Boundaries | Decision Boundaries |
| Technical Design / Data Model | Technical Design section |
| Success Criteria | Success Criteria |
| Implementation Phases/Steps | Tasks (inform issue creation) |
| Open Questions | Open Questions section |
| Risks & Mitigations | Risks section |
