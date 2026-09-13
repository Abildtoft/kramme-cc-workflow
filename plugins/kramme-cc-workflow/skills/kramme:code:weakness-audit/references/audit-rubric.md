# Weakness Audit Rubric

Use this rubric to turn raw observations into ranked, evidence-backed findings.

## Evidence Standards

A finding is ready only when it has:

- a concrete file and line range, or a small set of related locations
- a root cause that explains why the weakness exists
- evidence from code structure, tests, runtime boundaries, git history, docs, or project conventions
- a likely impact on maintainability, readability, correctness, or a mix of those
- a smallest useful first fix and a validation check

Do not record:

- preferences that merely differ from the agent's taste
- broad framework advice without local evidence
- one-off naming comments that do not change comprehension
- test-gap claims without an important behavior, invariant, or regression path
- architecture objections that contradict accepted ADRs without new evidence

## Lens-Specific Signals

### Maintainability

Strong signals:

- changes to one concept require edits across many unrelated files
- core behavior is split across modules with unclear ownership
- dependency cycles, deep import chains, or shared mutable state make changes fragile
- repeated logic exists in three or more meaningful places
- a file, class, or module owns unrelated responsibilities and changes frequently
- tests are hard to write because boundaries are hidden or side effects are global
- setup, scripts, or generated assets regularly obscure the real source of truth

Weak signals:

- a function is long but still linear, cohesive, and well tested
- a module is large because it is a deliberate registry or generated artifact
- a helper has one caller but carries real naming, validation, or platform-boundary value

### Readability

Strong signals:

- names contradict behavior or project domain language
- important flow requires jumping through several files with no obvious entry point
- control flow hides state transitions, error paths, or side effects
- comments are stale enough to mislead maintenance decisions
- similar concepts use inconsistent names across public surfaces
- readers cannot tell which module owns a responsibility without tracing internals

Weak signals:

- personal naming preference without ambiguity
- missing comments around straightforward code
- compact code that is idiomatic for the project and covered by tests

### Correctness

Strong signals:

- concrete input can produce wrong output, data loss, duplicate side effects, stale state, or masked failure
- boundary validation is missing where untrusted or loosely typed data enters
- invariants are implied but not enforced by types, schemas, checks, or tests
- async/concurrent flows can race, double-submit, leak state, or apply stale results
- error handling swallows failures or reports success after partial failure
- tests assert implementation details while missing the behavior that can regress

Weak signals:

- theoretical edge case with no reachable path
- defensive check that duplicates an enforced upstream framework guarantee
- missing test for code whose behavior is already covered through a stronger integration path

## Scoring Worksheet

Score each surviving candidate from 1 to 5 for each factor:

| Factor | 1 | 3 | 5 |
| --- | --- | --- | --- |
| Impact | Local inconvenience | Slows common work or can cause minor bugs | Can break important behavior, data integrity, or major change work |
| Breadth | One isolated location | Several related files or one important module | Cross-cutting pattern, core flow, or repeated system-wide friction |
| Confidence | Plausible but lightly evidenced | Clear code evidence and likely impact | Proven failure path, repeated evidence, or corroborating tests/history |
| Urgency | Can wait indefinitely | Worth scheduling in normal maintenance | Blocks confident change, release, migration, or debugging |
| Leverage | Fix is local cleanup | Fix reduces future risk in an area | Fix unlocks simpler work across multiple areas |
| Effort | Large redesign | Moderate refactor | Small targeted change |

Compute priority:

```text
priority_score = (impact * 3) + (confidence * 2) + breadth + urgency + leverage + effort
```

Use the score for sorting, not as a substitute for judgment. A lower-scoring correctness issue with a concrete failure path may outrank a broad maintainability issue.

## Severity Mapping

- **Critical**: impact 5 and confidence at least 4, especially correctness or data integrity.
- **High**: priority score at least 35, or impact 4+ with confidence 4+.
- **Medium**: priority score 25-34 with concrete evidence and a useful fix.
- **Low**: below 25. Usually exclude from the ranked findings and mention only as a follow-up candidate.

## Report Quality Bar

Before writing the report, verify:

- Every active finding has evidence and a line location.
- Every correctness finding names the failure path or invariant.
- Every maintainability finding names the future-change cost.
- Every readability finding names the likely misunderstanding.
- The top findings are genuinely more important than the filtered candidates.
- The recommended first action is small enough to start without a rewrite.
