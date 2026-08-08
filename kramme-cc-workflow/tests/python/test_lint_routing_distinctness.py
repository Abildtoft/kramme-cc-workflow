from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import lint_skill_contracts  # noqa: E402

ALPHA_DESCRIPTION = "Review branch changes accessibility problems report findings"
BETA_DESCRIPTION = "Review branch changes accessibility problems report findings keyboard focus contrast"
GAMMA_DESCRIPTION = "Generate release notes merged pull requests"
ALPHA_PATH = "kramme-cc-workflow/skills/alpha/SKILL.md"
BETA_PATH = "kramme-cc-workflow/skills/beta/SKILL.md"


class RoutingDistinctnessHelperTest(unittest.TestCase):
    def test_description_tokens_drop_stopwords_and_the_skill_name(self) -> None:
        tokens = lint_skill_contracts.description_tokens(
            "Review the review skill for drift",
            "kramme:skill:review",
            {"the"},
        )

        self.assertEqual(tokens, {"for", "drift"})

    def test_jaccard_scores_overlap_and_tolerates_empty_token_sets(self) -> None:
        self.assertEqual(lint_skill_contracts.jaccard({"a"}, {"a", "b"}), 0.5)
        self.assertEqual(lint_skill_contracts.jaccard(set(), set()), 0.0)


class RoutingDistinctnessCheckTest(unittest.TestCase):
    def _write_skill(self, root: Path, name: str, description: str, *, auto_invocable: bool = True) -> str:
        path = root / "kramme-cc-workflow" / "skills" / name / "SKILL.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "\n".join(
                [
                    "---",
                    f"name: {name}",
                    f"description: {description}",
                    f"disable-model-invocation: {'false' if auto_invocable else 'true'}",
                    "user-invocable: true",
                    "---",
                    "Body.",
                ]
            ),
            encoding="utf-8",
        )
        return f"kramme-cc-workflow/skills/{name}/SKILL.md"

    def _context(self, root: Path, **overrides: object) -> lint_skill_contracts.LintContext:
        config: dict[str, object] = {
            "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
            "warn_similarity": 0.3,
            "fail_similarity": 0.6,
            "stopwords": [],
        }
        config.update(overrides)
        return lint_skill_contracts.LintContext(root=root, registry={"routing_distinctness": config}, schema={})

    def test_reports_an_over_threshold_pair_without_a_recorded_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root))

        self.assertEqual(
            result.failures,
            [
                f"routing distinctness: {ALPHA_PATH} and {BETA_PATH} descriptions score 0.70 "
                "(fail at 0.60); differentiate the descriptions or add a "
                "routing_distinctness.recorded_boundaries entry with a positive one-clause routing rule"
            ],
        )
        self.assertEqual(result.warnings, [])

    def test_accepts_an_over_threshold_pair_with_a_recorded_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION)
            context = self._context(
                root,
                recorded_boundaries=[
                    {
                        "skills": [ALPHA_PATH, BETA_PATH],
                        "boundary": "Alpha audits a whole branch; beta audits one keyboard flow.",
                    }
                ],
            )

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertEqual(result.failures, [])
        self.assertEqual(result.warnings, [])

    def test_rejects_a_recorded_boundary_without_a_positive_clause(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION)
            context = self._context(
                root,
                recorded_boundaries=[{"skills": [ALPHA_PATH, BETA_PATH], "boundary": "   "}],
            )

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertIn(
            f"routing distinctness: recorded_boundaries entry 1 requires a non-empty boundary stating a "
            f"positive routing rule for {ALPHA_PATH}, {BETA_PATH}",
            result.failures,
        )
        self.assertTrue(any("descriptions score 0.70" in failure for failure in result.failures))

    def test_rejects_a_recorded_boundary_naming_a_missing_skill(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            context = self._context(
                root,
                recorded_boundaries=[
                    {
                        "skills": [ALPHA_PATH, "kramme-cc-workflow/skills/removed/SKILL.md"],
                        "boundary": "Alpha reviews a branch; removed did something else.",
                    }
                ],
            )

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertEqual(
            result.failures,
            [
                "routing distinctness: recorded_boundaries entry 1 skill does not exist: "
                "kramme-cc-workflow/skills/removed/SKILL.md; remove or fix the entry"
            ],
        )

    def test_ignores_a_below_threshold_pair(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "gamma", GAMMA_DESCRIPTION)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root))

        self.assertEqual(result.failures, [])
        self.assertEqual(result.warnings, [])

    def test_warns_instead_of_failing_when_both_skills_are_user_invoked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION, auto_invocable=False)
            self._write_skill(root, "beta", BETA_DESCRIPTION, auto_invocable=False)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root))

        self.assertEqual(result.failures, [])
        self.assertEqual(
            result.warnings,
            [
                f"routing distinctness: nearest-pair burndown: {ALPHA_PATH} and {BETA_PATH} score 0.70 "
                "(at or above the 0.60 failure threshold but exempt: only pairs with both skills "
                "auto-invocable fail, and at least one of these is user-invoked)"
            ],
        )

    def test_warns_when_only_one_skill_in_the_pair_is_user_invoked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION, auto_invocable=False)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root))

        self.assertEqual(result.failures, [])
        self.assertEqual(
            result.warnings,
            [
                f"routing distinctness: nearest-pair burndown: {ALPHA_PATH} and {BETA_PATH} score 0.70 "
                "(at or above the 0.60 failure threshold but exempt: only pairs with both skills "
                "auto-invocable fail, and at least one of these is user-invoked)"
            ],
        )

    def test_reports_a_recorded_boundary_that_no_longer_scores_above_the_warn_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "gamma", GAMMA_DESCRIPTION)
            context = self._context(
                root,
                recorded_boundaries=[
                    {
                        "skills": [ALPHA_PATH, "kramme-cc-workflow/skills/gamma/SKILL.md"],
                        "boundary": "Alpha audits a branch; gamma writes release notes.",
                    }
                ],
            )

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertEqual(result.failures, [])
        self.assertEqual(
            result.warnings,
            [
                f"routing distinctness: recorded boundary can be removed: {ALPHA_PATH} and "
                "kramme-cc-workflow/skills/gamma/SKILL.md score 0.00 (warn at 0.30)"
            ],
        )

    def test_fail_population_all_covers_user_invoked_skills(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION, auto_invocable=False)
            self._write_skill(root, "beta", BETA_DESCRIPTION, auto_invocable=False)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root, fail_population="all"))

        self.assertTrue(any("descriptions score 0.70" in failure for failure in result.failures))

    def test_warns_between_the_warn_and_fail_thresholds(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION)

            result = lint_skill_contracts.check_routing_distinctness(self._context(root, fail_similarity=0.9))

        self.assertEqual(result.failures, [])
        self.assertEqual(
            result.warnings,
            [
                f"routing distinctness: nearest-pair burndown: {ALPHA_PATH} and {BETA_PATH} score 0.70 "
                "(warn at 0.30, fail at 0.90)"
            ],
        )

    def test_reports_malformed_thresholds_and_populations(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            context = self._context(
                root,
                warn_similarity="high",
                fail_similarity=0.2,
                fail_population="sometimes",
                recorded_boundaries={},
            )

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertEqual(
            result.failures,
            [
                "routing distinctness: warn_similarity must be a number between 0 and 1",
                "routing distinctness: fail_similarity must be at or above warn_similarity",
                "routing distinctness: fail_population must be one of auto_invocable, all",
                "routing distinctness: recorded_boundaries must be an array",
            ],
        )

    def test_is_inert_without_registry_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._write_skill(root, "alpha", ALPHA_DESCRIPTION)
            self._write_skill(root, "beta", BETA_DESCRIPTION)
            context = lint_skill_contracts.LintContext(root=root, registry={}, schema={})

            result = lint_skill_contracts.check_routing_distinctness(context)

        self.assertEqual(result.failures, [])
        self.assertEqual(result.warnings, [])
