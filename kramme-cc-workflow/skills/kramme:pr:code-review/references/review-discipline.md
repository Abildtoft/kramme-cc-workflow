# Review discipline

Authoritative finding and safety guidance for spawned review agents and the orchestrator's aggregation and final-check passes. Both the standard and Team Mode workflows read this file before launching reviewers, pass its reviewer-facing rules to every reviewer, and use its aggregation rules before posting the report.

## Shared working tree

Reviewers read one working tree that is shared with every other reviewer in the same run, and that tree usually holds uncommitted work. A file a reviewer edits stops being the code under review and becomes false evidence for everyone else: the next reviewer reads the mutation, cannot see who made it, and reports it as a defect in the author's change. Findings fabricated this way are indistinguishable from real ones because they cite a real file and a real line.

**Every spawned reviewer is read-only.** This is not advice about scope; it is a hard constraint on the tools a reviewer may use.

- Never create, edit, delete, move, or rename a file. Never stage, commit, stash, reset, checkout, or apply a patch.
- Never run a command that rewrites files as a side effect: formatters, linters with `--fix`, codemods, dependency installs, build steps that write into the tree, or test runners that update snapshots, fixtures, or generated golden files.
- Read-only verification is encouraged: reading files, `git diff`, `git log`, `git show`, `grep`, and search tools all leave the tree untouched.
- When a fix requires a code change, put the change in the finding as recommended text. Describing the edit is the deliverable; applying it is `/kramme:pr:resolve-review`'s job.
- A reviewer that genuinely must execute something that writes has to run alone or in an isolated worktree. It must never do so inside a parallel batch on the shared tree.

The orchestrator captures a working-tree manifest before launching reviewers and again after collecting their findings (`${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh`). A difference means the tree changed mid-review, so:

- Re-read every path that differs, from disk, and re-verify each finding that cites one of those paths against the current text.
- Drop any finding whose cited code does not reproduce. Do not downgrade it to `UNVERIFIED` and keep it — a finding formed against text that no longer exists is a fabrication, not a weak observation.
- Report the mutated paths in `## Coverage Status` so the human can inspect them. Never revert or clean them automatically; uncommitted work in that tree may be the user's, not a reviewer's.

The manifest covers tracked paths differing from `HEAD` plus untracked, non-ignored paths. It does not cover ignored files, so build output and caches written by a stray command stay invisible to it.

## Reviewer calibration

Apply these rules before making a finding or recommending a fix:

- Match the existing practices in the touched files and nearby code. A defensive check, validation layer, retry, log, catch block, or runtime type guard is appropriate only when it fits the local style, an explicit project rule, or a concrete failure path introduced by the review scope.
- If the codebase relies on framework guarantees, schema validation, type narrowing, generated types, trusted internal callers, or centralized error boundaries, do not require redundant local guards unless this diff crosses a trust boundary or weakens that guarantee.
- If the local practice looks risky but the PR does not introduce or worsen it, label it `NOTICED BUT NOT TOUCHING` instead of making it a required finding.
- If the reviewer cannot prove the failure path from the diff, label it `UNVERIFIED` or `CONFUSION` and keep the recommendation optional.
- Security and data-loss risks may override local style, but the finding must name the concrete exploit path, information disclosure, corruption path, or user-visible failure that justifies stronger defensive handling.

### Overengineering check

- Judge the diff and every recommended fix against the simplest solution that fully and reliably meets the specific requirements and fits the existing architecture and established patterns.
- Flag complexity the current task does not require: premature abstractions, unnecessary layers or indirection, speculative configuration or extension points, hypothetical edge-case handling, and functionality beyond the change's scope. Name the concrete simpler alternative.
- Do not flag handling of real and likely edge cases as overengineering. Robustness for failure paths introduced by the review scope is required work.
- Overengineering findings default to Suggestion with action class `advisory`. Classify one as Important only when the unnecessary complexity has concrete present cost: it conceals or invites a bug, materially obscures the change, or creates a public surface other code must adopt.
- Recommend the smallest direct fix supported by the evidence; never add abstractions, layers, or hypothetical edge-case handling beyond it.
- Label every finding produced by this check with `OVERENGINEERING` on its own line so aggregation applies cleanup precedence independently of the source reviewer.

## Review speed norm

One business day is the **maximum** time a PR should sit waiting on review, not the target. If the review slips past a day, the diff stales, the author context-switches, and the eventual review skews toward nitpicks because the reviewer is working against the PR instead of with the author.

## Output markers

Use these markers so the user (and downstream tooling) can skim status at a glance. They are a **plugin-wide convention** for Addy-ported skills. Use them verbatim (uppercase, no decoration), one marker per line.

- **UNVERIFIED** — a finding asserted but not directly confirmed against the code. `UNVERIFIED: agent flagged a race on cache invalidation; I didn't trace all callsites`.
- **NOTICED BUT NOT TOUCHING** — a pre-existing issue or out-of-scope observation surfaced during review. `NOTICED BUT NOT TOUCHING: the whole retry helper swallows errors, but that's outside this PR`.
- **CONFUSION** — the reviewer can't decide whether something is a bug without more context. `CONFUSION: the nullable return from getUser() is new here; is None a valid result or a missing check?`
- **MISSING REQUIREMENT** — spec or intent is ambiguous; a product decision is needed before the review can complete. `MISSING REQUIREMENT: no guidance on how to handle the duplicate-email case — ask before approving`.
- **OVERENGINEERING** — the finding comes from the Overengineering Check and must receive cleanup-dimension precedence regardless of which reviewer emitted it. Put `OVERENGINEERING` on its own line in the raw finding.

## Finding schema

Every active finding must include these fields before it is posted:

| Field | Values | Purpose |
| --- | --- | --- |
| Finding ID | `CR-001`, `CR-002`, ... | Gives downstream workflows a stable source identifier for handoffs and resolution summaries. |
| Severity | Critical, Important, Suggestion, FYI | Describes merge impact. Use the severity prefix grammar below. |
| Location | `path/to/file:line`, `review-scope`, or `PR description` | Lets downstream workflows distinguish auto-fixable code findings from manual/process findings. |
| Confidence | `0-100` | States how directly the reviewer traced the issue. During the transition, map reviewer tiers as `high=80`, `medium=60`, `low=30`. |
| Action class | `gated_auto`, `manual`, `advisory` | Separates urgency from safe ownership. |
| Owner | resolver, author, maintainer, reviewer, unknown | Names who can act next. |
| Evidence | concrete trace, location, reproduction, failed expectation, or `UNVERIFIED` reason | Prevents unsupported findings from becoming gatekeeping. |
| Relevance status | PR-caused, pre-existing/out-of-scope, previously addressed, unresolved pending validation | Preserves the validator's classification without replacing the raw finding. |
| Resolution status | open, addressed, deferred, acknowledged, skipped | Records finding lifecycle; new active findings start as `open`. |
| Manual blocker | product/UX/architecture/maintainer decision, missing/contradictory requirement, PR-description/process update, cross-team/external ownership, unresolved contradiction, incomplete trace/UNVERIFIED, or dead-code approval | Required only for manual Critical/Important findings. Names why `/kramme:pr:resolve-review` must not act automatically. |
| Next human decision | one concrete decision, approval, clarification, access grant, or verification step | Required only for manual Critical/Important findings. Makes the manual follow-up actionable instead of a silent skip. |

Raw reviewers leave `Finding ID` blank; the aggregator assigns stable `CR-001`, `CR-002`, ... IDs after dedupe. Treat raw reviewer action classes as provisional because the aggregator owns the final action class, owner, and manual-follow-up fields.

## Severity prefix grammar

Label every finding within each bucket using Addy's prefixes so downstream tooling can parse severity at the finding level, not only the section level:

| Prefix | Meaning | Bucket |
| --- | --- | --- |
| _(no prefix)_ | Required | Important |
| **Critical:** | Blocks merge | Critical |
| **Nit:** | Optional; reviewer preference | Suggestion |
| **Optional:** / **Consider:** | Suggested, not required | Suggestion |
| **FYI** | Informational; no action expected | Strengths |

The report section headers (`## Critical Issues`, `## Important Issues`, `## Suggestions`) remain — the prefix is the finer-grained label inside each section.

## Dead-code ask shape

When `kramme:removal-planner` flags removable code, emit Addy's ask-shape verbatim so removals are never presented as silent deletions:

> `DEAD CODE IDENTIFIED: [comma-separated list]. Safe to remove these?`

This applies whether the finding lands in Critical, Important, or Suggestions — the ask shape is a display convention that keeps every deletion visible in the report, independent of action class. For a high-confidence (`gated_auto`) dead-code finding, the question is retained only for visibility: `/kramme:pr:resolve-review` treats it as pre-approved and does not wait for an answer. The interrogative wording acts as an approval gate only for low-confidence (`manual`) findings.

### High-confidence dead code is auto-removable

Only **low-confidence** dead-code findings require the author's or maintainer's answer before deletion. A dead-code finding is **high-confidence** when all of these hold:

- `Confidence` is at least 70.
- The reviewer traced every reference and callsite (including dynamic imports, reflection, string-based config references, and external/public-API consumers) and found none remaining — the `kramme:removal-planner` **Safe to Remove Now** tier, not **Requires Investigation**.
- The finding carries no `UNVERIFIED` marker, and removal is a mechanical deletion with an obvious, local fix path.

A high-confidence dead-code finding is `gated_auto` (or, in Suggestions, passes the safe-advisory test): `/kramme:pr:resolve-review` may delete it without a separate approval. A dead-code finding that misses any bar above is **low-confidence** and stays `manual` with the `dead-code approval` blocker until the ask is answered.

Because `high` maps to 80, an auto-removable dead-code finding usually sits in the 60-89 confidence band rather than 90-100, and that is intended. The bands under **Confidence and merge rules** below score how fully a finding's _runtime behavior_ was traced; dead-code removal safety instead turns on _static reference completeness_ — no remaining references anywhere. A removal can be fully traced against every reference yet still carry residual dynamic-reference risk, so a complete reference trace at `Confidence` at least 70 — not 90 — is the intended auto-removal bar here.

## Action classes

- **`gated_auto`** — Code-backed Critical or Important finding with a concrete file/line, an unambiguous fix direction, and enough confidence for `/kramme:pr:resolve-review` to attempt it. Do not use this for PR-description drift, product decisions, missing requirements, low-confidence dead-code removals still awaiting approval (see **High-confidence dead code is auto-removable** above), or broad process issues.
- **`manual`** — The finding needs a human decision before a fix is safe, for one of the reasons in the manual blocker tests below. Manual findings may still block merge when impact is high, but they must name the manual blocker and next human decision. `manual` is the exception, not the safe default: "a human should look at this" or "the fix touches important code" is not a blocker.
- **`advisory`** — Optional polish, FYI, low-confidence observation, or improvement idea. Advisory findings do not block merge and are not counted as auto-resolution candidates; `/kramme:pr:resolve-review` applies its own safe-advisory test when deciding whether to pick one up.

## Severity and action-class compatibility

- Critical and Important findings may use only `gated_auto` or `manual`; they must not use `advisory` because those buckets represent blocking or recommended work.
- Suggestions and FYI observations use `advisory`; do not mark optional work as `manual` just because a human would perform it.
- If a finding feels optional, put it in Suggestions instead of keeping it in Critical/Important with `advisory`.
- Critical or Important PR-caused findings default to `gated_auto` with owner `resolver` when they have a concrete `path/to/file:line` location, confidence at least 70, concrete evidence, and a clear local fix path.
- If a Critical or Important finding cannot be auto-resolved, keep it `manual` only with a named manual blocker and a specific next human decision.
- If a manual Critical/Important finding has a concrete file location, confidence at least 70, and no named manual blocker, reclassify it to `gated_auto`.

## Manual blocker tests

Keep a Critical or Important finding as `manual` only when at least one blocker below applies under its narrow test:

- **Product/UX/architecture/maintainer judgment** — only when two or more materially different fix directions exist with different user-visible behavior, API contracts, or data semantics, and the finding names those competing options. Choosing an implementation detail (which guard, a name, an error message, which nearby pattern) is not maintainer judgment.
- **Missing or contradictory requirement** — only when the correct behavior genuinely cannot be inferred from the diff, nearby code, tests, or the PR description. Merely undocumented behavior with one obvious reading is not a missing requirement.
- **Non-code state** — the finding is about `PR description`, branch/review process, or release coordination.
- **Cross-team/external ownership** — the fix needs cross-team ownership, external-system access, credentials, or human-only verification before implementation.
- **Unresolved contradiction** — between reviewers or code paths.
- **Incomplete trace/`UNVERIFIED`** — only after the reviewer attempted to complete the trace and verification requires resources the resolver also lacks (runtime-only behavior, external systems, production data). A merely skipped trace is not a blocker; complete it or lower confidence and downgrade.
- **Dead-code approval** — the finding is a **low-confidence** dead-code removal per **High-confidence dead code is auto-removable** above (confidence below 70, references not fully traced, `UNVERIFIED`, or not a mechanical deletion) and needs the author's or maintainer's answer before deletion. A high-confidence, fully traced dead-code finding does not qualify for this blocker; classify it `gated_auto`.

**Tiebreaker:** when a finding plausibly fits both `gated_auto` and `manual`, choose `gated_auto` — resolver fixes land as reviewable local commits with validation and rollback, so a wrong `gated_auto` costs one rejected patch, while a wrong `manual` silently removes the finding from automation. A finding matching any blocker above does not "plausibly fit both"; in particular, a **low-confidence** dead-code finding stays `manual` until the ask is answered, while a **high-confidence, fully traced** dead-code finding (per **High-confidence dead code is auto-removable** above) is `gated_auto`.

**Manual-heavy re-test:** if more than half of the Critical/Important findings are `manual`, re-test each one against the blockers above once. If every manual finding passes its blocker test, keep them all — a majority-manual report is then correct (release-coordination reviews are often legitimately manual-heavy).

## Confidence and merge rules

- **90-100 confidence** means the reviewer traced the behavior to the changed code, reproduced it, or tied it to a concrete failing expectation.
- **60-89 confidence** means the issue is strongly indicated by the diff but still depends on a nearby assumption, framework behavior, or untested runtime state.
- **0-59 confidence** means the issue is plausible but not traced. Keep the `UNVERIFIED` marker visible and avoid merge-blocking language unless another reviewer proves the same risk.
- Merge duplicate findings only when they identify the same concrete location or review scope and the same root cause.
- Keep the highest severity across merged duplicates, combine their evidence, and preserve every source reviewer.
- Promote confidence only when independent reviewers agree on the same issue, not merely the same broad concern.
- Do not merge findings that only share a broad theme but require different fixes.
- Keep contradictory findings separate and record the conflict as `CONFUSION` or `MISSING REQUIREMENT` with action class `manual`; use Critical or Important only when its impact blocks approval.
- A retained `UNVERIFIED` finding stays below 60 confidence and uses `manual` or `advisory` unless concrete evidence separately proves the risk.

## Correctness and security precedence

Apply this pass before emphasis and action-class normalization:

- Treat findings from `kramme:lean-reviewer` and cleanup-mode `kramme:code-simplifier` as cleanup-dimension findings (`lean`, `refactor`, `simplify`). Treat findings labeled `OVERENGINEERING` by any reviewer the same way.
- Treat unresolved Critical or Important findings from `kramme:code-reviewer`, `kramme:silent-failure-hunter`, `kramme:pr-test-analyzer`, `kramme:type-design-analyzer`, `kramme:injection-reviewer`, `kramme:auth-reviewer`, `kramme:data-reviewer`, and `kramme:logic-reviewer` as higher-priority correctness/security findings while active.
- A cleanup finding collides when its recommendation would remove or weaken validation, auth, authorization, injection protection, data protection, error propagation, test coverage, type invariants, or the concrete fix path of an unresolved correctness/security finding.
- Do not promote a colliding cleanup finding, classify it as Critical or Important, or assign it `gated_auto`. Either drop it as redundant or unsafe, or keep it as an advisory Suggestion with evidence: `Blocked by the matching correctness/security finding; revisit after that finding is resolved.` After final IDs are assigned, replace the provisional blocker with the blocking `CR-XXX` ID.
- Preserve the correctness/security finding unchanged. Append cleanup-collision context only when it helps the resolver avoid an unsafe cleanup path.
- If the cleanup remains valid after the higher-priority fix, keep it as an advisory Suggestion and name the dependency. If it requires choosing a different correctness/security fix, record a `CONFUSION` manual finding instead of silently choosing the cleanup path.

## Common rationalizations

Watch for these excuses — they signal the review is slipping into low-value territory.

| Excuse | Reality |
| --- | --- |
| "It's just a nit, skip it." | Nits compound across reviews; ship the `Nit:` prefix and let the author decide, or the diff drifts on every PR. |
| "This doesn't block merge, so it's fine." | "Doesn't block" is not "good." Approve only if the change definitely improves overall code health. |
| "AI wrote it, and the tests pass." | AI-generated code needs more scrutiny, not less — it's confident even when wrong. Read the diff as if a new hire wrote it under deadline. |
| "We can clean this up in a follow-up." | Follow-ups are negotiable; the diff on screen is not. Land safe cleanup now or mark it clearly, unless it collides with an unresolved correctness/security finding. |
| "I'll re-review when they push again." | Re-review is a checkpoint, not a finding delivery mechanism. Surface every finding on the first pass or they rot across round-trips. |
| "This will make it easier to extend later." | Speculative flexibility is a real cost today and a guess about tomorrow. Recommend the simplest change that meets the actual requirements; an abstraction earns its keep when the second caller arrives. |

## Red flags — STOP

If any of these are true, pause and re-scope the review before posting it:

- Every finding you're about to post is marked **Critical:** — the bucket has lost meaning; re-triage.
- The review is older than the PR (you've been reviewing longer than the author spent writing).
- You're rewriting the PR in your head instead of reviewing the diff in front of you.
- You're about to edit a file, apply a fix, or run a formatter or `--fix` to check whether your recommendation works. The tree is shared; describe the change instead.
- You're flagging style issues the project doesn't enforce anywhere else.
- You're requiring defensive checks, logging, retries, or validation layers that nearby code intentionally does not use, and you cannot point to a concrete new failure path.
- You're asking for flexibility, configurability, abstraction, or edge-case handling for scenarios the requirements don't include — or a recommended fix adds a layer the smallest direct change doesn't need.
- You're approving because the CI is green, not because the change definitely improves overall code health.
- A dead-code finding is phrased as an instruction (`"delete X"`) instead of the ask shape (`DEAD CODE IDENTIFIED: X. Safe to remove these?`).
- You have no `FYI` in the Strengths section — a review with zero positive observations is usually miscalibrated, not comprehensive.

## Verification checklist

Before posting the review, confirm:

- [ ] The post-review working-tree manifest matches the pre-launch capture; if it does not, findings citing the differing paths were re-verified against disk, unreproducible ones were dropped, and `## Coverage Status` names the mutated paths.
- [ ] Every finding has a severity prefix (`Critical:`, `Nit:`, `Optional:`, `Consider:`, `FYI`, or no prefix for Required).
- [ ] Every active finding has a stable Finding ID (`CR-001`, `CR-002`, ...).
- [ ] Every active finding includes Location, Confidence, Action class, Owner, and Evidence.
- [ ] Every manual Critical/Important finding includes `Manual blocker` and `Next human decision`.
- [ ] Manual Critical/Important findings have a concrete blocker; otherwise they were reclassified to `gated_auto` or downgraded to advisory.
- [ ] If more than half of the Critical/Important findings are `manual`, each one was re-tested once against the manual blocker tests; findings whose blocker held stayed `manual` (a majority-manual report is then correct).
- [ ] The Auto-resolution Readiness section counts eligible `gated_auto` Critical/Important findings and manual Critical/Important findings by blocker reason.
- [ ] Dead-code findings use the verbatim ask shape `DEAD CODE IDENTIFIED: [list]. Safe to remove these?`
- [ ] The Approval Standard line appears: _"Approve if the change definitely improves overall code health."_
- [ ] Pre-existing or out-of-scope observations are labeled `NOTICED BUT NOT TOUCHING`.
- [ ] Every emphasized dimension in `--emphasize` actually produced findings in this review (or you noted that it didn't).
- [ ] No finding is presented as certain when the reviewer didn't trace it — those are labeled `UNVERIFIED`.
- [ ] Every finding produced by the Overengineering Check is labeled `OVERENGINEERING` before cleanup precedence is applied.
- [ ] No recommended fix introduces abstractions, layers, or hypothetical edge-case handling beyond what its evidence requires, and overengineering findings without concrete present cost sit in Suggestions as `advisory`.
- [ ] Cleanup-dimension findings (`lean`, `refactor`, `simplify`) that collide with unresolved correctness/security findings were suppressed or kept only as advisory suggestions blocked by the higher-priority finding.
- [ ] Kept cleanup-collision suggestions name the final blocking `CR-XXX` ID after finding IDs are assigned.
- [ ] `gated_auto` appears only on code-backed findings with a concrete location and a clear fix path.
- [ ] `advisory` appears only on Suggestions or FYI observations, never on Critical or Important findings.
