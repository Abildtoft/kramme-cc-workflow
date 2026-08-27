# Review Convergence Policy

Use this policy after the skill has frozen the caller's requirements and validated the committed local branch plus any plan scope. In normal mode, a one-shot gut check opens the loop; every quality round then selects applicable gates and runs regular code review, convention review, overengineering review, and PR-scoped refactor discovery in that order. When explicitly enabled, a required different-provider review runs as Gate 5 after the ordinary gates have reached a no-change candidate. Validation-only mode skips the gut check and runs that ordered gate pass once without edits. Preserve each delegated skill's scope, evidence, relevance, and reporting rules.

## Finding Terms

- **Emitted finding** — every finding returned by a quality gate in the latest round, before this workflow triages or dispositions it.
- **Accepted finding** — an emitted finding whose evidence is valid, PR-caused, in scope, and worth changing or escalating.
- **Rejected finding** — an emitted finding disproved by the code path, pre-existing/out of scope, speculative without a concrete failure path, or harmful/inconsistent with repository practice.
- **Blocked finding** — an accepted finding that needs a genuinely unavailable human decision, approval, owner, service, or external access.
- **Active finding** — an accepted finding that is not yet fixed or blocked on a question already presented to the user.
- **Gut-check item** — one observation returned by the one-shot Gate 0 pass. An item carries no severity, so it is not a severity-bearing finding: it never enters the review-debt score, never enters the active set, and never satisfies or blocks a severity-keyed completion rule. It is triaged under Gate 0's own disposition rules.
- **Remediation cycle** — one review-skill-owned code-edit batch followed by focused verification and a review rerun. Multiple findings fixed as one coherent batch count once. One gate's accepted work consumes exactly one cycle however many findings, files, commits, or verified refactor slices it produced; a multi-slice Gate 4 refactor pass is one cycle, not one per slice. Delegated quality gates are read-only and never maintain a separate counter.

“Zero active findings” means zero accepted unresolved findings after evidence-based triage. It does not mean changing code until every subjective suggestion disappears from reviewer output.

## Reviewer Handoff Ledger

Initialize one producer-owned `REVIEWER_HANDOFF_FINDINGS` ledger and one `REVIEWER_HANDOFF_FOCUS` ledger in run state before Gate 0. These ledgers, not the replaceable report archive, are the durable caller handoff. Update an existing entry by the finding fingerprint (quality gate plus concrete location or review scope plus root cause) when a later round changes its disposition; never duplicate the same root cause because a report was regenerated or line numbers moved.

Initialize `DIFF_COMMENTS_POSTED_TOTAL=0` beside those ledgers. It counts only newly posted Conductor comments reported by normal-mode Gate 1 producer invocations in this convergence run. Never read Conductor comments as findings input or reconstruct this count from host state.

Record a finding entry for every accepted finding that changes code, every emitted Critical, Important, or `OVERDONE` finding that is fixed, rejected, deferred optional, or blocked, and every lower-severity finding intentionally deferred for later review. Each entry contains `fingerprint`, `gate`, `summary`, `disposition` (`fixed`, `rejected`, `deferred_optional`, or `blocked`), and the evidence-based `rationale`. Omit rejected Nit/FYI noise unless its rationale materially changes what a reviewer should inspect.

Record a focus entry for every unresolved manual or advisory note and every Judgment Call or concrete risk area surfaced by a gate. Each entry contains `kind` (`judgment_call`, `risk`, or `advisory`), `summary`, and `rationale`. Remove or update a focus entry when remediation or a later gate resolves it. Keep the ledgers current through normal reruns and validation-only passes even when a gate reports inline or its archived report is replaced.

## Quality Round

Re-evaluate applicability at the start of every round because accepted fixes can introduce or remove a gate's trigger conditions. Then run active gates in the order below. Never skip a gate merely to save time or avoid findings.

When `VALIDATION_ONLY=false`, use parsed `MAX_AUTOMATIC_REMEDIATION_CYCLES` from the invocation and initialize one cycle ledger for the entire quality loop. Do not reset the counter between gates or delegated skills. The initial read-only gate pass does not consume a cycle; consume one whenever accepted review work changes code, then run focused verification before continuing. Gate 0 sits outside this rotation and outside the ledger under its own rules below.

When `VALIDATION_ONLY=true`, create no remediation ledger and permit no source, test, configuration, or documentation edit, deletion, revert, staging operation, or commit. Generated review reports may be created and isolated under the ignored archive. Run one applicability evaluation and one complete ordered pass. A required finding or manual blocker fails validation; optional findings receive evidence-based reported dispositions without changing code.

### Quality-Loop Artifact Isolation

Step 2 already created and validated `{review-archive}`, stored its canonical path as `REVIEW_ARCHIVE_CANONICAL`, and proved the fixed path is ignored. Before every move, replacement, restoration, or deletion below, repeat the non-symlink component walk and canonical containment proof; stop if the archive identity changed. Do not ask for or substitute another location during this policy.

Use `{review-archive}/` as the workflow's gitignored report archive. After consuming a file-backed gate or resolver result, move `REVIEW_OVERVIEW.md`, `CONVENTION_REVIEW_OVERVIEW.md`, `OVERENGINEERING_REVIEW_OVERVIEW.md`, and `REFACTOR_OPPORTUNITIES_OVERVIEW.md` there before focused verification or the next unified-scope collection. Replace the matching archived file when a gate reruns. Keep finding dispositions and the reviewer handoff ledgers in current run state so moving or replacing a report does not lose caller-visible triage state.

In normal mode, this run has invoked no quality gate yet, so any `OVERENGINEERING_REVIEW_OVERVIEW.md` already sitting in the archive belongs to an earlier invocation. Its `OE-NNN` identities and dispositions may describe another work item or branch and must never be inherited. Delete it before the first quality round and initialize `OVERENGINEERING_LIFECYCLE_ESTABLISHED=false`. Stop instead of deleting when that archived path is not a regular, non-symlink file. Validation-only mode does not read, restore, delete, or recreate this lifecycle file.

Normal overengineering rounds need this run's own previous report so `kramme:pr:overengineering-review` can preserve `OE-NNN` identities and resolver lifecycle fields. After applicability evaluation and the preceding gates have finished, but immediately before invoking the active overengineering gate, restore the archived `OVERENGINEERING_REVIEW_OVERVIEW.md` to the repository root. Continue only when the root path is absent and the archived path is a regular, non-symlink file; stop rather than overwriting either location or copying ambiguous state. The delegated gate independently enforces that the restored root report is untracked and safe to read. Set `OVERENGINEERING_LIFECYCLE_ESTABLISHED=true` as soon as the gate's first report is archived. Start the gate without a report only while that flag is still `false`; if the archived report is missing while the flag is `true`, stop, because this run established lifecycle state that has since disappeared and a silent fresh start would discard the stable IDs and recorded dispositions the completion rules still depend on. After consuming the refreshed report, or after a resolver updates it, move it back to the archive before focused verification, refactor discovery, or another unified-scope collection; this re-archive is mandatory after every normal-mode invocation, including one that emits no finding, changes no code, or stops on a blocker. Do not pass `--inline` during normal rounds because inline output cannot carry the gate's stable lifecycle state into a later remediation round.

Never leave generated review output in the project root while another applicability check, review, refactor scan, or verification command collects changed and untracked files. Retain the archive as the review-ready handoff. A downstream shipping workflow may retire the registered archive with `kramme:workflow-artifacts:cleanup --auto` before Pull Request creation.

### Remediation Commit Boundary

After any accepted review work changes source, tests, configuration, or documentation:

1. Move generated review reports into the archive above.
2. Run the smallest focused verification that covers the changed behavior.
3. Inspect `git status --porcelain` and classify every remaining path. If a delegated refactor pass already returned a verified commit and the worktree is clean, validate and record that commit, then skip the staging and commit steps below. Otherwise continue only when each non-ignored path is an in-scope, workflow-owned remediation change. Stop on pre-existing, unrelated, or ambiguous paths instead of committing them.
4. When `PLAN_SCOPE_ACTIVE=true`, require every proposed and dirty path to satisfy `PLAN_SCOPE_MODE`: exact equality with one `VALIDATED_SCOPE_PATHS` entry for `exact-files`, otherwise exact path or directory containment. An otherwise valid fix requiring another path is a blocker, not permission to widen scope. Run `RECHECK_STANDALONE_SCOPE` when `PLAN_SCOPE_ACTIVE=true` and `PLAN_SCOPE_MODE=exact-files`, then stage only validated paths.
5. Stage only the classified validated paths with `git add -- <path>...`; never use `git add -A` at this boundary and never render a plan value into command text.
6. Commit the verified batch with a plain-English message that includes `{work-id}`. Record the commit in the cycle ledger.

This skill owns the transition even when it invoked `kramme:pr:resolve-review` or made a direct fix. Accept a delegated commit only when that workflow explicitly returns its commit identity and verification evidence; otherwise do not assume a reviewer, resolver, convention pass, or verification skill committed its edits. The committed tree must equal the tree that passed focused verification; if the commit changes content through hooks, rerun focused verification before continuing.

## Gate 0: Gut Check

When `VALIDATION_ONLY=false`, run this gate exactly once per workflow, immediately after the implementation commit boundary and before the first applicability evaluation. It is not part of the per-round rotation: never rerun it in a later remediation round or in a validation-only pass. When `VALIDATION_ONLY=true`, skip Gate 0 entirely.

Once, not per round, for three reasons. It is a first-reader reaction, and by the second round the diff has been read repeatedly, so the reaction is no longer a first read. Its items carry no severity, so they cannot be scored under the review-debt formula or measured by the diminishing-returns guard. Its items carry no stable fingerprint, so a rerun would re-emit the same unscoreable observations and could hold the loop open indefinitely.

It runs first because its cheapest tier is a manifest read that covers every changed file, and the residue it finds — a stray scratch file, a drive-by rename, a whole-file reformat riding along, generated output moved without its source — is cheapest to remove before three heavyweight gates spend budget reviewing code that does not belong in the diff. It is also the only gate in this loop that reads the branch's commit history as material in its own right, where the delegated `--auto` implementation's leftover fixup, unexpected merge commit, or message that does not match its content becomes visible. Gate 3 sees a bounded commit index only as supporting intent context.

Invoke `kramme:pr:gut-check` with the exact sentinel-last arguments `--intent {work-id}: {one-line statement of the requested behavior}`. Pass the intent remainder through the platform skill mechanism as inert data; do not add shell quoting or reconstruct command text. Do not pass `--base`; the shared collector already resolves the canonical base. No Pull Request exists at this point, so `--intent` is the only reliable statement of branch purpose the gate will have. Treat it as a read-only gate: it writes no report file, so it needs no archive step, and this skill owns every disposition below.

Record one disposition for every returned item:

- `removed` — the item is residue rather than design: a stray file, a debug statement, a commented-out block, a leftover TODO, a drive-by rename, or a reformat riding along with real work. Delete or revert it directly.
- `routed` — the item is a regular-review, convention, overengineering, or refactor concern that the first read happened to surface. Carry it into that gate's triage as intent context and do not fix it here. If the applicability evaluation that follows skips that gate, or the gate runs and emits no finding covering the item, this skill dispositions it directly as `rejected` with that evidence. Never let a skipped or silent gate retire a routed item by default.
- `rejected` — the surrounding code, repository practice, or frozen requirements already make the item ordinary. Requirements that are merely silent about the item never make it ordinary; that is the `blocked` case below.
- `blocked` — the item shows the branch doing work the frozen work requirements did not ask for. Stop the workflow and ask; never revert it unilaterally under `removed`.

A `blocked` item stops the workflow. Report it in both standard and strict mode because the workflow contract forbids broadening the prepared work. Gate 3 also measures the diff against the requirements, but it judges whether complexity is necessary rather than owning scope expansion. Every other item is non-blocking; a gut-check item alone never keeps the standard-mode completion rule open, and strict mode requires only that each item has one of the four dispositions recorded.

A `removed` batch does not consume a remediation cycle, for the same reason the implementation commit boundary does not: it retires residue left by the delegated implementation phase before any quality gate has emitted a finding. It still crosses the remediation commit boundary above, except that boundary's ledger step: record the removal commit in run state, not in the cycle ledger. Allow at most one such batch; anything a rerun would find belongs to the gates that follow.

Report:

```text
Gut check: {count} items — removed {count}, routed {count}, rejected {count}, blocked {count}
```

With no `blocked` item, continue to applicability evaluation and Gate 1, whether or not the batch changed code.

## Applicability Evaluation

Build `ACTIVE_QUALITY_GATES` and `SKIPPED_QUALITY_GATES` from the current unified branch scope: committed PR diff plus staged, unstaged, and untracked files. Record an evidence-based reason for every skipped gate.

When `ADVERSARIAL_REVIEW=true`, append `adversarial-review` to `ACTIVE_QUALITY_GATES`; its applicability comes from the caller's explicit cross-provider authorization rather than diff shape. When false, record `adversarial-review` as skipped because it was not requested. Never auto-enable an external provider from CLI presence.

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

Activate `overengineering-review` when the diff introduces or materially changes an abstraction, helper layer, generic mechanism, extensibility point, configuration surface, compatibility path, defensive branch, retry/fallback, state machine, indirection, or design whose necessity must be judged against the frozen work requirements. Also activate it when Gate 0, regular review, or convention review identifies needless complexity, speculative generality, unlikely-edge-case hedging, or a solution materially broader than the requested behavior.

Skip it for generated-only changes, pure copy/prose/metadata edits, fixture or lockfile refreshes, and narrow mechanical changes with no structural or defensive choice. The fact that an implementation follows local convention is not a reason to skip this task-relative lens. When uncertain whether the branch added machinery beyond the frozen requirements, activate it.

### PR-Scoped Refactor Discovery

Activate `refactor-opportunities` when the reviewed diff adds or materially changes logic, control flow, state/data transformation, component/module structure, abstractions, duplication, type invariants, error handling, or performance-sensitive code. Also activate it when regular or convention review identifies accidental complexity, repeated code, a questionable seam, or cleanup needed to make the accepted fix fit cleanly.

Skip it for docs/copy/metadata/generated-only changes, test-fixture refreshes, dependency-lock churn, or a narrow mechanical fix whose changed code is already demonstrably simple and contains no structural choice. When uncertain, activate it.

`--strict` changes finding disposition, not gate applicability. It does not force an irrelevant gate to run, and it does not permit a skipped gate without recorded evidence.

Gate 0 is not evaluated here. Normal mode runs it exactly once before the first evaluation; validation-only mode skips it. It never appears in `ACTIVE_QUALITY_GATES`, `SKIPPED_QUALITY_GATES`, or the per-round report below.

Before launching reviewers, report:

```text
Quality gates:
- Regular code review: run|skip — {reason}
- Convention review: run|skip — {reason}
- Overengineering review: run|skip — {reason}
- PR-scoped refactor discovery: run|skip — {reason}
- Adversarial model review: run|skip — {explicitly requested or not requested}
```

### Validation-Only Gate Rule

When `VALIDATION_ONLY=true`, every active gate below is read-only. Do not invoke `kramme:pr:resolve-review`, `kramme:code:refactor-pass`, or any direct fix path. Do not consume a cycle or restart applicability. Run all active gates once in order, including Gate 5 when requested, disposition optional output for reporting, and stop on any accepted Critical, Important, or `OVERDONE` finding or genuine manual blocker. Isolate generated refactor or resolver-free reports before the next gate or return.

### Gate 1: Regular Code Review

When active, invoke `kramme:pr:code-review --parallel --inline` in normal mode; keep diff comments enabled on every round so the producer can project newly appearing root-cause fingerprints and deduplicate stable fingerprints without relying on ordinal Finding IDs. When `VALIDATION_ONLY=true`, invoke `kramme:pr:code-review --parallel --inline --no-diff-comments` so a validation pass creates no new host comments. Treat either invocation as a read-only gate: this skill owns relevance decisions, finding dispositions, all review-triggered edits, focused verification, commits, and reruns.

Require exactly one producer summary line `Diff comments posted: N (skipped M already present)` with nonnegative integer counts. In normal mode, add `N` to `DIFF_COMMENTS_POSTED_TOTAL`; in validation-only mode require `N=0` and do not change the ledger. A projection-limitation line is reporting context, not degraded review coverage. The canonical inline report remains the only findings input.

- In standard mode, fix every accepted actionable Critical or Important finding. Report remaining manual and advisory findings.
- In strict mode, extend triage to every emitted manual, Suggestion, and FYI finding using the policy below.

In normal mode, if accepted findings require code changes, group one coherent remediation batch, consume exactly one review cycle, use `kramme:pr:resolve-review` with the inline findings when its structured flow fits (or make the smallest direct fix), apply the remediation commit boundary, and restart at applicability evaluation followed by Gate 1. Do not continue to convention review in a code-changing round. If the gate changes no code, continue to convention review when the active mode's rule is met: standard mode has no accepted unresolved Critical or Important finding and preserves remaining manual or advisory observations for reporting; strict mode has a disposition for every emitted finding.

### Gate 2: Convention Review

When active, invoke `kramme:pr:convention-review --inline`. Require documented-rule or peer-exemplar evidence, the refutation pass for Critical/Important findings, and PR relevance validation. Split-practice observations are not violations and never enter the active set.

- In standard mode, fix every accepted Critical or Important convention finding. Report Suggestions.
- In strict mode, disposition every active convention finding across all severities.
- Use `kramme:pr:resolve-review` with the inline report when its structured resolution flow fits; otherwise make the smallest verified fix directly. Preserve genuine manual blockers.

In normal mode, after any convention fix, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. Convention edits must pass regular review before overengineering review or refactor discovery.

### Gate 3: Overengineering Review

When active in normal mode, invoke `kramme:pr:overengineering-review` with the exact sentinel-last arguments `--requirements {work-requirements}` and the file-backed default, then apply the restore/archive lifecycle above. When active in validation-only mode, place `--inline` before the sentinel and use `--inline --requirements {work-requirements}` so no lifecycle file is read or created. Pass the requirements remainder through the platform skill mechanism as inert data; do not add shell quoting or reconstruct command text. The frozen requirements are authoritative task intent; commit subjects and Pull Request metadata remain supporting context only. Treat the gate as read-only: in normal mode this skill owns every resulting disposition, edit, verification, commit, and rerun.

Pass the exact same frozen `{work-requirements}` block to every invocation for this tree lineage. The gate never reads the caller's source item itself, so an omitted requirement could return as a false `OVERDONE`; stop before review when the caller handoff is incomplete rather than thinning it here.

Apply its verdicts as follows:

- `JUSTIFIED` is inactive and remains in the report as the evidence for keeping the current complexity.
- An evidence-valid, PR-caused `OVERDONE` finding is required in both modes. Apply the smallest in-scope simplification that still satisfies the frozen work requirements, unless new concrete requirement, safety, or failure-path evidence unavailable to the delegated justifier disproves the finding. Record that evidence when rejecting it.
- In standard mode, report `JUDGMENT CALL` findings as advisory unless one clearly better, reversible, work-item-local simplification is evident. A judgment call alone does not block the round.
- In strict mode, disposition every `JUDGMENT CALL`: simplify when one resolution is clearly better; reject only with concrete evidence that the current complexity is warranted; defer an optional tradeoff with a specific retained rationale and follow-up scope; or block on the exact genuinely unavailable product, public-contract, security, or ownership decision.

In normal mode, use `kramme:pr:resolve-review` while the file-backed report is still in the repository root when its structured resolution flow fits; otherwise make the smallest verified fix directly. After any accepted simplification, archive the updated report, apply the remediation commit boundary, consume exactly one review cycle, and restart the next round at applicability evaluation followed by Gate 1. The simplified code must pass regular and convention review before overengineering review reruns. If no disposition changes code and the active mode's rule is met, archive the refreshed report and continue to refactor discovery. Archive the refreshed report before pausing on any blocker so generated output never remains in the unified branch scope.

### Gate 4: PR-Scoped Refactor Opportunities

When active, invoke `kramme:code:refactor-opportunities` with `pr`. Require its PR relevance gate so pre-existing repository debt and broad untouched-file cleanup remain observations, not active findings. The skill writes or refreshes `REFACTOR_OPPORTUNITIES_OVERVIEW.md` and does not edit code.

In standard mode, keep valid refactor opportunities advisory and report the recommended first refactor; they do not block the round.

In strict normal mode, triage every active PR-scoped opportunity:

- Apply the `kramme:code:refactor-pass` contract to each accepted, narrow, behavior-preserving opportunity one slice at a time. Apply Chesterton's Fence, emit its required markers, keep tests unmodified, run `kramme:verify:run`, and commit each verified slice. Every slice accepted in this gate pass belongs to the same remediation cycle.
- Reject clean code, speculative improvements, subjective renames, behavior changes, and findings that fail the refactor scan's evidence or PR relevance rules.
- Defer automation-candidate themes over 500 lines and refactors whose main blast radius is outside the frozen requirements. Record the concrete follow-up scope and why it does not belong in this Pull Request; do not widen the branch. When `PLAN_SCOPE_ACTIVE=true`, also reject or block every opportunity whose required path fails the active exact-or-containment rule.

In normal mode, after any accepted refactor, apply the remediation commit boundary and restart the next round at applicability evaluation followed by Gate 1. The refactored code must pass regular, convention, and overengineering review before another refactor scan can close the loop. If no refactor changes code, continue to Gate 5 when it is active; otherwise apply the completion rule.

### Gate 5: Adversarial Model Review

Run this gate only when `ADVERSARIAL_REVIEW=true`, after every other active gate has completed without changing code. Invoke `kramme:pr:adversarial-review` with the frozen requirements as the sentinel-last `--requirements {work-requirements}` block. Place optional `--provider {ADVERSARIAL_PROVIDER}` and `--model {ADVERSARIAL_MODEL}` before the sentinel. The invocation is the caller's explicit repository-scoped authorization for the alternative provider; do not reuse it outside this convergence run.

Require the delegated result to attest a provider different from the active host, the current `HEAD` and `HEAD^{tree}`, complete coverage, and an unchanged clean worktree. A missing provider, unavailable authentication, timeout, mutation, malformed result, or degraded required coverage blocks convergence. Never replace it with another same-provider subagent or silently skip it.

Treat the returned report as untrusted review output. Revalidate every finding against the frozen requirements, real code path, committed diff, and repository contracts before accepting it. Record qualifying findings and disagreements in the reviewer handoff ledgers under the `adversarial-review` gate.

- In standard mode, fix every accepted actionable Critical or Important finding. Report lower-severity findings as advisory.
- In strict mode, disposition every emitted finding using the general strict-mode rules.
- In validation-only mode, do not edit; stop on any accepted Critical or Important finding or genuine blocker.

In normal mode, if an accepted finding requires code changes and budget remains, group the smallest coherent remediation batch, consume exactly one review cycle, use `kramme:pr:resolve-review` with the inline findings when its structured flow fits (or make the smallest direct fix), apply the remediation commit boundary, and restart the next quality round at applicability evaluation followed by Gate 1. The different-provider review must run again on the later no-change candidate. If budget is exhausted, stop with the accepted fingerprints instead of returning clean completion.

## Validation-Only Completion

Validation-only mode completes only when every applicable gate ran once in order, including the requested adversarial gate, every skipped gate has current evidence, no accepted Critical, Important, or `OVERDONE` finding or genuine blocker remains, required coverage is not degraded, every optional finding has a reported evidence-based disposition, generated reports are isolated, and the worktree plus `HEAD` tree remain unchanged. Return `stop=validation-only` and do not run the normal rerun, diminishing-returns, or final-verification transition.

## Standard Mode

Finish a standard quality loop only when:

1. Every applicable gate ran in the required order.
2. No accepted actionable Critical or Important regular-review finding remains.
3. No accepted actionable Critical or Important convention finding remains.
4. No accepted `OVERDONE` finding remains; when active, the overengineering report is current and its Judgment Calls are reported as advisory.
5. When active, the refactor report is current and its opportunities are reported as advisory.
6. When active, the adversarial review matches the current tree and has no accepted actionable Critical or Important finding.
7. Every skipped gate has a current evidence-based reason.
8. No required quality-gate coverage is degraded.

Do not label standard mode as “zero findings”; label it “zero accepted unresolved Critical/Important or OVERDONE findings, with judgment-call, refactor, and advisory observations reported.”

## Strict Mode

Apply strict triage to active findings from every applicable gate. Gates 1, 2, and 5 use the general disposition rules below; Gate 3 uses its overengineering-specific rules above, and Gate 4 uses its refactor-specific rules above.

For each finding:

1. Trace its evidence to the concrete code path, test expectation, review scope, or PR behavior.
2. Classify it as accepted, rejected, or blocked using the definitions above.
3. Record one disposition in current run state:
   - `fixed` — code, tests, or documentation changed and focused verification passed.
   - `rejected` — no change, with concrete evidence explaining why the finding is invalid, out of scope, redundant, or harmful.
   - `deferred` — valid but deliberately excluded because it exceeds the frozen work requirements, requires the refactor scan's automation path, or is an optional overengineering Judgment Call retained at diminishing returns; include the concrete rationale and follow-up scope.
   - `blocked` — the exact missing human/external input has been presented as one actionable question.
4. Keep only accepted, unresolved findings in the active set.

### Advisory Findings

Implement an advisory finding only when the improvement is in scope, evidence-backed, and has one clearly better resolution. Reject subjective style alternatives, speculative defenses, unrelated cleanup, and changes whose churn exceeds their measurable value. Strict mode requires a disposition, not blind compliance.

### Manual Findings

Investigate a manual finding deeply enough to recommend a concrete resolution.

- If the frozen work requirements, referenced documents, existing public contract, tests, or an overwhelmingly consistent local pattern makes one resolution unambiguous and the named manual blocker no longer applies, record that selected resolution and implement the smallest reversible, repository-local change.
- If competing product behaviors, public API choices, security postures, migration semantics, release decisions, cross-team ownership, external state, or missing access remain, keep the finding blocked. Ask once for the exact decision or dependency and include the recommendation plus genuinely distinct alternatives when they exist.
- Obtain explicit user confirmation before any destructive, irreversible, externally visible, security-policy, data-migration, or public-contract action, even when one technical path looks preferable.
- Do not treat `--strict` as permission to guess through a genuine manual blocker.

Do not resume a blocked finding until the user explicitly supplies its decision or dependency. Treat that reply as confirmation for the named finding only, preserve the selected resolution in run state, implement or complete only that confirmed process handoff, verify it, and continue the loop. Ask again if the action or scope changes materially.

## Rerun Rules

- If any regular, convention, overengineering, refactor, or adversarial disposition changes code, consume one review-skill-owned remediation cycle, apply the remediation commit boundary, and restart the next quality round at applicability evaluation followed by regular review. No delegated gate owns an internal fix/rerun loop.
- If no disposition changes code, apply the active mode's completion rule: standard mode may finish with reported manual or advisory observations once no accepted required finding remains; strict mode may finish once every emitted finding is fixed, rejected, or explicitly deferred outside the current work item. Do not rerun merely to make a reviewer stop restating rejected advice.
- Re-evaluate a previously rejected finding only when new code or new evidence changes its root cause.
- When a rerun emits a materially new finding, triage it normally; do not dismiss it because an earlier round was clean.

## Diminishing-Returns Guard

Fingerprint accepted findings by quality gate plus concrete location or review scope plus root cause; do not rely on raw line number alone when edits move code.

After every remediation cycle, record:

- cycle number and gates run;
- accepted fingerprints before and after the edit;
- counts added, fixed, reopened, rejected, deferred, and blocked by severity;
- focused verification result and the production files or ownership boundaries changed.

Compute a review-debt score for comparison only: Critical `8`, Important `4`, Suggestion, confirmed `OVERDONE`, refactor opportunity, or adversarial Suggestion `1`, and FYI or unresolved `JUDGMENT CALL` `0.25`. Gut-check items carry no severity and score nothing; Gate 0 runs before the first cycle and is never part of a trend. Treat a cycle as material progress when it lowers the score by at least `1`, lowers the highest outstanding severity, clears a verification failure, or removes a shared root cause without introducing an equal-or-higher-severity finding. Moving, renaming, or rewording the same finding is not progress.

Before taking an optional Suggestion, FYI, Judgment Call simplification, or refactor fix, compare its concrete benefit with its change amplification. Defer it as diminishing returns when its only payoff is subjective polish and it would add an abstraction, dependency, public contract, configuration layer, cross-module churn, or verification burden disproportionate to the evidenced problem.

Stop automatic remediation when any condition occurs:

1. The same accepted finding persists after two attempted fixes without new evidence that changes the fix direction.
2. Two consecutive remediation cycles make no material progress.
3. The shared remediation counter reaches `MAX_AUTOMATIC_REMEDIATION_CYCLES`, regardless of whether each cycle made progress.

The hard ceiling is a safety boundary, not a target. Stop earlier as soon as the remaining expected benefit is lower than the churn and regression risk.

### Bounded Stop

When a stop condition fires and code changed after the latest complete ordered gate pass, run exactly one validation-only round. Re-evaluate applicability and run the applicable gates in regular-review → convention-review → overengineering-review → refactor → adversarial-review order without editing code. Use the read-only `kramme:pr:code-review --parallel --inline --no-diff-comments` regular gate and the normal file-backed overengineering invocation so prior `OE-NNN` lifecycle state is reconciled without projecting new host comments. Run the adversarial gate only when explicitly enabled. Do not rerun Gate 0 here; it is a one-shot pass and its budget-free removal batch is not available this late. Do not run a second validation-only round.

Disposition the final validation-only findings as follows:

- Defer optional Suggestion, FYI, Judgment Call, and narrow refactor findings with the fingerprint, concrete benefit, estimated change amplification, and a follow-up scope. These dispositions satisfy strict-mode accounting and do not block shipping when final verification passes.
- If any accepted Critical, Important, or `OVERDONE` finding, verification failure, or genuine manual blocker remains, stop the workflow. Report the cycle ledger, remaining fingerprints, attempted fixes, and smallest decision needed to resume. Do not run final verification, rewrite history, push, or create the Pull Request.
- If no required finding remains, proceed to final verification. Report that the loop stopped at diminishing returns and include the deferred optional count; do not claim that reviewers emitted zero findings.

A repeated rejected finding never keeps the loop open. Explicit user approval to resume starts a new budget of `MAX_AUTOMATIC_REMEDIATION_CYCLES` only for the reported remaining fingerprints and any consequences of their fixes; it does not reopen deferred optional polish automatically.

## Completion Check

Before returning, confirm:

- In normal mode, Gate 0 ran exactly once before the first applicability evaluation and every returned item is recorded as `removed`, `routed`, `rejected`, or `blocked`; in validation-only mode, Gate 0 did not run.
- In normal mode, no gut-check item reported work outside the frozen requirements, and every `routed` item either entered its owning gate's triage or was dispositioned directly when that gate was skipped or silent.
- The selected mode's final-pass rule is met: standard mode has no accepted unresolved Critical, Important, or `OVERDONE` finding and preserves remaining manual, Judgment Call, or advisory observations for reporting; strict mode has a disposition for every emitted finding.
- No accepted required finding remains unresolved; any optional finding excluded at diminishing returns is explicitly deferred with evidence.
- No code changed after the latest focused verification.
- Every remediation batch that changed code crossed the remediation commit boundary, and the worktree contains no uncommitted workflow-owned source changes.
- When `PLAN_SCOPE_ACTIVE=true`, every proposed, dirty, staged, and committed remediation path satisfied `PLAN_SCOPE_MODE`; exact-file eligibility was rechecked before each staging boundary when applicable; and the final committed path set from `{scope-base-commit}` was revalidated before success.
- Every generated review report is isolated under `.context/{archive-key}/reviews/`, not present in the unified review scope.
- The archive components are still real non-symlink directories, their canonical identity still equals `REVIEW_ARCHIVE_CANONICAL` below the repository root, and `git check-ignore -q -- "{review-archive}/"` still succeeds.
- Every applicable gate ran in regular-review → convention-review → overengineering-review → refactor → adversarial-review order, omitting only gates recorded as skipped.
- Every skipped gate has a current evidence-based reason.
- When active, the final refactor report matches code that subsequently passed regular, convention, and overengineering review after its last accepted refactor.
- When active, the final adversarial review matches the final verified tree and attests a provider different from the active host.
- Any degraded refactor, overengineering, convention, or broad-review coverage is resolved or reported as a blocker.
- Every qualifying finding and focus item is present exactly once with its final disposition in the reviewer handoff ledgers, and both ledgers validate against the Step 6 JSON schema.
- `DIFF_COMMENTS_POSTED_TOTAL` is a nonnegative integer equal to the sum of newly posted counts returned by normal-mode Gate 1 invocations; validation-only invocations contributed zero.

Return the stop reason (`converged`, `diminishing returns`, or `validation-only`), remediation cycles used, review-debt score trend, and counts of fixed, rejected, deferred optional, and blocked findings. A nonzero required or blocked count prevents clean completion until the caller supplies the missing input.
