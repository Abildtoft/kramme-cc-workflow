# Skill Contract Linter

This package implements the registry-driven checks behind
[`../lint-skill-contracts.py`](../lint-skill-contracts.py). The compatibility
script preserves the established CLI and import surface; this directory owns
the parsing, validation, synchronization, and reporting behavior.

## Responsibility Map

| Area | Owning modules | Start here when |
| --- | --- | --- |
| Compatibility and public API | `../lint-skill-contracts.py`, `__init__.py`, `checks/__init__.py` | The legacy script or an importing consumer cannot reach the package API. |
| CLI and reporting | `cli.py` | Arguments, registry loading, exit status, warning output, or failure output is wrong. |
| Shared parsing and paths | `frontmatter.py`, `markdown.py`, `strings.py`, `io.py` | Frontmatter values, Markdown table cells, normalized strings, resolved paths, hashes, or skill discovery are wrong. |
| Contract schema | `schema.py` | Schema loading, fallback behavior, required frontmatter fields, or source-manifest fields are wrong. |
| Check orchestration | `checks/types.py`, `checks/registry.py` | Check ordering, shared context, or failure and warning aggregation is wrong. |
| Text and file contracts | `checks/basic.py` | Synced text, inventory, heading order, file identity, or required-file checks are wrong. |
| Workflow guidance contracts | `checks/base_diff_scope.py`, `checks/epilogue.py`, `checks/ui_relevance.py` | Base-diff guidance, skill epilogue order, or UI-relevance rules and fixtures are wrong. |
| Manifest, provenance, hook, and mechanical contracts | `checks/marker_manifest.py`, `checks/source_provenance.py`, `checks/hooks_json.py`, `checks/mechanical.py` | Source manifests, copied-source licensing or immutable origin metadata, forbidden source snapshots, hook registration, frontmatter, naming, or skill line budgets are wrong. |
| Routing distinctness | `checks/routing_distinctness.py` | Skill descriptions overlap too closely for auto-invocation routing, a recorded routing boundary is stale, removable, or missing its positive clause, or the nearest-pair burndown is wrong. |
| README synchronization | `readme.py`, `checks/readme_sync.py` | Skill, agent, or hook reference rows drift, or generated component-reference output is wrong. |
| Compact component catalog | `catalog.py`, `checks/component_catalog.py` | The generated JSON component index drifts, omits a component, or emits a path that does not exist. |

The ordered runtime boundary is `checks/registry.py`. New checks belong in a
focused check module and must be registered there. Keep generic parsing in the
shared helpers, and keep CLI presentation in `cli.py`.

## Investigation Paths

- A skill-frontmatter diagnostic starts in `checks/mechanical.py`, then follows
  parsing into `frontmatter.py` and field definitions into `schema.py`.
- A README row mismatch starts in `checks/readme_sync.py`, then follows
  comparison and rendering into `readme.py`. The write-capable consumer is
  [`../generate-component-reference.py`](../generate-component-reference.py).
- A component catalog mismatch starts in `checks/component_catalog.py`, then
  follows rendering into `catalog.py`. The catalog reads its source directories
  from the README sync configs, so a component source problem is reported by the
  README sync checks and the catalog check only reports that it is blocked.
- Missing, duplicated, or reordered diagnostics start in `checks/registry.py`
  and `checks/types.py`; only final terminal formatting belongs in `cli.py`.

## Tests and Commands

The focused Python suite covers parsing helpers, schema-backed frontmatter
behavior, check registration and aggregation, representative specialized
checks, README helpers, and the compatibility entry point:

```bash
python3 -m unittest kramme-cc-workflow/tests/python/test_lint_skill_contracts.py
```

The Bats suite exercises the CLI against the live registry and integration
fixtures for text, file, hook, manifest, mechanical, and README synchronization
contracts:

```bash
make -C kramme-cc-workflow test-skill-contracts
```

Run the linter itself when changing
[`../synced-contracts.yaml`](../synced-contracts.yaml), the shared
[`../schemas/skill-contracts.json`](../schemas/skill-contracts.json), or a
registered source:

```bash
python3 kramme-cc-workflow/scripts/lint-skill-contracts.py
```

Test sources:

- [`../../tests/python/test_lint_skill_contracts.py`](../../tests/python/test_lint_skill_contracts.py)
- [`../../tests/python/test_lint_routing_distinctness.py`](../../tests/python/test_lint_routing_distinctness.py)
- [`../../tests/lint-skill-contracts.bats`](../../tests/lint-skill-contracts.bats)
