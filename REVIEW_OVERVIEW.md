# PR Review Summary

Review producer: kramme:pr:code-review

Review status: COMPLETE Review execution: /tmp/kramme-pr-review-run.524xUB Review run: 82b6fe08-a703-44fd-88da-dc8f3011b90a Execution evidence: self-attested; validated locally

## Coverage Status

- Normalized aspects: `all`
- Base: `refs/remotes/origin/main` (merge base `b09c6d2a7df4f20d3d0b8a0482341e85b2d15e4d`)
- Unified scope: 48 changed paths; committed, staged, unstaged, and untracked scope reviewed.
- Working-tree integrity: PASS; `@head` stayed `b525e14243a86e962264146b98d5d617f1623a3c`, path-record diff empty.
- Reviewer jobs: code-reviewer succeeded; silent-failure-hunter succeeded; deslop-reviewer succeeded; pr-test-analyzer succeeded; comment-analyzer succeeded; type-design-analyzer succeeded; removal-planner succeeded; lean-reviewer succeeded; code-simplifier succeeded; performance-oracle succeeded; injection-reviewer succeeded; auth-reviewer succeeded; data-reviewer succeeded; logic-reviewer succeeded.
- Post-processing: integrity succeeded; relevance succeeded; slop-meta succeeded; previous-context succeeded; aggregation succeeded; final-check succeeded.
- Applicability: comments, tests, errors, types, code, slop, security, performance, removal, lean, refactor, and simplify were applicable and executed. No dimension was excluded.
- Focused verification: converter Node contracts, the 17-case converter Bats suite, and `make -C kramme-cc-workflow test-smoke` passed (68 Python tests, 12 bootstrap Bats cases, and 8 Node tests).

## Relevance Filter

- 12 findings retained as PR-caused after deduplication.
- 0 findings filtered as pre-existing or out-of-scope.
- 0 findings filtered as previously addressed.
- 0 findings carried forward from the previous review.

## Previous Review Context

- Source: `REVIEW_OVERVIEW.md`
- Parseable prior findings: 6
- Previously addressed filtered: 0
- Open/deferred/acknowledged/skipped carried forward: 0
- Open/deferred/acknowledged/skipped not carried forward: 6 (different files and root causes)
- All six prior findings concern the earlier PR-creation attachment workflow and are absent from this converter/plugin scope.

## Auto-resolution Readiness

- 0 Critical findings remain eligible for `$kramme:pr:resolve-review`.
- 0 Important findings remain eligible for `$kramme:pr:resolve-review`.
- 1 Important finding is deferred and requires maintainer/release-policy follow-up.
- Manual blockers: release publication provenance and branch/tag protection (1).
- Promoted findings: 0.

## Critical Issues (0 found)

None.

## Important Issues (8 found)

- **Important: marketplace ownership is inferred from a mutable name.**
  - Finding ID: CR-001
  - Location: `kramme-cc-workflow/scripts/convert-plugin.js:198-225`, `kramme-cc-workflow/scripts/convert-plugin/codex-cli.js:127-145`
  - Confidence: 95
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Added a converter-owned marketplace marker, validated marker identity before local replacement/uninstall, and validated the registered marketplace source before remote removal. Added foreign same-name coverage.
  - Evidence: `assertReplaceableMarketplaceRoot` accepts any non-empty root whose marketplace manifest has the expected name, then replacement/uninstall recursively removes it. `unregisterCodexPlugin` also removes registrations by name before local ownership is validated. A same-name foreign marketplace or `--marketplace-dir` can lose unrelated plugins/files or a trusted remote registration.
  - Recommended fix: require a converter-owned marker and expected one-plugin shape/source before any local deletion or remote unregister; validate ownership before unregistering and refuse mismatches.

- **Important: marketplace conflict replacement has no rollback.**
  - Finding ID: CR-002
  - Location: `kramme-cc-workflow/scripts/convert-plugin/codex-cli.js:80-103`
  - Confidence: 94
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Removed destructive conflict replacement entirely. A marketplace name conflict is now reported with the registered source and leaves the existing registration untouched.
  - Evidence: on `already added from a different source`, the code removes the existing marketplace and retries. If the retry fails, the previous registration and its installed plugins are already gone.
  - Recommended fix: inspect and validate the existing source, require explicit replacement where appropriate, and preserve/restore the old registration if re-add fails.

- **Important: legacy cleanup deletes global multi-plugin and recovery artifacts.**
  - Finding ID: CR-003
  - Location: `kramme-cc-workflow/scripts/convert-plugin/legacy-install-cleanup.js:168-171`
  - Confidence: 96
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Legacy cleanup now edits only the requested plugin record, preserves other plugin state, and leaves shared lock, staging, transaction, and active native paths intact.
  - Evidence: cleanup for one plugin removes the global state/manifests plus `.kramme-install-lock`, `.kramme-install-staging`, and `.kramme-install-transactions` in both homes. The old state supports multiple plugins and the old transaction layer owns lock/recovery semantics, so unrelated outputs or an active recovery journal can be orphaned or destroyed.
  - Recommended fix: update only the requested plugin record, remove shared state/artifacts only when no records remain, and preserve active or unverified transaction artifacts through the old ownership/staleness checks.

- **Important: manifest-only legacy installs are skipped.**
  - Finding ID: CR-004
  - Location: `kramme-cc-workflow/scripts/convert-plugin/legacy-install-cleanup.js:31-34,48-50,119`
  - Confidence: 93
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Legacy detection now recognizes the target per-plugin manifest even when the shared state file is absent; manifest-only cleanup is covered by a regression test.
  - Evidence: `hasLegacyInstall` checks only `.kramme-install-state.json`, while the reader and documentation support per-plugin manifests. After an interrupted install leaves only a manifest and copied skills, cleanup returns `absent` and leaves duplicate legacy output.
  - Recommended fix: detect the target manifest (or read entries before the early return) and add a state-missing/manifest-present regression test.

- **Important: malformed legacy metadata is deleted after a zero-entry cleanup.**
  - Finding ID: CR-005
  - Location: `kramme-cc-workflow/scripts/convert-plugin/legacy-install-cleanup.js:90-103,112-174`
  - Confidence: 95
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Cleanup fails closed when ownership metadata is unreadable without recoverable entries, preserves malformed records, and removes only validated records.
  - Evidence: unreadable or invalid records are logged and treated as null; after confirmation, cleanup removes the record/artifact directories and reports success even when no legacy paths were recovered. Copied skills/helpers remain with no ownership metadata.
  - Recommended fix: fail closed when records cannot be parsed, preserve metadata for recovery, and never report successful cleanup with unrecovered entries.

- **Important: uninstall reports success after Codex removal failures.**
  - Finding ID: CR-006
  - Location: `kramme-cc-workflow/scripts/convert-plugin/codex-cli.js:127-145`, `kramme-cc-workflow/scripts/convert-plugin.js:113-123`
  - Confidence: 96
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Uninstall validates the registered source, suppresses only explicit missing-registration responses, and propagates other Codex removal failures before deleting local output.
  - Evidence: every nonzero `codex plugin remove` or marketplace-remove status is only warned; uninstall then deletes the local marketplace and prints `Uninstalled`. Permission/configuration failures can leave the plugin registered and cached while the user is told it is gone.
  - Recommended fix: suppress only explicit not-found statuses, propagate other failures, and remove local files/claim success only after remote removal succeeds.

- **Important: install deletes the legacy install before native install succeeds.**
  - Finding ID: CR-007
  - Location: `kramme-cc-workflow/scripts/convert-plugin.js:85-96`
  - Confidence: 95
  - Action class: `gated_auto`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Native marketplace build and Codex registration now complete before legacy cleanup; registration-failure coverage confirms legacy output remains recoverable.
  - Evidence: `runInstall` confirms and runs legacy cleanup before marketplace build/registration. A build failure, missing Codex CLI, or plugin-add failure leaves no working native install and no recoverable legacy copy.
  - Recommended fix: preflight/build/register before destructive cleanup, or retain a recoverable legacy record and roll back on failure; add failure-path tests with seeded legacy output.

- **Important: the publication workflow can publish arbitrary refs with write access.**
  - Finding ID: CR-008
  - Location: `.github/workflows/publish-codex-plugin.yml:3-10,31-50`
  - Confidence: 86
  - Action class: `manual`
  - Owner: maintainer
  - Relevance status: PR-caused
  - Resolution status: deferred
  - Action taken: Deferred pending the maintainer decision on restricting manual publication to main and requiring v\* tags to reference commits reachable from main.
  - Evidence: any `v*` tag or `workflow_dispatch` run checks out its selected ref, builds executable hooks/skills, and force-pushes `codex-plugin` with `contents: write`. A write-capable collaborator can publish unreviewed source unless repository protections constrain the trigger.
  - Recommended fix: require tag commits to be reachable from protected `main`, restrict manual dispatch to `main`/protected release refs, and use an environment or equivalent approval gate for publication.
  - Manual blocker: Release publication currently accepts arbitrary v\* tags and workflow_dispatch refs with contents:write.
  - Next human decision: Choose whether manual publication must be restricted to main and whether v\* tags must point to commits reachable from main.
  - Recommended resolution: Restrict workflow_dispatch to main, fetch the protected main ref, and reject v\* tags whose commit is not an ancestor of main before publishing.
  - Alternatives:
    - Defer policy: Keep the current workflow and track publication provenance as a separate release-hardening change.
  - To proceed: Reply naming CR-008 and the chosen option, then rerun `$kramme:pr:resolve-review`.

## Suggestions (4 found)

- **Suggestion: update the stale Codex output path in the portability matrix.**
  - Finding ID: CR-009
  - Location: `kramme-cc-workflow/docs/agent-portability.md:25`
  - Confidence: 95
  - Action class: `advisory`
  - Owner: author
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Updated the portability matrix to describe the temporary review snapshot or provider-specific cloud artifact rather than the obsolete ~/.codex/skills path.
  - Evidence: the row still says the adversarial review output is a converted directory under `~/.codex/skills`, while this diff makes native plugin cache output the active Codex surface and calls the old directory legacy.
  - Recommended fix: describe the native cache path or the current alternative-provider artifact precisely.

- **Suggestion: remove the stale `smol-toml` dependency.**
  - Finding ID: CR-010
  - Location: `kramme-cc-workflow/package.json:25`
  - Confidence: 98
  - Action class: `advisory`
  - Owner: author/maintainer
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Removed the unused smol-toml dependency from the converter package manifest.
  - Evidence: `smol-toml` is the only remaining dependency for deleted TOML/config/transaction code; repository search finds no source/test import, while the root package and lockfile already removed it.
  - Recommended fix: DEAD CODE IDENTIFIED: kramme-cc-workflow/package.json dependency "smol-toml". Safe to remove these? Remove it from the nested manifest and verify converter metadata/tests.

- **Suggestion: keep `stats` independent of install-only Codex CLI loading.**
  - Finding ID: CR-011
  - Location: `kramme-cc-workflow/scripts/convert-plugin.js:248-264,323`
  - Confidence: 90
  - Action class: `advisory`
  - Owner: resolver
  - Relevance status: PR-caused
  - Resolution status: addressed
  - Action taken: Made home and confirmation option resolution install/uninstall-only so build and stats remain independent of install-only Codex modules.
  - Evidence: `validateOptions` calls `resolveHomeRoots` for every command, which requires `codex-cli` even for `stats` and `build`; the module README promises `stats` never loads Codex CLI.
  - Recommended fix: resolve home/confirmation options only for install/uninstall or make validation command-specific.

- **Suggestion: confirm the version contract before relying on path-safe tokens.**
  - Finding ID: CR-012
  - Location: `kramme-cc-workflow/scripts/convert-plugin/codex-transformer.js:135-153`
  - Confidence: 60
  - Action class: `advisory`
  - Owner: resolver
  - Relevance status: PR-caused, unresolved pending validation
  - Resolution status: acknowledged
  - Action taken: Kept the path-safe local fallback because the pinned runtime accepts it and the converter needs a non-semver local build identity; strict semver remains the authoring contract for published plugin manifests.
  - Evidence: the converter defaults missing versions to `local` and validates only a path-safe token. The official [Codex plugin manifest specification](https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/plugin-creator/references/plugin-json-spec.md) says versions use strict semver, while the pinned runtime source appears to validate path-safe segments. UNVERIFIED: the pinned `@openai/codex@0.154.0` install path may accept these values despite the authoring specification.
  - Recommended fix: confirm the pinned CLI contract; then enforce strict semver or synthesize a valid fallback and add missing/non-semver fixtures if required.

## Slop Warnings (3 found)

- CR-012 remains explicitly `UNVERIFIED` and advisory pending confirmation of the pinned Codex runtime contract.
- The proposed content-hash/no-op install optimization was dropped as `OVERENGINEERING` because no measured bottleneck or requirement justified a new cache/invalidation path.
- The optional same-name marketplace marker suggestion was folded into CR-001 rather than retained as duplicate cleanup advice.

## Filtered (Pre-existing/Out-of-scope)

0 findings.

## Filtered (Previously Addressed)

0 findings.

## Strengths

- Marketplace replacement stages output before swapping, reducing half-written generated trees.
- Codex CLI arguments use spawn arrays, and path helpers enforce managed-root containment.
- The converter centralizes plugin-root rewriting and tests assert no `CLAUDE_PLUGIN_ROOT` remains in converted skills.
- Workflows pin action/tool versions and the focused smoke suite passed in this run.

## Approval Standard

Approve if the change definitely improves overall code health.

## Recommended Action

1. Decide the deferred release-publication policy in CR-008 before merging.
2. Re-run the full review after the policy decision and any workflow change.

**To automatically resolve eligible `gated_auto` code-backed findings, run:** `$kramme:pr:resolve-review`

## Resolution Summary

- 10 findings addressed.
- 1 finding deferred as a manual release-policy decision (CR-008).
- 0 findings open for selected-resolution retry or blocked implementation.
- 1 manual finding awaits the maintainer decision (CR-008).
- 0 accepted process handoffs await completion.
- 0 findings wait on an external owner, approval, or access.

Implementation commit: `ece3cb1a` (`Fix native Codex install cleanup safety`).

## Diff comments

Diff comments posted: 0 (skipped 0 already present)

## Execution Ledger

- `code-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/code-reviewer.txt
- `silent-failure-hunter`: succeeded — /tmp/kramme-pr-review-run.524xUB/silent-failure-hunter.txt
- `deslop-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/deslop-reviewer.txt
- `pr-test-analyzer`: succeeded — /tmp/kramme-pr-review-run.524xUB/pr-test-analyzer.txt
- `comment-analyzer`: succeeded — /tmp/kramme-pr-review-run.524xUB/comment-analyzer.txt
- `type-design-analyzer`: succeeded — /tmp/kramme-pr-review-run.524xUB/type-design-analyzer.txt
- `removal-planner`: succeeded — /tmp/kramme-pr-review-run.524xUB/removal-planner.txt
- `lean-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/lean-reviewer.txt
- `code-simplifier`: succeeded — /tmp/kramme-pr-review-run.524xUB/code-simplifier.txt
- `performance-oracle`: succeeded — /tmp/kramme-pr-review-run.524xUB/performance-oracle.txt
- `injection-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/injection-reviewer.txt
- `auth-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/auth-reviewer.txt
- `data-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/data-reviewer.txt
- `logic-reviewer`: succeeded — /tmp/kramme-pr-review-run.524xUB/logic-reviewer.txt
- `integrity`: succeeded — /tmp/kramme-pr-review-run.524xUB/integrity.txt
- `relevance`: succeeded — /tmp/kramme-pr-review-run.524xUB/relevance.txt
- `slop-meta`: succeeded — /tmp/kramme-pr-review-run.524xUB/slop-meta.txt
- `previous-context`: succeeded — /tmp/kramme-pr-review-run.524xUB/previous-context.txt
- `aggregation`: succeeded — /tmp/kramme-pr-review-run.524xUB/aggregation.txt
- `final-check`: succeeded — /tmp/kramme-pr-review-run.524xUB/final-check.txt
