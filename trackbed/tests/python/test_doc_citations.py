from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "check-doc-citations.py"
SPEC = importlib.util.spec_from_file_location("check_doc_citations", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
check_doc_citations = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_doc_citations
SPEC.loader.exec_module(check_doc_citations)


class CheckGuideTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name).resolve()
        self.plugin = self.repo / "plugin"
        (self.plugin / "docs").mkdir(parents=True)
        (self.plugin / "skills" / "a").mkdir(parents=True)
        (self.plugin / "skills" / "b").mkdir(parents=True)
        (self.plugin / "skills" / "a" / "SKILL.md").write_text("first a\nsecond a\nthird a\n")
        (self.plugin / "skills" / "b" / "SKILL.md").write_text("first b\nsecond b\n")
        (self.repo / "AGENTS.md").write_text("Rule one applies here.\nRule `two` is **bold** text, always.\n")

    def check(self, line: str) -> tuple[list[str], int]:
        guide = self.plugin / "docs" / "guide.md"
        guide.write_text(line + "\n")
        problems, count = check_doc_citations.check_guide(guide, self.plugin, self.repo)
        return [problem.message for problem in problems], count

    def test_a_citation_resolves_against_the_plugin_then_the_repository(self) -> None:
        self.assertEqual(self.check("See `skills/a/SKILL.md:2` and `AGENTS.md:1`."), ([], 2))

    def test_a_repository_relative_path_resolves(self) -> None:
        self.assertEqual(self.check("See `plugin/skills/a/SKILL.md:1`."), ([], 1))

    def test_text_without_citations_counts_nothing(self) -> None:
        self.assertEqual(self.check('A "quoted phrase" and `code` and `file.md`.'), ([], 0))

    def test_a_host_port_image_tag_or_url_is_not_a_citation(self) -> None:
        self.assertEqual(self.check("See `localhost:3000`, `node:20`, and `http://example.test/a.md:80`."), ([], 0))

    def test_a_file_without_a_known_extension_still_counts(self) -> None:
        (self.plugin / "Makefile").write_text("all:\n")
        self.assertEqual(self.check("See `Makefile:1`."), ([], 1))
        messages, _ = self.check("See `Makefile:999`.")
        self.assertEqual(messages, ["`Makefile:999` is outside the file's 1 lines"])

    def test_a_path_with_a_slash_must_resolve_whatever_its_extension(self) -> None:
        messages, count = self.check("See `hooks/list.conf:9` and `hooks/list.txt:9`.")
        self.assertEqual(count, 2)
        self.assertEqual(
            messages,
            ["`hooks/list.conf` does not resolve to a file", "`hooks/list.txt` does not resolve to a file"],
        )

    def test_a_missing_file_is_reported(self) -> None:
        messages, _ = self.check("See `skills/missing/SKILL.md:1`.")
        self.assertEqual(messages, ["`skills/missing/SKILL.md` does not resolve to a file"])

    def test_a_bare_name_with_no_earlier_citation_must_exist_at_a_root(self) -> None:
        messages, _ = self.check("See `SKILL.md:1`.")
        self.assertEqual(messages, ["`SKILL.md` does not resolve to a file"])

    def test_a_bare_name_means_the_most_recent_file_cited_under_that_name(self) -> None:
        messages, _ = self.check(
            '`skills/a/SKILL.md:1` then `skills/b/SKILL.md:1` then `SKILL.md:2` says "second b here".'
        )
        self.assertEqual(len(messages), 1)
        self.assertIn('quotes "second b here"', messages[0])
        passing, count = self.check(
            '`skills/a/SKILL.md:1` then `skills/b/SKILL.md:1` then `SKILL.md:2` says "second b".'
        )
        self.assertEqual((passing, count), ([], 3))

    def test_a_bare_name_carries_across_lines_of_the_guide(self) -> None:
        self.assertEqual(self.check('`skills/a/SKILL.md:1`\n`SKILL.md:3` says "third a".'), ([], 2))

    def test_lines_outside_the_file_are_reported(self) -> None:
        for citation in (
            "skills/b/SKILL.md:3",
            "skills/b/SKILL.md:0",
            "skills/b/SKILL.md:1-9",
            "skills/b/SKILL.md:2-1",
        ):
            messages, _ = self.check(f"See `{citation}`.")
            self.assertEqual(messages, [f"`{citation}` is outside the file's 2 lines"], citation)

    def test_a_quote_on_the_cited_line_passes(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1` says "Rule one applies here."'), ([], 1))

    def test_a_shifted_quote_reports_its_current_line(self) -> None:
        messages, _ = self.check('`skills/a/SKILL.md:1` says "second a word".')
        self.assertEqual(
            messages, ['`skills/a/SKILL.md:1` quotes "second a word", but it is not on any single line of the file']
        )
        messages, _ = self.check('`AGENTS.md:1` says "Rule two is bold".')
        self.assertEqual(messages, ['`AGENTS.md:1` quotes "rule two is bold", but it is on line 2'])

    def test_a_quote_within_a_cited_range_passes(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1-2` says "Rule two is bold".'), ([], 1))

    def test_quotes_ignore_markup_case_spacing_and_trailing_punctuation(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:2` says "rule `two`  is **BOLD** text,".'), ([], 1))

    def test_bracketed_edits_are_treated_as_editorial(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1` says "Rule one[s] applies here".'), ([], 1))

    def test_a_bracketed_phrase_is_still_checked(self) -> None:
        messages, _ = self.check('`AGENTS.md:1` says "[Made up phrase]".')
        self.assertEqual(
            messages, ['`AGENTS.md:1` quotes "[made up phrase]", but it is not on any single line of the file']
        )

    def test_brackets_in_the_cited_file_are_kept(self) -> None:
        (self.repo / "AGENTS.md").write_text("Read [the guide](x.md) first.\n")
        self.assertEqual(self.check('`AGENTS.md:1` says "Read [the guide](x.md) first".'), ([], 1))

    def test_curly_quotes_are_checked_too(self) -> None:
        self.assertEqual(self.check("`AGENTS.md:1` says \u201cRule one applies\u201d."), ([], 1))
        messages, _ = self.check("`AGENTS.md:1` says \u201cRule made up\u201d.")
        self.assertEqual(
            messages, ['`AGENTS.md:1` quotes "rule made up", but it is not on any single line of the file']
        )

    def test_each_side_of_an_ellipsis_must_appear(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1` says "Rule one... applies here".'), ([], 1))
        self.assertEqual(self.check('`AGENTS.md:1` says "Rule one… applies here".'), ([], 1))
        messages, _ = self.check('`AGENTS.md:1` says "Rule one... not there".')
        self.assertEqual(messages, ['`AGENTS.md:1` quotes "not there", but it is not on any single line of the file'])

    def test_a_single_quoted_word_is_a_term_not_a_quotation(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1` is the "canonical" rule.'), ([], 1))

    def test_a_quote_inside_a_code_span_is_part_of_that_code(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:1` is found with `grep -l "made up phrase" file`.'), ([], 1))

    def test_a_code_span_inside_a_quote_still_counts(self) -> None:
        self.assertEqual(self.check('`AGENTS.md:2` says "Rule `two` is".'), ([], 1))
        messages, _ = self.check('`AGENTS.md:1` says "Rule `two` is".')
        self.assertEqual(messages, ['`AGENTS.md:1` quotes "rule two is", but it is on line 2'])

    def test_a_quote_belongs_to_the_citation_before_it(self) -> None:
        self.assertEqual(
            self.check('`AGENTS.md:1` says "Rule one applies" and `AGENTS.md:2` says "Rule two is".'), ([], 2)
        )
        messages, _ = self.check('`AGENTS.md:2` says "Rule one applies" and `AGENTS.md:1` says "Rule two is".')
        self.assertEqual(len(messages), 2)

    def test_a_quote_before_the_citation_is_not_attributed_to_it(self) -> None:
        self.assertEqual(self.check('The "made up phrase" is at `AGENTS.md:1`.'), ([], 1))


class MainTests(unittest.TestCase):
    def run_main(self, argv: list[str]) -> tuple[int, str, str]:
        out = io.StringIO()
        err = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = check_doc_citations.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_an_unreadable_guide_exits_two(self) -> None:
        code, _, err = self.run_main(["/nonexistent/guide.md"])
        self.assertEqual(code, 2)
        self.assertIn("Could not read", err)

    def test_problems_exit_one_and_name_the_guide_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            guide = Path(tmp) / "guide.md"
            guide.write_text("Intro.\nSee `no/such/file.md:1`.\n")
            code, out, err = self.run_main([str(guide)])
        self.assertEqual(code, 1)
        self.assertIn(f"{guide}:2: `no/such/file.md` does not resolve to a file", err)
        self.assertIn("Checked 1 citations in 1 guides: 1 problems.", out)


class ShippedGuidesTests(unittest.TestCase):
    def test_decision_records_are_not_checked(self) -> None:
        guides = check_doc_citations.default_guides()
        self.assertTrue(guides)
        self.assertFalse([guide for guide in guides if guide.parent.name == "decisions"])

    def test_every_citation_in_the_maintainer_guides_holds(self) -> None:
        total = 0
        for guide in check_doc_citations.default_guides():
            problems, count = check_doc_citations.check_guide(guide)
            total += count
            self.assertEqual([str(problem) for problem in problems], [])
        self.assertGreater(total, 0)


if __name__ == "__main__":
    unittest.main()
