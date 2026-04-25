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


if __name__ == "__main__":
    unittest.main()
