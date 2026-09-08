# Development Guide

Contributor reference for testing, verification, skill security scanning, and the SkillOpt eval pilot. For the contribution workflow see [CONTRIBUTING.md](../../CONTRIBUTING.md); for component conventions see the repo-root [AGENTS.md](../../AGENTS.md).

## Running the Tests

The hooks are tested using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Pure JavaScript and Python helper modules also have focused unit test runners. The Bats suite requires `jq` for JSON parsing in hooks.

### Setup

```bash
# Read-only prerequisite check
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --check

# Explicit setup (Node.js 20+, npm, and Python 3.10+ must already be available on Linux)
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --install
```

### Running Tests

```bash
# Run all tests
make -C kramme-cc-workflow test

# Run the measured cross-language smoke loop (8.9 seconds locally; budget: under 30 seconds)
make -C kramme-cc-workflow test-smoke

# Run only Bats integration tests
make -C kramme-cc-workflow test-bats

# Run one Bats integration test file
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/context-links.bats

# Run only Node unit tests
make -C kramme-cc-workflow test-node

# Re-run affected Node tests when their files or dependencies change
make -C kramme-cc-workflow test-node-watch

# Run the closest Node test for a changed source file
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/frontmatter.test.js

# Run only Python unit tests
make -C kramme-cc-workflow test-python

# Run one Python unit test file
make -C kramme-cc-workflow test-python-file PYTHON_TEST_FILE=tests/python/test_git_command_parser.py

# Enforce conservative Node/Python coverage baselines
make -C kramme-cc-workflow unit-coverage

# Run all coverage gates and validate the production-source inventory
make -C kramme-cc-workflow coverage

# Run with verbose output (show test names)
make -C kramme-cc-workflow test-verbose

# Run converter Node contracts and Bats CLI smoke tests
make -C kramme-cc-workflow test-convert

# Run only non-interactive git tests
make -C kramme-cc-workflow test-noninteractive

# Run only block-rm-rf tests
make -C kramme-cc-workflow test-block

# Run only context-links tests
make -C kramme-cc-workflow test-context

# Run only auto-format tests
make -C kramme-cc-workflow test-format

# Run only skill usage stats tests
make -C kramme-cc-workflow test-skill-usage
```

The initial coverage baselines are 80% lines, 70% branches, and 80% functions for Node, plus a 35% production-line aggregate for Python. They sit below the measured results (91.82%/82.66%/95.24% for the Node production aggregate on Node 20.20.2, and 49.59% for Python locally against 51.23% in CI) and should only ratchet upward.

`coverage-node` keeps the human-readable test report separate from the machine-readable LCOV report. The gate matches each LCOV source to the JavaScript production inventory, sums hit and total counters for `measured` sources, and applies the baselines to those weighted production totals. Test files and registered `contract_only` sources do not contribute to the denominator. Missing measured sources, unregistered production sources, malformed records, duplicate source records, and impossible hit/total pairs fail the gate. A valid zero branch or function denominator is treated as 100% because the measured sources contain no obligations for that metric.

The copied-Makefile regression fixture was exercised with Node 20.20.2 and the development runtime, Node 24.14.1. On both runtimes, deliberately undercovered production failed the gate despite a test file containing 120 fully executed assertions; the counter fixtures also cover unequal file sizes so a simple average of per-file percentages cannot satisfy the contract.

`coverage-python` also enforces a 20% per-file floor (`PYTHON_FILE_COVERAGE_MIN`) on every `measured` source and prints the ten lowest-covered files with the floor each one must clear. Sources that predate the floor are seeded in `python.measured_floors` with the lower value they currently hold; a seeded file that climbs 15 points past the default floor (`PYTHON_FILE_COVERAGE_STALE_MARGIN`) fails the gate until its entry is deleted, so the ratchet only moves upward. Keep floors conservative: `trace` attributes lines slightly differently across supported Python versions, so a floor set at a file's exact measurement will flap.

Bats exercises shell integration behavior, so `coverage` reports its complete top-level `tests/*.bats` file/test inventory as a contract proxy rather than claiming line coverage.

Production sources are registered in `kramme-cc-workflow/config/coverage-production-sources.json`. The `coverage` target reconciles that inventory with executable JavaScript, Python, and shell files under the plugin's `evals/`, `hooks/`, and `scripts/` directories. It also discovers JavaScript and shell files in plugin skill-local `scripts/` and `assets/` directories, plus executable files in repository-maintenance skill-local `scripts/` directories under `.agents/skills/`.

Put JavaScript and Python files in `measured` when the native coverage report includes them consistently across supported runtimes; otherwise put them in `contract_only` and map each source to one or more top-level `kramme-cc-workflow/tests/*.bats` contracts. A contract-only source may still appear incidentally in a native report, but the coverage gate does not require it there or include its Python result in the measured aggregate. Vendored JavaScript assets that are intentionally outside coverage may instead be registered in `javascript.excluded` with a non-empty rationale. Shell sources, including skill assets, use `contract_only`. The Bats runner does not recurse into nested test directories, so mapped contracts must be top-level files. Update the inventory whenever a production source is added, moved, removed, or changes coverage mode.

The optional `python.measured_floors` map records accepted debt against the per-file floor by mapping a measured Python source to the lower percentage it currently holds. Keys must name measured sources, and values must be non-negative numbers below the stale-floor threshold (`PYTHON_FILE_COVERAGE_MIN + PYTHON_FILE_COVERAGE_STALE_MARGIN`); invalid entries fail every coverage target that consumes the map.

For Node changes, `test-node-watch` uses the [built-in test runner's dependency watching](https://nodejs.org/docs/latest-v20.x/api/test.html#watch-mode). For a focused change-to-test loop, use `test-node-file` with the closest mapping in [code-map.md](code-map.md); the equivalent npm command is `npm run test:node:file -- kramme-cc-workflow/tests/node/<file>.test.js` from the repository root.

The `NODE_TEST_FILE`, `PYTHON_TEST_FILE`, and `BATS_TEST_FILE` values are paths relative to `kramme-cc-workflow/`, because `make -C kramme-cc-workflow` enters that directory before running the target. Each single-file target exits with a usage error when its variable is omitted.

### Pre-PR Verification

`make -C kramme-cc-workflow test` is the fast default suite. It runs the Node unit tests, Python unit tests, and Bats integration tests. For ordinary Pull Request verification, run:

```bash
make -C kramme-cc-workflow pr-verify
```

The `pr-verify` target runs the repository's local pre-PR gates: the read-only dependency check, shell/Python/JS linting, format checks, skill-contract linting, changed-skill SkillSpector scanning with `--fail-on high`, the test suite, and the coverage gates. CI additionally runs environment-specific compatibility and isolated installer jobs that are not part of this local target. `pr-verify` does not add a separate `skill-eval-skill-review` pass beyond the skill-review eval coverage already exercised by the Bats suite.

To verify prerequisites without running any gate, use `make -C kramme-cc-workflow check-deps` (or `npm run check:deps`). It is read-only: it reports missing tools and installs nothing.

Historical runtimes measured locally on an Apple silicon laptop, for choosing the smallest useful gate (the original sample did not record a date or detailed host/runtime versions):

| Target | Runtime | Notes |
| --- | --- | --- |
| `check-deps` | 0.4s | Read-only tool check |
| `test-smoke` | 8.9s | Representative cross-language loop |
| `coverage` | 51s | Includes its own `test-python` run |
| `pr-verify` | 28m | Dominated by `test-bats`; coverage adds roughly 36s on top of `test` |

In that historical sample, the coverage gates were cheap relative to the suite they joined: `coverage-python` reuses the `test-python` run that `pr-verify` already performs, so folding `coverage` into `pr-verify` costs about 36 seconds. Run `make -C kramme-cc-workflow coverage` on its own when only the inventory or floors are in question.

#### Measuring Bats suite cost

Set `KRAMME_BATS_TIMINGS=1` to run each selected top-level suite serially in its own Bats process and report `suite`, `elapsed_seconds`, and numeric exit `status` to stderr. Use `LC_ALL=C` for repeatable filename ordering:

```bash
LC_ALL=C KRAMME_BATS_TIMINGS=1 bash kramme-cc-workflow/tests/run-tests.sh

# Repeat one suite; the path is relative to tests/, including paths with spaces.
LC_ALL=C KRAMME_BATS_TIMINGS=1 bash kramme-cc-workflow/tests/run-tests.sh makefile.bats
```

The existing `test-bats` Make target also inherits the switch. Only the exact value `1` enables timing. The default runner still invokes `bats --tap` once, and `test-smoke` retains its separate representative selection. Timing mode uses the same top-level `*.bats` inventory without recursion, records failing suites, completes the remaining suites, and returns the first nonzero suite status. Focused mode preserves the selected suite's status.

Elapsed values use Bash's whole-second `SECONDS` counter; zero means less than one counter tick, not no work. Each interval includes Bats startup, fixtures, tests, and teardown. Timing mode adds a process per suite and emits a separate TAP stream for each, so its stdout is diagnostic output rather than one aggregate TAP document. Compare repeated suites under the same instrumentation and host conditions; these samples do not establish a speedup, a CI threshold, or safe parallel execution.

Measurement on 2026-09-08, based on commit `183f1728` plus this timing change: Apple M4 Max, 36 GiB RAM, macOS 26.4.1 arm64, Bash 5.3.9, Bats 1.14.0, Node 24.14.1, and Python 3.14.7. Locked Node dependencies were installed before measurement. One full serial run and immediate serial repeats of its three slowest suites used the commands above, with no concurrent test or scan jobs launched by this workflow. Background host activity and cache state were not controlled.

All 73 selected suites passed. Their elapsed intervals sum to **1,649 seconds (27m 29s)**; this excludes runner setup/reporting outside those intervals and is not a measurement of the full `pr-verify` gate. Every repeated suite also passed. Values below are seconds; a dash means no repeat was collected.

| Suite | Full run | Focused repeat | Status |
| --- | --: | --: | --- |
| `adversarial-review-guidance.bats` | 2 | — | Passed |
| `adversarial-review-runner.bats` | 57 | — | Passed |
| `audit-agent-config-guidance.bats` | 1 | — | Passed |
| `auto-format.bats` | 39 | — | Passed |
| `benchmark-hook-overhead.bats` | 6 | — | Passed |
| `block-rm-rf.bats` | 55 | — | Passed |
| `bootstrap-dev.bats` | 17 | — | Passed |
| `check-enabled.bats` | 13 | — | Passed |
| `check-environment.bats` | 38 | — | Passed |
| `clean-gone-branches.bats` | 56 | — | Passed |
| `code-deprecate-guidance.bats` | 4 | — | Passed |
| `code-migrate-guidance.bats` | 2 | — | Passed |
| `confirm-review-responses.bats` | 121 | 60 | Passed |
| `context-links.bats` | 14 | — | Passed |
| `contract-registry-helper.bats` | 3 | — | Passed |
| `convert-plugin.bats` | 290 | 90 | Passed |
| `demo-reel-skill.bats` | 3 | — | Passed |
| `dev-server-scripts.bats` | 16 | — | Passed |
| `discovery-delegation-guidance.bats` | 1 | — | Passed |
| `docs-sync-release-guidance.bats` | 2 | — | Passed |
| `experience-quality-guidance.bats` | 1 | — | Passed |
| `feature-spec-guidance.bats` | 1 | — | Passed |
| `find-sibling-bugs-guidance.bats` | 1 | — | Passed |
| `forward-progress-guidance.bats` | 1 | — | Passed |
| `git-fixture-helper.bats` | 8 | — | Passed |
| `github-review-guidance.bats` | 2 | — | Passed |
| `guidance-contract-helper.bats` | 4 | — | Passed |
| `gut-check-guidance.bats` | 1 | — | Passed |
| `harden-security-guidance.bats` | 1 | — | Passed |
| `issue-and-plan-to-pr-guidance.bats` | 3 | — | Passed |
| `linear-backlog-refine-guidance.bats` | 1 | — | Passed |
| `linear-breakdown-findings-guidance.bats` | 1 | — | Passed |
| `linear-issue-define-guidance.bats` | 16 | — | Passed |
| `linear-issue-implement-guidance.bats` | 0 | — | Passed |
| `linear-issue-to-pr-guidance.bats` | 3 | — | Passed |
| `linear-review-pr-guidance.bats` | 4 | — | Passed |
| `linear-select-next-guidance.bats` | 2 | — | Passed |
| `lint-skill-contracts.bats` | 79 | — | Passed |
| `makefile.bats` | 49 | — | Passed |
| `noninteractive-git.bats` | 24 | — | Passed |
| `optimize-skill.bats` | 9 | — | Passed |
| `outside-view-guidance.bats` | 0 | — | Passed |
| `plan-to-pr-validation.bats` | 64 | — | Passed |
| `pr-create-guidance.bats` | 39 | — | Passed |
| `pr-generate-description-guidance.bats` | 4 | — | Passed |
| `pr-walkthrough.bats` | 7 | — | Passed |
| `product-describe-behavior-guidance.bats` | 2 | — | Passed |
| `product-pulse-guidance.bats` | 0 | — | Passed |
| `qa-intake-guidance.bats` | 0 | — | Passed |
| `recreate-commits-push-target.bats` | 27 | — | Passed |
| `refactor-pass-guidance.bats` | 2 | — | Passed |
| `release.bats` | 61 | — | Passed |
| `repository-instructions.bats` | 0 | — | Passed |
| `resolve-base.bats` | 85 | — | Passed |
| `resolve-stack-membership.bats` | 16 | — | Passed |
| `review-diff-scripts.bats` | 29 | — | Passed |
| `review-execution-guidance.bats` | 1 | — | Passed |
| `review-shared-tree.bats` | 11 | — | Passed |
| `session-automate-repeats-guidance.bats` | 2 | — | Passed |
| `session-search-scripts.bats` | 1 | — | Passed |
| `siw-issue-reservation.bats` | 177 | 218 | Passed |
| `skill-create-guidance.bats` | 1 | — | Passed |
| `skill-resource-references.bats` | 7 | — | Passed |
| `skill-review-eval.bats` | 8 | — | Passed |
| `skill-source-audit-guidance.bats` | 0 | — | Passed |
| `skill-usage-stats.bats` | 6 | — | Passed |
| `skillopt-adapter.bats` | 9 | — | Passed |
| `skillopt-candidate-review.bats` | 8 | — | Passed |
| `skillspector-runner.bats` | 77 | — | Passed |
| `test-audit-guidance.bats` | 1 | — | Passed |
| `visual-check-slop.bats` | 34 | — | Passed |
| `workflow-artifacts-cleanup.bats` | 2 | — | Passed |
| `worktree-helper.bats` | 17 | — | Passed |

The first investigation target is `convert-plugin.bats`, the largest contributor in the full run (290 seconds, about 18% of the total). Its 90-second repeat shows substantial variability; suite timing alone cannot attribute that difference to fixture setup, package installation, filesystem/cache state, or background load. Measure those phases and the individual full-plugin installation cases next before proposing a fixture change. `siw-issue-reservation.bats` (177/218 seconds) is another substantial contributor; preserve its lock-contention and recovery assertions in any follow-up. These measurements justify further attribution, not removed tests, shared mutable fixtures, or parallel Bats execution.

GitHub Actions also runs the standalone skill-review eval as a separate path-filtered, scheduled, and manual workflow. That workflow uploads the aggregate JSON result as the `skill-review-eval` artifact and is meant to catch harness or fixture regressions without treating score movement as a merge gate.

Before a release candidate or before marking a larger Pull Request ready, run the stronger local gate:

```bash
make -C kramme-cc-workflow verify
```

The `verify` target runs `pr-verify` plus the standalone full skill-review eval split. These verification targets expect the existing local tools used by those checks to be installed: `shellcheck`, `ruff`, `skillspector`, `bats`, `jq`, Python 3.10+, and Node.js.

Python development tool pins used by CI live in `requirements-dev.txt`. First party `actions/*` workflow actions are pinned to commit SHAs with a trailing comment naming the major tag used for lookup. Refresh them with `git ls-remote` against the upstream action repository before updating the SHA.

### Skill Security Scans

SkillSpector scans complement tests, linting, and human review. Run them for new or materially changed skills, before installing third-party skills, and as a full-tree check for release candidates. Static-only scanning is the default; semantic analysis is opt-in.

The GitHub Actions release workflow runs the full-tree static scan before creating a release branch or Pull Request. Release scan findings are advisory for now, but SkillSpector installation or execution errors fail the release workflow. The workflow uploads the full report as the `skillspector-release-report` artifact and includes a concise scan summary in the generated release Pull Request body.

The Pull Request workflow runs a static SkillSpector scan for changed skill directories. Pull Requests with no changed skills exit successfully without running the scanner. Changed-skill scans are blocking: enforceable high and critical findings fail `Skill Lint / SkillSpector static skill scan` and should block merge. Repository branch protection should require that check on `main`; if GitHub lists only the job name, require `SkillSpector static skill scan`.

```bash
# Scan every plugin skill
make -C kramme-cc-workflow skill-security

# Scan only skill directories changed against BASE_REF, defaulting to origin/main
make -C kramme-cc-workflow skill-security-changed

# Scan every plugin skill with SkillSpector semantic analysis enabled.
# Defaults to JSON to avoid running a second LLM-backed companion report.
make -C kramme-cc-workflow skill-security-semantic
```

For third-party skill intake, scan the source before installing it:

```bash
# Scan an external Git URL, zip, directory, or SKILL.md without LLM analysis
skillspector scan SOURCE --no-llm
```

Reports are written to `.context/skillspector/` by default, or `$RUNNER_TEMP/skillspector` in CI. Override behavior with `SKILLSPECTOR_FORMAT`, `SKILLSPECTOR_SEMANTIC_FORMAT`, `SKILLSPECTOR_FAIL_ON`, and `SKILLSPECTOR_BASE`.

Triage high and critical findings before installation, release, or merge. In ordinary Pull Requests, fix enforceable high and critical findings or record a specific accepted finding before merging. Enable semantic scanning only when provider credentials are intentionally configured and the skill contents are acceptable to send to that provider; semantic scans remain manual and are not required for ordinary Pull Requests.

Accepted findings live in `kramme-cc-workflow/config/skillspector-accepted-findings.json`. Keep this registry small: add an entry only when a finding has been reviewed and the risk is intentionally accepted or proven to be scanner noise. Each entry must name the exact repo-relative `path`, `rule_id`, `reason`, `owner`, `accepted_at`, and either `expires_at` or `review_after`.

```json
{
  "accepted_findings": [
    {
      "path": "kramme-cc-workflow/skills/kramme:example/SKILL.md",
      "rule_id": "E4",
      "reason": "Reviewed scanner false positive; command is documented-only.",
      "owner": "Security",
      "accepted_at": "2026-06-13",
      "expires_at": "2026-09-13"
    }
  ]
}
```

Accepted findings are excluded from `--fail-on` threshold calculations only when both path and rule match and the entry is still active. They are still counted in runner output as accepted findings, and the JSON reports remain unchanged. Entries past `expires_at` or `review_after` fail blocking scans (`SKILLSPECTOR_FAIL_ON=high` or `critical`) and warn in advisory scans. Use `--accepted-findings <path>` to test a policy file other than the default registry.

### Test Structure

This is a representative inventory by test language, not an exhaustive list of the top-level Bats contracts:

```
kramme-cc-workflow/tests/
├── run-tests.sh                      # Complete top-level Bats runner
├── node/
│   ├── codex-hook-compat.test.js     # Codex hook conversion contracts
│   ├── converter-core.test.js        # Converter loading and transforms
│   ├── converter-install.test.js     # Converter install transactions
│   ├── converter-integration.test.js # Cross-module converter flows
│   ├── converter-output.test.js      # Converter writers and config
│   ├── frontmatter.test.js           # Frontmatter unit contracts
│   └── scorer.test.js                # Skill-review scorer contracts
├── python/
│   ├── test_changelog.py
│   ├── test_generate_image.py
│   ├── test_git_command_parser.py
│   ├── test_lint_skill_contracts.py
│   ├── test_session_search_extractors.py
│   └── test_session_search_python38.py
├── fixtures/                         # Shared parser/frontmatter cases
├── test_helper/
│   ├── common.bash                   # Shared Bats utilities
│   └── mocks/                        # Mock git, gh, and skillspector commands
├── makefile.bats                      # Make target contracts
├── convert-plugin.bats                # Converter CLI smoke tests
└── … other top-level *.bats           # Hook, skill, script, and guidance contracts
```

The aggregate Python target also discovers repository-maintenance tests under `.agents/skills/kramme:skill:audit-sources/scripts/`.

## SkillOpt Adoption

SkillOpt is currently a conservative pilot for `kramme:skill:review` only. The deterministic eval split lives in `kramme-cc-workflow/evals/skill-review/`, and the repo-local SkillOpt bridge lives in `kramme-cc-workflow/evals/skillopt/`. Keep the external SkillOpt checkout, model credentials, run output, and candidate review artifacts outside tracked source under `.context/`.

The entry points are the split check, dry-run or real SkillOpt runner, candidate export, and candidate review packet documented in [`evals/skillopt/README.md`](../evals/skillopt/README.md). Generated `best_skill.md` output is never auto-applied. A candidate is eligible for a normal source edit only after the manual review packet under `.context/skillopt-runs/skill-review/<run-id>/candidate-review/` has been inspected, the patch applies cleanly, the eval scores do not regress, and the candidate gate passes:

```bash
make -C kramme-cc-workflow skillopt-candidate-check
```

The candidate gate runs skill contract linting, changed-skill SkillSpector scanning with JSON output and `--fail-on high`, Node unit tests, Python unit tests, Bats integration tests, and the full skill-review eval split.

Do not add another skill to the optimization loop until it has a deterministic train/val/test split, false-positive coverage, a candidate gate, and the same manual acceptance model. SkillOpt-Sleep is proposal-only: it may suggest candidate edits from prior sessions, but deterministic held-out evals and the manual review packet remain the acceptance gate.
