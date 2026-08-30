# AGENTS.md

## Scope

- **NOTE** This file is the canonical agent-facing instruction source for the `kramme-cc-workflow` Claude Code plugin and its Codex conversion path.

## Context Map

- **ALWAYS** read [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, change guidelines, and contributor verification.
- **ALWAYS** read [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) before changing subsystem boundaries or runtime flow.
- **ALWAYS** use [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to choose the first source files and closest tests for a change.
- **ALWAYS** consult [docs/decisions/README.md](kramme-cc-workflow/docs/decisions/README.md) before revisiting a settled repository decision.
- **ALWAYS** keep install, usage, component listings, and testing documentation in the canonical public [README.md](README.md).
- **PREFER** the generated [component catalog](kramme-cc-workflow/docs/component-catalog.json) over the full README when locating a shipped skill, agent, or hook; regenerate it with `python3 kramme-cc-workflow/scripts/generate-component-reference.py --write` after component changes.
- **ALWAYS** use [.agents/skills/](.agents/skills/) or [Local Repository Maintenance](README.md#local-repository-maintenance) to locate repository-maintenance skills, which are intentionally absent from the shipped component catalog.
- **ALWAYS** read [agent-portability.md](kramme-cc-workflow/docs/agent-portability.md) before changing converter, hook, MCP, or host-adapter behavior.
- **NOTE** `CLAUDE.md` imports this file so every host receives the same repository instructions.

## Project Structure

- **NOTE** The repository has one canonical Claude Code plugin source plus local-only maintenance skills:

```text
kramme-cc-workflow/            # Canonical plugin source
  .claude-plugin/plugin.json   # Plugin manifest
  agents/                      # Specialized subagents
  skills/                      # Shipped skills
  hooks/hooks.json             # Event handlers configuration
.agents/skills/                # Local repository-maintenance skills
```

## Adding Components

### Agents

- **ALWAYS** create agents at `kramme-cc-workflow/agents/kramme:<agent-name>.md` with this frontmatter shape:

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

- **ALWAYS** create shipped skills at `kramme-cc-workflow/skills/kramme:<domain>:<skill-name>/SKILL.md` with this frontmatter shape:

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

- **ALWAYS** declare `name`, `description`, `disable-model-invocation`, and `user-invocable` explicitly in every skill.
- **ALWAYS** make `name` and `description` precise enough to route model auto-invocation correctly.
- **CAN** add `argument-hint` as the slash-menu placeholder when a skill accepts arguments.
- **CAN** add `kramme-platforms` to restrict a skill to `[claude-code]`, `[codex]`, or both; omit it to include the skill on all platforms.
- **ALWAYS** restrict skills that require Claude Code-only behavior such as Agent Teams to `kramme-platforms: [claude-code]`.
- **ALWAYS** set `disable-model-invocation: true` for user-triggered skills with side effects such as git mutations, file deletion, or Pull Request creation; use `false` when model auto-invocation is safe.
- **CAN** set `disable-model-invocation: false` for a side-effecting child skill only when an accepted ADR names the exact child and parent, its description narrowly routes model use, its body defines a least-side-effect model-invocation contract, and focused tests pin the parent's guarded arguments.
- **ALWAYS** set `user-invocable: false` only for background conventions that should not appear in the slash-command menu; use `true` for skills users should see there.
- **PREFER** the Agent Skills directory shape below and keep `SKILL.md` focused on orchestration:

```text
kramme:<domain>:<skill-name>/
├── SKILL.md           # Core instructions, target under 500 lines
├── references/        # Documentation and prompts loaded on demand
├── assets/            # Output and code templates
└── scripts/           # Executable helpers
```

- **PREFER** moving reference data, prompts, and examples to `references/`, templates to `assets/`, and executable behavior to `scripts/`, with explicit on-demand read instructions from `SKILL.md`; see [Anthropic's skill documentation](https://code.claude.com/docs/en/skills#add-supporting-files).
- **CAN** use `/kramme:skill:create` for guided skill scaffolding.

### Hooks

- **ALWAYS** edit `kramme-cc-workflow/hooks/hooks.json` when adding `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, or `Stop` handlers.
- **ALWAYS** make every hook support the toggle system by starting its script with the appropriate form below:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "hook-name"        # PreToolUse
exit_if_hook_disabled "hook-name" "json" # PostToolUse or Stop
```

## Component Conventions

- **ALWAYS** use namespaced `kramme:` component names with kebab-case name segments.
- **ALWAYS** store component definitions as Markdown files with YAML frontmatter.
- **PREFER** concise, actionable instructions.
- **ALWAYS** document every command, skill, agent, and hook in `README.md` with what it does and when to use it.
- **ALWAYS** use “Pull Request” or “PR” terminology consistently.
- **ALWAYS** use plain-English branch commit messages without Conventional Commit prefixes.
- **ALWAYS** use Conventional Commits for PR titles because CI validates them and they become changelog-generating merge commit messages.
- **PREFER** keeping new or refactored `SKILL.md` files under 500 lines by moving supporting material into the skill directory; legacy skills may exceed the target only until migrated.
- **ALWAYS** treat `long-skill burndown` warnings at or above 300 lines from `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py` as an ordered review queue, starting with the first warning and preserving the 500-line hard-failure budget and existing behavior; warnings prompt review, not automatic deletion or unsafe trimming.
- **ALWAYS** treat `long-description burndown` warnings at or above 500 characters as an ordered review queue, starting with the first warning and preserving trigger nouns, safety constraints, and non-derivable context while shrinking.
- **ALWAYS** keep every skill and agent `description` frontmatter value at or below 1024 characters for Codex compatibility, moving examples and extended trigger guidance into the body.
- **ALWAYS** resolve shipped skill edits to `kramme-cc-workflow/skills/kramme:<domain>:<skill-name>/` and maintenance skill edits to `.agents/skills/<skill-name>/`.
- **NEVER** edit installed copies under `~/.codex/skills`, `~/.agents/skills`, `~/.claude/skills`, app bundles, or generated install output when changing repository behavior.
- **ALWAYS** keep each skill self-contained inside its own directory so installed skills never depend on this repository's `AGENTS.md`, `CLAUDE.md`, `README.md`, or shared `docs/` files.
- **ALWAYS** run static SkillSpector scanning for new or materially changed skills with `make -C kramme-cc-workflow skill-security-changed`; use `make -C kramme-cc-workflow skill-security` for release-candidate full-tree checks and `skillspector scan <url-or-path> --no-llm` before installing third-party skills.
- **PREFER** semantic SkillSpector scans only when provider credentials are intentionally configured and the skill contents are acceptable to send to that provider.
- **NOTE** SkillSpector complements tests, linting, and human review rather than replacing them.
- **ALWAYS** triage high and critical SkillSpector findings before merge or installation.

## External Sources and Rights

- **ALWAYS** declare every external inspiration or copied source in `<skill>/references/sources.yaml` with `id`, `url` or `context7_library`, `title`, `rationale`, `usage`, `last_reviewed_at`, and `baseline_hash`.
- **ALWAYS** use `usage: inspiration` only when the local skill retains ideas, facts, methods, or workflow influence expressed in original local language.
- **ALWAYS** use `usage: copied` when source prose, code, templates, or substantial assets remain, and include a verified compatible `license`, skill-relative `notice`, exact `upstream_path`, and one immutable `upstream_commit`, `baseline_commit`, `upstream_revision`, `upstream_release`, or `version`.
- **ALWAYS** ship the complete required notice with copied material and repeat the source, license, path, and immutable revision pointer in copied-file headers where the format permits it.
- **NEVER** treat public availability, attribution, or this repository's MIT license as permission to retain third-party expression.
- **NEVER** copy material whose license is absent, unclear, incompatible, or forbids reproduction; link to it and write an original summary instead.
- **NEVER** commit fetched source bodies or `references/sources-snapshot/` directories.
- **NOTE** Source audits may process upstream content transiently, but the repository retains only source URLs, original provenance notes, review dates, hashes, and required copied-source metadata enforced by the skill-contract linter.

## Skill Naming

- **ALWAYS** use exactly `kramme:<domain>:<skill-name>` for every new or renamed skill unless an accepted ADR grants an exception.
- **PREFER** verb-first action names such as `resolve-review`, `generate-phases`, and `fix-ci`.
- **CAN** use object-first names such as `issue-define` and `issue-implement` when two or more skills share the object prefix.
- **CAN** use noun compounds such as `code-review`, `spec-audit`, and `commit-message` when the name describes a thing rather than an action.
- **ALWAYS** create a singleton domain only when it names a durable capability area that would be misleading under every existing domain, adds routing information beyond restating the skill name, can plausibly classify more than one responsibility, and has either recorded use or a time-bounded emerging case with an owner and review date.
- **ALWAYS** merge adjacent skills when intent, inputs, output, side effects, and safety gates overlap and only an implementation technique or mode differs.
- **ALWAYS** keep adjacent skills separate when a single-clause route identifies a distinct intent, workflow phase, durable output, permission boundary, or failure path.
- **ALWAYS** consult current 30-day and 90-day usage as evidence without treating usage as the sole catalog decision criterion.
- **NEVER** treat legacy naming outliers as precedent; structural exceptions require an accepted ADR before merge.

## Verification

- **ALWAYS** run the smallest meaningful check first and broaden in proportion to the change:

```bash
make -C kramme-cc-workflow test      # Fast default suite
make -C kramme-cc-workflow lint      # Shell, Python, and JavaScript linting
make -C kramme-cc-workflow pr-verify # Normal pre-PR gate
make -C kramme-cc-workflow verify    # Release-candidate gate
```

- **ALWAYS** use [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to map changed files to the closest focused tests.
- **ALWAYS** regenerate the component reference after changing a skill, agent, or hook with `python3 kramme-cc-workflow/scripts/generate-component-reference.py --write`.
