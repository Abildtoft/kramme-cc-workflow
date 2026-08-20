# Quality-Loop Convergence Policy

Use this policy after implementation and before final verification. A one-shot gut check opens the loop, then every quality round selects applicable gates and runs regular code review, convention review, overengineering review, and PR-scoped refactor discovery in that order. Preserve each delegated skill's scope, evidence, relevance, and reporting rules.

## Finding Terms

- **Emitted finding** — every finding returned by a quality gate in the latest round, before this workflow triages or dispositions it.
- **Accepted finding** — an emitted finding whose evidence is valid, PR-caused, in scope, and worth changing or escalating.
- **Rejected finding** — an emitted finding disproved by the code path, pre-existing/out of scope, speculative without a concrete failure path, or harmful/inconsistent with repository practice.
- **Blocked finding** — an accepted finding that needs a genuinely unavailable human decision, approval, owner, service, or external access.
- **Active finding** — an accepted finding that is not yet fixed or blocked on a question already presented to the user.
- **Gut-check item** — one observation returned by the one-shot Gate 0 pass. An item carries no severity, so it is not a severity-bearing finding: it never enters the review-debt score, never enters the active set, and never satisfies or blocks a severity-keyed completion rule. It is triaged under Gate 0's own disposition rules.
- **Remediation cycle** — one parent-owned review-triggered code-edit batch followed by focused verification and a review rerun. Multiple findings fixed as one coherent batch count once. One gate's accepted work consumes exactly one cycle however many findings, files, commits, or verified refactor slices it produced; a multi-slice Gate 4 refactor pass is one cycle, not one per slice. Delegated quality gates are read-only and never maintain a separate counter.

“Zero active findings” means zero accepted unresolved findings after evidence-based triage. It does not mean changing code until every subjective suggestion disappears from reviewer output.

## Quality Round

Re-evaluate applicability at the start of every round because accepted fixes can introduce or remove a gate's trigger conditions. Then run active gates in the order below. Never skip a gate merely to save time or avoid findings.

Initialize `MAX_AUTOMATIC_REMEDIATION_CYCLES=5` and one cycle ledger for the entire quality loop. Do not reset the counter between gates or delegated skills. The initial read-only gate pass does not consume a cycle; consume one whenever accepted review work changes code, then run focused verification before continuing. Gate 0 sits outside this rotation and outside the ledger under its own rules below.

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

After the check passes, use `.context/linear-issue-to-pr/` as the workflow's gitignored report archive. After consuming a file-backed gate or resolver result, move `REVIEW_OVERVIEW.md`, `CONVENTION_REVIEW_OVERVIEW.md`, `OVERENGINEERING_REVIEW_OVERVIEW.md`, and `REFACTOR_OPPORTUNITIES_OVERVIEW.md` there before focused verification or the next unified-scope collection. Replace the matching archived file when a gate reruns. Keep finding dispositions in current run state so moving a report does not lose triage state.

This run has invoked no quality gate yet, so any `OVERENGINEERING_REVIEW_OVERVIEW.md` already sitting in the archive belongs to an earlier invocation: this workflow restarts from implementation instead of resuming a previous run, and its non-shipping path deliberately leaves an archive behind that a later run for a different Linear issue would find in the same workspace. That report's `OE-NNN` identities and dispositions describe an earlier review, possibly of another branch entirely, and must never be inherited here. Delete it now, before the first quality round, and initialize `OVERENGINEERING_LIFECYCLE_ESTABLISHED=false`. Stop instead of deleting when that archived path is not a regular, non-symlink file.

Normal overengineering rounds need this run's own previous report so `kramme:pr:overengineering-review` can preserve `OE-NNN` identities and resolver lifecycle fields. After applicability evaluation and the preceding gates have finished, but immediately before invoking the active overengineering gate, restore the archived `OVERENGINEERING_REVIEW_OVERVIEW.md` to the repository root. Continue only when the root path is absent and the archived path is a regular, non-symlink file; stop rather than overwriting either location or copying ambiguous state. The delegated gate independently enforces that the restored root report is untracked and safe to read. Set `OVERENGINEERING_LIFECYCLE_ESTABLISHED=true` as soon as the gate's first report is archived. Start the gate without a report only while that flag is still `false`; if the archived report is missing while the flag is `true`, stop, because this run established lifecycle state that has since disappeared and a silent fresh start would discard the stable IDs and recorded dispositions the completion rules still depend on. After consuming the refreshed report, or after a resolver updates it, move it back to the archive before focused verification, refactor discovery, or another unified-scope collection; this re-archive is mandatory after every invocation, including one that emits no finding, changes no code, or stops on a blocker. Do not pass `--inline` during normal rounds because inline output cannot carry the gate's stable lifecycle state into a later remediation round.

Never leave generated review output in the project root while another applicability check, review, refactor scan, or verification command collects changed and untracked files. Without `--ship`, retain the archive as the review-ready handoff. With `--ship`, the registered `kramme:workflow-artifacts:cleanup --auto` path retires the archive before Pull Request creation.

### Remediation Commit Boundary

After any accepted review work changes source, tests, configuration, or documentation:

1. Move generated review reports into the archive above.
2. Run the smallest focused verification that covers the changed behavior.
3. Inspect `git status --porcelain` and classify every remaining path. If a delegated refactor pass already returned a verified commit and the worktree is clean, validate and record that commit, then skip the staging and commit steps below. Otherwise continue only when each non-ignored path is an in-scope, workflow-owned remediation change. Stop on pre-existing, unrelated, or ambiguous paths instead of committing them.
4. Stage only the classified paths with `git add -- <path>...`; never use `git add -A` at this boundary.
5. Commit the verified batch with a plain-English message that includes `{issue-id}`. Record the commit in the cycle ledger.

The parent owns this transition even when it invoked `kramme:pr:resolve-review` or made a direct fix. Accept a delegated commit only when that workflow explicitly returns its commit identity and verification evidence; otherwise do not assume a reviewer, resolver, convention pass, or verification skill committed its edits. The committed tree must equal the tree that passed focused verification; if the commit changes content through hooks, rerun focused verification before continuing.

## Gate 0: Gut Check

Run this gate exactly once per workflow, immediately after the implementation commit boundary and before the first applicability evaluation. It is not part of the per-round rotation: never rerun it in a later remediation round or in the bounded stop's validation-only round.

Once, not per round, for three reasons. It is a first-reader reaction, and by the second round the diff has been read repeatedly, so the reaction is no longer a first read. Its items carry no severity, so they cannot be scored under the review-debt formula or measured by the diminishing-returns guard. Its items carry no stable fingerprint, so a rerun would re-emit the same unscoreable observations and could hold the loop open indefinitely.

It runs first because its cheapest tier is a manifest read that covers every changed file, and the residue it finds — a stray scratch file, a drive-by rename, a whole-file reformat riding along, generated output moved without its source — is cheapest to remove before three heavyweight gates spend budget reviewing code that does not belong in the diff. It is also the only gate in this loop that reads the branch's commit history as material in its own right, where the delegated `--auto` implementation's leftover fixup, unexpected merge commit, or message that does not match its content becomes visible. Gate 3 sees a bounded commit index only as supporting intent context.

Invoke `kramme:pr:gut-check` with `--intent "{issue-title}: {one-line statement of the behavior the Linear issue requests}"`. Do not pass `--base`; the shared collector already resolves the canonical base. No Pull Request exists at this point, so `--intent` is the only reliable statement of branch purpose the gate will have. Treat it as a read-only gate: it writes no report file, so it needs no archive step, and the parent owns every disposition below.

Record one disposition for every returned item:

- `removed` — the item is residue rather than design: a stray file, a debug statement, a commented-out block, a leftover TODO, a drive-by rename, or a reformat riding along with real work. Delete or revert it directly.
- `routed` — the item is a regular-review, convention, overengineering, or refactor concern that the first read happened to surface. Carry it into that gate's triage as intent context and do not fix it here. If the applicability evaluation that follows skips that gate, or the gate runs and emits no finding covering the item, the parent dispositions it directly as `rejected` with that evidence. Never let a skipped or silent gate retire a routed item by default.
- `rejected` — the surrounding code, the repository's practice, or work the Linear issue already covers makes it ordinary. An issue that is merely silent about the item never makes it ordinary; that is the `blocked` case below.
- `blocked` — the item shows the branch doing work the Linear issue did not ask for. Stop the workflow and ask; never revert it unilaterally under `removed`.

A `blocked` item stops the workflow. Report it in both standard and strict mode, because the workflow contract forbids broadening the issue's scope, and no later gate stops for out-of-issue work: Gate 3 also measures the diff against the issue, but it judges whether complexity is necessary and returns verdicts rather than a scope block. Every other item is non-blocking; a gut-check item alone never keeps the standard-mode completion rule open, and strict mode requires only that each item has one of the four dispositions recorded.

A `removed` batch does not consume a remediation cycle, for the same reason the implementation commit boundary does not: it retires residue left by the delegated implementation phase before any quality gate has emitted a finding. It still crosses the remediation commit boundary above, except that boundary's ledger step: record the removal commit in run state, not in the cycle ledger. Allow at most one such batch; anything a rerun would find belongs to the gates that follow.

Report:

```text
Gut check: {count} items — removed {count}, routed {count}, rejected {count}, blocked {count}
```

With no `blocked` item, continue to applicability evaluation and Gate 1, whether or not the batch changed code.

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

### Overengineering Review

Activate `overengineering-review` when the diff introduces or materially changes an abstraction, helper layer, generic mechanism, extensibility point, configuration surface, compatibility path, defensive branch, retry/fallback, state machine, indirection, or design whose necessity must be judged against the Linear issue. Also activate it when Gate 0, regular review, or convention review identifies needless complexity, speculative generality, unlikely-edge-case hedging, or a solution materially broader than the requested behavior.

Skip it for generated-only changes, pure copy/prose/metadata edits, fixture or lockfile refreshes, and narrow mechanical changes with no structural or defensive choice. The fact that an implementation follows local convention is not a reason to skip this task-relative lens. When uncertain whether the branch added machinery beyond the issue's needs, activate it.

### PR-Scoped Refactor Discovery

Activate `refactor-opportunities` when the reviewed diff adds or materially changes logic, control flow, state/data transformation, component/module structure, abstractions, duplication, type invariants, error handling, or performance-sensitive code. Also activate it when regular or convention review identifies accidental complexity, repeated code, a questionable seam, or cleanup needed to make the accepted fix fit cleanly.

Skip it for docs/copy/metadata/generated-only changes, test-fixture refreshes, dependency-lock churn, or a narrow mechanical fix whose changed code is already demonstrably simple and contains no structural choice. When uncertain, activate it.

`--strict` changes finding disposition, not gate applicability. It does not force an irrelevant gate to run, and it does not permit a skipped gate without recorded evidence.

Gate 0 is not evaluated here. It always runs, exactly once, before the first evaluation, so it never appears in `ACTIVE_QUALITY_GATES` or `SKIPPED_QUALITY_GATES` and never appears in the per-round report below.

Before launching reviewers, report:

```text
Quality gates:
- Regular code review: run|skip — {reason}
- Convention review: run|skip — {reason}
- Overengineering review: run|skip — {reason}
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

After any convention fix, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. Convention edits must pass regular review before overengineering review or refactor discovery.

### Gate 3: Overengineering Review

When active, invoke `kramme:pr:overengineering-review --requirements "{issue-requirements}"`. The Linear issue text is authoritative task intent because no Pull Request exists yet; commit subjects and any unavailable PR metadata remain supporting context only. Use the file-backed default during normal rounds, not `--inline`, and apply the restore/archive lifecycle above. Treat the gate as read-only: it may write `OVERENGINEERING_REVIEW_OVERVIEW.md`, but the parent owns relevance decisions, finding dispositions, review-triggered edits, verification, commits, and reruns.

Build `{issue-requirements}` once, before the first overengineering invocation, and pass that same text to every later invocation in this run, including the shipping contract's validation-only pass. The gate treats it as the authoritative statement of requested behavior and never reads the Linear issue itself, so anything the issue requires but this text omits reaches the justifier as an unrequested complication and returns as a false `OVERDONE`. Compose the complete requirement set from the issue and the references the implementation workflow already mapped:

- the issue title and the behavior it requests;
- every acceptance criterion, checklist item, and explicit success condition;
- every stated constraint the implementation must satisfy, including compatibility, migration, security, privacy, performance, rollout, and error-handling requirements;
- every stated non-goal or explicit out-of-scope boundary.

Keep it bounded: quote or tightly paraphrase what the issue and its referenced context state, in their own terms. Do not invent a requirement the issue does not state, restate the implementation, or paste a linked document in full. When the issue states no acceptance criteria or no constraints, record that absence explicitly rather than omitting the section, so the justifier can tell a requirement that does not exist from one this summary dropped.

Apply its verdicts as follows:

- `JUSTIFIED` is inactive and remains in the report as the evidence for keeping the current complexity.
- An evidence-valid, PR-caused `OVERDONE` finding is required in both modes. Apply the smallest in-scope simplification that still satisfies the Linear issue, unless new concrete requirement, safety, or failure-path evidence unavailable to the delegated justifier disproves the finding. Record that evidence when rejecting it.
- In standard mode, report `JUDGMENT CALL` findings as advisory unless one clearly better, reversible, issue-local simplification is evident. A judgment call alone does not block the round.
- In strict mode, disposition every `JUDGMENT CALL`: simplify when one resolution is clearly better; reject only with concrete evidence that the current complexity is warranted; defer an optional tradeoff with a specific retained rationale and follow-up scope; or block on the exact genuinely unavailable product, public-contract, security, or ownership decision.

Use `kramme:pr:resolve-review` while the file-backed report is still in the repository root when its structured resolution flow fits; otherwise make the smallest verified fix directly. After any accepted simplification, archive the updated report, apply the remediation commit boundary, consume exactly one parent cycle, and restart the next round at applicability evaluation followed by Gate 1. The simplified code must pass regular and convention review before overengineering review reruns. If no disposition changes code and the active mode's rule is met, archive the refreshed report and continue to refactor discovery. Archive the refreshed report before pausing on any blocker so generated output never remains in the unified branch scope.

### Gate 4: PR-Scoped Refactor Opportunities

When active, invoke `kramme:code:refactor-opportunities` with `pr`. Require its PR relevance gate so pre-existing repository debt and broad untouched-file cleanup remain observations, not active findings. The skill writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md` and does not edit code.

In standard mode, keep valid refactor opportunities advisory and report the recommended first refactor; they do not block the round.

In strict mode, triage every active PR-scoped opportunity:

- Apply the `kramme:code:refactor-pass` contract to each accepted, narrow, behavior-preserving opportunity one slice at a time. Apply Chesterton's Fence, emit its required markers, keep tests unmodified, run `kramme:verify:run`, and commit each verified slice. Every slice accepted in this gate pass belongs to the same remediation cycle.
- Reject clean code, speculative improvements, subjective renames, behavior changes, and findings that fail the refactor scan's evidence or PR relevance rules.
- Defer automation-candidate themes over 500 lines and refactors whose main blast radius is outside the Linear issue. Record the concrete follow-up scope and why it does not belong in this Pull Request; do not widen the branch.

After any accepted refactor, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. The refactored code must pass regular, convention, and overengineering review before another refactor scan can close the loop.

## Standard Mode

Finish a standard quality loop only when:

1. Every applicable gate ran in the required order.
2. No accepted actionable Critical or Important regular-review finding remains.
3. No accepted actionable Critical or Important convention finding remains.
4. No accepted `OVERDONE` finding remains; when active, the overengineering report is current and its Judgment Calls are reported as advisory.
5. When active, the refactor report is current and its opportunities are reported as advisory.
6. Every skipped gate has a current evidence-based reason.
7. No required quality-gate coverage is degraded.

Do not label standard mode as “zero findings”; label it “zero accepted unresolved Critical/Important or OVERDONE findings, with judgment-call, refactor, and advisory observations reported.”

## Strict Mode

Apply strict triage to active findings from every applicable gate. Gates 1 and 2 use the general disposition rules below; Gate 3 uses its overengineering-specific rules above, and Gate 4 uses its refactor-specific rules above.

For each finding:

1. Trace its evidence to the concrete code path, test expectation, review scope, or PR behavior.
2. Classify it as accepted, rejected, or blocked using the definitions above.
3. Record one disposition in current run state:
   - `fixed` — code, tests, or documentation changed and focused verification passed.
   - `rejected` — no change, with concrete evidence explaining why the finding is invalid, out of scope, redundant, or harmful.
   - `deferred` — valid but deliberately excluded because it exceeds the Linear issue, requires the refactor scan's automation path, or is an optional overengineering Judgment Call retained at diminishing returns; include the concrete rationale and follow-up scope.
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

- If any regular, convention, overengineering, or refactor disposition changes code, consume one parent-owned remediation cycle, apply the remediation commit boundary, and restart the next quality round at applicability evaluation followed by regular review. No delegated gate owns an internal fix/rerun loop.
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

Compute a review-debt score for comparison only: Critical `8`, Important `4`, Suggestion, confirmed `OVERDONE`, or refactor opportunity `1`, and FYI or unresolved `JUDGMENT CALL` `0.25`. Gut-check items carry no severity and score nothing; Gate 0 runs before the first cycle and is never part of a trend. Treat a cycle as material progress when it lowers the score by at least `1`, lowers the highest outstanding severity, clears a verification failure, or removes a shared root cause without introducing an equal-or-higher-severity finding. Moving, renaming, or rewording the same finding is not progress.

Before taking an optional Suggestion, FYI, Judgment Call simplification, or refactor fix, compare its concrete benefit with its change amplification. Defer it as diminishing returns when its only payoff is subjective polish and it would add an abstraction, dependency, public contract, configuration layer, cross-module churn, or verification burden disproportionate to the evidenced problem.

Stop automatic remediation when any condition occurs:

1. The same accepted finding persists after two attempted fixes without new evidence that changes the fix direction.
2. Two consecutive remediation cycles make no material progress.
3. The shared remediation counter reaches five, regardless of whether each cycle made progress.

The hard ceiling is a safety boundary, not a target. Stop earlier as soon as the remaining expected benefit is lower than the churn and regression risk.

### Bounded Stop

When a stop condition fires and code changed after the latest complete ordered gate pass, run exactly one validation-only round. Re-evaluate applicability and run the applicable gates in regular-review → convention-review → overengineering-review → refactor order without editing code. Use the same read-only `kramme:pr:code-review --parallel --inline` regular gate and the normal file-backed overengineering invocation so prior `OE-NNN` lifecycle state is reconciled. Do not rerun Gate 0 here; it is a one-shot pass and its budget-free removal batch is not available this late. Do not run a second validation-only round.

Disposition the final validation-only findings as follows:

- Defer optional Suggestion, FYI, Judgment Call, and narrow refactor findings with the fingerprint, concrete benefit, estimated change amplification, and a follow-up scope. These dispositions satisfy strict-mode accounting and do not block shipping when final verification passes.
- If any accepted Critical, Important, or `OVERDONE` finding, verification failure, or genuine manual blocker remains, stop the workflow. Report the cycle ledger, remaining fingerprints, attempted fixes, and smallest decision needed to resume. Do not run final verification, rewrite history, push, or create the Pull Request.
- If no required finding remains, proceed to final verification. Report that the loop stopped at diminishing returns and include the deferred optional count; do not claim that reviewers emitted zero findings.

A repeated rejected finding never keeps the loop open. Explicit user approval to resume starts a new five-cycle budget only for the reported remaining fingerprints and any consequences of their fixes; it does not reopen deferred optional polish automatically.

## Completion Check

Before returning to the parent skill, confirm:

- Gate 0 ran exactly once, before the first applicability evaluation, and every returned item is recorded as `removed`, `routed`, `rejected`, or `blocked`.
- No gut-check item reported the branch doing work outside the Linear issue, and every `routed` item either entered its owning gate's triage or was dispositioned directly by the parent when that gate was skipped or emitted nothing covering it.
- The selected mode's final-pass rule is met: standard mode has no accepted unresolved Critical, Important, or `OVERDONE` finding and preserves remaining manual, Judgment Call, or advisory observations for reporting; strict mode has a disposition for every emitted finding.
- No accepted required finding remains unresolved; any optional finding excluded at diminishing returns is explicitly deferred with evidence.
- No code changed after the latest focused verification.
- Every remediation batch that changed code crossed the remediation commit boundary, and the worktree contains no uncommitted workflow-owned source changes.
- Every generated review report is isolated under `.context/linear-issue-to-pr/`, not present in the unified review scope.
- The archive still passes `git check-ignore -q -- .context/linear-issue-to-pr/`.
- Every applicable gate ran in regular-review → convention-review → overengineering-review → refactor order.
- Every skipped gate has a current evidence-based reason.
- When active, the final refactor report matches code that subsequently passed regular, convention, and overengineering review after its last accepted refactor.
- Any degraded refactor, overengineering, convention, or broad-review coverage is resolved or reported as a blocker.

Return the stop reason (`converged` or `diminishing returns`), remediation cycles used, review-debt score trend, and counts of fixed, rejected, deferred optional, and blocked findings. A nonzero required or blocked count prevents clean completion until the user supplies the missing input.
