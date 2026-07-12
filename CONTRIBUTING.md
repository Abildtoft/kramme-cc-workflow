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

Install Node dependencies from the repository root:

```bash
npm install
```

Install Bats and `jq` for the shell test suite:

```bash
make -C kramme-cc-workflow install-test-deps
```

That target uses Homebrew because the project is developed primarily on macOS. On Linux, install equivalent packages with the system package manager.

## Change Guidelines

- Keep changes scoped to the subsystem being modified.
- Add or update README entries when adding skills, agents, hooks, commands, or user-facing workflows.
- Keep skills self-contained inside their own directory. Skill runtime files must not depend on repository-level docs.
- Keep `SKILL.md` files focused; move reference material to `references/`, templates to `assets/`, and executable helpers to `scripts/`.
- Preserve upstream source and license notes when copying scripts or substantial assets.
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

Focused targets are listed in [README.md](README.md#running-the-tests). Use [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) to map files to likely tests.

### Optional pre-commit check

Run the fast contributor gate before committing:

```bash
npm run check:pre-commit
```

It checks formatting for maintained JavaScript, shell, Markdown, JSON, and YAML files changed from the base branch, then runs lint and the cross-language smoke suite. The command is opt-in and does not install or modify Git hooks.
