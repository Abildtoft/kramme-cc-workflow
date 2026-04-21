# <Feature name>

<One-sentence hook: what is this feature and who is it for?>

## 1. Objective

<One paragraph — the problem this feature solves and the intended outcome. Concrete, not aspirational.>

## 2. Scope & Non-goals

### In scope

- <What this feature will do.>
- <Additional in-scope item.>

### Non-goals

- <What this feature will explicitly not do, so reviewers can catch scope creep.>
- <Additional out-of-scope item.>

## 3. Boundaries

Feature-scoped rules the implementer should follow. Keep project-wide rules out of this spec.

### Always Do

- <Rule the implementer must follow for this feature.>
- <Additional Always Do rule.>

### Ask First

- <Action the implementer should pause and confirm before doing.>
- <Additional Ask First rule.>

### Never Do

- <Action that is explicitly off-limits for this feature.>
- <Additional Never Do rule.>

## 4. Testing Strategy

What gets covered and at which tier. Do not prescribe test code — name the coverage intent.

| Tier | What it covers |
|------|----------------|
| Unit | <pure-logic areas, edge cases, invariants> |
| Integration | <module boundaries, data flow, contracts> |
| E2E | <user-visible flows, critical paths> |

Mark any tier deliberately skipped with one line explaining why.

## 5. Open Questions

Unresolved items that need user input or further research before or during implementation.

- <Open question — what the question is and what blocks without an answer.>
- POTENTIAL CONCERNS: <Risk flagged for user review — what could go wrong and why it matters.>
- <Additional open question or concern.>

## 6. Success Criteria

Testable statements. If you can't write a check that confirms a criterion, it isn't a criterion.

- [ ] <Observable outcome a reviewer can verify.>
- [ ] <Additional success criterion.>
- [ ] <Additional success criterion.>

---

<!--
Notes for authors:

- Inferred claims (presumed user count, presumed API availability, presumed schema) must be prefixed inline with `UNVERIFIED:`.
- Keep each section tight — a one-page spec should be skimmable in under two minutes.
- When a Boundary rule depends on security depth beyond "Ask First", defer that depth to a dedicated security-hardening skill rather than inlining it here.
- Remove every `<...>` placeholder and this comment block before considering the spec final.
-->
