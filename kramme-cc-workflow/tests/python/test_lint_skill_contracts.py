from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "scripts" / "lint-skill-contracts.py"
)
SPEC = importlib.util.spec_from_file_location("lint_skill_contracts", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
lint_skill_contracts = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = lint_skill_contracts
SPEC.loader.exec_module(lint_skill_contracts)


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


if __name__ == "__main__":
    unittest.main()
