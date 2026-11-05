# Namespace Components Through the `trackbed` Plugin Name

- Status: ACCEPTED
- Date: 2026-11-05
- Deciders: repository maintainers

## Context

The repository moved from `Abildtoft/kramme-cc-workflow` to `trackbed/skills`. Every shipped skill and agent carried its own `kramme:` prefix, and the plugin was named `kramme-cc-workflow`. Codex invokes a skill by its own name, so Codex users typed `$kramme:pr:code-review`. Claude Code always puts the plugin name in front of a plugin skill, so Claude Code users typed `/kramme-cc-workflow:kramme:pr:code-review`: two namespaces for one component.

A throwaway plugin on Claude Code 2.1.318 confirmed the mechanism. A plugin named `trackbed` with a skill named `pr:code-review` runs as `/trackbed:pr:code-review`, and `/pr:code-review` alone does not resolve. The plugin name cannot be omitted, so the only way to shorten the Claude Code name is to make the plugin name the namespace.

## Decision

- Name the plugin and its marketplace `trackbed`. Users install `trackbed@trackbed` in both hosts.
- Drop the `kramme:` prefix from every shipped skill and agent frontmatter name and folder: `skills/pr:code-review/` with `name: pr:code-review`, and `agents/code-reviewer.md` with `name: code-reviewer`. Claude Code invokes them as `trackbed:pr:code-review` and `trackbed:code-reviewer`.
- Have the Codex converter add the same prefix. Converted skills and agent skills carry `trackbed:<name>` as their name and folder, and plugin-root paths to a skill's own files follow the folder rename, so Codex users type `$trackbed:pr:code-review`.
- Write every reference to a shipped component, in skills, agents, shared files, docs, and tests, as the qualified `trackbed:<name>`. That string is the real name on both hosts, so one text serves both.
- Give the local maintenance skill the full name `trackbed:skill:audit-sources` in its frontmatter and folder. Project skills get no plugin prefix, so their own name is what users type.
- Replace the naming rule in [2026-07-29-skill-catalog-shape.md](2026-07-29-skill-catalog-shape.md): new and renamed skills use exactly `<domain>:<skill-name>` in frontmatter and folder, invoked as `trackbed:<domain>:<skill-name>`. Frontmatter names stay within 55 characters, so the qualified Codex name stays within 64.
- Map pre-1.0.0 names in usage telemetry. `kramme:<name>`, `kramme-cc-workflow:kramme-<name>`, and stored `kramme:` records count as `trackbed:<name>`, so the 30-day and 90-day usage evidence that catalog decisions rely on carries over.
- Update names in existing records in place for components that exist today. Names of removed or renamed skills, release history in `CHANGELOG.md`, and fixtures for legacy installs keep their `kramme:` spelling.

## Consequences

- Every existing install breaks once. Claude Code users remove `kramme-cc-workflow@kramme-cc-workflow` and its marketplace, then add `trackbed/skills` and install `trackbed@trackbed`. Codex users remove the old plugin and marketplace, then install again. The release that ships this is 1.0.0.
- The plugin source folder moved from `kramme-cc-workflow/` to `trackbed/` in the same release. Installs from before 1.0.0 check for updates at a URL that contains the old folder, so they stop receiving update notices; they have to be reinstalled anyway, as the README migration section describes.
- A follow-up change before 1.0.0 renamed the remaining identifiers as well: `TRACKBED_*` environment variables, the `trackbed.baseBranch` Git setting, `trackbed/` state and config directories, `~/.trackbed/diagrams/` and the repository-local `.trackbed/` folder, the `trackbed-platforms` frontmatter key, the `.trackbed-plugin-marketplaces` Codex install directory, temporary-file prefixes, and the npm package names. Settings an existing machine may hold keep working: `KRAMME_*` variables and `kramme.baseBranch` are read while their new names are unset, existing files in the `kramme-cc-workflow/` state and config directories stay in use until a `trackbed/` file exists, and the Codex installer still recognizes marketplaces it generated under the old names.
- Review-comment identity markers such as `[kramme:pr:identity …]` keep their spelling, so comments posted before the rename stay recognizable.
- Claude Code also lists each skill under a hyphenated id, such as `trackbed:pr-code-review`. Launch strings that need that id, such as the Conductor cloud launcher, use it.

## Alternatives Considered

- **Name the plugin `kramme`.** Claude Code would show `/kramme:pr:code-review`, Codex names and most prose references would not change, and the migration would be much smaller. Rejected because the repository now belongs to the `trackbed` organization, and the namespace should match it.
- **Keep the `kramme:` prefix and rename only the plugin.** Claude Code would show `/trackbed:kramme:pr:code-review`, which keeps the double namespace this decision removes.
- **Prefix the source names with `trackbed:`.** Claude Code would show `/trackbed:trackbed:pr:code-review`.
- **Keep Codex folders unprefixed and change only the Codex frontmatter name.** Skill-local paths would need no rewrite, but each folder name would no longer match its skill name, which the repository's naming rules require.
