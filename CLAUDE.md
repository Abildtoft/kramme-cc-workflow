# CLAUDE.md

This repo contains Claude Code plugins providing workflow automation for daily development tasks.

## Start Here

This file owns component conventions only. For setup, architecture, test selection, or settled decisions, read the narrowest canonical source instead of inferring from here:

1. [CONTRIBUTING.md](CONTRIBUTING.md) — local setup, change guidelines, and verification commands.
2. [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) — subsystem boundaries and runtime flow.
3. [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) — source-to-test map; use it to pick the first files to read and the closest tests to run.
4. [docs/decisions/README.md](kramme-cc-workflow/docs/decisions/README.md) — settled repository decisions and their sources.
5. [README.md](README.md) — canonical public documentation, including the full component reference.
6. [AGENTS.md](AGENTS.md) — the same routing plus the repository ground rules and their sources.

To locate a shipped skill, agent, or hook without loading the full README, read the generated index at [docs/component-catalog.json](kramme-cc-workflow/docs/component-catalog.json). It carries names, invocation modes, and source paths only; README rows stay canonical for descriptions. Repository-maintenance skills are not included in this catalog; find them under `.agents/skills/` or [Local Repository Maintenance](README.md#local-repository-maintenance).

## Project Structure

```
kramme-cc-workflow/            # General workflow plugin
  .claude-plugin/plugin.json   # Plugin manifest
  agents/                      # Specialized subagents (markdown files)
  skills/                      # Skills (subdirectories with SKILL.md)
  hooks/hooks.json             # Event handlers configuration
```

## Adding Components

### Agents

Create `kramme-cc-workflow/agents/kramme:<agent-name>.md`:

```yaml
---
name: kramme:<agent-name>
description: When and how to use this agent (shown in Task tool)
model: inherit
color: <appropriate-color>
---
# Agent mission and expected output
```

### Skills

Create `kramme-cc-workflow/skills/kramme:<domain>:<skill-name>/SKILL.md`:

```yaml
---
name: kramme:<domain>:<skill-name>
description: When to auto-trigger this skill
argument-hint: [optional-argument]
disable-model-invocation: false
user-invocable: true
---
# Skill instructions
```

**Frontmatter fields (all required except `argument-hint` and `kramme-platforms`):**

- `name` / `description` — Description triggers auto-invocation matching.
- `argument-hint` — Placeholder text shown in `/` menu for expected arguments. Only include when the skill accepts arguments.
- `disable-model-invocation` — `true` prevents Claude from auto-invoking; user must trigger via `/` menu. Use for skills with side effects (git operations, file deletion, PR creation). Set to `false` to allow auto-invocation.
- `user-invocable` — `false` hides from `/` menu; Claude auto-invokes based on context. Use for background conventions (commit style, verification rules). Set to `true` to show in `/` menu.
- `kramme-platforms` — Restrict skill to specific platforms: `[claude-code]`, `[codex]`, or both. Omit to include on all platforms. Skills using Claude Code-only features (e.g. Agent Teams) should set `kramme-platforms: [claude-code]`.

**Skill directory structure** (follows [Agent Skills spec](https://agentskills.io/specification)):

```
kramme:<domain>:<skill-name>/
├── SKILL.md           # Core instructions (required, target under 500 lines)
├── references/        # Docs, prompts, examples agents read (loaded on demand)
├── assets/            # Output templates, code templates, static resources
└── scripts/           # Executable scripts
```

Keep `SKILL.md` focused on orchestration logic. Move reference data, templates, agent prompts, and code examples to supporting files and reference them via `Read` tool instructions. See [Anthropic's skill docs](https://code.claude.com/docs/en/skills#add-supporting-files).

For guided skill creation with best-practice scaffolding, use `/kramme:skill:create`.

### Hooks

Edit `hooks/hooks.json` to add event handlers (PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, Stop).

**Important:** All hooks must support the toggle system. Add this at the start of each hook script:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "hook-name"        # For PreToolUse hooks
exit_if_hook_disabled "hook-name" "json" # For PostToolUse/Stop hooks
```

## Conventions

- Use namespaced `kramme:` component names with kebab-case name segments
- Components are markdown files with YAML frontmatter
- Keep instructions concise and actionable
- **Document all components in README.md** - Every command, skill, agent, and hook must be documented in the README with a description of what it does and when to use it
- Use "Pull Request" (PR) terminology consistently.
- **Commit/PR title policy (canonical)** - Use plain-English commit messages for normal branch commits (no Conventional Commit prefix). Use [Conventional Commits](https://www.conventionalcommits.org/) format for PR titles (`feat:`, `fix:`, `docs:`, etc.). PR titles are validated by CI, become merge commit messages, and feed changelog generation.
- **SKILL.md target under 500 lines** - Keep new or refactored skills under ~500 lines by moving reference material, templates, and examples to supporting files. Legacy skills may temporarily exceed this target until migrated.
- **Skill prose burndown** - `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py` reports warning-only `long-skill burndown` entries for `SKILL.md` files at or above 400 lines, sorted by length. Use the first warning in the current output as the next extraction target, keeping the 500-line hard failure budget unchanged. Success means moving reference material to `references/`, templates to `assets/`, and executable behavior to `scripts/` until the target drops meaningfully below the warning threshold without changing skill behavior.
- **Explicit skill frontmatter** - Every skill SKILL.md must declare all frontmatter fields explicitly (`name`, `description`, `disable-model-invocation`, `user-invocable`). Never rely on defaults.
- **ALWAYS** keep every skill and agent `description` frontmatter field at or below 1024 characters for Codex compatibility. Move examples and extended trigger guidance into the body instead of frontmatter.
- **ALWAYS** resolve skill edits to the in-repo source path: plugin skills live under `kramme-cc-workflow/skills/kramme:<skill-name>/`, and repository-maintenance skills live under `.agents/skills/<skill-name>/`.
- **NEVER** edit installed skill copies under `~/.codex/skills`, `~/.agents/skills`, `~/.claude/skills`, app bundles, or generated install output when the goal is to change this repository's skill behavior.
- **Skills must be self-contained** - `SKILL.md` files and skill resources must not cite, link to, or instruct reading repository-level docs (including this repo's `CLAUDE.md`, `README.md`, or shared `docs/` files). Reason: skills run after installation in downstream environments, and cross-references create hidden coupling and brittle behavior. Every skill must contain its runtime policy within its own folder (`SKILL.md` + local `references/`/`assets/`).
- **Skill security scanning** - Run SkillSpector for new or materially changed skills. Use static-only scans by default: `make -C kramme-cc-workflow skill-security-changed` for branch changes, `make -C kramme-cc-workflow skill-security` for release-candidate full-tree checks, and `skillspector scan <url-or-path> --no-llm` before installing third-party skills. Semantic scans are optional and only appropriate when provider credentials are intentionally configured and the skill contents are acceptable to send to that provider. Treat SkillSpector as an additional scanner that complements tests, linting, and human review; triage high and critical findings before merge or installation.
- **External-source rights and provenance (canonical)** - A public URL or public GitHub repository is not permission to copy. Every external source used to build a skill must be declared in `<skill>/references/sources.yaml` with `id`, `url` (or `context7_library`), `title`, `rationale`, `usage`, `last_reviewed_at`, and `baseline_hash`. Use `usage: inspiration` only when the local work retains ideas, facts, methods, or workflow influence and rewrites all expression in original local language. Use `usage: copied` whenever source prose, code, templates, or substantial assets remain; before retaining them, verify that the upstream license permits this repository's use, add non-empty `license`, skill-relative `notice`, and exact `upstream_path` fields, and pin the copied expression with an immutable `upstream_commit`, `baseline_commit`, `upstream_revision`, `upstream_release`, or `version`. Ship the complete required notice with the skill and repeat the source/license pointer in copied file headers where the format permits it. Attribution alone is not permission, and the repository's MIT license never replaces third-party terms. If the license is absent, unclear, incompatible, or forbids online reproduction, do not copy: link to the source and write an original summary instead. **NEVER commit fetched source bodies or `references/sources-snapshot/` directories.** Source audits may handle upstream content transiently, but the repository stores only the URL, original provenance notes, review date, and normalized hash. The skill-contract linter enforces `usage`, copied-source license/notice/location/revision fields, notice-file existence, and the source-snapshot ban.
- **Skill name word order** - Multi-word skill names (the segment after `kramme:domain:`) follow one of three patterns:
  1. **Verb-first** (default for actions): `resolve-review`, `generate-phases`, `fix-ci`
  2. **Object-first** (only when 2+ skills share the prefix): `issue-define`, `issue-implement`
  3. **Noun compound** (names a thing, not an action): `code-review`, `spec-audit`, `commit-message`
- **Skill catalog shape** - Use exactly `kramme:<domain>:<skill-name>` for every new or renamed skill. Create a singleton domain only when it names a durable capability that no existing domain classifies, adds routing information beyond the skill name, and has recorded use or a time-bounded emerging/showcase case with an owner and review date. Merge adjacent skills when their intent, inputs, output, side effects, and safety gates overlap and only an implementation technique or mode separates them; keep them separate only when a positive single-clause route identifies a different intent, workflow phase, durable output, permission boundary, or failure path. Consult current 30-day and 90-day usage as evidence, never as the sole criterion. Structural naming exceptions require an accepted ADR before merge; legacy outliers are not precedent.

## Development

Install locally for testing:

```bash
claude /plugin install /path/to/this/repo
```

### Verification

Run the smallest meaningful check, then broaden:

```bash
make -C kramme-cc-workflow test   # fast default suite
make -C kramme-cc-workflow lint   # shell, Python, and JS linting
make -C kramme-cc-workflow verify # stronger pre-PR / release gate
```

Map changed files to the closest tests with [docs/code-map.md](kramme-cc-workflow/docs/code-map.md). After changing a skill, agent, or hook, regenerate the component reference output:

```bash
python3 kramme-cc-workflow/scripts/generate-component-reference.py --write
```
