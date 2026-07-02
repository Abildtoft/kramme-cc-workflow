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


def load_compat_script():
    spec = importlib.util.spec_from_file_location("lint_skill_contracts_cli", SCRIPT_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


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


if __name__ == "__main__":
    unittest.main()
