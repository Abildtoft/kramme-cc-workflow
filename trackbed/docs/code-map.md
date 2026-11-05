# Code Map

Use this map to choose the first files to read and the closest focused test to run. After the focused check, use `make -C trackbed test-smoke` for representative feedback, `pr-verify` for Pull Request gates, or `verify` for release candidates. The full command list lives in [development.md](development.md#running-the-tests) and the [Makefile](../Makefile).

## Test Entry Points

Paths passed through file variables are relative to `trackbed/`.

| Scope | Complete suite | Focused file |
| --- | --- | --- |
| Node | `make -C trackbed test-node` | `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/<file>.test.js` |
| Python | `make -C trackbed test-python` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_<name>.py` |
| Bats | `make -C trackbed test-bats` | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/<name>.bats` |
| Converter | `make -C trackbed test-convert` (Node converter contracts plus Bats CLI smoke) | `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/converter-core.test.js` (also `converter-build.test.js`, `converter-integration.test.js`, `codex-cli.test.js`, `codex-hook-compat.test.js`, or `legacy-install-cleanup.test.js`) or `make -C trackbed test-bats-file BATS_TEST_FILE=tests/convert-plugin.bats` |

## Source to Test Map

| Area | Source files | Closest tests or checks |
| --- | --- | --- |
| Public docs and conventions | `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, `trackbed/docs/` | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/repository-instructions.bats`, then `git diff --check -- README.md CONTRIBUTING.md AGENTS.md CLAUDE.md trackbed/docs` |
| Maintainer guide citations | `trackbed/scripts/check-doc-citations.py`, `trackbed/docs/*.md`, and any file those guides cite by line | `python3 trackbed/scripts/check-doc-citations.py`, `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_doc_citations.py` |
| Review and shipping guides | `trackbed/docs/review.md`, `trackbed/docs/shipping.md` | `python3 trackbed/scripts/lint-skill-contracts.py`, `bats trackbed/tests/{github-review-guidance,linear-issue-to-pr-guidance,pr-create-guidance}.bats` |
| Plugin manifests | `.claude-plugin/marketplace.json`, `trackbed/.claude-plugin/plugin.json` | `make -C trackbed test-convert` |
| Skills | `trackbed/skills/*/SKILL.md`, skill `references/`, `assets/`, `scripts/` | Look up behavioral suites in `config/coverage-production-sources.json` as shown below; also run `make -C trackbed test-skill-contracts` and `make -C trackbed skill-security-changed` |
| Agents | `trackbed/agents/*.md` | `python3 trackbed/scripts/lint-skill-contracts.py`, `make -C trackbed test-convert`, `bats trackbed/tests/review-shared-tree.bats` |
| Hook manifest and hooks | `trackbed/hooks/hooks.json`, `trackbed/hooks/*.sh` | `bats trackbed/tests/{auto-format,block-rm-rf,check-enabled,confirm-review-responses,skill-usage-stats,update-check}.bats`, plus the hook-specific tests below |
| Hook enablement | `trackbed/hooks/lib/check-enabled.sh`, hook scripts that source it | `bats trackbed/tests/check-enabled.bats` |
| Git command safety parsing | `trackbed/hooks/lib/command_safety/`, `trackbed/hooks/lib/git_command_parser.py`, `trackbed/hooks/confirm-review-responses.sh`, `trackbed/hooks/block-rm-rf.sh` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_git_command_parser.py`, `bats trackbed/tests/confirm-review-responses.bats trackbed/tests/block-rm-rf.bats` |
| Hook invocation benchmark | `trackbed/scripts/benchmark-hook-overhead.sh` | `bats trackbed/tests/benchmark-hook-overhead.bats` |
| Review convergence run state | `trackbed/skills/pr:review-convergence/scripts/convergence-state.py` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_convergence_state.py` |
| Linear issue-to-PR preflight | `trackbed/skills/linear:issue-to-pr/scripts/preflight.py`, `trackbed/skills/linear:issue-to-pr/SKILL.md` Steps 1–2 | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_issue_to_pr_preflight.py`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/linear-issue-to-pr-guidance.bats` |
| PR create preflight | `trackbed/skills/pr:create/scripts/pr-create-preflight.py`, `trackbed/skills/pr:create/SKILL.md` Steps 1–4.5 | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_pr_create_preflight.py`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/pr-create-guidance.bats` |
| GitHub review re-review scope and stack overview | `trackbed/skills/pr:github-review/scripts/review-delta.py`, `trackbed/skills/pr:github-review/scripts/stack-overview.py`, `trackbed/skills/pr:github-review/references/{delta-review,stack-mode}.md` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_review_delta.py`, `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_stack_overview.py`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/github-review-guidance.bats` |
| PR risk triage signals | `trackbed/scripts/risk-signals.py`, `trackbed/scripts/risk_patterns.py`, `trackbed/skills/pr:triage-risk/references/signals.md` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_risk_signals.py`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/pr-triage-risk-guidance.bats` |
| Practice audit session signals | `trackbed/skills/code:audit-practice/scripts/session-signals.py`, `trackbed/skills/code:audit-practice/scripts/signal_patterns.py`, `trackbed/skills/code:audit-practice/references/mistakes.md` | `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_audit_practice_session_signals.py`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/audit-practice-guidance.bats` |
| Auto-format hook | `trackbed/hooks/auto-format.sh` | `make -C trackbed test-format` |
| Update notices | `trackbed/hooks/update-check.sh`, the `Claude auto-update` and `Plugin update` rows in `trackbed/skills/setup/scripts/check-environment.sh` | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/update-check.bats`, `make -C trackbed test-bats-file BATS_TEST_FILE=tests/check-environment.bats` |
| Skill usage stats | `trackbed/hooks/skill-usage-stats.sh`, `trackbed/scripts/skill-usage.js`, `trackbed/scripts/lib/skill-usage-hosts.js`, `trackbed/scripts/lib/skill-usage-cost.js` | `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/skill-usage.test.js`, `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/skill-usage-hosts.test.js`, `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/skill-usage-cost.test.js`, `make -C trackbed test-skill-usage` |
| Converter frontmatter | `trackbed/scripts/convert-plugin/frontmatter.js` | `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/frontmatter.test.js` |
| Converter contracts and Codex hook output | `trackbed/scripts/convert-plugin/*.js`, `trackbed/hooks/hooks.json`, `trackbed/docs/hooks.md` | `make -C trackbed test-convert`, `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/codex-hook-compat.test.js` |
| Codex converter | `trackbed/scripts/convert-plugin.js`, `trackbed/scripts/convert-plugin/`, `trackbed/scripts/install-codex.sh` | `make -C trackbed test-convert` |
| Dev-server detection | `scripts/dev-server/*.sh`, `scripts/dev-server/README.md` | `bats trackbed/tests/dev-server-scripts.bats` |
| Development bootstrap | `scripts/bootstrap-dev.sh` | `make -C trackbed test-bootstrap` |
| PR diff, base, stack-membership, stack-context, and rewrite-state helpers | `scripts/resolve-base.sh`, `scripts/verify-rewrite-state.sh`, `scripts/collect-review-diff.sh`, `scripts/resolve-stack-membership.sh`, `scripts/resolve-stack-context.py`, `shared/pr-review/references/stacked-pr-review.md` | `bats trackbed/tests/resolve-base.bats trackbed/tests/review-diff-scripts.bats trackbed/tests/resolve-stack-membership.bats trackbed/tests/stacked-pr-review-guidance.bats`, `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_resolve_stack_context.py` |
| Outsider-reader isolation | `agents/cold-reader.md`, `shared/agents/references/cold-reader.md`, `scripts/probe-cold-reader-isolation.js` | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/cold-reader-guidance.bats`, `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/probe-cold-reader-isolation.test.js`; live check: `node trackbed/scripts/probe-cold-reader-isolation.js` |
| Review documented-rule sources and `REVIEW.md` policy | `skills/pr:convention-review/SKILL.md` Step 3 and `references/baseline-mining.md` Tier 1; `skills/pr:code-review/SKILL.md` Steps 7 and 11, `references/team-mode.md` Step 2, `references/output-template.md` Coverage Status, and `references/fowler-smell-baseline.md` Rules | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/review-standards-guides-guidance.bats` |
| Review evidence rules, closeout loop, and diff-comment lifecycle | `skills/pr:code-review/references/review-discipline.md`, `references/closeout-loop.md`, `references/team-mode.md`, and Steps 5-12b of its `SKILL.md`; `agents/pr-relevance-validator.md`, `agents/silent-failure-hunter.md`, `agents/security-reviewer.md`; `skills/pr:convention-review/references/baseline-mining.md` markers; the synced Conductor diff-comment contract | `bats trackbed/tests/review-evidence-guidance.bats trackbed/tests/review-closeout-loop-guidance.bats trackbed/tests/convention-review-markers-guidance.bats trackbed/tests/review-diff-comments-guidance.bats` |
| Review working-tree integrity | `scripts/review-tree-fingerprint.sh`, `skills/pr:code-review/references/review-discipline.md` shared-working-tree section, `skills/pr:product-review/references/shared-working-tree.md`, reviewer agent read-only mandates and `disallowedTools` frontmatter | `bats trackbed/tests/review-shared-tree.bats` |
| Verification tree identity and reuse | `scripts/worktree-tree-id.sh`, `skills/verify:run/SKILL.md`, `skills/verify:run/references/completion-claims.md`, `skills/verify:run/scripts/discovery-cache.sh`, `skills/pr:review-convergence/SKILL.md` Step 5 | `bats trackbed/tests/worktree-tree-id.bats trackbed/tests/verification-cadence-guidance.bats trackbed/tests/verify-run-discovery-cache.bats` |
| Subagent models (review and opted-in non-review roles) | `shared/pr-review/references/model-selection.md`, review entry points and wrapper handoffs, non-review skills that name its Non-Review Subagent Roles section | `make -C trackbed test-bats-file BATS_TEST_FILE=tests/review-model-selection-guidance.bats`, `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/converter-integration.test.js` |
| Review execution and completion | `skills/pr:code-review/scripts/review-execution.js`, `references/execution-contract.md`, `evals/review-completion/` | `node --test trackbed/tests/node/review-execution.test.js trackbed/tests/node/review-completion-eval.test.js`, `bats trackbed/tests/review-execution-guidance.bats` |
| Release and changelog | `trackbed/scripts/release.py`, `trackbed/scripts/changelog.py`, `trackbed/RELEASE.md`, `trackbed/CHANGELOG.md` | `bats trackbed/tests/release.bats` |
| Skill contract linting | `trackbed/scripts/lint-skill-contracts.py`, [package responsibility map](../scripts/lint_skill_contracts/README.md), skill and agent frontmatter | `make -C trackbed test-skill-contracts`, `python3 trackbed/scripts/lint-skill-contracts.py` |
| Generated component reference | `trackbed/scripts/generate-component-reference.py`, `trackbed/scripts/lint_skill_contracts/readme.py`, `trackbed/scripts/lint_skill_contracts/readme_summaries.py`, `trackbed/scripts/lint_skill_contracts/catalog.py`, README `summaries` in `trackbed/scripts/synced-contracts.yaml`, `README.md` component rows, `trackbed/docs/component-catalog.json` | `python3 trackbed/scripts/generate-component-reference.py --check`, `make -C trackbed test-skill-contracts` |
| SkillSpector runner | `trackbed/scripts/run-skillspector.sh`, `trackbed/config/skillspector-accepted-findings.json` | `bats trackbed/tests/skillspector-runner.bats` |
| Skill-review eval | `trackbed/evals/skill-review/` | `make -C trackbed test-skill-review-eval`, `make -C trackbed skill-eval-skill-review` |
| Skill-review scorer | `trackbed/evals/skill-review/scorer.js` | `make -C trackbed test-node-file NODE_TEST_FILE=tests/node/scorer.test.js` |
| Live skill-review adapters, credit failover, and checkpoints | `evals/skill-review/{providers,credit-pool,eval-state,review-profile,live-predict,claude-predict,openai-predict,run-live-eval,ci-checkpoint}.js`, `.github/workflows/skill-review-live-eval.yml` | `make -C trackbed test-skill-review-live-eval` (fake SDK and Responses endpoint, no credentials); closest Node suites are `credit-pool`, `eval-state`, `claude-predict`, `openai-predict`, `run-live-eval`, and `ci-checkpoint`; workflow/CLI contracts are in `tests/skill-review-live-eval.bats` |
| SkillOpt adapter | `trackbed/evals/skillopt/` | `bats trackbed/tests/skillopt-adapter.bats trackbed/tests/skillopt-candidate-review.bats` |
| Shared skill resources | `trackbed/shared/`, plugin-level helpers in `trackbed/scripts/` that skills reference through `${CLAUDE_PLUGIN_ROOT}` | `bats trackbed/tests/skill-resource-references.bats`, `make -C trackbed test-convert` |

## Skill Contract Lookup

From the repository root, look up every registered suite and contract kind for an exact `SKILL.md` path:

```bash
skill_path="trackbed/skills/pr:create/SKILL.md"
jq -r --arg skill "$skill_path" \
  '.skill_contracts[] | select(.skills | index($skill)) | [.kind, .suite] | @tsv' \
  trackbed/config/coverage-production-sources.json
```

Run each returned suite through the focused Bats entry point, removing the leading `trackbed/` from the stored suite path:

```bash
make -C trackbed test-bats-file BATS_TEST_FILE=tests/pr-create-guidance.bats
```

Run a returned `tests/python/` suite through the focused Python entry point instead, for example `make -C trackbed test-python-file PYTHON_TEST_FILE=tests/python/test_issue_to_pr_preflight.py`.

No lookup result means the skill is still listed under `skill_contract_coverage.mechanical_only` in `scripts/synced-contracts.yaml`. The linter warns for that reviewed debt and fails when a skill is in neither the behavioral registry nor the explicit burndown.

## Common Investigation Paths

When a skill behaves incorrectly, start with its `SKILL.md`, then load only the files it references: its own skill directory and any plugin-level `shared/` or `scripts/` paths its `SKILL.md` names. Check `scripts/lint-skill-contracts.py` if the issue is frontmatter, naming, description length, platform filtering, or self-contained resource policy.

When a hook blocks or misses a command, inspect the hook script, then the shared helpers under `hooks/lib/` (see `hooks/lib/README.md` for the helper responsibility map). `git_command_parser.py` is the executable entry point the hooks invoke; the parser for complex shell and git command shapes lives in `hooks/lib/command_safety/`, one module per policy mode over shared syntax, vocabulary, prefix, and lexer layers.

For skill usage report and scan output, degraded-input diagnostics, and strict mode, see [hooks.md](hooks.md#skill-usage-stats).

When Codex output is wrong, read `scripts/convert-plugin.js` first, then follow the boundary in `scripts/convert-plugin/README.md`: loader, transformer, plugin builder, Codex CLI registration, and legacy cleanup.

When browser or visual skills cannot find an app, read `scripts/dev-server/README.md`, the relevant shell detector, and the skill-local reference that calls it.
