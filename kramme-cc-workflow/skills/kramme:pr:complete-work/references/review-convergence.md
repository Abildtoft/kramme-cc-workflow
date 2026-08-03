# Quality-Loop Convergence Policy

Apply this policy after the caller has committed the prepared implementation and before final verification. Preserve every delegated gate's scope, evidence, relevance, and reporting rules.

## Finding Terms and Budget

- **Emitted**: returned by the latest gate before parent triage.
- **Accepted**: evidence is valid, branch-caused, in scope, and worth changing or escalating.
- **Rejected**: disproved, pre-existing/out of scope, speculative without a concrete failure path, or harmful/inconsistent with repository practice.
- **Blocked**: accepted but needs a genuinely unavailable decision, approval, owner, service, or external access.
- **Active**: accepted and neither fixed nor already presented as a blocker.
- **Remediation cycle**: one parent-owned review-triggered edit batch, focused verification, commit, and ordered review rerun. Multiple coherent findings or refactor slices in one gate pass consume one cycle.

Initialize `MAX_AUTOMATIC_REMEDIATION_CYCLES=3` and one ledger for the whole loop. The initial read-only pass consumes no cycle. Delegated gates never own a nested edit/rerun counter.

“Zero active findings” means zero accepted unresolved findings after evidence-based triage, not editing until subjective advice disappears.

## Artifact Isolation

Use the fixed caller archive `.context/{archive-key}/reviews/`, created and ignore-checked by the parent.

Before every unified-scope collection, require:

```bash
git check-ignore -q -- .context/{archive-key}/reviews/
```

Move file-backed results named `REVIEW_OVERVIEW.md`, `CONVENTION_REVIEW_OVERVIEW.md`, and `REFACTOR_OPPORTUNITIES_OVERVIEW.md` into that directory after consuming them and before focused verification or another review. Replace the matching archived file on rerun. Apply the same rule to resolver output.

Never leave generated review output in the project root while a gate or verification command collects committed, staged, unstaged, and untracked branch scope.

## Remediation Commit Boundary

After accepted review work changes source, tests, configuration, or documentation:

1. Isolate generated reports.
2. Run the smallest focused verification covering the changed behavior.
3. Classify `git status --porcelain`. Continue only when every non-ignored path is an in-scope remediation change owned by this invocation. When `PLAN_SCOPE_ACTIVE=true`, require exact equality with one `VALIDATED_SCOPE_PATHS` entry for `PLAN_SCOPE_MODE=exact-files`, and otherwise allow exact path or directory containment; never widen the list from reviewer output.
4. If a delegated refactor already returned a verified commit and the worktree is clean, validate and record that commit. Otherwise, run `RECHECK_STANDALONE_SCOPE` when `PLAN_SCOPE_ACTIVE=true` and `PLAN_SCOPE_MODE=exact-files`, then stage only classified paths through quoted argv with `git add -- <validated path array>`. Never render plan paths into command text.
5. Commit the verified batch with a plain-English message containing `{work-id}`.
6. If hooks change content, rerun focused verification.

The committed tree must be the tree that passed focused verification. Do not assume a reviewer, resolver, or verification skill committed edits unless it returned commit identity and verification evidence.

## Applicability Evaluation

At the start of every round, build `ACTIVE_QUALITY_GATES` and `SKIPPED_QUALITY_GATES` from the unified branch scope. Record an evidence-based reason for each skip and report:

```text
Quality gates:
- Regular code review: run|skip — {reason}
- Convention review: run|skip — {reason}
- PR-scoped refactor discovery: run|skip — {reason}
```

### Regular Code Review

Activate for executable source, tests, schemas, public contracts, runtime/build configuration, scripts, behavior-bearing instructions, or a claimed bug fix, feature, migration, security, performance, or error-handling change.

Skip only when the complete scope is non-behavioral prose, static metadata, or generated churn with no contract, instruction, release, or verification claim. When uncertain, run it.

### Convention Review

Activate when the diff materially changes dependencies, modules, placement, public types, schemas, architectural boundaries, helpers, wrappers, abstractions, configuration layers, result/error/loading patterns, validation, retries, fallbacks, logging, feature flags, build/test conventions, or any pattern whose precedent matters.

Skip generated-only work, pure copy edits, fixture/data refreshes, or mechanical changes with no pattern choice. Small size alone is not a skip reason.

### PR-Scoped Refactor Discovery

Activate when the diff changes logic, control flow, state/data transformation, module structure, abstractions, duplication, type invariants, error handling, or performance-sensitive code, or when another gate identifies accidental complexity.

Skip docs/copy/metadata/generated-only changes, fixture refreshes, lock churn, or a narrow mechanical fix already demonstrated to be simple.

`--strict` changes finding disposition, not gate applicability.

## Ordered Gates

### Gate 1: Regular Code Review

Invoke `kramme:pr:code-review --parallel --inline`.

- Standard mode: fix every accepted actionable Critical or Important finding; report manual and advisory findings.
- Strict mode: disposition every emitted finding.

When accepted work changes code, group a coherent batch, consume one cycle, use `kramme:pr:resolve-review` when its structured flow fits or make the smallest direct fix, cross the remediation commit boundary, and restart with applicability then Gate 1. Do not continue to Gate 2 in a code-changing round.

### Gate 2: Convention Review

Invoke `kramme:pr:convention-review --inline`. Require documented-rule or peer-exemplar evidence, refutation of Critical/Important candidates, and branch relevance. Split-practice observations are not violations.

- Standard mode: fix accepted Critical or Important findings; report Suggestions.
- Strict mode: disposition every active finding.

After any fix, cross the remediation commit boundary and restart with applicability then Gate 1.

### Gate 3: PR-Scoped Refactor Discovery

Invoke `kramme:code:refactor-opportunities pr`. Require its PR-relevance gate so pre-existing debt stays observational.

- Standard mode: keep valid opportunities advisory and report the recommended first refactor.
- Strict mode: apply `kramme:code:refactor-pass` only to accepted, narrow, behavior-preserving opportunities. Apply Chesterton's Fence, keep tests unmodified by the refactor itself, verify each slice, and commit it. All slices accepted in one pass consume one parent cycle.
- Reject subjective renames, speculative improvements, behavior changes, or findings without branch relevance.
- Defer themes over 500 lines or work whose main blast radius falls outside the prepared work item.

After any accepted refactor, cross the remediation commit boundary and restart with applicability then Gate 1.

## Completion Rules

Standard mode completes only when:

1. Every applicable gate ran in order.
2. No accepted actionable Critical or Important regular or convention finding remains.
3. The refactor report is current when applicable and its remaining opportunities are advisory.
4. Every skipped gate has current evidence.
5. No required coverage is degraded.

Describe this as “zero accepted unresolved Critical/Important findings,” not “zero findings.”

Strict mode requires each emitted finding to receive one evidence-based disposition:

- `fixed`
- `rejected`
- `deferred` with concrete out-of-scope follow-up
- `blocked` with the exact missing input

Implement advisory work only when one in-scope resolution is clearly better and its value exceeds churn. Strict mode requires disposition, not blind compliance.

For manual findings, use the prepared work item, specs or plans, referenced contracts, tests, and strong local precedent. Ask for a decision when product behavior, public API, security posture, migration semantics, release policy, cross-team ownership, external state, or access remains genuinely unresolved. Neither `--strict` nor `--ship` permits guessing.

## Rerun and Diminishing-Returns Rules

- Any gate-triggered source change consumes one cycle and restarts at applicability followed by Gate 1.
- No-change rounds apply the selected completion rule; do not rerun merely to silence repeated rejected advice.
- Re-evaluate a rejected finding only when new evidence or code changes its root cause.

Fingerprint accepted findings by gate, concrete location/review scope, and root cause. After each cycle, record gates run; fingerprints before/after; counts added, fixed, reopened, rejected, deferred, and blocked; verification; and production boundaries changed.

Use a comparison-only debt score: Critical `8`, Important `4`, Suggestion/refactor `1`, FYI `0.25`. Material progress lowers the score by at least `1`, lowers highest severity, clears verification, or removes a shared root cause without an equal-or-higher regression.

Stop automatic remediation when:

1. The same accepted finding survives two attempted fixes without new direction.
2. Two consecutive cycles make no material progress.
3. The shared counter reaches three.

Stop earlier when remaining benefit is lower than churn or regression risk.

### Bounded Stop

If a stop fires after code changed since the latest complete ordered pass, run exactly one validation-only round. Re-evaluate applicability and run active gates in regular-review, convention-review, refactor order without edits. Do not run a second validation-only round.

- Defer optional Suggestions, FYIs, and narrow refactors with fingerprint, benefit, change amplification, and follow-up scope.
- If an accepted Critical/Important finding, verification failure, or genuine blocker remains, stop before final verification, history rewriting, push, or Pull Request creation.
- If no required finding remains, continue to final verification and report `diminishing returns`.

Explicit approval to resume creates a new three-cycle budget only for the reported required fingerprints and consequences of their fixes.

## Return Contract

Before returning, require:

- the selected mode's completion rule is met;
- no accepted required or blocked finding remains;
- no source changed after focused verification;
- every edit batch crossed the commit boundary;
- when `PLAN_SCOPE_ACTIVE=true`, every dirty, staged, and committed remediation path satisfied `PLAN_SCOPE_MODE`, standalone eligibility was rechecked before each staging boundary, and the final committed path set from `{scope-base-commit}` was revalidated before success;
- every generated report is in `.context/{archive-key}/reviews/`;
- the archive remains gitignored;
- applicable gates ran in order and skipped gates have evidence; and
- required coverage is not degraded.

Return stop reason (`converged` or `diminishing returns`), cycles used, debt trend, active/skipped gates, and fixed/rejected/deferred/blocked counts.
