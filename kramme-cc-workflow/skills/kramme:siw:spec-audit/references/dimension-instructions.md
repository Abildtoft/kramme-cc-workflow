# Spec Audit Dimension Instructions

Include the relevant blocks below in each Explore agent's prompt based on its assigned dimensions.

---

## Dimension: Coherence

Check for:

1. **Contradictions between sections.** Does one section say X while another says not-X? Check naming, behaviors, data types, constraints.

2. **Terminology consistency.** Does the spec use the same term for the same concept throughout? Does it switch between names for the same entity?

3. **Cross-reference accuracy.** Do internal references (to other sections, tasks, specs) point to things that actually exist? Are task numbers consistent?

4. **Design decision alignment.** Do design decisions in one section conflict with requirements in another?

5. **Scope consistency.** Does the in-scope section align with what the tasks actually cover? Are out-of-scope items accidentally included in tasks?

**Severity guide:**

- Critical: Direct contradiction between requirements
- Major: Terminology inconsistency that could cause confusion during implementation
- Minor: Cosmetic inconsistencies (formatting, numbering)

---

## Dimension: Completeness

Check for:

1. **Missing sections.** A well-structured spec should have: overview/objectives, scope and audience, success criteria, requirements and constraints, design decisions, implementation tasks, testing/verification checklist, edge cases, and out-of-scope declarations. Which are absent or empty?

2. **Incomplete requirements.** Are there requirements that mention a concept but don't define it? Vague references to "appropriate handling" or "as needed"?

3. **Missing edge cases.** For each requirement, are error scenarios and boundary conditions addressed? What happens on failure?

4. **Missing acceptance criteria.** Do tasks have verifiable completion criteria? Can someone objectively determine if a task is done?

5. **Gaps between tasks.** Are there logical gaps where one task ends and another begins? Would something fall through the cracks?

6. **Missing dependencies.** Are cross-task or external dependencies identified?

7. **Missing non-functional requirements.** Performance, security, accessibility, backwards compatibility — are relevant ones addressed?

**Severity guide:**

- Critical: Missing core requirements, entire undefined subsystems
- Major: Missing edge cases for important flows, missing acceptance criteria on complex tasks
- Minor: Missing nice-to-have sections, minor gaps in coverage

---

## Dimension: Clarity

Check for:

1. **Ambiguous requirements.** Phrases like "should handle appropriately", "user-friendly", "fast enough", "as needed" — anything that two developers could interpret differently.

2. **Missing specifics.** Requirements that describe WHAT but not HOW MUCH, WHEN, or UNDER WHAT CONDITIONS. Missing sizes, limits, timeouts, thresholds.

3. **Undefined terms.** Technical terms, acronyms, or domain concepts used without definition.

4. **Passive voice hiding responsibility.** "The data will be processed" — by whom? By what component?

5. **Weasel words.** "Etc.", "and so on", "similar to", "like", "various", "appropriate" — these hide missing detail.

6. **Implicit knowledge.** Requirements that assume knowledge not documented in the spec.

7. **Conflicting levels of detail.** Some sections highly detailed while others are hand-wavy.

**Severity guide:**

- Critical: Ambiguity that blocks implementation (can't start without guessing)
- Major: Ambiguity that risks wrong implementation
- Minor: Cosmetic confusion, minor vagueness in non-critical areas

---

## Dimension: Scope

Check for:

1. **Missing scope boundaries.** Is there an explicit in-scope/out-of-scope section?

2. **Scope creep indicators.** Tasks or requirements that seem to go beyond the stated objectives. Features mentioned in passing that aren't in the task list.

3. **Implicit inclusions.** Things not explicitly listed as in-scope but required for the stated goals to work.

4. **Missing out-of-scope declarations.** Related features or improvements that are NOT being addressed — are they explicitly excluded?

5. **Phase boundary clarity.** If the spec has phases, are phase boundaries clear? Could a task leak from one phase to another?

6. **Task-to-objective alignment.** Do the defined tasks collectively achieve the stated objectives? Are there objectives with no corresponding tasks?

**Severity guide:**

- Critical: No scope definition at all, objectives don't match tasks
- Major: Implicit inclusions that could derail timeline, unclear phase boundaries
- Minor: Missing out-of-scope declarations for unlikely features

---

## Dimension: Actionability

Check for:

1. **Non-actionable tasks.** Tasks that describe outcomes but not concrete steps. "Make the system fast" vs "Reduce API response time to under 200ms".

2. **Missing file/component references.** Tasks without clear indication of WHERE changes need to happen.

3. **Tasks that are too large.** Single tasks covering multiple unrelated changes that should be subdivided.

4. **Tasks that are too granular.** Micro-tasks that could be combined. Tasks with no meaningful independent value.

5. **Missing acceptance criteria per task.** Each task should have testable criteria. Can an implementor know when they're done?

6. **Self-containedness.** Can each task be understood without reading all other tasks? Does it have enough context to be picked up independently?

7. **Ordering and dependency clarity.** Is it clear which tasks must be done before others? Are blocking dependencies explicit?

**Severity guide:**

- Critical: Tasks so vague they can't be started
- Major: Missing acceptance criteria, tasks too large to estimate
- Minor: Minor dependency gaps, slightly over-granular tasks

---

## Dimension: Testability

Check for:

1. **Unmeasurable success criteria.** Success criteria that can't be objectively verified. "System should be intuitive" vs "User can complete task X in under 3 clicks".

2. **Missing verification methods.** Requirements without any indication of how to verify them.

3. **Subjective acceptance criteria.** Criteria that require judgment calls. "Clean code", "good performance", "well-documented".

4. **Missing error/failure test cases.** Happy path covered but no mention of what failure looks like or how to test error handling.

5. **Missing data requirements for testing.** Test scenarios that need specific data states or configurations but don't define them.

6. **Unverifiable constraints.** Non-functional requirements without specific thresholds or test methods.

**Severity guide:**

- Critical: Core success criteria that can't be verified
- Major: Important requirements with no way to test
- Minor: Nice-to-have verifications, minor subjective criteria

---

## Dimension: Rationale Documentation

Assess whether the specification records enough product rationale to guide implementation. Evaluate the presence, clarity, and internal consistency of that rationale only. Do not judge whether the product is worth building, whether the chosen solution is the best one, or whether prioritization and strategy are correct; those questions belong to `/kramme:siw:product-audit`.

Check for:

1. **Missing or unclear problem statement.** Does the spec explicitly state the problem that its requirements are intended to address? Are assumptions labeled as assumptions instead of presented as validated facts?

2. **Missing beneficiary or stakeholder identification.** Does the spec state who benefits from the work and who is affected, clearly enough to interpret requirements and tradeoffs?

3. **Undocumented decision rationale.** Does the spec record why its chosen approach was selected and note materially relevant alternatives or constraints? Check whether the rationale exists and is understandable; do not substitute a different product decision.

4. **Missing intended outcomes.** Does the spec connect its requirements and success criteria to stated outcomes or metrics, so implementers understand what the work is meant to achieve?

5. **Missing priority or timing context.** When sequencing or tradeoffs depend on urgency, does the spec explain why the work matters now?

6. **Rationale inconsistencies.** Do the stated problem, beneficiaries, outcomes, constraints, and selected approach agree with one another? Flag contradictions or gaps that would force implementation choices to rely on guessed intent.

**Severity guide:**

- Critical: Missing or contradictory rationale leaves the intended behavior or a core implementation tradeoff unknowable
- Major: A key problem, beneficiary, outcome, constraint, or decision rationale is absent or ambiguous enough that implementers must infer intent
- Minor: Non-critical context or traceability is incomplete but implementation intent remains clear

---

## Dimension: Technical Design

**Note:** This dimension requires domain judgment. Mark fix confidence on all findings (0-100) — score how deterministic a fix would be using four conditions: determinism of fix, information availability in spec, meaning preservation, absence of alternatives. Technical Design findings typically score lower due to subjectivity.

Check for:

1. **Data model soundness.** Are entities well-defined? Are relationships between entities clear (one-to-many, many-to-many)? Are there normalization issues? Are constraints (required fields, uniqueness, valid ranges) specified?

2. **API contract completeness.** Are request/response shapes fully defined? Are error responses specified? Are authentication/authorization requirements clear? Are HTTP methods and status codes appropriate?

3. **Architecture fit.** Are the chosen patterns appropriate for the problem? Are there known anti-patterns? Are component boundaries and responsibilities clear? Are integration points between components defined?

4. **Scalability considerations.** Will the design handle expected load? Are pagination, caching, and rate limiting addressed where needed? Are there N+1 query risks or unbounded result sets?

5. **Security surface.** Are authentication and authorization flows defined? Is sensitive data handling specified? Are input validation boundaries clear? Are there data exposure risks?

6. **Technology choice justification.** Are technology selections explained? Are there known limitations that affect the design?

**Severity guide:**

- Critical: Fundamental design flaws (circular dependencies, missing entities for core flows, no auth on sensitive endpoints)
- Major: Design gaps that will require rework (missing error contracts, unclear component boundaries, scalability blind spots)
- Minor: Suboptimal choices, missing non-critical constraints
