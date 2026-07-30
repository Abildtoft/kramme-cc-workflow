# Contributing

This repository ships the `kramme-cc-workflow` Claude Code plugin. The root [README.md](README.md) is the canonical public documentation; plugin source and tests live under [kramme-cc-workflow/](kramme-cc-workflow/).

## Start Here

Before changing files, read the narrowest docs that match the work:

- [CLAUDE.md](CLAUDE.md) for component conventions.
- [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) for subsystem boundaries.
- [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) for source-to-test mapping.
- [docs/decisions/README.md](kramme-cc-workflow/docs/decisions/README.md) for settled repository decisions.

Check the working tree before editing and preserve unrelated local changes:

```bash
git status --short
```

## Local Setup

Check the portable baseline toolchain without changing the host:

```bash
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --check
```

To install missing dependencies, choose the explicit install mode:

```bash
bash kramme-cc-workflow/scripts/bootstrap-dev.sh --install
```

On macOS, installation uses Homebrew for Make, Bats, `jq`, Node.js 20+, and Python 3.10+. On Debian 12+ and Ubuntu 22.04+, install Node.js 20+ with npm first; Python 3.10+ must also be available before setup mutates the host. The bootstrap then uses `apt-get` for `make`, `bats`, `jq`, `python3`, and `python3-venv`. Both paths create a repository-local `.venv` from the pinned `requirements-dev.txt` and install Node packages with `npm ci`. The Makefile automatically prefers ShellCheck, Ruff, and mypy from `.venv`.

The equivalent npm aliases are `npm run bootstrap:check` and `npm run bootstrap:install` once Node.js 20+, npm, and Python 3.10+ are available. The check mode is the default and never invokes a package manager. Neither mode installs or modifies Git hooks. Skill changes also require SkillSpector for `pr-verify`; install it separately before running the changed-skill security gate.

## Change Guidelines

- Keep changes scoped to the subsystem being modified.
- Add or update README entries when adding skills, agents, hooks, commands, or user-facing workflows.
- Keep skills self-contained inside their own directory. Skill runtime files must not depend on repository-level docs.
- Keep `SKILL.md` files focused; move reference material to `references/`, templates to `assets/`, and executable helpers to `scripts/`.
- Treat public availability as provenance, not permission. Copy external prose, code, templates, or substantial assets only under a verified compatible license; preserve the complete required notice in the affected skill and mark the source `usage: copied` in `references/sources.yaml` with its exact upstream path and an immutable commit, revision, release, or version. For conceptual inspiration, use `usage: inspiration` and rewrite in original language.
- Never commit fetched upstream source bodies or `references/sources-snapshot/` directories. Store source URLs, original notes, review dates, and normalized hashes only.
- Use plain-English commit messages on branches. Pull Request titles must use Conventional Commits format.

## Verification

Choose the smallest meaningful check first, then broaden when the change has shared behavior or release impact.

```bash
# Fast default suite
make -C kramme-cc-workflow test

# Shell and Python linting
make -C kramme-cc-workflow lint

# Stronger pre-PR or release gate
make -C kramme-cc-workflow verify
```

Focused targets are listed in [docs/development.md](kramme-cc-workflow/docs/development.md#running-the-tests). Use [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to map files to likely tests.

### Optional pre-commit check

Run the fast contributor gate directly before committing:

```bash
npm run check:pre-commit
```

It checks formatting for maintained Python, JavaScript, shell, Markdown, JSON, and YAML files changed from the base branch, then runs lint and the cross-language smoke suite.

To opt in to the repository-managed hook, install `pre-commit` first (`brew install pre-commit` on macOS or `sudo apt-get install -y pre-commit` on Debian/Ubuntu), then run:

```bash
npm run hooks:install
```

The local hook delegates to `npm run check:pre-commit`. Remove it at any time with `npm run hooks:uninstall`. No hook is installed by the bootstrap script or other repository commands.
