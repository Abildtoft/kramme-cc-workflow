# Interview Rounds

Five-round interview structure for comprehensive issue definition. Ask every question with the structured question tool as defined in `SKILL.md`; group each round into one to two calls.

## Round 1: Problem & Value (Most Important)

**This round is critical.** Spend extra time here to deeply understand the "why."

**Questions to cover:**

- What specific problem or pain point does this solve?
- Who is affected (end users, customers, internal teams)?
- How significant is the impact? (frequency, severity, scale)
- What triggers the need for this change now?
- What happens if we don't address this? (cost of inaction)
- What value does solving this deliver? (user benefit, business outcome)
- How does this align with product/company goals?
- Which part of the problem matters most in this issue versus a later follow-up?

**Dig deep on value:**

- Don't accept vague answers like "it would be nice" or "users want it"
- Push for concrete impact: numbers, user quotes, business metrics
- Understand the opportunity cost of NOT doing this

**Context to provide:**

- Share relevant findings from codebase exploration
- Reference any related code or patterns discovered

## Round 2: Scope & Boundaries

**Questions to cover:**

- What is explicitly in scope for this issue?
- What is explicitly out of scope?
- Are there related changes that should be separate issues?
- What is the minimum viable implementation?
- Which decisions belong in this issue, and which should remain implementation details for engineering?

**Dig deeper when:**

- Scope seems too broad for a single issue
- There are natural breakpoints for phased delivery

## Round 3: Technical Context

**Questions to cover:**

- Which components/areas are affected? (informed by exploration)
- Are there dependencies or blocking issues?
- What existing patterns should be followed?
- Are there technical constraints to consider?
- Is there any missing product decision currently being pushed into technical implementation?

**Leverage exploration findings:**

- Present discovered patterns as options
- Highlight related code that should be considered
- Note any TODOs/FIXMEs that are relevant

## Round 4: Acceptance Criteria

**Questions to cover:**

- What defines "done" for this issue?
- How should this be tested/verified?
- Are there specific edge cases to handle?
- What quality criteria must be met?

**Guide toward testable criteria:**

- Each criterion should be verifiable
- Include both happy path and error scenarios
- Consider performance/security if relevant
- Prefer user-facing outcomes over implementation completion checklists

## Round 5: Metadata & Classification

**Questions to cover:**

- Which team should own this issue? (confirm the team resolved in Phase 2)
- What labels apply? (present the team's labels from Phase 2)
- Should this be associated with a project?
- What priority level is appropriate?
- Should this go into a cycle? (only when the team uses cycles; offer the current and next cycle)
- Should it be assigned now? (offer "me", leave unassigned, or a named person; default unassigned)
- Confirm the related, blocking, and blocked issues gathered in Phase 3 — these become Linear relations, not just prose

**Use predefined options:**

- Present actual team names from `list_teams`
- Present actual labels from `list_issue_labels` for the team
- Present active projects from `list_projects` and cycles from `list_cycles` for the team
- Skip cycle and assignee questions silently when the team has no cycles or the user is defining on someone else's behalf
