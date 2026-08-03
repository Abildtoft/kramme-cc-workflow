# Quality-Loop Convergence Policy

Use this policy after implementation and before final verification. A quality round selects applicable gates, then runs regular code review, convention review, and PR-scoped refactor discovery in that order. Preserve each delegated skill's scope, evidence, relevance, and reporting rules.

## Finding Terms

- **Emitted finding** — every finding returned by a quality gate in the latest round, before this workflow triages or dispositions it.
- **Accepted finding** — an emitted finding whose evidence is valid, PR-caused, in scope, and worth changing or escalating.
- **Rejected finding** — an emitted finding disproved by the code path, pre-existing/out of scope, speculative without a concrete failure path, or harmful/inconsistent with repository practice.
- **Blocked finding** — an accepted finding that needs a genuinely unavailable human decision, approval, owner, service, or external access.
- **Active finding** — an accepted finding that is not yet fixed or blocked on a question already presented to the user.
- **Remediation cycle** — one parent-owned review-triggered code-edit batch followed by focused verification and a review rerun. Multiple findings fixed as one coherent batch count once. One gate's accepted work consumes exactly one cycle however many findings, files, commits, or verified refactor slices it produced; a multi-slice Gate 3 refactor pass is one cycle, not one per slice. Delegated quality gates are read-only and never maintain a separate counter.

“Zero active findings” means zero accepted unresolved findings after evidence-based triage. It does not mean changing code until every subjective suggestion disappears from reviewer output.

## Quality Round

Re-evaluate applicability at the start of every round because accepted fixes can introduce or remove a gate's trigger conditions. Then run active gates in the order below. Never skip a gate merely to save time or avoid findings.

Initialize `MAX_AUTOMATIC_REMEDIATION_CYCLES=5` and one cycle ledger for the entire quality loop. Do not reset the counter between gates or delegated skills. The initial read-only gate pass does not consume a cycle; consume one whenever accepted review work changes code, then run focused verification before continuing.

### Quality-Loop Artifact Isolation

Before collecting the first quality-round scope, create `.context/linear-issue-to-pr/` and verify the exact archive path is ignored:

```bash
if ! mkdir -p .context/linear-issue-to-pr; then
  echo "MISSING REQUIREMENT: unable to create .context/linear-issue-to-pr/" >&2
  exit 1
fi

if git check-ignore -q -- .context/linear-issue-to-pr/; then
  :
else
  CHECK_IGNORE_STATUS=$?
  if [ "$CHECK_IGNORE_STATUS" -eq 1 ]; then
    echo "MISSING REQUIREMENT: .context/linear-issue-to-pr/ is not gitignored" >&2
  else
    echo "Error: git check-ignore failed while validating .context/linear-issue-to-pr/ (status $CHECK_IGNORE_STATUS)" >&2
  fi
  exit "$CHECK_IGNORE_STATUS"
fi
```

If directory creation fails, preserve that filesystem error instead of suggesting an ignore-rule change. If `git check-ignore` returns status `1`, ask for a safe ignored location or explicit permission to update the repository's ignore rules. Treat any other status as a fatal Git error and surface it unchanged. Do not assume a Conductor or installation-local exclude exists in the consumer repository.

After the check passes, use `.context/linear-issue-to-pr/` as the workflow's gitignored report archive. After consuming a file-backed gate or resolver result, move `REVIEW_OVERVIEW.md`, `CONVENTION_REVIEW_OVERVIEW.md`, and `REFACTOR_OPPORTUNITIES_OVERVIEW.md` there before focused verification or the next unified-scope collection. Replace the matching archived file when a gate reruns. Keep finding dispositions in current run state so moving a report does not lose triage state.

Never leave generated review output in the project root while another applicability check, review, refactor scan, or verification command collects changed and untracked files. Without `--ship`, retain the archive as the review-ready handoff. With `--ship`, the registered `kramme:workflow-artifacts:cleanup --auto` path retires the archive before Pull Request creation.

### Remediation Commit Boundary

After any accepted review work changes source, tests, configuration, or documentation:

1. Move generated review reports into the archive above.
2. Run the smallest focused verification that covers the changed behavior.
3. Inspect `git status --porcelain` and classify every remaining path. If a delegated refactor pass already returned a verified commit and the worktree is clean, validate and record that commit, then skip the staging and commit steps below. Otherwise continue only when each non-ignored path is an in-scope, workflow-owned remediation change. Stop on pre-existing, unrelated, or ambiguous paths instead of committing them.
4. Stage only the classified paths with `git add -- <path>...`; never use `git add -A` at this boundary.
5. Commit the verified batch with a plain-English message that includes `{issue-id}`. Record the commit in the cycle ledger.

The parent owns this transition even when it invoked `kramme:pr:resolve-review` or made a direct fix. Accept a delegated commit only when that workflow explicitly returns its commit identity and verification evidence; otherwise do not assume a reviewer, resolver, convention pass, or verification skill committed its edits. The committed tree must equal the tree that passed focused verification; if the commit changes content through hooks, rerun focused verification before continuing.

## Applicability Evaluation

Build `ACTIVE_QUALITY_GATES` and `SKIPPED_QUALITY_GATES` from the current unified branch scope: committed PR diff plus staged, unstaged, and untracked files. Record an evidence-based reason for every skipped gate.

### Regular Code Review

Activate `code-review` when the diff changes executable source, tests, schemas, public contracts, runtime/build configuration, scripts, or behavior-bearing documentation. Also activate it whenever the change claims a bug fix, feature, migration, security change, performance change, or error-handling change.

Skip it only when the complete scope is non-behavioral prose, static metadata, or generated-output churn with no contract, instruction, release, or verification claim to review. When uncertain, activate it.

### Convention Review

Activate `convention-review` when the diff introduces or materially changes any of:

- dependencies, modules, file placement, public types, schemas, or architectural boundaries;
- helpers, wrappers, abstractions, configuration layers, or result/error/loading patterns;
- validation, guards, catches, retries, fallbacks, logging, feature flags, or other defensive behavior;
- lint, formatting, type-checking, build, test, or repository instruction conventions;
- a new implementation pattern where peer files could establish precedent.

Skip it for generated-only changes, pure copy/prose edits, fixture/data refreshes, or a mechanical change that introduces no pattern choice. A small diff is not by itself a reason to skip. When uncertain whether the change establishes a precedent, activate it.

### PR-Scoped Refactor Discovery

Activate `refactor-opportunities` when the reviewed diff adds or materially changes logic, control flow, state/data transformation, component/module structure, abstractions, duplication, type invariants, error handling, or performance-sensitive code. Also activate it when regular or convention review identifies accidental complexity, repeated code, a questionable seam, or cleanup needed to make the accepted fix fit cleanly.

Skip it for docs/copy/metadata/generated-only changes, test-fixture refreshes, dependency-lock churn, or a narrow mechanical fix whose changed code is already demonstrably simple and contains no structural choice. When uncertain, activate it.

`--strict` changes finding disposition, not gate applicability. It does not force an irrelevant gate to run, and it does not permit a skipped gate without recorded evidence.

Before launching reviewers, report:

```text
Quality gates:
- Regular code review: run|skip — {reason}
- Convention review: run|skip — {reason}
- PR-scoped refactor discovery: run|skip — {reason}
```

### Gate 1: Regular Code Review

When active, invoke `kramme:pr:code-review --parallel --inline`. Treat this as a read-only gate: the parent owns relevance decisions, finding dispositions, all review-triggered edits, focused verification, commits, and reruns.

- In standard mode, fix every accepted actionable Critical or Important finding. Report remaining manual and advisory findings.
- In strict mode, extend triage to every emitted manual, Suggestion, and FYI finding using the policy below.

If accepted findings require code changes, group one coherent remediation batch, consume exactly one parent cycle, use `kramme:pr:resolve-review` with the inline findings when its structured flow fits (or make the smallest direct fix), apply the remediation commit boundary, and restart at applicability evaluation followed by Gate 1. Do not continue to convention review in a code-changing round. If the gate changes no code, continue to convention review when the active mode's rule is met: standard mode has no accepted unresolved Critical or Important finding and preserves remaining manual or advisory observations for reporting; strict mode has a disposition for every emitted finding.

### Gate 2: Convention Review

When active, invoke `kramme:pr:convention-review --inline`. Require documented-rule or peer-exemplar evidence, the refutation pass for Critical/Important findings, and PR relevance validation. Split-practice observations are not violations and never enter the active set.

- In standard mode, fix every accepted Critical or Important convention finding. Report Suggestions.
- In strict mode, disposition every active convention finding across all severities.
- Use `kramme:pr:resolve-review` with the inline report when its structured resolution flow fits; otherwise make the smallest verified fix directly. Preserve genuine manual blockers.

After any convention fix, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. Convention edits must pass regular review before refactor discovery.

### Gate 3: PR-Scoped Refactor Opportunities

When active, invoke `kramme:code:refactor-opportunities` with `pr`. Require its PR relevance gate so pre-existing repository debt and broad untouched-file cleanup remain observations, not active findings. The skill writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md` and does not edit code.

In standard mode, keep valid refactor opportunities advisory and report the recommended first refactor; they do not block the round.

In strict mode, triage every active PR-scoped opportunity:

- Apply the `kramme:code:refactor-pass` contract to each accepted, narrow, behavior-preserving opportunity one slice at a time. Apply Chesterton's Fence, emit its required markers, keep tests unmodified, run `kramme:verify:run`, and commit each verified slice. Every slice accepted in this gate pass belongs to the same remediation cycle.
- Reject clean code, speculative improvements, subjective renames, behavior changes, and findings that fail the refactor scan's evidence or PR relevance rules.
- Defer automation-candidate themes over 500 lines and refactors whose main blast radius is outside the Linear issue. Record the concrete follow-up scope and why it does not belong in this Pull Request; do not widen the branch.

After any accepted refactor, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. The refactored code must pass regular and convention review before another refactor scan can close the loop.

## Standard Mode

Finish a standard quality loop only when:

1. Every applicable gate ran in the required order.
2. No accepted actionable Critical or Important regular-review finding remains.
3. No accepted actionable Critical or Important convention finding remains.
4. When active, the refactor report is current and its opportunities are reported as advisory.
5. Every skipped gate has a current evidence-based reason.
6. No required quality-gate coverage is degraded.

Do not label standard mode as “zero findings”; label it “zero accepted unresolved Critical/Important findings, with refactor and advisory observations reported.”

## Strict Mode

Apply strict triage to active findings from every applicable gate. Gates 1 and 2 use the general disposition rules below; Gate 3 also uses its refactor-specific rules above.

For each finding:

1. Trace its evidence to the concrete code path, test expectation, review scope, or PR behavior.
2. Classify it as accepted, rejected, or blocked using the definitions above.
3. Record one disposition in current run state:
   - `fixed` — code, tests, or documentation changed and focused verification passed.
   - `rejected` — no change, with concrete evidence explaining why the finding is invalid, out of scope, redundant, or harmful.
   - `deferred` — valid but deliberately excluded because it exceeds the Linear issue or requires the refactor scan's automation path; include a concrete follow-up scope.
   - `blocked` — the exact missing human/external input has been presented as one actionable question.
4. Keep only accepted, unresolved findings in the active set.

### Advisory Findings

Implement an advisory finding only when the improvement is in scope, evidence-backed, and has one clearly better resolution. Reject subjective style alternatives, speculative defenses, unrelated cleanup, and changes whose churn exceeds their measurable value. Strict mode requires a disposition, not blind compliance.

### Manual Findings

Investigate a manual finding deeply enough to recommend a concrete resolution.

- If the Linear issue, referenced documents, existing public contract, tests, or an overwhelmingly consistent local pattern makes one resolution unambiguous and the named manual blocker no longer applies, record that selected resolution and implement the smallest reversible, repository-local change.
- If competing product behaviors, public API choices, security postures, migration semantics, release decisions, cross-team ownership, external state, or missing access remain, keep the finding blocked. Ask once for the exact decision or dependency and include the recommendation plus genuinely distinct alternatives when they exist.
- Obtain explicit user confirmation before any destructive, irreversible, externally visible, security-policy, data-migration, or public-contract action that is not already specifically authorized by `--ship`, even when one technical path looks preferable.
- Do not treat `--strict` or `--ship` as permission to guess through a genuine manual blocker.

Do not resume a blocked finding until the user explicitly supplies its decision or dependency. Treat that reply as confirmation for the named finding only, preserve the selected resolution in run state, implement or complete only that confirmed process handoff, verify it, and continue the loop. Ask again if the action or scope changes materially.

## Rerun Rules

- If any regular, convention, or refactor disposition changes code, consume one parent-owned remediation cycle, apply the remediation commit boundary, and restart the next quality round at applicability evaluation followed by regular review. No delegated gate owns an internal fix/rerun loop.
- If no disposition changes code, apply the active mode's completion rule: standard mode may finish with reported manual or advisory observations once no accepted required finding remains; strict mode may finish once every emitted finding is fixed, rejected, or explicitly deferred outside the current issue. Do not rerun merely to make a reviewer stop restating rejected advice.
- Re-evaluate a previously rejected finding only when new code or new evidence changes its root cause.
- When a rerun emits a materially new finding, triage it normally; do not dismiss it because an earlier round was clean.

## Diminishing-Returns Guard

Fingerprint accepted findings by quality gate plus concrete location or review scope plus root cause; do not rely on raw line number alone when edits move code.

After every remediation cycle, record:

- cycle number and gates run;
- accepted fingerprints before and after the edit;
- counts added, fixed, reopened, rejected, deferred, and blocked by severity;
- focused verification result and the production files or ownership boundaries changed.

Compute a review-debt score for comparison only: Critical `8`, Important `4`, Suggestion or refactor opportunity `1`, and FYI `0.25`. Treat a cycle as material progress when it lowers the score by at least `1`, lowers the highest outstanding severity, clears a verification failure, or removes a shared root cause without introducing an equal-or-higher-severity finding. Moving, renaming, or rewording the same finding is not progress.

Before taking an optional Suggestion, FYI, or refactor fix, compare its concrete benefit with its change amplification. Defer it as diminishing returns when its only payoff is subjective polish and it would add an abstraction, dependency, public contract, configuration layer, cross-module churn, or verification burden disproportionate to the evidenced problem.

Stop automatic remediation when any condition occurs:

1. The same accepted finding persists after two attempted fixes without new evidence that changes the fix direction.
2. Two consecutive remediation cycles make no material progress.
3. The shared remediation counter reaches five, regardless of whether each cycle made progress.

The hard ceiling is a safety boundary, not a target. Stop earlier as soon as the remaining expected benefit is lower than the churn and regression risk.

### Bounded Stop

When a stop condition fires and code changed after the latest complete ordered gate pass, run exactly one validation-only round. Re-evaluate applicability and run the applicable gates in regular-review → convention-review → refactor order without editing code. Use the same read-only `kramme:pr:code-review --parallel --inline` regular gate. Do not run a second validation-only round.

Disposition the final validation-only findings as follows:

- Defer optional Suggestion, FYI, and narrow refactor findings with the fingerprint, concrete benefit, estimated change amplification, and a follow-up scope. These dispositions satisfy strict-mode accounting and do not block shipping when final verification passes.
- If any accepted Critical or Important finding, verification failure, or genuine manual blocker remains, stop the workflow. Report the cycle ledger, remaining fingerprints, attempted fixes, and smallest decision needed to resume. Do not run final verification, rewrite history, push, or create the Pull Request.
- If no required finding remains, proceed to final verification. Report that the loop stopped at diminishing returns and include the deferred optional count; do not claim that reviewers emitted zero findings.

A repeated rejected finding never keeps the loop open. Explicit user approval to resume starts a new five-cycle budget only for the reported remaining fingerprints and any consequences of their fixes; it does not reopen deferred optional polish automatically.

## Completion Check

Before returning to the parent skill, confirm:

- The selected mode's final-pass rule is met: standard mode has no accepted unresolved Critical or Important finding and preserves remaining manual or advisory observations for reporting; strict mode has a disposition for every emitted finding.
- No accepted required finding remains unresolved; any optional finding excluded at diminishing returns is explicitly deferred with evidence.
- No code changed after the latest focused verification.
- Every remediation batch that changed code crossed the remediation commit boundary, and the worktree contains no uncommitted workflow-owned source changes.
- Every generated review report is isolated under `.context/linear-issue-to-pr/`, not present in the unified review scope.
- The archive still passes `git check-ignore -q -- .context/linear-issue-to-pr/`.
- Every applicable gate ran in regular-review → convention-review → refactor order.
- Every skipped gate has a current evidence-based reason.
- When active, the final refactor report matches code that subsequently passed regular and convention review after its last accepted refactor.
- Any degraded refactor, convention, or broad-review coverage is resolved or reported as a blocker.

Return the stop reason (`converged` or `diminishing returns`), remediation cycles used, review-debt score trend, and counts of fixed, rejected, deferred optional, and blocked findings. A nonzero required or blocked count prevents clean completion until the user supplies the missing input.
