# Code Map

Use this map to choose the first files to read and the closest tests to run.
The full command list lives in the root [README.md](../../README.md#running-the-tests)
and [Makefile](../Makefile).

## Source to Test Map

| Area | Source files | Closest tests or checks |
| --- | --- | --- |
| Public docs and conventions | `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `kramme-cc-workflow/docs/` | `git diff --check -- README.md CONTRIBUTING.md kramme-cc-workflow/docs` |
| Plugin manifests | `.claude-plugin/marketplace.json`, `kramme-cc-workflow/.claude-plugin/plugin.json` | `make -C kramme-cc-workflow test-convert` |
| Skills | `kramme-cc-workflow/skills/*/SKILL.md`, skill `references/`, `assets/`, `scripts/` | `make -C kramme-cc-workflow test-skill-contracts`, `make -C kramme-cc-workflow skill-security-changed`, targeted `tests/*skill*.bats` |
| Agents | `kramme-cc-workflow/agents/*.md` | `bats kramme-cc-workflow/tests/agent-description-length.bats`, `make -C kramme-cc-workflow test-convert` |
| Hook manifest and hooks | `kramme-cc-workflow/hooks/hooks.json`, `kramme-cc-workflow/hooks/*.sh` | `bats kramme-cc-workflow/tests/{auto-format,block-rm-rf,check-enabled,confirm-review-responses,context-links,noninteractive-git,skill-usage-stats}.bats`, plus the hook-specific tests below |
| Hook enablement | `kramme-cc-workflow/hooks/lib/check-enabled.sh`, hook scripts that source it | `bats kramme-cc-workflow/tests/check-enabled.bats` |
| Git command safety parsing | `kramme-cc-workflow/hooks/lib/git_command_parser.py`, `kramme-cc-workflow/hooks/noninteractive-git.sh`, `kramme-cc-workflow/hooks/confirm-review-responses.sh`, `kramme-cc-workflow/hooks/block-rm-rf.sh` | `python3 -m unittest discover -s kramme-cc-workflow/tests/python -p test_git_command_parser.py`, `bats kramme-cc-workflow/tests/noninteractive-git.bats kramme-cc-workflow/tests/confirm-review-responses.bats kramme-cc-workflow/tests/block-rm-rf.bats` |
| Auto-format hook | `kramme-cc-workflow/hooks/auto-format.sh` | `make -C kramme-cc-workflow test-format` |
| Context links hook | `kramme-cc-workflow/hooks/context-links.sh`, `kramme-cc-workflow/hooks/context-links.config.example` | `make -C kramme-cc-workflow test-context` |
| Skill usage stats | `kramme-cc-workflow/hooks/skill-usage-stats.sh`, `kramme-cc-workflow/hooks/skill-usage.js`, `kramme-cc-workflow/scripts/skill-usage.js` | `make -C kramme-cc-workflow test-skill-usage` |
| Codex converter | `scripts/convert-plugin.js`, `scripts/convert-plugin/`, `scripts/install-codex.sh` | `make -C kramme-cc-workflow test-convert` |
| Dev-server detection | `scripts/dev-server/*.sh`, `scripts/dev-server/README.md` | `bats kramme-cc-workflow/tests/dev-server-scripts.bats` |
| PR diff and base helpers | `scripts/resolve-base.sh`, `scripts/collect-review-diff.sh` | `bats kramme-cc-workflow/tests/resolve-base.bats kramme-cc-workflow/tests/review-diff-scripts.bats` |
| Release and changelog | `kramme-cc-workflow/scripts/release.py`, `kramme-cc-workflow/scripts/changelog.py`, `kramme-cc-workflow/RELEASE.md`, `kramme-cc-workflow/CHANGELOG.md` | `bats kramme-cc-workflow/tests/release.bats` |
| Skill contract linting | `kramme-cc-workflow/scripts/lint-skill-contracts.py`, skill and agent frontmatter | `make -C kramme-cc-workflow test-skill-contracts`, `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py` |
| SkillSpector runner | `kramme-cc-workflow/scripts/run-skillspector.sh`, `kramme-cc-workflow/config/skillspector-accepted-findings.json` | `bats kramme-cc-workflow/tests/skillspector-runner.bats` |
| Skill-review eval | `kramme-cc-workflow/evals/skill-review/` | `make -C kramme-cc-workflow test-skill-review-eval`, `make -C kramme-cc-workflow skill-eval-skill-review` |
| SkillOpt adapter | `kramme-cc-workflow/evals/skillopt/` | `bats kramme-cc-workflow/tests/skillopt-adapter.bats kramme-cc-workflow/tests/skillopt-candidate-review.bats` |
| Visual shared assets | `kramme-cc-workflow/scripts/generate-visual-shared-assets.py`, visual skill shared assets | `make -C kramme-cc-workflow check-visual-shared-assets` |

## Common Investigation Paths

When a skill behaves incorrectly, start with its `SKILL.md`, then load only the
referenced local files under the same skill directory. Check
`scripts/lint-skill-contracts.py` if the issue is frontmatter, naming,
description length, platform filtering, or self-contained resource policy.

When a hook blocks or misses a command, inspect the hook script, then the shared
helpers under `hooks/lib/` (see `hooks/lib/README.md` for the helper
responsibility map). `git_command_parser.py` is the production parser for complex
shell and git command shapes used by the command-safety hooks.

When Codex output is wrong, read `scripts/convert-plugin.js` first, then follow
the boundary in `scripts/convert-plugin/README.md`: loader, transformer, writer,
config, staging, and install state.

When browser or visual skills cannot find an app, read
`scripts/dev-server/README.md`, the relevant shell detector, and the skill-local
reference that calls it.
