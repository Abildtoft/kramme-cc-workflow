# kramme-cc-workflow

This repository contains Claude Code workflow plugins and support scripts.

> [!IMPORTANT]
> Several skills in `kramme-cc-workflow` are adapted from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills).
> See the detailed attribution list in [`kramme-cc-workflow/README.md`](kramme-cc-workflow/README.md#attribution).

## Main Plugin Contents (`kramme-cc-workflow`)

- `72` skills in `skills/` (SIW, PR workflows, Linear workflows, verification, documentation utilities, and session helpers)
- `20` specialized agents in `agents/` for review and analysis
- built-in hooks in `hooks/hooks.json` for command safety, non-interactive git enforcement, formatting, and context links
- release and install tooling in `scripts/`
- Bats test suite in `tests/`

Detailed documentation is available in [`kramme-cc-workflow/README.md`](kramme-cc-workflow/README.md).

## Local Repository Maintenance

This workspace also includes local maintenance skills under `.agents/skills/`, exposed to Claude Code through the `.claude/skills` symlink. These are for maintaining this repository and are not shipped as part of the public plugins.

| Skill | Description |
|---|---|
| `/kramme:skill:audit-sources` | Audits one or more skills against declared inspiration sources, bootstraps missing `references/sources.yaml` manifests, compares fetched source snapshots, and writes `.context/skill-source-audit-<timestamp>.md` reports. |

## What SIW Is

SIW means **Structured Implementation Workflow**.

It is a local, file-based workflow for planning and implementing non-trivial work in a repository. Instead of relying on an external tracker, SIW keeps specification, issue breakdown, and progress state in versioned Markdown files.

SIW typically manages:
- specification files (created or linked during setup)
- `siw/LOG.md` for decisions and progress notes
- `siw/OPEN_ISSUES_OVERVIEW.md` as the active issue index
- `siw/issues/` for issue files with status and implementation context

Common SIW command flow:

```bash
/kramme:siw:init               # create or link spec + initialize siw/
/kramme:siw:generate-phases    # break spec into phase-based issues
/kramme:siw:issue-implement    # implement one issue
/kramme:siw:implementation-audit
/kramme:siw:issue-reindex
```

Related SIW commands include `/kramme:siw:issue-define`, `/kramme:siw:spec-audit`, `/kramme:siw:breakdown-findings`, `/kramme:siw:reset`, `/kramme:siw:reverse-engineer-spec`, and `/kramme:siw:remove`.

## Installation

Marketplace:

```bash
claude /plugin marketplace add Abildtoft/kramme-cc-workflow
claude /plugin install kramme-cc-workflow@kramme-cc-workflow
```

Local install:

```bash
claude /plugin install /path/to/kramme-cc-workflow/kramme-cc-workflow
```

Update marketplace install:

```bash
claude /plugin marketplace update kramme-cc-workflow
```

## Example Commands

After installation, common entry points are:

```bash
/kramme:siw:init
/kramme:pr:code-review
/kramme:pr:fix-ci
/kramme:verify:run
```

## Repository Structure

| Directory | Purpose |
|---|---|
| [`.agents/skills/`](.agents/skills/) | Local repository-maintenance skills used while developing this repo |
| [`.claude/skills`](.claude/skills) | Symlink exposing local maintenance skills to Claude Code |
| [`kramme-cc-workflow/`](kramme-cc-workflow/) | Main plugin: workflow automation, review agents, hooks, and verification |

## Documentation

- [`kramme-cc-workflow/README.md`](kramme-cc-workflow/README.md)

## License

MIT
