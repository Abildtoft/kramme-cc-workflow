# Interview Rounds

Five-round interview structure for comprehensive issue definition.

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

**Dig deeper when:**
- Scope seems too broad for a single issue
- There are natural breakpoints for phased delivery

## Round 3: Technical Context

**Questions to cover:**
- Which components/areas are affected? (informed by exploration)
- Are there dependencies or blocking issues?
- What existing patterns should be followed?
- Are there technical constraints to consider?

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

## Round 5: Metadata & Classification

**Questions to cover:**
- Which team should own this issue? (present options from Phase 2)
- What labels apply? (present options from Phase 2)
- Should this be associated with a project?
- What priority level is appropriate?
- Are there related issues (blockers, related work)?

**Use predefined options:**
- Present actual team names from `list_teams`
- Present actual labels from `list_issue_labels`
- Present active projects from `list_projects`
