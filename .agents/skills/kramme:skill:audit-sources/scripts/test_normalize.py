#!/usr/bin/env python3

from __future__ import annotations

import unittest

from normalize import normalize_html


class NormalizeHtmlTests(unittest.TestCase):
    def test_void_tag_inside_skipped_region_does_not_extend_skip(self) -> None:
        raw = "<nav><img><p>drop</p></nav><p>keep</p>"

        self.assertEqual(normalize_html(raw), "keep\n")

    def test_void_end_tag_inside_skipped_region_does_not_end_skip(self) -> None:
        raw = '<nav><input></input><a href="/leak">drop</a></nav><p>keep</p>'

        self.assertEqual(normalize_html(raw), "keep\n")

    def test_utility_class_tokens_do_not_drop_page_content(self) -> None:
        raw = (
            '<div class="grid min-h-(--fd-docs-height) [--fd-header-height:0px] [--fd-sidebar-width:0px]">'
            "<main><h1>Guide</h1><p>Body text</p></main></div>"
        )

        self.assertEqual(normalize_html(raw), "# Guide\n\nBody text\n")

    def test_plain_chrome_class_and_id_names_still_drop(self) -> None:
        raw = (
            '<div class="site-header">drop</div><div id="main-nav">drop</div>'
            '<div class="md:hidden cookie-banner">drop</div><p>keep</p>'
        )

        self.assertEqual(normalize_html(raw), "keep\n")


if __name__ == "__main__":
    unittest.main()
