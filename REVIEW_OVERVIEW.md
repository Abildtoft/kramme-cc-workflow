# PR Review Summary

## Relevance Filter

- 6 findings validated as PR-caused
- 7 findings filtered (pre-existing or out-of-scope)
- 0 findings filtered (previously addressed in previous-review source)
- 0 findings carried forward from a previous review

## Previous Review Context

- Source: none
- Parseable previous findings: 0
- Previously addressed filtered: 0
- Open/deferred/acknowledged/skipped carried forward: 0
- Open/deferred/acknowledged/skipped not carried forward: 0
- Ignored or unparseable previous entries: 0

## Auto-resolution Readiness

- 0 Critical/Important findings remain eligible for `$kramme:pr:resolve-review` (`Action class: gated_auto`); 5 were addressed
- 0 Critical/Important findings remain deferred for manual follow-up; 1 was completed by maintainer decision
- Manual blockers: product/UX/architecture/maintainer decision 1; missing/contradictory requirement 0; PR-description/process update 0; cross-team/external ownership 0; unresolved contradiction 0; incomplete trace/UNVERIFIED 0; dead-code approval 0

## Critical Issues (0 found)

## Important Issues (6 found)

- [kramme:injection-reviewer]: Model-produced media can be published without an independent trust gate [`kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:337`]
  - Finding ID: CR-001
  - Location: `kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:337`
  - Confidence: 72
  - Action class: manual
  - Owner: maintainer
  - Resolution status: addressed
  - Action taken: Addressed by maintainer decisions and follow-up implementation — retained attachments under `--auto`, made UI-facing diffs presumptively relevant for screenshot or video capture, and added guarded best-effort startup for straightforward local environments.
  - Evidence: Repository-derived diff and context drive the model-invoked capture child, the same model performs the semantic secret scan, and `--auto` passes any path-valid image/video to `gh pr create --attach` without an independent artifact preview or content/provenance check. A prompt-injected or mistaken capture can therefore publish credentials or private data in a syntactically valid media file.
  - Selected resolution: Keep attachments enabled under `--auto`; when a diff touches UI-facing behavior, require the agent to attempt screenshot or video capture and, when no app is running, make a best-effort attempt to start a straightforward safe local environment.
  - Decision outcome: Commits `Require visual evidence attempts for UI changes` and `Start simple environments for UI evidence` update `kramme:pr:create`, description generation, demo capture, focused tests, public documentation, and the accepted ADRs. Automatic startup is guarded by an internal capability, limited to an unambiguous entrypoint unchanged from the pinned base, excludes setup and external mutation, waits at most 60 seconds, and cleans up the exact launched process. Auto mode may still publish captured evidence without an independent preview gate; the maintainer accepts reliance on the agent's relevance and semantic safety assessment.

- [kramme:code-reviewer, kramme:auth-reviewer, kramme:logic-reviewer]: The local help check does not prove remote attachment capability [`kramme-cc-workflow/skills/kramme:pr:create/SKILL.md:301`]
  - Finding ID: CR-002
  - Location: `kramme-cc-workflow/skills/kramme:pr:create/SKILL.md:301`
  - Confidence: 98
  - Action class: gated_auto
  - Owner: resolver
  - Resolution status: addressed
  - Action taken: Added an exact allowlist for GitHub CLI attachment failures that occur before Pull Request submission, then retry once without evidence; clarified that the local help check proves syntax only and added executable remote-capability regression coverage.
  - Evidence: GitHub CLI v2.100 advertises `--attach` locally, but `attachments.NewUploader` rejects GitHub Enterprise Server, unsupported token types, and insufficient repository permission before `submitPR`. Those errors omit the later `no pull request was created` sentinel required by the retry at `confirmation-and-creation.md:344`, so best-effort evidence blocks otherwise-valid PR creation after branch publication.

- [kramme:code-reviewer]: Visual delegation passes an undefined base-commit token [`kramme-cc-workflow/skills/kramme:pr:generate-description/references/visual-capture.md:28`]
  - Finding ID: CR-003
  - Location: `kramme-cc-workflow/skills/kramme:pr:generate-description/references/visual-capture.md:28`
  - Confidence: 95
  - Action class: gated_auto
  - Owner: resolver
  - Resolution status: addressed
  - Action taken: Changed visual delegation to pass the Phase 1 `MERGE_BASE` full OID, and updated the synced contract and focused guidance tests.
  - Evidence: The new child invocation requires `{BASE_COMMIT}`, but Phase 1 exports only `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE`; direct `--visual` invocations also need not provide `BASE_COMMIT_OVERRIDE`. The delegated child consequently has no defined full OID and must reject or skip capture.

- [kramme:silent-failure-hunter]: A failed attachment-free retry can be reported as a partial attachment success [`kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:353`]
  - Finding ID: CR-004
  - Location: `kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:353`
  - Confidence: 96
  - Action class: gated_auto
  - Owner: resolver
  - Resolution status: addressed
  - Action taken: Reset effective attachment state before every attachment-free retry, kept first-attempt diagnostics separate from final-attempt output, and extended non-zero result verification to attachment-free retries that may have created the Pull Request.
  - Evidence: If the zero-upload first attempt triggers an attachment-free retry and that retry creates the PR but exits nonzero for another post-creation warning, the code concatenates the first attachment diagnostic into `PR_CREATE_OUTPUT` while retaining a positive effective attachment count. The later classifier then sees the retry URL plus the stale attachment error and falsely reports `partially attached`, although the creating invocation received no attachments.

- [kramme:type-design-analyzer]: Lexical deduplication misses attachment aliases that GitHub CLI rejects [`kramme-cc-workflow/skills/kramme:pr:create/scripts/prepare-demo-attachments.py:92`]
  - Finding ID: CR-005
  - Location: `kramme-cc-workflow/skills/kramme:pr:create/scripts/prepare-demo-attachments.py:92`
  - Confidence: 98
  - Action class: gated_auto
  - Owner: resolver
  - Resolution status: addressed
  - Action taken: Deduplicated artifacts by filesystem device/inode identity after regular-file validation, with a hardlink-alias regression test.
  - Evidence: The helper's `set[Path]` treats hard links and case aliases as distinct, while GitHub CLI v2.100 uses `os.SameFile` and rejects duplicate file identities during flag validation, before PR submission and without the retry sentinel. A manifest accepted as safe can therefore block best-effort PR creation.

- [kramme:pr-test-analyzer]: The attachment publication state machine is tested only as prose [`kramme-cc-workflow/tests/pr-create-guidance.bats:5`]
  - Finding ID: CR-006
  - Location: `kramme-cc-workflow/tests/pr-create-guidance.bats:5`
  - Confidence: 92
  - Action class: gated_auto
  - Owner: resolver
  - Resolution status: addressed
  - Action taken: Added an executable harness for the documented creation block covering remote pre-submit fallback, non-zero post-create retry state, stale-diagnostic separation, and no retry for unrelated failures.
  - Evidence: The new tests grep for tokens in `confirmation-and-creation.md` but never execute the shell block that assembles attachment pairs, retries a proven zero-upload failure, and classifies partial/post-creation failures. CR-002 and CR-004 are concrete defects that all focused and broad tests currently pass without detecting.

## Suggestions (0 found)

## Slop Warnings (2 found)

- CR-002: A broad parallel host/auth/permission preflight would duplicate GitHub CLI policy and introduce time-of-check/time-of-use drift. Prefer narrowly recognizing only known errors that prove no PR was created, then retry without attachments.
- CR-001: A new independent scanner/provenance subsystem would be speculative without an existing trusted facility. Prefer explicit preview/approval or omit attachments from `--auto`.

## Filtered (Pre-existing/Out-of-scope)

<collapsed>
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/skills/kramme:pr:generate-description/references/visual-capture.md:73`: Direct output-only descriptions already included local paths before this branch; the changed condition preserves that pre-existing behavior.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/tests/pr-create-guidance.bats:68`: Exact NUL-record assertions would strengthen coverage, but the JSON-mode test already checks the same computed values and no defect was demonstrated.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/tests/pr-create-guidance.bats:71`: Consumer-side symlink tests would strengthen coverage, but no failing boundary case was demonstrated.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/skills/kramme:pr:create/references/confirmation-and-creation.md:268`: The lower-case braced token is an agent-substituted placeholder, not a shell variable; no literal execution path was established.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/skills/kramme:pr:create/scripts/prepare-demo-attachments.py:95`: Rejecting all hard-linked content would not prove provenance because an actor able to copy the source can bypass that rule; the meaningful media-trust risk is CR-001.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/skills/kramme:pr:create/scripts/prepare-demo-attachments.py:112`: Removing the manifest's explicit media kind is a preference; the current field provides coherent consistency validation.
- NOTICED BUT NOT TOUCHING: `kramme-cc-workflow/skills/kramme:pr:create/scripts/prepare-demo-attachments.py:121`: Shrinking JSON output is optional; the current validated record shape has no demonstrated present cost.
</collapsed>

## Filtered (Previously Addressed)

<collapsed>
(0 found)
</collapsed>

## Strengths

- **FYI** The attachment helper centralizes path containment, symlink, file type, size, and shell-argument validation, and publication revalidates the manifest immediately before building a quoted argument array.
- **FYI** Partial-upload handling intentionally avoids blind retries after any successful upload, preserving the at-most-once PR creation boundary.
- **FYI** Focused Bats suites, the full default test suite, the 113-test skill-contract suite, changed-skill static security scanning, and repository lint all completed successfully; the retained findings are behavioral gaps those prose-oriented checks do not exercise.

## Approval Standard

Approve if the change definitely improves overall code health.

## Recommended Action

1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run review after fixes

**To automatically resolve eligible `gated_auto` code-backed findings, run:** `$kramme:pr:resolve-review`

## Resolution Summary

- Changes made: fixed all 5 gated-auto findings in commit `Resolve PR demo evidence review findings`; added behavioral tests for attachment fallback/state classification and filesystem-identity deduplication; implemented the maintainer's UI-evidence policy in `Require visual evidence attempts for UI changes`; then added capability-gated, bounded startup and exact-process cleanup for straightforward local environments in `Start simple environments for UI evidence`.
- Findings: 6 addressed, 0 deferred as out-of-scope, 0 open selected-resolution retries or blocked implementations, 0 manual findings awaiting a user decision, 0 accepted process handoffs awaiting completion, and 0 manual findings waiting on an external owner, approval, or access.
- Breaking API/config changes: none. Automatic UI evidence changes from discretionary relevance judgment to a presumptive best-effort capture attempt that may start one qualifying local development process when needed.
- Manual verification/risk: The selected CR-001 policy intentionally relies on the agent's relevance and semantic safety assessment rather than an independent artifact preview gate. It also permits one trusted-baseline local development command behind the internal `--start-if-easy` capability; setup, stateful infrastructure, new or modified branch commands, and external mutations remain excluded. The initial full suite had one unrelated interrupt-fixture timing failure; that exact test passed on isolated rerun. The latest 37 focused tests, 113 skill-contract tests, formatting, lint, component-reference sync, and changed-skill static scanning passed; the strict security wrapper remains blocked by three expired accepted-finding records in unrelated skills.
