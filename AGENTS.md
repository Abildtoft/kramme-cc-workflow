# AGENTS.md

Entry point for coding agents and maintainers working in this repository. This
file routes to the canonical sources of truth; it does not restate their rules.

## Start Here

Read the narrowest doc that matches the work, in this order:

1. [CONTRIBUTING.md](CONTRIBUTING.md) — local setup, change guidelines, and
   verification commands.
2. [CLAUDE.md](CLAUDE.md) — component conventions: naming, skill frontmatter, and
   the commit/PR title policy.
3. [docs/architecture.md](kramme-cc-workflow/docs/architecture.md) — subsystem
   boundaries and runtime flow.
4. [docs/code-map.md](kramme-cc-workflow/docs/code-map.md) — source-to-test map;
   use it to pick the first files to read and the closest tests to run.
5. [docs/decisions/README.md](kramme-cc-workflow/docs/decisions/README.md) —
   settled repository decisions and their sources.

## Ground Rules

Each rule points to its source of truth; follow the source, not this summary.

- The root [README.md](README.md) is the canonical public documentation. Keep
  install, usage, component listings, and testing there.
- Skills are self-contained. A skill's `SKILL.md` and resources must not depend
  on repository-level docs after installation ([CLAUDE.md](CLAUDE.md)).
- Codex output is generated from the Claude plugin source. Edit the source or the
  converter, never installed copies
  ([docs/agent-portability.md](kramme-cc-workflow/docs/agent-portability.md)).

## Before You Finish

Run the smallest meaningful check, then broaden:

```bash
make -C kramme-cc-workflow test     # fast default suite
make -C kramme-cc-workflow lint     # shell, Python, and JS linting
make -C kramme-cc-workflow verify   # stronger pre-PR / release gate
```

Map changed files to the closest tests with
[docs/code-map.md](kramme-cc-workflow/docs/code-map.md).
