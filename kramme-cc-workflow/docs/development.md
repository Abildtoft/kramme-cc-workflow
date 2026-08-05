# Development Guide

Contributor reference for testing, verification, skill security scanning, and the SkillOpt eval pilot. For the contribution workflow see [CONTRIBUTING.md](../../CONTRIBUTING.md); for component conventions see the repo-root [CLAUDE.md](../../CLAUDE.md).

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

The initial coverage baselines are 80% lines, 70% branches, and 80% functions for Node, plus a 35% production-line aggregate for Python. They sit below the measured results (84.26%/75.56%/86.38% for Node, and 49.59% for Python locally against 51.23% in CI) and should only ratchet upward.

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

The `pr-verify` target runs every class of check the Pull Request workflows enforce: the read-only dependency check, shell/Python/JS linting, format checks, skill-contract linting, changed-skill SkillSpector scanning with `--fail-on high`, the test suite, and the coverage gates. It does not add a separate `skill-eval-skill-review` pass beyond the skill-review eval coverage already exercised by the Bats suite.

To verify prerequisites without running any gate, use `make -C kramme-cc-workflow check-deps` (or `npm run check:deps`). It is read-only: it reports missing tools and installs nothing.

Runtimes measured locally on an Apple silicon laptop, for choosing the smallest useful gate:

| Target | Runtime | Notes |
| --- | --- | --- |
| `check-deps` | 0.4s | Read-only tool check |
| `test-smoke` | 8.9s | Representative cross-language loop |
| `coverage` | 51s | Includes its own `test-python` run |
| `pr-verify` | 28m | Dominated by `test-bats`; coverage adds roughly 36s on top of `test` |

The coverage gates are cheap relative to the suite they join: `coverage-python` reuses the `test-python` run that `pr-verify` already performs, so folding `coverage` into `pr-verify` costs about 36 seconds. Run `make -C kramme-cc-workflow coverage` on its own when only the inventory or floors are in question.

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
