from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
SCRIPT_PATH = SCRIPTS_DIR / "lint-skill-contracts.py"
sys.path.insert(0, str(SCRIPTS_DIR))

import lint_skill_contracts  # noqa: E402


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
        cells = lint_skill_contracts.split_markdown_table_row(
            r"| Skill | `foo\|bar` | Uses \<value\> |"
        )

        self.assertEqual(cells, ["Skill", r"`foo\|bar`", r"Uses \<value\>"])
        self.assertEqual(
            lint_skill_contracts.normalize_markdown_cell(cells[1]), "foo|bar"
        )
        self.assertEqual(
            lint_skill_contracts.normalize_markdown_cell(cells[2]), "Uses <value>"
        )

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
            ),
        )


class FrontmatterContractHelpersTest(unittest.TestCase):
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
                "epilogue_order",
                "hooks_json",
                "readme_skill_sync",
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
            registry = lint_skill_contracts.load_registry(
                SCRIPTS_DIR / "synced-contracts.yaml"
            )
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

        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/components/Button.tsx", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("tailwind.config.ts", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path(
                "packages/ui/design-tokens/colors.json",
                matcher,
            )
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("public/logo.svg", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/components/Button.TSX", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/Page.astro", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("docs/component.mdx", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("public/index.htm", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/styles/theme.styl", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/ui/Button.ts", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("src/component/Button.ts", matcher)
        )
        self.assertTrue(
            lint_skill_contracts.is_ui_relevant_path("public/Logo.SVG", matcher)
        )
        self.assertFalse(
            lint_skill_contracts.is_ui_relevant_path("src/assets/data.json", matcher)
        )
        self.assertFalse(
            lint_skill_contracts.is_ui_relevant_path("src/server/user.ts", matcher)
        )

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
                "UI relevance path contract: ui-relevance-path-contract-v1\n"
                "Required terms: *.tsx\n",
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
                "fixture-ui-contract: canonical.md fixture 'src/components/Button.tsx' "
                "documents False; expected True",
            ],
        )


class VerifyRunGuidanceTest(unittest.TestCase):
    def test_nx_affected_guidance_uses_resolved_base_ref(self) -> None:
        plugin_root = SCRIPTS_DIR.parent
        skill_text = (
            plugin_root / "skills" / "kramme:verify:run" / "SKILL.md"
        ).read_text(encoding="utf-8")
        commands_text = (
            plugin_root
            / "skills"
            / "kramme:verify:run"
            / "references"
            / "commands-by-project-type.md"
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
