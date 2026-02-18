# kramme-cc-workflow

This repository contains Claude Code workflow plugins and support scripts.

## Included Plugins

| Plugin | Description |
|---|---|
| [`kramme-cc-workflow`](kramme-cc-workflow/) | General workflow plugin. Includes SIW planning, PR lifecycle skills, verification helpers, review agents, hooks, and supporting scripts. |
| [`kramme-connect-workflow`](kramme-connect-workflow/) | Connect-specific plugin for [Consensus ApS](https://consensus.dk)'s monorepo work (Angular modernization, Nx extraction, NgRx migration, and Rive docs). |

## Main Plugin Contents (`kramme-cc-workflow`)

- `48` skills in `skills/` (SIW, PR workflows, Linear workflows, verification, documentation utilities, and session helpers)
- `20` specialized agents in `agents/` for review and analysis
- built-in hooks in `hooks/hooks.json` for command safety, non-interactive git enforcement, formatting, and context links
- release and install tooling in `scripts/`
- Bats test suite in `tests/`

Detailed documentation is available in [`kramme-cc-workflow/README.md`](kramme-cc-workflow/README.md).

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
/kramme:siw:issues-reindex
```

Related SIW commands include `/kramme:siw:issue-define`, `/kramme:siw:spec-audit`, `/kramme:siw:reset`, `/kramme:siw:reverse-engineer-spec`, and `/kramme:siw:remove`.

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

Install the Connect plugin from marketplace:

```bash
claude /plugin install kramme-cc-workflow@kramme-connect-workflow
```

Local install for the Connect plugin:

```bash
claude /plugin install /path/to/kramme-cc-workflow/kramme-connect-workflow
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
| [`kramme-cc-workflow/`](kramme-cc-workflow/) | Main plugin: workflow automation, review agents, hooks, and verification |
| [`kramme-connect-workflow/`](kramme-connect-workflow/) | Connect product-specific skills |

## Documentation

- [`kramme-cc-workflow/README.md`](kramme-cc-workflow/README.md)
- [`kramme-connect-workflow/README.md`](kramme-connect-workflow/README.md)

## License

MIT
