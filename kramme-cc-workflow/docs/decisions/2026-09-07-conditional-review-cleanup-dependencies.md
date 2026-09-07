# Sequence Conditional Review Cleanup After Deletion Outcomes

- Status: ACCEPTED
- Date: 2026-09-07
- Deciders: repository maintainers

## Context

PR review can produce both a deletion recommendation and cleanup that concerns the same code. Flattening the cleanup into the deletion finding loses independent lifecycle state, while emitting both as immediately actionable asks the resolver to polish code that may disappear. The first dependency contract preserved both findings with a `Depends on` field, but it evaluated that field during pre-implementation eligibility. At that point an open deletion had no outcome, severity-filtered findings were indistinguishable from attempted failures, and Team Mode could assign the dependency and dependent to different agents. Persisted reports also need the relationship to survive inline transport, previous-review carry-forward, and explicit reopening without introducing a new status vocabulary.

## Decision

Keep conditional cleanup as a separate advisory finding with one of two exact `Depends on` conditions. The producer marks structured reports and preserves surviving dependency edges across reruns. The resolver validates one graph, removes dependents from initial candidacy, and processes each connected component sequentially in topological order after focused verification establishes the dependency outcome. Severity-filtered open dependencies leave dependents unchanged, while recorded processed outcomes may activate them. An activated fallback ignores only its dependency in the unresolved-finding gate. Explicitly reopening a deletion reopens fallback cleanup acknowledged solely because of that deletion. Team Mode excludes dependency-connected components from parallel groups.

## Consequences

- Cleanup cannot run before the deletion decision or implementation outcome it depends on.
- Local, inline, and other accepted structured code-review reports retain the same dependency semantics, while arbitrary external `Depends on` prose remains inert.
- Severity filters can split work across runs without treating an excluded open finding as a failed attempt.
- Team Mode gives up parallelism for dependency-connected findings but preserves parallel execution for independent file groups.
- The resolver must run focused verification for a dependency before evaluating its dependents, followed by its existing full affected verification gate.
- Reopening a deletion performs one explicit dependent-state transition; unrelated acknowledged findings remain terminal.

## Alternatives Considered

### Store fallback cleanup only in deletion evidence

Rejected because evidence has no independent finding ID or resolution status, so rejected or deferred deletion would strand valid cleanup.

### Evaluate dependencies entirely during action-class eligibility

Rejected because eligibility precedes implementation and validation, so it cannot distinguish eventual success, safe non-addressed disposition, or an unprocessed severity-filter exclusion.

### Add a dormant resolution status

Rejected because the existing statuses plus an explicit dependency-reopen transition express the lifecycle without expanding every producer, parser, and consumer's status vocabulary.
