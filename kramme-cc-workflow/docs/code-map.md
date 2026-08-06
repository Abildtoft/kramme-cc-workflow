# Code Map

Use this map to choose the first files to read and the closest tests to run. The full command list lives in [development.md](development.md#running-the-tests) and the [Makefile](../Makefile).

## Test Entry Points

Paths passed through file variables are relative to `kramme-cc-workflow/`.

| Scope | Complete suite | Focused file |
| --- | --- | --- |
| Node | `make -C kramme-cc-workflow test-node` | `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/<file>.test.js` |
| Python | `make -C kramme-cc-workflow test-python` | `make -C kramme-cc-workflow test-python-file PYTHON_TEST_FILE=tests/python/test_<name>.py` |
| Bats | `make -C kramme-cc-workflow test-bats` | `make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/<name>.bats` |
| Converter | `make -C kramme-cc-workflow test-convert` (Node converter contracts plus Bats CLI smoke) | `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/converter-core.test.js` (also `converter-install.test.js`, `converter-output.test.js`, or `converter-integration.test.js`) or `make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/convert-plugin.bats` |

## Source to Test Map

| Area | Source files | Closest tests or checks |
| --- | --- | --- |
| Public docs and conventions | `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `kramme-cc-workflow/docs/` | `git diff --check -- README.md CONTRIBUTING.md kramme-cc-workflow/docs` |
| Plugin manifests | `.claude-plugin/marketplace.json`, `kramme-cc-workflow/.claude-plugin/plugin.json` | `make -C kramme-cc-workflow test-convert` |
| Skills | `kramme-cc-workflow/skills/*/SKILL.md`, skill `references/`, `assets/`, `scripts/` | Look up behavioral suites in `config/coverage-production-sources.json` as shown below; also run `make -C kramme-cc-workflow test-skill-contracts` and `make -C kramme-cc-workflow skill-security-changed` |
| Agents | `kramme-cc-workflow/agents/*.md` | `bats kramme-cc-workflow/tests/agent-description-length.bats`, `make -C kramme-cc-workflow test-convert` |
| Hook manifest and hooks | `kramme-cc-workflow/hooks/hooks.json`, `kramme-cc-workflow/hooks/*.sh` | `bats kramme-cc-workflow/tests/{auto-format,block-rm-rf,check-enabled,confirm-review-responses,context-links,noninteractive-git,skill-usage-stats}.bats`, plus the hook-specific tests below |
| Hook enablement | `kramme-cc-workflow/hooks/lib/check-enabled.sh`, hook scripts that source it | `bats kramme-cc-workflow/tests/check-enabled.bats` |
| Git command safety parsing | `kramme-cc-workflow/hooks/lib/git_command_parser.py`, `kramme-cc-workflow/hooks/noninteractive-git.sh`, `kramme-cc-workflow/hooks/confirm-review-responses.sh`, `kramme-cc-workflow/hooks/block-rm-rf.sh` | `make -C kramme-cc-workflow test-python-file PYTHON_TEST_FILE=tests/python/test_git_command_parser.py`, `bats kramme-cc-workflow/tests/noninteractive-git.bats kramme-cc-workflow/tests/confirm-review-responses.bats kramme-cc-workflow/tests/block-rm-rf.bats` |
| Hook invocation benchmark | `kramme-cc-workflow/scripts/benchmark-hook-overhead.sh` | `bats kramme-cc-workflow/tests/benchmark-hook-overhead.bats` |
| Auto-format hook | `kramme-cc-workflow/hooks/auto-format.sh` | `make -C kramme-cc-workflow test-format` |
| Context links hook | `kramme-cc-workflow/hooks/context-links.sh`, `kramme-cc-workflow/hooks/context-links.config.example` | `make -C kramme-cc-workflow test-context` |
| Skill usage stats | `kramme-cc-workflow/hooks/skill-usage-stats.sh`, `kramme-cc-workflow/scripts/skill-usage.js` | `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/skill-usage.test.js`, `make -C kramme-cc-workflow test-skill-usage` |
| Converter frontmatter | `kramme-cc-workflow/scripts/convert-plugin/frontmatter.js` | `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/frontmatter.test.js` |
| Converter contracts and Codex hook output | `kramme-cc-workflow/scripts/convert-plugin/*.js`, `kramme-cc-workflow/hooks/hooks.json`, `kramme-cc-workflow/docs/hooks.md` | `make -C kramme-cc-workflow test-convert`, `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/codex-hook-compat.test.js` |
| Codex converter | `kramme-cc-workflow/scripts/convert-plugin.js`, `kramme-cc-workflow/scripts/convert-plugin/`, `kramme-cc-workflow/scripts/install-codex.sh` | `make -C kramme-cc-workflow test-convert` |
| Dev-server detection | `scripts/dev-server/*.sh`, `scripts/dev-server/README.md` | `bats kramme-cc-workflow/tests/dev-server-scripts.bats` |
| Development bootstrap | `scripts/bootstrap-dev.sh` | `make -C kramme-cc-workflow test-bootstrap` |
| PR diff, base, stack-membership, and rewrite-state helpers | `scripts/resolve-base.sh`, `scripts/verify-rewrite-state.sh`, `scripts/collect-review-diff.sh`, `scripts/resolve-stack-membership.sh` | `bats kramme-cc-workflow/tests/resolve-base.bats kramme-cc-workflow/tests/review-diff-scripts.bats kramme-cc-workflow/tests/resolve-stack-membership.bats` |
| Release and changelog | `kramme-cc-workflow/scripts/release.py`, `kramme-cc-workflow/scripts/changelog.py`, `kramme-cc-workflow/RELEASE.md`, `kramme-cc-workflow/CHANGELOG.md` | `bats kramme-cc-workflow/tests/release.bats` |
| Skill contract linting | `kramme-cc-workflow/scripts/lint-skill-contracts.py`, [package responsibility map](../scripts/lint_skill_contracts/README.md), skill and agent frontmatter | `make -C kramme-cc-workflow test-skill-contracts`, `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py` |
| Generated component reference | `kramme-cc-workflow/scripts/generate-component-reference.py`, `kramme-cc-workflow/scripts/lint_skill_contracts/readme.py`, `kramme-cc-workflow/scripts/lint_skill_contracts/catalog.py`, `README.md` component rows, `kramme-cc-workflow/docs/component-catalog.json` | `python3 kramme-cc-workflow/scripts/generate-component-reference.py --check`, `make -C kramme-cc-workflow test-skill-contracts` |
| SkillSpector runner | `kramme-cc-workflow/scripts/run-skillspector.sh`, `kramme-cc-workflow/config/skillspector-accepted-findings.json` | `bats kramme-cc-workflow/tests/skillspector-runner.bats` |
| Skill-review eval | `kramme-cc-workflow/evals/skill-review/` | `make -C kramme-cc-workflow test-skill-review-eval`, `make -C kramme-cc-workflow skill-eval-skill-review` |
| Skill-review scorer | `kramme-cc-workflow/evals/skill-review/scorer.js` | `make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/scorer.test.js` |
| SkillOpt adapter | `kramme-cc-workflow/evals/skillopt/` | `bats kramme-cc-workflow/tests/skillopt-adapter.bats kramme-cc-workflow/tests/skillopt-candidate-review.bats` |
| Synced file mirrors (incl. visual shared assets) | `kramme-cc-workflow/scripts/generate-synced-files.py`, mirrored files declared in `scripts/synced-contracts.yaml` | `bats kramme-cc-workflow/tests/lint-skill-contracts.bats`, `make -C kramme-cc-workflow check-visual-shared-assets` |

## Skill Contract Lookup

From the repository root, look up every registered suite and contract kind for an exact `SKILL.md` path:

```bash
skill_path="kramme-cc-workflow/skills/kramme:pr:create/SKILL.md"
jq -r --arg skill "$skill_path" \
  '.skill_contracts[] | select(.skills | index($skill)) | [.kind, .suite] | @tsv' \
  kramme-cc-workflow/config/coverage-production-sources.json
```

Run each returned suite through the focused Bats entry point, removing the leading `kramme-cc-workflow/` from the stored suite path:

```bash
make -C kramme-cc-workflow test-bats-file BATS_TEST_FILE=tests/pr-create-guidance.bats
```

No lookup result means the skill is still listed under `skill_contract_coverage.mechanical_only` in `scripts/synced-contracts.yaml`. The linter warns for that reviewed debt and fails when a skill is in neither the behavioral registry nor the explicit burndown.

## Common Investigation Paths

When a skill behaves incorrectly, start with its `SKILL.md`, then load only the referenced local files under the same skill directory. Check `scripts/lint-skill-contracts.py` if the issue is frontmatter, naming, description length, platform filtering, or self-contained resource policy.

When a hook blocks or misses a command, inspect the hook script, then the shared helpers under `hooks/lib/` (see `hooks/lib/README.md` for the helper responsibility map). `git_command_parser.py` is the production parser for complex shell and git command shapes used by the command-safety hooks.

For skill usage report and scan output, degraded-input diagnostics, and strict mode, see [hooks.md](hooks.md#skill-usage-stats).

When Codex output is wrong, read `scripts/convert-plugin.js` first, then follow the boundary in `scripts/convert-plugin/README.md`: loader, transformer, writer, config, staging, and install state.

When browser or visual skills cannot find an app, read `scripts/dev-server/README.md`, the relevant shell detector, and the skill-local reference that calls it.
