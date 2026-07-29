#!/usr/bin/env python3

from __future__ import annotations

import unittest

from extract_graphql_definitions import extract_definitions


class ExtractGraphqlDefinitionsTests(unittest.TestCase):
    def test_extracts_requested_definitions_with_descriptions_in_order(self) -> None:
        schema = '''\
"""Relation description with an ignored { brace."""
enum Relation {
  blocks
}

type IgnoreMe {
  value: String
}

"""
Create description with an ignored } brace.
"""
input CreateInput {
  example: String = "{still ignored}"
  nested: NestedInput
}
'''

        result = extract_definitions(schema, ["CreateInput", "Relation"])

        self.assertEqual(
            result,
            '''\
"""
Create description with an ignored } brace.
"""
input CreateInput {
  example: String = "{still ignored}"
  nested: NestedInput
}

"""Relation description with an ignored { brace."""
enum Relation {
  blocks
}
''',
        )

    def test_rejects_missing_definition(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing GraphQL definitions: Missing"):
            extract_definitions("type Present { id: ID! }\n", ["Missing"])

    def test_rejects_unclosed_definition(self) -> None:
        with self.assertRaisesRegex(ValueError, "unclosed GraphQL definition"):
            extract_definitions("type Broken {\n  id: ID!\n", ["Broken"])


if __name__ == "__main__":
    unittest.main()
