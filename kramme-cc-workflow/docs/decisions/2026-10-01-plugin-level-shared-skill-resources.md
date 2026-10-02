# Skills share plugin-level resources instead of mirrored copies

- Status: ACCEPTED
- Date: 2026-10-01
- Deciders: repository maintainer (explicit implementation request)

## Context

The self-containment rule required every skill to carry its runtime files inside its own directory. It was written while the Codex converter copied skills one by one into `~/.codex/skills`, so a skill could be installed without its siblings. Since [2026-09-12](2026-09-12-native-codex-plugin-install.md) both hosts install the whole plugin, and 29 skills already ran plugin-level helpers through `${CLAUDE_PLUGIN_ROOT}/scripts/`.

What the rule still produced was duplication. Nine `file_identity_groups` kept 41 byte-identical copies of 9 files in sync: the visual family's CSS, library, navigation, and template files across five skills; the review model-selection policy across seven Pull Request review skills; the SIW fix-confidence rubric across two skills; and the 1,788-line SIW issue-reservation helper across two skills. That was 17,840 duplicated lines, guarded by `scripts/generate-synced-files.py` (398 lines), two Makefile targets, a linter check, and 15 Bats fixture tests.

Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` inline anywhere in a skill's Markdown body, but not in files the model reads later and not in the Bash tool environment ([plugin reference](https://code.claude.com/docs/en/plugins-reference#environment-variables)). Six reference files used `${CLAUDE_PLUGIN_ROOT}/scripts/...` that their `SKILL.md` never named, so the model had to infer the plugin root to run them.

## Decision

The installed plugin is the unit of self-containment. A skill may depend on its own directory, on shared references and assets under `kramme-cc-workflow/shared/<topic>/{references,assets}/`, and on runtime helpers under `kramme-cc-workflow/scripts/`. It must never depend on repository-only files such as `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, or `tests/`.

- A file that two or more skills need lives once under `shared/` (references and assets) or `scripts/` (executables). Mirrored copies, `file_identity_groups`, and the sync generator are removed.
- Skills reference plugin-level files as `${CLAUDE_PLUGIN_ROOT}/shared/...` or `${CLAUDE_PLUGIN_ROOT}/scripts/...`, and every such path a reference file uses is also named in that skill's `SKILL.md` body, where Claude Code substitutes it. Subagent prompt templates take the resolved path through a placeholder instead.
- The Codex converter copies `shared/` into the plugin, applies the same Markdown rewrite skill-local references receive, and allowlists each shared runtime script.
- `tests/skill-resource-references.bats` enforces existence, containment within `shared/` or `scripts/`, and the `SKILL.md` naming rule.
- `scripts/run-skillspector.sh` scans each `shared/<topic>` directory as its own target, in full-tree and changed-file runs, so shared instruction content keeps static security scanning.
- Each consuming skill keeps declaring the external inspirations behind shared content in its own `references/sources.yaml`.

Inline synced passages (`text_contracts`) are not changed by this decision.

## Alternatives and consequences

Keeping mirrors preserved standalone skill copies that no supported install path produces, at the cost of the duplication and its sync machinery. Generating self-contained copies at build time would keep source files single but add a build step to the Claude Code path, which installs straight from the repository. Letting skills reference each other's directories would couple skills to sibling layouts; the resource checker still rejects cross-skill paths.

A skill copied out of the plugin without `shared/` and `scripts/` no longer works on its own. Shared content changes now affect every consuming skill at once, which is the intent, so reviews of a shared file cover all of its consumers.
