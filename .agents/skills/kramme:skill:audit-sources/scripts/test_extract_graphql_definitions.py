#!/usr/bin/env python3

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from extract_graphql_definitions import extract_definitions, read_source


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

    def test_extracts_multiline_union_and_next_line_braced_definition(self) -> None:
        schema = """\
union SearchResult =
  | User
  | Team

input CreateInput
{
  name: String!
}
"""

        result = extract_definitions(schema, ["CreateInput", "SearchResult"])

        self.assertEqual(
            result,
            """\
input CreateInput
{
  name: String!
}

union SearchResult =
  | User
  | Team
""",
        )

    def test_stops_non_braced_definitions_at_directive_and_schema_boundaries(self) -> None:
        schema = """\
scalar Timestamp

directive @auth on FIELD_DEFINITION

union SearchResult =
  | User
  | Team

schema {
  query: User
}

type User {
  id: ID!
}
"""

        result = extract_definitions(schema, ["Timestamp", "SearchResult"])

        self.assertEqual(
            result,
            """\
scalar Timestamp

union SearchResult =
  | User
  | Team
""",
        )

    def test_preserves_single_line_string_description(self) -> None:
        schema = """\
"Timestamp value with an \\"escaped quote\\"."
scalar Timestamp
"""

        result = extract_definitions(schema, ["Timestamp"])

        self.assertEqual(result, schema)

    def test_ignores_unrelated_extensions_and_includes_requested_extensions(self) -> None:
        schema = """\
type Wanted {
  id: ID!
}

type Other {
  id: ID!
}

extend type Other {
  name: String
}

extend type Wanted {
  name: String
}
"""

        result = extract_definitions(schema, ["Wanted"])

        self.assertEqual(
            result,
            """\
type Wanted {
  id: ID!
}

extend type Wanted {
  name: String
}
""",
        )

    def test_rejects_duplicate_requested_base_definition(self) -> None:
        schema = """\
type Duplicate {
  id: ID!
}

type Duplicate {
  name: String
}
"""

        with self.assertRaisesRegex(ValueError, "duplicate top-level GraphQL definition: Duplicate"):
            extract_definitions(schema, ["Duplicate"])

    @patch("extract_graphql_definitions.urlopen")
    def test_reads_https_source_without_model_fetch(self, mock_urlopen: MagicMock) -> None:
        response = mock_urlopen.return_value.__enter__.return_value
        response.read.return_value = b"type Remote { id: ID! }\n"

        self.assertEqual(
            read_source("https://example.com/schema.graphql"),
            "type Remote { id: ID! }\n",
        )
        mock_urlopen.assert_called_once_with(
            "https://example.com/schema.graphql",
            timeout=30,
        )

    def test_rejects_non_https_source(self) -> None:
        with self.assertRaisesRegex(ValueError, "must use HTTPS"):
            read_source("file:///tmp/schema.graphql")


if __name__ == "__main__":
    unittest.main()
