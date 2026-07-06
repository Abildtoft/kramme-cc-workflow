from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "changelog.py"
SPEC = importlib.util.spec_from_file_location("changelog", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
changelog = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = changelog
SPEC.loader.exec_module(changelog)


def parse_commit(
    subject: str,
    body: str = "",
    pr_number: str | None = None,
) -> changelog.ChangelogEntry | None:
    return changelog.CommitParser().parse(
        changelog.Commit(
            hash="abc123",
            subject=subject,
            body=body,
            pr_number=pr_number,
        )
    )


class CommitParserTest(unittest.TestCase):
    def test_conventional_commits_map_to_changelog_categories(self) -> None:
        cases = [
            ("feat: add import flow", "Added", "Add import flow"),
            ("fix: correct release output", "Fixed", "Correct release output"),
            ("docs: clarify setup", "Changed", "Clarify setup"),
            ("style: normalize headings", "Changed", "Normalize headings"),
            ("refactor: split generator", "Changed", "Split generator"),
            ("perf: cache changelog reads", "Changed", "Cache changelog reads"),
            ("revert: restore updater behavior", "Changed", "Restore updater behavior"),
        ]

        for subject, category, message in cases:
            with self.subTest(subject=subject):
                entry = parse_commit(subject)

                self.assertIsNotNone(entry)
                assert entry is not None
                self.assertEqual(entry.category, category)
                self.assertEqual(entry.message, message)

    def test_excludes_internal_commit_types_and_release_commits(self) -> None:
        excluded_subjects = [
            "test: cover release script",
            "build: update package metadata",
            "ci: run release checks",
            "chore: refresh fixtures",
            "Release v1.2.3",
        ]

        for subject in excluded_subjects:
            with self.subTest(subject=subject):
                self.assertIsNone(parse_commit(subject))

    def test_extracts_pr_number_from_subject_or_commit_metadata(self) -> None:
        subject_entry = parse_commit("feat(cli): add release command (#123)")
        metadata_entry = parse_commit("fix: repair changelog link", pr_number="456")

        self.assertIsNotNone(subject_entry)
        self.assertIsNotNone(metadata_entry)
        assert subject_entry is not None
        assert metadata_entry is not None
        self.assertEqual(subject_entry.message, "Add release command")
        self.assertEqual(subject_entry.pr_number, "123")
        self.assertEqual(metadata_entry.pr_number, "456")

    def test_formats_breaking_changes_from_marker_or_body(self) -> None:
        marker_entry = parse_commit("feat!: replace config schema")
        body_entry = parse_commit(
            "fix: repair token handling",
            body="BREAKING CHANGE: tokens are now rotated on release.",
        )

        self.assertIsNotNone(marker_entry)
        self.assertIsNotNone(body_entry)
        assert marker_entry is not None
        assert body_entry is not None
        self.assertEqual(marker_entry.message, "**BREAKING:** Replace config schema")
        self.assertEqual(body_entry.message, "**BREAKING:** Repair token handling")

    def test_falls_back_to_keyword_categories_for_plain_subjects(self) -> None:
        removed_entry = parse_commit("remove stale release notes")
        security_entry = parse_commit("security hardening for token logs")
        default_entry = parse_commit("retitle workflow steps")

        self.assertIsNotNone(removed_entry)
        self.assertIsNotNone(security_entry)
        self.assertIsNotNone(default_entry)
        assert removed_entry is not None
        assert security_entry is not None
        assert default_entry is not None
        self.assertEqual(removed_entry.category, "Removed")
        self.assertEqual(security_entry.category, "Security")
        self.assertEqual(default_entry.category, "Changed")


class ChangelogGeneratorTest(unittest.TestCase):
    def test_generate_changelog_handles_empty_git_history(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            subprocess.run(
                ["git", "init"],
                cwd=tmp_dir,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                updated = changelog.generate_changelog(
                    Path(tmp_dir),
                    "1.0.0",
                    repo_url="https://github.com/example/repo",
                    dry_run=True,
                )

            self.assertFalse(updated)
            self.assertIn(
                "No commits found in repository history", output.getvalue()
            )
            self.assertNotIn("fatal:", output.getvalue())

    def test_generate_changelog_can_raise_empty_history_for_release(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            subprocess.run(
                ["git", "init"],
                cwd=tmp_dir,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

            with self.assertRaises(changelog.ChangelogHistoryError):
                changelog.generate_changelog(
                    Path(tmp_dir),
                    "1.0.0",
                    repo_url="https://github.com/example/repo",
                    dry_run=True,
                    fail_on_history_error=True,
                )

    def test_formats_version_section_in_category_order_with_pr_references(self) -> None:
        generator = changelog.ChangelogGenerator(Path("."))
        section = generator.format_version_section(
            "1.2.3",
            {
                "Security": [
                    changelog.ChangelogEntry("Security", "Patch token logging", "44")
                ],
                "Fixed": [changelog.ChangelogEntry("Fixed", "Repair links")],
                "Added": [
                    changelog.ChangelogEntry("Added", "Add changelog tests", "42")
                ],
            },
            release_date=date(2026, 7, 1),
        )

        self.assertEqual(
            section,
            "\n".join(
                [
                    "## [1.2.3] - 2026-07-01",
                    "",
                    "### Added",
                    "- Add changelog tests (#42)",
                    "",
                    "### Fixed",
                    "- Repair links",
                    "",
                    "### Security",
                    "- Patch token logging (#44)",
                    "",
                ]
            ),
        )

    def test_formats_compare_or_release_link_references(self) -> None:
        generator = changelog.ChangelogGenerator(Path("."))

        self.assertEqual(
            generator.format_link_reference(
                "1.2.3", "https://github.com/example/repo", "v1.2.2"
            ),
            "[1.2.3]: https://github.com/example/repo/compare/v1.2.2...v1.2.3",
        )
        self.assertEqual(
            generator.format_link_reference("1.2.3", "https://github.com/example/repo"),
            "[1.2.3]: https://github.com/example/repo/releases/tag/v1.2.3",
        )


class ChangelogUpdaterTest(unittest.TestCase):
    def test_get_previous_version_finds_first_release_after_header(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            changelog_path = Path(tmp_dir) / "CHANGELOG.md"
            changelog_path.write_text(
                "\n".join(
                    [
                        "# Changelog",
                        "",
                        "## Unreleased",
                        "",
                        "### Changed",
                        "- Pending work",
                        "",
                        "## [2.0.0] - 2026-07-01",
                        "",
                    ]
                )
            )

            self.assertEqual(
                changelog.ChangelogUpdater(changelog_path).get_previous_version(),
                "2.0.0",
            )

    def test_update_inserts_version_before_first_release_and_link_before_links(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            changelog_path = Path(tmp_dir) / "CHANGELOG.md"
            changelog_path.write_text(
                "\n".join(
                    [
                        "# Changelog",
                        "",
                        "Intro text.",
                        "",
                        "## Unreleased",
                        "",
                        "### Changed",
                        "- Pending work",
                        "",
                        "## [1.0.0] - 2026-01-01",
                        "",
                        "### Added",
                        "- Existing release",
                        "",
                        "[1.0.0]: https://github.com/example/repo/releases/tag/v1.0.0",
                        "",
                    ]
                )
            )
            updater = changelog.ChangelogUpdater(changelog_path)

            with contextlib.redirect_stdout(io.StringIO()):
                updated = updater.update(
                    "1.1.0",
                    "\n".join(
                        [
                            "## [1.1.0] - 2026-02-01",
                            "",
                            "### Fixed",
                            "- Repair changelog links",
                        ]
                    ),
                    "[1.1.0]: https://github.com/example/repo/compare/v1.0.0...v1.1.0",
                )

            content = changelog_path.read_text()
            self.assertTrue(updated)
            self.assertLess(
                content.index("Intro text."),
                content.index("## [1.1.0] - 2026-02-01"),
            )
            self.assertLess(
                content.index("## [1.1.0] - 2026-02-01"),
                content.index("## [1.0.0] - 2026-01-01"),
            )
            self.assertLess(
                content.index("[1.1.0]: https://github.com/example/repo/compare"),
                content.index("[1.0.0]: https://github.com/example/repo/releases"),
            )

    def test_update_preserves_default_header_when_creating_missing_changelog(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            changelog_path = Path(tmp_dir) / "CHANGELOG.md"
            updater = changelog.ChangelogUpdater(changelog_path)

            with contextlib.redirect_stdout(io.StringIO()):
                updated = updater.update(
                    "1.0.0",
                    "## [1.0.0] - 2026-01-01\n\n### Added\n- Initial release",
                    "[1.0.0]: https://github.com/example/repo/releases/tag/v1.0.0",
                )

            content = changelog_path.read_text()
            self.assertTrue(updated)
            self.assertIn(
                "Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n"
                "## [1.0.0] - 2026-01-01",
                content,
            )
            self.assertLess(
                content.index("Semantic Versioning"),
                content.index("## [1.0.0] - 2026-01-01"),
            )

    def test_update_separates_first_release_from_unreleased_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            changelog_path = Path(tmp_dir) / "CHANGELOG.md"
            changelog_path.write_text(
                "\n".join(
                    [
                        "# Changelog",
                        "",
                        "## Unreleased",
                        "",
                        "### Changed",
                        "- Pending work",
                        "",
                    ]
                )
            )
            updater = changelog.ChangelogUpdater(changelog_path)

            with contextlib.redirect_stdout(io.StringIO()):
                updated = updater.update(
                    "1.0.0",
                    "## [1.0.0] - 2026-01-01\n\n### Added\n- Initial release",
                    "[1.0.0]: https://github.com/example/repo/releases/tag/v1.0.0",
                )

            content = changelog_path.read_text()
            self.assertTrue(updated)
            self.assertIn("- Pending work\n\n## [1.0.0] - 2026-01-01", content)

    def test_update_is_idempotent_and_dry_run_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            changelog_path = Path(tmp_dir) / "CHANGELOG.md"
            initial_content = "## [1.0.0] - 2026-01-01\n"
            changelog_path.write_text(initial_content)
            updater = changelog.ChangelogUpdater(changelog_path)

            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(
                    updater.update(
                        "1.0.0",
                        "## [1.0.0] - 2026-01-01",
                        "[1.0.0]: https://github.com/example/repo/releases/tag/v1.0.0",
                    )
                )
                self.assertTrue(
                    updater.update(
                        "1.1.0",
                        "## [1.1.0] - 2026-02-01",
                        (
                            "[1.1.0]: "
                            "https://github.com/example/repo/compare/v1.0.0...v1.1.0"
                        ),
                        dry_run=True,
                    )
                )

            self.assertEqual(changelog_path.read_text(), initial_content)


if __name__ == "__main__":
    unittest.main()
