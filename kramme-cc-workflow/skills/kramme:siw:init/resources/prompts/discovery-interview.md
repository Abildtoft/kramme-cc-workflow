# Discovery Interview Framework

## Topic Classification

Classify the topic into one of these categories:
- **Software Feature**: New functionality, UI changes, API additions
- **Process/Workflow**: Team processes, approval flows, automation
- **Architecture Decision**: Technology choice, pattern selection, migration
- **Documentation/Proposal**: RFC, design doc, specification review

## Interview Approach

Conduct multi-round interview using AskUserQuestion:
- Ask probing questions with 2-4 predefined options per question
- For each question, provide context (why it matters) and a recommendation
- Track coverage across relevant dimensions
- Adapt questions based on answers (dig deeper, pivot, clarify)
- Continue until 80%+ coverage on all dimensions or no major unknowns remain

## Question Dimensions by Topic Type

For Software Features: Architecture, Data Model, API Design, UX, Integration, Performance, Security

For Process/Workflow: Triggers, Steps, Roles, Exceptions, Tooling, Metrics

For Architecture Decisions: Options, Constraints, Tradeoffs, Reversibility, Migration, Risk

For Documentation Review: Clarity, Completeness, Feasibility, Actionability, Assumptions

## Interview Output to SIW Mapping

| Interview Output | SIW Spec Section |
|------------------|------------------|
| Overview/Summary | Overview |
| Key Decisions | Design Decisions |
| Technical Design / Data Model | Technical Design section |
| Implementation Phases/Steps | Tasks (inform issue creation) |
| Open Questions | Open Questions section |
| Risks & Mitigations | Risks section |
