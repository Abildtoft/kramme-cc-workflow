# Contributing

This repository ships the `trackbed` Claude Code plugin from `trackbed/`. The root [README.md](README.md) is the canonical entry point for public documentation, and the guides under [trackbed/docs/](trackbed/docs/) hold the deep usage reference it links; plugin source and tests live under [trackbed/](trackbed/).

## Start Here

Before changing files, read the narrowest docs that match the work:

- [AGENTS.md](AGENTS.md) for component conventions.
- [docs/architecture.md](trackbed/docs/architecture.md) for subsystem boundaries.
- [docs/code-map.md](trackbed/docs/code-map.md) for source-to-test mapping.
- [docs/decisions/README.md](trackbed/docs/decisions/README.md) for settled repository decisions.

Check the working tree before editing and preserve unrelated local changes:

```bash
git status --short
```

## Local Setup

Check the portable baseline toolchain without changing the host:

```bash
bash trackbed/scripts/bootstrap-dev.sh --check
```

To install missing dependencies, choose the explicit install mode:

```bash
bash trackbed/scripts/bootstrap-dev.sh --install
```

On macOS, installation uses Homebrew for Make, Bats, `jq`, Node.js 20+, and Python 3.10+. On Debian 12+ and Ubuntu 22.04+, install Node.js 20+ with npm first; Python 3.10+ must also be available before setup mutates the host. The bootstrap then uses `apt-get` for `make`, `bats`, `jq`, `python3`, and `python3-venv`. Both paths create a repository-local `.venv` from the pinned `requirements-dev.txt` and install Node packages with `npm ci`. The Makefile automatically prefers ShellCheck, Ruff, and mypy from `.venv`.

The equivalent npm aliases are `npm run bootstrap:check` and `npm run bootstrap:install` once Node.js 20+, npm, and Python 3.10+ are available. The check mode is the default and never invokes a package manager. Neither mode installs or modifies Git hooks. Skill changes also require SkillSpector for `pr-verify`; install it separately before running the changed-skill security gate.

### Converter changes

For a focused converter change, run `make -C trackbed test-convert`.

The repository-root `package.json` versions the npm installer entrypoint. `trackbed/package.json` versions the plugin package and is managed by the plugin release flow. These versions are intentionally independent; do not synchronize them. See the [release guide](trackbed/RELEASE.md) for the complete versioning and release contract.

## Change Guidelines

- Keep changes scoped to the subsystem being modified.
- Add or update README entries when adding skills, agents, hooks, commands, or user-facing workflows, including a one-line summary for each new skill or agent in `trackbed/scripts/synced-contracts.yaml`. Keep README paragraphs short, and put deep usage detail in the matching guide under `trackbed/docs/`.
- Keep skills self-contained within the installed plugin. A skill may use its own directory, plugin-level `trackbed/shared/` references and assets, and `trackbed/scripts/` helpers, but never repository-level docs. Put a file that two or more skills need in one of those plugin-level locations instead of copying it, and name its `${CLAUDE_PLUGIN_ROOT}/...` path in each consuming `SKILL.md`.
- Keep `SKILL.md` files focused; move reference material to `references/`, templates to `assets/`, and executable helpers to `scripts/`.
- Treat public availability as provenance, not permission. Copy external prose, code, templates, or substantial assets only under a verified compatible license; preserve the complete required notice in the affected skill and mark the source `usage: copied` in `references/sources.yaml` with its exact upstream path and an immutable commit, revision, release, or version. For conceptual inspiration, use `usage: inspiration` and rewrite in original language.
- Never commit fetched upstream source bodies or `references/sources-snapshot/` directories. Store source URLs, original notes, review dates, upstream commit IDs, and normalized hashes only.
- Use plain-English commit messages on branches. Pull Request titles must use Conventional Commits format.

## Verification

Choose the smallest meaningful focused check first. Use the smoke target for representative cross-language feedback, then broaden to the complete PR or release gate when the change warrants it.

```bash
# Closest focused test for a documentation change (use the code map for other changes)
make -C trackbed test-bats-file BATS_TEST_FILE=tests/repository-instructions.bats

# Representative cross-language feedback
make -C trackbed test-smoke

# Complete default suite
make -C trackbed test

# Shell, Python, and JavaScript linting
make -C trackbed lint

# Normal Pull Request gate
make -C trackbed pr-verify

# Release-candidate gate
make -C trackbed verify
```

Focused targets are listed in [docs/development.md](trackbed/docs/development.md#running-the-tests). Use [docs/code-map.md](trackbed/docs/code-map.md) to map files to likely tests.

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
