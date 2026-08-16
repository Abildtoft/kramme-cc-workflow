from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
SCRIPT_PATH = SCRIPTS_DIR / "lint-skill-contracts.py"
sys.path.insert(0, str(SCRIPTS_DIR))

import lint_skill_contracts  # noqa: E402
from lint_skill_contracts.frontmatter import frontmatter_type_errors  # noqa: E402


def load_compat_script(module_name="lint_skill_contracts_cli"):
    spec = importlib.util.spec_from_file_location(module_name, SCRIPT_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    previous = sys.modules.get(module_name)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
        return module
    finally:
        if previous is None:
            sys.modules.pop(module_name, None)
        else:
            sys.modules[module_name] = previous


class MarkdownTableHelpersTest(unittest.TestCase):
    def test_split_markdown_table_row_keeps_escaped_pipes_in_cells(self) -> None:
        cells = lint_skill_contracts.split_markdown_table_row(r"| Skill | `foo\|bar` | Uses \<value\> |")

        self.assertEqual(cells, ["Skill", r"`foo\|bar`", r"Uses \<value\>"])
        self.assertEqual(lint_skill_contracts.normalize_markdown_cell(cells[1]), "foo|bar")
        self.assertEqual(lint_skill_contracts.normalize_markdown_cell(cells[2]), "Uses <value>")

    def test_render_skill_reference_row_escapes_table_cells(self) -> None:
        reference = lint_skill_contracts.SkillReference(
            name="kramme:test",
            display_name="/kramme:test",
            invocation="User",
            arguments="[left|right]",
            description="Use a | b",
        )

        self.assertEqual(
            lint_skill_contracts.render_skill_reference_row(reference),
            r"| `/kramme:test` | User | `[left\|right]` | Use a \| b |",
        )

    def test_render_agent_and_hook_reference_rows_escape_table_cells(self) -> None:
        self.assertEqual(
            lint_skill_contracts.render_agent_reference_row(
                lint_skill_contracts.AgentReference(
                    name="kramme:reviewer",
                    description="Use a | b",
                )
            ),
            r"| `kramme:reviewer` | Use a \| b |",
        )
        self.assertEqual(
            lint_skill_contracts.render_hook_reference_row(
                lint_skill_contracts.HookReference(
                    name="sample-hook",
                    event="PostToolUse (Write|Edit)",
                    description="Use a | b",
                )
            ),
            r"| `sample-hook` | PostToolUse (Write\|Edit) | Use a \| b |",
        )

    def test_load_hook_references_aggregates_duplicate_hook_events(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            hooks_path = root / "hooks" / "hooks.json"
            hooks_path.parent.mkdir(parents=True)
            hooks_path.write_text(
                """
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/sample-hook.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/sample-hook.sh"
          }
        ]
      }
    ]
  }
}
""".strip(),
                encoding="utf-8",
            )
            failures: list[str] = []

            references = lint_skill_contracts.load_hook_references(
                root,
                {
                    "hooks_json": "hooks/hooks.json",
                    "descriptions": {"sample-hook": "Runs a sample hook"},
                },
                failures,
            )

        self.assertEqual(failures, [])
        self.assertEqual(
            references["sample-hook"],
            lint_skill_contracts.HookReference(
                name="sample-hook",
                event="PreToolUse (Skill), UserPromptSubmit",
                description="Runs a sample hook",
                path="kramme-cc-workflow/hooks/sample-hook.sh",
            ),
        )


FRONTMATTER_TYPE_CASES = json.loads(
    (Path(__file__).resolve().parents[1] / "fixtures" / "frontmatter-type-cases.json").read_text(encoding="utf-8")
)["cases"]


class FrontmatterTypeContractTest(unittest.TestCase):
    """Pin the Python linter to the shared converter oracle fixtures."""

    def test_shared_fixtures_are_non_empty(self) -> None:
        self.assertGreater(len(FRONTMATTER_TYPE_CASES), 0)

    def test_type_errors_match_shared_converter_fixtures(self) -> None:
        for case in FRONTMATTER_TYPE_CASES:
            with self.subTest(case=case["name"]):
                fields = sorted(field for field, _ in frontmatter_type_errors(case["text"]))
                self.assertEqual(fields, sorted(case["invalidFields"]))


class FrontmatterContractHelpersTest(unittest.TestCase):
    def test_type_errors_strip_comments_from_quoted_block_array_items(self) -> None:
        empty_item_with_comment = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - "" # placeholder
---
"""
        valid_items_with_comment = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - "codex" # primary
  - claude-code
---
"""

        self.assertEqual(
            frontmatter_type_errors(empty_item_with_comment),
            [
                (
                    "kramme-platforms",
                    "a non-empty array of non-empty strings",
                )
            ],
        )
        self.assertEqual(frontmatter_type_errors(valid_items_with_comment), [])

    def test_type_errors_match_converter_legacy_numeric_strings(self) -> None:
        text = """---
name: +1
description: 1e3
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - -1e2
---
"""

        self.assertEqual(frontmatter_type_errors(text), [])

    def test_type_errors_decode_quoted_yaml_before_checking_emptiness(self) -> None:
        text = r"""---
name: test-skill
description: "\n"
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, "\x20"]
---
"""

        self.assertEqual(
            frontmatter_type_errors(text),
            [
                ("description", "a non-empty string"),
                (
                    "kramme-platforms",
                    "a non-empty array of non-empty strings",
                ),
            ],
        )

    def test_type_errors_accept_escaped_quotes_in_flow_arrays(self) -> None:
        text = r"""---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: ["claude\",code", codex]
---
"""

        self.assertEqual(frontmatter_type_errors(text), [])

    def test_type_errors_read_complete_multiline_quoted_scalars(self) -> None:
        whitespace_string = """---
name: test-skill
description: "
  "
disable-model-invocation: false
user-invocable: true
---
"""
        multiline_boolean = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: "true
  "
---
"""

        self.assertEqual(
            frontmatter_type_errors(whitespace_string),
            [("description", "a non-empty string")],
        )
        self.assertEqual(frontmatter_type_errors(multiline_boolean), [])

        quoted_boolean_with_comment = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: "true" # Remains user invocable
---
"""
        self.assertEqual(frontmatter_type_errors(quoted_boolean_with_comment), [])

    def test_type_errors_accept_a_trailing_flow_array_comma(self) -> None:
        text = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex,]
---
"""

        self.assertEqual(frontmatter_type_errors(text), [])

    def test_type_errors_reject_non_string_flow_tags_and_aliases(self) -> None:
        invalid_values = ['!!int "1"', "*target", "&target 1"]

        for value in invalid_values:
            with self.subTest(value=value):
                text = f"""---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, {value}]
---
"""
                self.assertEqual(
                    frontmatter_type_errors(text),
                    [
                        (
                            "kramme-platforms",
                            "a non-empty array of non-empty strings",
                        )
                    ],
                )

        explicitly_tagged_string = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [!!str 1, &target codex]
---
"""
        self.assertEqual(frontmatter_type_errors(explicitly_tagged_string), [])

    def test_type_errors_reject_nested_and_empty_block_array_values(self) -> None:
        nested_mapping = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - target:
      name: codex
---
"""
        empty_block_scalar = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - |
---
"""
        expected = [
            (
                "kramme-platforms",
                "a non-empty array of non-empty strings",
            )
        ]

        self.assertEqual(frontmatter_type_errors(nested_mapping), expected)
        self.assertEqual(frontmatter_type_errors(empty_block_scalar), expected)

    def test_type_errors_accepts_an_indented_continued_string(self) -> None:
        text = """---
name: test-skill
description:
  Test skill continued on the next line
disable-model-invocation: false
user-invocable: true
---
"""

        self.assertEqual(frontmatter_type_errors(text), [])

    def test_type_errors_rejects_a_leading_dot_number_in_a_string_array(self) -> None:
        text = """---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, .5]
---
"""

        self.assertEqual(
            frontmatter_type_errors(text),
            [
                (
                    "kramme-platforms",
                    "a non-empty array of non-empty strings",
                )
            ],
        )

    def test_expected_invocation_distinguishes_user_and_background_modes(self) -> None:
        self.assertEqual(
            lint_skill_contracts.expected_invocation(
                {
                    "user-invocable": "true",
                    "disable-model-invocation": "true",
                }
            ),
            "User",
        )
        self.assertEqual(
            lint_skill_contracts.expected_invocation({"user-invocable": "false"}),
            "Background",
        )

    def test_expected_arguments_hides_non_user_invocable_skills(self) -> None:
        self.assertEqual(
            lint_skill_contracts.expected_arguments(
                {
                    "user-invocable": "false",
                    "argument-hint": "[path]",
                }
            ),
            "\u2014",
        )
        self.assertEqual(
            lint_skill_contracts.expected_arguments(
                {
                    "user-invocable": "true",
                    "argument-hint": "'[path]'",
                }
            ),
            "[path]",
        )


class SourceProvenanceCheckTest(unittest.TestCase):
    def _context(self, root: Path) -> lint_skill_contracts.LintContext:
        return lint_skill_contracts.LintContext(
            root=root,
            registry={
                "source_provenance": {
                    "manifest_glob": ("kramme-cc-workflow/skills/*/references/sources.yaml"),
                    "forbidden_snapshot_globs": [("kramme-cc-workflow/skills/*/references/sources-snapshot")],
                }
            },
            schema={},
        )

    def test_accepts_inspiration_and_licensed_copy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            references = root / "kramme-cc-workflow" / "skills" / "example" / "references"
            references.mkdir(parents=True)
            (references / "UPSTREAM-LICENSE").write_text("license notice\n", encoding="utf-8")
            (references / "sources.yaml").write_text(
                """
sources:
  - id: concepts
    url: https://example.com/concepts
    usage: inspiration
  - id: copied
    url: https://example.com/copied
    usage: copied
    license: MIT
    notice: references/UPSTREAM-LICENSE
    upstream_path: scripts/copied.sh
    upstream_commit: 0123456789abcdef0123456789abcdef01234567
""".strip(),
                encoding="utf-8",
            )

            result = lint_skill_contracts.check_source_provenance(self._context(root))

        self.assertEqual(result.failures, [])

    def test_rejects_snapshots_invalid_usage_and_incomplete_copy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            references = root / "kramme-cc-workflow" / "skills" / "example" / "references"
            snapshot = references / "sources-snapshot"
            snapshot.mkdir(parents=True)
            (references / "UPSTREAM-LICENSE").write_text("license notice\n", encoding="utf-8")
            (references / "sources.yaml").write_text(
                """
sources:
  - id: missing-usage
    url: https://example.com/missing
  - id: invalid-usage
    url: https://example.com/invalid
    usage: quoted
  - id: incomplete-copy
    url: https://example.com/copied
    usage: copied
  - id: moving-copy
    url: https://example.com/moving
    usage: copied
    license: MIT
    notice: references/UPSTREAM-LICENSE
    upstream_path: scripts/moving.sh
    upstream_commit: main
""".strip(),
                encoding="utf-8",
            )

            result = lint_skill_contracts.check_source_provenance(self._context(root))

        failures = "\n".join(result.failures)
        self.assertIn("committed upstream source bodies are forbidden", failures)
        self.assertIn("is missing non-empty 'usage'", failures)
        self.assertIn("has invalid usage 'quoted'", failures)
        self.assertIn("is missing non-empty 'license'", failures)
        self.assertIn("is missing non-empty 'notice'", failures)
        self.assertIn("is missing non-empty 'upstream_path'", failures)
        self.assertIn("is missing an immutable upstream revision", failures)
        self.assertIn("'upstream_commit' must be immutable, not 'main'", failures)
        self.assertIn("'upstream_commit' must be a full 40- or 64-character commit hash", failures)

    def test_rejects_notice_outside_skill_or_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            references = root / "kramme-cc-workflow" / "skills" / "example" / "references"
            references.mkdir(parents=True)
            (references / "sources.yaml").write_text(
                """
sources:
  - id: traversal
    url: https://example.com/traversal
    usage: copied
    license: MIT
    notice: ../../OUTSIDE-LICENSE
    upstream_path: scripts/traversal.sh
    upstream_commit: 0123456789abcdef0123456789abcdef01234567
  - id: missing
    url: https://example.com/missing
    usage: copied
    license: MIT
    notice: references/MISSING-LICENSE
    upstream_path: scripts/missing.sh
    upstream_commit: 0123456789abcdef0123456789abcdef01234567
""".strip(),
                encoding="utf-8",
            )

            result = lint_skill_contracts.check_source_provenance(self._context(root))

        failures = "\n".join(result.failures)
        self.assertIn("must stay within the skill directory", failures)
        self.assertIn("notice file does not exist", failures)


COMPONENT_CATALOG_REGISTRY = {
    "component_catalog": {"path": "catalog.json", "canonical_reference": "README.md"},
    "readme_skill_sync": {"skills_dir": "skills"},
    "readme_agent_sync": {"agents_dir": "agents"},
    "readme_hook_sync": {
        "hooks_json": "hooks/hooks.json",
        "plugin_root": "plugin",
        "descriptions": {"sample-hook": "Runs a sample hook"},
    },
}


class ComponentCatalogTest(unittest.TestCase):
    def _write_tree(self, root: Path) -> None:
        skill = root / "skills" / "kramme:sample"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            """
---
name: kramme:sample
description: Sample skill
disable-model-invocation: true
user-invocable: true
---
# kramme:sample
""".strip()
            + "\n",
            encoding="utf-8",
        )
        agents = root / "agents"
        agents.mkdir()
        (agents / "kramme:reviewer.md").write_text(
            """
---
name: kramme:reviewer
description: Reviews code
---
# kramme:reviewer
""".strip()
            + "\n",
            encoding="utf-8",
        )
        hooks = root / "plugin" / "hooks"
        hooks.mkdir(parents=True)
        (hooks / "sample-hook.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
        manifest = root / "hooks"
        manifest.mkdir()
        (manifest / "hooks.json").write_text(
            json.dumps(
                {
                    "hooks": {
                        "PreToolUse": [
                            {
                                "matcher": "Bash",
                                "hooks": [
                                    {
                                        "type": "command",
                                        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/sample-hook.sh",
                                    }
                                ],
                            }
                        ]
                    }
                }
            ),
            encoding="utf-8",
        )

    def _context(self, root: Path) -> lint_skill_contracts.LintContext:
        return lint_skill_contracts.LintContext(
            root=root,
            registry=COMPONENT_CATALOG_REGISTRY,
            schema=lint_skill_contracts.DEFAULT_CONTRACT_SCHEMA,
        )

    def test_render_returns_nothing_without_registry_config(self) -> None:
        relative, rendered, failures = lint_skill_contracts.render_component_catalog(Path("/tmp/repo"), {}, {})

        self.assertEqual((relative, rendered, failures), (None, None, []))

    def test_document_indexes_every_component_type_by_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_tree(root)
            failures: list[str] = []

            document = lint_skill_contracts.component_catalog_document(
                root,
                COMPONENT_CATALOG_REGISTRY,
                lint_skill_contracts.DEFAULT_CONTRACT_SCHEMA,
                failures,
            )

        self.assertEqual(failures, [])
        assert document is not None
        self.assertEqual(document["canonical_reference"], "README.md")
        self.assertEqual(
            document["skills"],
            [
                {
                    "name": "kramme:sample",
                    "invocation": "User",
                    "path": "skills/kramme:sample/SKILL.md",
                }
            ],
        )
        self.assertEqual(
            document["agents"],
            [{"name": "kramme:reviewer", "path": "agents/kramme:reviewer.md"}],
        )
        self.assertEqual(
            document["hooks"],
            [
                {
                    "name": "sample-hook",
                    "event": "PreToolUse (Bash)",
                    "path": "plugin/hooks/sample-hook.sh",
                }
            ],
        )

    def test_render_is_deterministic_json_with_trailing_newline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_tree(root)

            first = lint_skill_contracts.render_component_catalog(
                root, COMPONENT_CATALOG_REGISTRY, lint_skill_contracts.DEFAULT_CONTRACT_SCHEMA
            )
            second = lint_skill_contracts.render_component_catalog(
                root, COMPONENT_CATALOG_REGISTRY, lint_skill_contracts.DEFAULT_CONTRACT_SCHEMA
            )

        self.assertEqual(first, second)
        self.assertEqual(first[0], "catalog.json")
        assert first[1] is not None
        self.assertTrue(first[1].endswith("\n"))
        self.assertEqual(json.loads(first[1]), json.loads(second[1] or ""))

    def test_check_reports_missing_and_stale_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_tree(root)
            context = self._context(root)

            missing = lint_skill_contracts.check_component_catalog(context)

            (root / "catalog.json").write_text("{}\n", encoding="utf-8")
            stale = lint_skill_contracts.check_component_catalog(context)

            _relative, rendered, _failures = lint_skill_contracts.render_component_catalog(
                root, COMPONENT_CATALOG_REGISTRY, lint_skill_contracts.DEFAULT_CONTRACT_SCHEMA
            )
            (root / "catalog.json").write_text(rendered or "", encoding="utf-8")
            synced = lint_skill_contracts.check_component_catalog(context)

        self.assertIn("registered path is missing: catalog.json", "\n".join(missing.failures))
        self.assertIn("catalog.json is stale", "\n".join(stale.failures))
        self.assertIn(
            "run python3 kramme-cc-workflow/scripts/generate-component-reference.py --write",
            "\n".join(stale.failures),
        )
        self.assertEqual(synced.failures, [])

    def test_check_requires_readme_sync_configs(self) -> None:
        failures: list[str] = []

        lint_skill_contracts.check_component_catalog_drift(
            Path("/tmp/repo"),
            {"component_catalog": {"path": "catalog.json"}},
            {},
            failures,
        )

        self.assertIn("readme_skill_sync", "\n".join(failures))
        self.assertIn("readme_agent_sync", "\n".join(failures))
        self.assertIn("readme_hook_sync", "\n".join(failures))


class CheckRegistryTest(unittest.TestCase):
    def test_registry_preserves_cli_check_order(self) -> None:
        self.assertEqual(
            [name for name, _check in lint_skill_contracts.CHECKS],
            [
                "text_contracts",
                "ordered_heading_contracts",
                "file_identity",
                "required_file_contracts",
                "base_diff_scope",
                "ui_relevance_contracts",
                "marker_manifests",
                "source_provenance",
                "epilogue_order",
                "hooks_json",
                "readme_skill_sync",
                "component_catalog",
                "routing_distinctness",
                "mechanical",
            ],
        )

    def test_run_checks_accumulates_results_in_registry_order(self) -> None:
        context = lint_skill_contracts.LintContext(
            root=Path("/tmp/repo"),
            registry={},
            schema={},
        )

        def first(_context):
            return lint_skill_contracts.CheckResult(
                failures=["first failure"],
                warnings=["first warning"],
            )

        def second(_context):
            return lint_skill_contracts.CheckResult(
                failures=["second failure"],
                warnings=["second warning"],
            )

        result = lint_skill_contracts.run_checks(
            context,
            checks=(("first", first), ("second", second)),
        )

        self.assertEqual(result.failures, ["first failure", "second failure"])
        self.assertEqual(result.warnings, ["first warning", "second warning"])


class BaseDiffScopeCheckTest(unittest.TestCase):
    def test_rejects_quoted_and_unquoted_manual_remote_snippets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            skill_path = root / "skills" / "example" / "SKILL.md"
            skill_path.parent.mkdir(parents=True)
            skill_path.write_text(
                "\n".join(
                    [
                        "```bash",
                        "BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null)",
                        "git fetch origin refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}",
                        'git merge-base "origin/${BASE_BRANCH}" HEAD',
                        'git diff --name-only "origin/$BASE_BRANCH"...HEAD',
                        "```",
                    ]
                ),
                encoding="utf-8",
            )
            registry = lint_skill_contracts.load_registry(SCRIPTS_DIR / "synced-contracts.yaml")
            config = dict(registry["base_diff_scope"])
            config["paths"] = ["skills/example/SKILL.md"]
            context = lint_skill_contracts.LintContext(
                root=root,
                registry={"base_diff_scope": config},
                schema={},
            )

            result = lint_skill_contracts.check_base_diff_scope(context)

            failures = "\n".join(result.failures)
            self.assertIn("manual-origin-head-base-detection", failures)
            self.assertIn("manual-base-fetch", failures)
            self.assertIn("manual-origin-base-merge-base", failures)
            self.assertIn("manual-origin-base-diff", failures)


class UIRelevanceContractTest(unittest.TestCase):
    def test_ui_relevance_matcher_classifies_fixture_paths(self) -> None:
        matcher = {
            "extensions": [".tsx", ".astro", ".mdx", ".htm", ".hbs", ".css", ".styl"],
            "basename_prefixes": ["tailwind.config.", "theme."],
            "directory_segments": ["design-tokens", "pages", "component", "components", "ui"],
            "asset_directory_segments": ["public", "assets"],
            "asset_extensions": [".svg", ".webp"],
        }

        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/components/Button.tsx", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("tailwind.config.ts", matcher))
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path(
                "packages/ui/design-tokens/colors.json",
                matcher,
            )
        )
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("public/logo.svg", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/components/Button.TSX", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/Page.astro", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("docs/component.mdx", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("public/index.htm", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/styles/theme.styl", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/ui/Button.ts", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("src/component/Button.ts", matcher))
        self.assertTrue(lint_skill_contracts.is_ui_relevant_path("public/Logo.SVG", matcher))
        self.assertFalse(lint_skill_contracts.is_ui_relevant_path("src/assets/data.json", matcher))
        self.assertFalse(lint_skill_contracts.is_ui_relevant_path("src/server/user.ts", matcher))

    def test_ui_relevance_contract_reports_missing_terms_and_fixture_drift(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir).resolve()
            canonical = root / "canonical.md"
            local = root / "skill.md"
            canonical.write_text(
                "\n".join(
                    [
                        "UI relevance path contract: ui-relevance-path-contract-v1",
                        "Required terms: *.tsx, assets/",
                        "| Path | Expected |",
                        "| --- | --- |",
                        "| `src/components/Button.tsx` | Non-UI |",
                    ]
                ),
                encoding="utf-8",
            )
            local.write_text(
                "UI relevance path contract: ui-relevance-path-contract-v1\nRequired terms: *.tsx\n",
                encoding="utf-8",
            )
            context = lint_skill_contracts.LintContext(
                root=root,
                registry={
                    "ui_relevance_contracts": [
                        {
                            "name": "fixture-ui-contract",
                            "contract_id": "ui-relevance-path-contract-v1",
                            "canonical_path": "canonical.md",
                            "paths": ["skill.md"],
                            "required_terms": ["*.tsx", "assets/"],
                            "matcher": {
                                "extensions": [".tsx"],
                                "asset_directory_segments": ["assets"],
                                "asset_extensions": [".svg"],
                            },
                            "fixtures": [
                                {
                                    "path": "src/components/Button.tsx",
                                    "ui_relevant": True,
                                }
                            ],
                        }
                    ]
                },
                schema={},
            )

            result = lint_skill_contracts.check_ui_relevance_contracts(context)

        self.assertEqual(
            result.failures,
            [
                "fixture-ui-contract: skill.md is missing UI relevance term 'assets/'",
                "fixture-ui-contract: canonical.md fixture 'src/components/Button.tsx' documents False; expected True",
            ],
        )


class VerifyRunGuidanceTest(unittest.TestCase):
    def test_nx_affected_guidance_uses_resolved_base_ref(self) -> None:
        plugin_root = SCRIPTS_DIR.parent
        skill_text = (plugin_root / "skills" / "kramme:verify:run" / "SKILL.md").read_text(encoding="utf-8")
        commands_text = (
            plugin_root / "skills" / "kramme:verify:run" / "references" / "commands-by-project-type.md"
        ).read_text(encoding="utf-8")

        self.assertIn("Nx `--base=$BASE_REF`", skill_text)
        self.assertIn("use the `$BASE_REF`", skill_text)
        self.assertIn("--base=$BASE_REF", commands_text)
        self.assertNotIn("--base=$BASE_BRANCH", skill_text + commands_text)


class MechanicalCheckTest(unittest.TestCase):
    def test_mechanical_returns_structured_warnings_and_failures(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            skill_path = root / "skills" / "example" / "SKILL.md"
            skill_path.parent.mkdir(parents=True)
            skill_path.write_text(
                "\n".join(
                    [
                        "---",
                        "name: example",
                        "description: Example skill",
                        "disable-model-invocation: true",
                        "---",
                        "one",
                        "two",
                    ]
                ),
                encoding="utf-8",
            )
            context = lint_skill_contracts.LintContext(
                root=root,
                registry={
                    "mechanical": {
                        "skill_glob": "skills/*/SKILL.md",
                        "max_skill_lines": 6,
                        "warn_skill_lines": 5,
                        "skill_line_report_limit": 1,
                        "required_frontmatter": [
                            "name",
                            "description",
                            "disable-model-invocation",
                            "user-invocable",
                        ],
                    }
                },
                schema={},
            )

            result = lint_skill_contracts.check_mechanical(context)

        self.assertEqual(
            result.failures,
            [
                "mechanical: skills/example/SKILL.md has 7 lines, exceeds 6; "
                "move reference material out of SKILL.md or add a registry burndown entry",
                "mechanical: skills/example/SKILL.md is missing frontmatter field 'user-invocable'",
            ],
        )
        self.assertEqual(
            result.warnings,
            [
                "mechanical: long-skill burndown: skills/example/SKILL.md has 7 lines "
                "(over hard budget; warn at 5, fail above 6)"
            ],
        )

    def test_description_warnings_apply_threshold_order_cap_and_hard_limit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            fixtures = "below:4 aaa-at:5 zzz-at:5 middle:6 beta:7 alpha:7 high:9 over:10"
            for fixture in fixtures.split():
                name, length = fixture.split(":")
                path = root / "skills" / name / "SKILL.md"
                path.parent.mkdir(parents=True)
                skill = (
                    f"---\nname: {name}\ndescription: {'x' * int(length)}\n"
                    "disable-model-invocation: false\nuser-invocable: true\n---\nBody.\n"
                )
                path.write_text(skill, encoding="utf-8")
            config = {
                "skill_glob": "skills/*/SKILL.md",
                "max_description_chars": 9,
                "warn_description_chars": 5,
                "skill_description_report_limit": 6,
            }
            context = lint_skill_contracts.LintContext(root=root, registry={"mechanical": config}, schema={})
            result = lint_skill_contracts.check_mechanical(context)

        self.assertEqual(result.failures, ["mechanical: skills/over/SKILL.md description is 10 chars, exceeds 9"])
        warning_paths = [warning.split("burndown: ", 1)[1].split(" description", 1)[0] for warning in result.warnings]
        expected_paths = (
            "skills/over/SKILL.md skills/high/SKILL.md skills/alpha/SKILL.md "
            "skills/beta/SKILL.md skills/middle/SKILL.md skills/aaa-at/SKILL.md"
        ).split()
        self.assertEqual(warning_paths, expected_paths)
        self.assertIn("(over hard budget; warn at 5, fail above 9)", result.warnings[0])


class CompatibilityEntryPointTest(unittest.TestCase):
    def test_legacy_script_reexports_package_api(self) -> None:
        compat = load_compat_script()

        self.assertEqual(compat.CHECKS[-1][0], "mechanical")
        self.assertIsNotNone(compat.main)

    def test_legacy_script_reexports_when_loaded_as_package_name(self) -> None:
        compat = load_compat_script("lint_skill_contracts")

        self.assertEqual(compat.CHECKS[-1][0], "mechanical")
        self.assertIsNotNone(compat.main)


if __name__ == "__main__":
    unittest.main()
