from __future__ import annotations

import os
import sys
import tempfile
import unittest
from dataclasses import FrozenInstanceError
from pathlib import Path
from unittest.mock import patch

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import json_object  # noqa: E402
import lint_skill_contracts  # noqa: E402
from lint_skill_contracts.checks import basic  # noqa: E402
from lint_skill_contracts.checks.types import TextContract, TextContractInventory  # noqa: E402


class ValidatedTextContractTest(unittest.TestCase):
    def test_normalized_records_detach_paths_and_inventory_from_raw_input(self) -> None:
        paths = ["a.md", "a.md"]
        inventory = {"glob": "*.md", "marker": "marker"}
        failures: list[str] = []
        records = list(
            basic._normalize_text_contracts(
                {
                    "text_contracts": [
                        {
                            "name": "copies",
                            "extract_regex": "value: (.*)",
                            "paths": paths,
                            "normalizer": "linewise",
                            "inventory": inventory,
                        }
                    ]
                },
                failures,
            )
        )
        paths.append("b.md")
        inventory["marker"] = "changed"
        self.assertEqual(failures, [])
        self.assertEqual(
            records,
            [
                TextContract(
                    label="copies",
                    extract_regex="value: (.*)",
                    paths=("a.md", "a.md"),
                    normalizer="linewise",
                    inventory=TextContractInventory(glob="*.md", marker="marker"),
                )
            ],
        )
        with self.assertRaises(FrozenInstanceError):
            records[0].label = "changed"
        with self.assertRaises(FrozenInstanceError):
            records[0].inventory.marker = "changed"

    def test_partial_paths_execute_before_next_group_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "a.md").write_text("value: one", encoding="utf-8")
            (root / "b.md").write_text("value: two", encoding="utf-8")
            context = basic.LintContext(
                root=root,
                registry={
                    "text_contracts": [
                        {
                            "extract_regex": "value: (.*)",
                            "paths": [1, "a.md", "", "b.md"],
                            "inventory": {"glob": "", "marker": ""},
                        },
                        {"name": "last"},
                    ]
                },
                schema={},
            )
            self.assertEqual(
                basic.check_text_contracts(context).failures,
                [
                    "text_contracts[0]: entry missing required string key 'name'",
                    "text_contracts[0]: 'paths' entries must be strings",
                    "text_contracts[0]: 'paths' entries must be non-empty strings",
                    "text_contracts[0]: inventory glob must be a non-empty string",
                    "text_contracts[0]: b.md:1 differs from a.md:1; expected 'one', got 'two'",
                    "last: entry missing required string key 'extract_regex'",
                    "last: entry missing required list key 'paths'",
                ],
            )

    def test_inventory_validation_preserves_first_failure_for_raw_callers(self) -> None:
        context = basic.LintContext(root=Path("/unused"), registry={}, schema={})
        for inventory, message in [
            (None, "inventory must be an object"),
            ([], "inventory must be an object"),
            ({}, "inventory glob must be a non-empty string"),
            ({"glob": 1, "marker": ""}, "inventory glob must be a non-empty string"),
            ({"glob": "*.md"}, "inventory marker must be a non-empty string"),
            ({"glob": "*.md", "marker": []}, "inventory marker must be a non-empty string"),
        ]:
            with self.subTest(inventory=inventory):
                self.assertEqual(
                    basic.check_text_contract_inventory(context, "copies", ["a.md", "a.md"], inventory).failures,
                    [f"copies: {message}"],
                )

    def test_non_string_and_unknown_normalizers_keep_default_behavior(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "a.md").write_text("one   two", encoding="utf-8")
            (root / "b.md").write_text("one two", encoding="utf-8")
            for normalizer in [None, False, 1, [], {}, "unknown"]:
                with self.subTest(normalizer=normalizer):
                    context = basic.LintContext(
                        root=root,
                        registry={
                            "text_contracts": [
                                {
                                    "name": "copies",
                                    "extract_regex": "(.+)",
                                    "paths": ["a.md", "b.md"],
                                    "normalizer": normalizer,
                                }
                            ]
                        },
                        schema={},
                    )
                    self.assertEqual(basic.check_text_contracts(context).failures, [])

    def test_non_list_groups_and_empty_valid_path_set_keep_diagnostics(self) -> None:
        context = basic.LintContext(root=Path("/unused"), registry={"text_contracts": {}}, schema={})
        self.assertEqual(
            basic.check_text_contracts(context).failures, ["text_contracts: registry entry must be a list"]
        )
        context.registry["text_contracts"] = [
            {
                "name": "empty",
                "extract_regex": "x",
                "paths": [None, ""],
                "inventory": [],
            }
        ]
        self.assertEqual(
            basic.check_text_contracts(context).failures,
            [
                "empty: 'paths' entries must be strings",
                "empty: 'paths' entries must be non-empty strings",
                "empty: inventory must be an object",
            ],
        )


class TextContractInventoryReadsTest(unittest.TestCase):
    def test_overlapping_inventories_share_reads_and_keep_ordered_failures(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir).resolve()
            (root / "a.md").write_text("marker marker\nvalue: one\n", encoding="utf-8")
            (root / "b.md").write_text("marker\nvalue: two\n", encoding="utf-8")
            group = {
                "extract_regex": r"value: (\w+)",
                "paths": ["a.md", "a.md", "missing.md"],
                "inventory": {"glob": "*.md", "marker": "marker"},
            }
            context = basic.LintContext(
                root=root,
                registry={
                    "text_contracts": [
                        {"name": "first", **group},
                        "malformed",
                        {"name": "bad", **group, "inventory": {"glob": "*.md", "marker": ""}},
                        {"name": "second", **group, "paths": ["a.md", "b.md"]},
                        {
                            "name": "overlap",
                            **group,
                            "paths": ["./a.md"],
                            "inventory": {"glob": "a*.md", "marker": "value:"},
                        },
                    ]
                },
                schema={},
            )
            with (
                patch.object(basic, "read_text", wraps=basic.read_text) as reads,
                patch.object(basic, "skill_paths", wraps=basic.skill_paths) as discoveries,
            ):
                result = basic.check_text_contracts(context)

            self.assertEqual(
                result.failures,
                [
                    "first: registered inventory contains duplicate paths",
                    "first: a.md contains 2 inventory markers; expected exactly 1",
                    "first: discovered unregistered contract copy: b.md",
                    "first: registered contract copy is not discoverable: missing.md",
                    "first: registered inventory count 3 does not equal discovered count 2",
                    "first: registered path is missing: missing.md",
                    "text_contracts[1]: entry must be an object",
                    "bad: inventory marker must be a non-empty string",
                    "bad: registered path is missing: missing.md",
                    "second: a.md contains 2 inventory markers; expected exactly 1",
                    "second: b.md:2 differs from a.md:2; expected 'one', got 'two'",
                    "overlap: discovered unregistered contract copy: a.md",
                    "overlap: registered contract copy is not discoverable: ./a.md",
                ],
            )
            self.assertEqual(result.warnings, [])
            self.assertEqual(discoveries.call_count, 2)
            self.assertCountEqual([call.args[0] for call in reads.call_args_list], [root / "a.md", root / "b.md"])

    def test_second_invocation_rereads_content_and_rediscovers_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir).resolve()
            (root / "a.md").write_text("marker\nvalue: one\n", encoding="utf-8")
            context = basic.LintContext(
                root=root,
                registry={
                    "text_contracts": [
                        {
                            "name": "copies",
                            "extract_regex": r"value: (\w+)",
                            "paths": ["a.md"],
                            "inventory": {"glob": "*.md", "marker": "marker"},
                        }
                    ]
                },
                schema={},
            )
            self.assertEqual(basic.check_text_contracts(context).failures, [])
            (root / "a.md").write_text("no contract\n", encoding="utf-8")
            (root / "b.md").write_text("marker\nvalue: two\n", encoding="utf-8")
            self.assertEqual(
                basic.check_text_contracts(context).failures,
                [
                    "copies: discovered unregistered contract copy: b.md",
                    "copies: registered contract copy is not discoverable: a.md",
                    "copies: no registered contract match in a.md",
                ],
            )

    def test_standalone_inventory_calls_reread_content(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir).resolve()
            path = root / "a.md"
            path.write_text("marker", encoding="utf-8")
            context = basic.LintContext(root=root, registry={}, schema={})
            inventory = {"glob": "*.md", "marker": "marker"}
            self.assertEqual(basic.check_text_contract_inventory(context, "copies", ["a.md"], inventory).failures, [])
            path.write_text("marker marker", encoding="utf-8")
            self.assertEqual(
                basic.check_text_contract_inventory(context, "copies", ["a.md"], inventory).failures,
                [
                    "copies: a.md contains 2 inventory markers; expected exactly 1",
                ],
            )


class MalformedRegistryShapeTest(unittest.TestCase):
    def test_text_contracts_reports_malformed_entries_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            context = lint_skill_contracts.LintContext(
                root=Path(tmp_dir),
                registry={
                    "text_contracts": [
                        "not-an-object",
                        {"extract_regex": "x"},
                        {"name": "missing-fields"},
                        {"name": "bad-paths", "extract_regex": "x", "paths": "not-a-list"},
                        {"name": "bad-path-entry", "extract_regex": "x", "paths": [1, "ok.md"]},
                        {"name": "empty-path-entry", "extract_regex": "x", "paths": [""]},
                    ]
                },
                schema={},
            )

            result = lint_skill_contracts.check_text_contracts(context)

        self.assertEqual(
            result.failures,
            [
                "text_contracts[0]: entry must be an object",
                "text_contracts[1]: entry missing required string key 'name'",
                "text_contracts[1]: entry missing required list key 'paths'",
                "missing-fields: entry missing required string key 'extract_regex'",
                "missing-fields: entry missing required list key 'paths'",
                "bad-paths: entry missing required list key 'paths'",
                "bad-path-entry: 'paths' entries must be strings",
                "bad-path-entry: registered path is missing: ok.md",
                "empty-path-entry: 'paths' entries must be non-empty strings",
            ],
        )

    def test_ordered_heading_contracts_reports_malformed_entries_without_crashing(self) -> None:
        context = lint_skill_contracts.LintContext(
            root=Path("/tmp/repo"),
            registry={
                "ordered_heading_contracts": [
                    {"name": "toc"},
                    {"name": "toc2", "headings": "nope", "paths": ["a.md"]},
                ]
            },
            schema={},
        )

        result = lint_skill_contracts.check_ordered_heading_contracts(context)

        self.assertEqual(
            result.failures,
            [
                "toc: entry missing required list key 'headings'",
                "toc: entry missing required list key 'paths'",
                "toc2: entry missing required list key 'headings'",
            ],
        )

    def test_file_identity_reports_malformed_entries_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            context = lint_skill_contracts.LintContext(
                root=Path(tmp_dir),
                registry={
                    "file_identity_groups": [
                        {"paths": ["a.md", "b.md"]},
                        {"name": "grp", "paths": "nope"},
                    ]
                },
                schema={},
            )

            result = lint_skill_contracts.check_file_identity(context)

        self.assertEqual(
            result.failures,
            [
                "file_identity_groups[0]: entry missing required string key 'name'",
                "file_identity_groups[0]: registered path is missing: a.md",
                "file_identity_groups[0]: registered path is missing: b.md",
                "grp: entry missing required list key 'paths'",
            ],
        )

    def test_required_file_contracts_reports_malformed_entries_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "c.md").write_text("hello world", encoding="utf-8")
            context = lint_skill_contracts.LintContext(
                root=root,
                registry={
                    "required_file_contracts": [
                        {"path": "a.md"},
                        {
                            "name": "c",
                            "path": "c.md",
                            "frontmatter": "nope",
                            "contains": [1, "ok-missing-text"],
                        },
                    ]
                },
                schema={},
            )

            result = lint_skill_contracts.check_required_file_contracts(context)

        self.assertEqual(
            result.failures,
            [
                "required_file_contracts[0]: entry missing required string key 'name'",
                "required_file_contracts[0]: registered path is missing: a.md",
                "c: 'frontmatter' contract must be an object",
                "c: 'contains' entries must be strings",
                "c: c.md is missing required text 'ok-missing-text'",
            ],
        )


class JsonObjectLoaderTest(unittest.TestCase):
    @unittest.skipIf(hasattr(os, "geteuid") and os.geteuid() == 0, "cannot deny read access while running as root")
    def test_unreadable_file_raises_systemexit_with_path_context(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "registry.yaml"
            path.write_text("{}", encoding="utf-8")
            path.chmod(0o000)
            try:
                with self.assertRaises(SystemExit) as ctx:
                    json_object.load_json_object(path, "registry")
            finally:
                path.chmod(0o644)

            message = str(ctx.exception)

        self.assertIn(str(path), message)
        self.assertIn("cannot read registry", message)


class DefaultContractSchemaTest(unittest.TestCase):
    def test_unreadable_default_schema_reports_error_without_crashing(self) -> None:
        schema_module = lint_skill_contracts.schema
        original_path = schema_module.DEFAULT_CONTRACT_SCHEMA_PATH
        with tempfile.TemporaryDirectory() as tmp_dir:
            missing_path = Path(tmp_dir) / "missing-schema.json"
            schema_module.DEFAULT_CONTRACT_SCHEMA_PATH = missing_path
            try:
                schema, error = schema_module._load_default_contract_schema_with_error()
            finally:
                schema_module.DEFAULT_CONTRACT_SCHEMA_PATH = original_path

        self.assertEqual(schema, {})
        assert error is not None
        self.assertIn(str(missing_path), error)
        self.assertIn("cannot read", error)

    def test_non_object_default_schema_reports_error(self) -> None:
        schema_module = lint_skill_contracts.schema
        original_path = schema_module.DEFAULT_CONTRACT_SCHEMA_PATH
        with tempfile.TemporaryDirectory() as tmp_dir:
            array_path = Path(tmp_dir) / "schema.json"
            array_path.write_text("[]", encoding="utf-8")
            schema_module.DEFAULT_CONTRACT_SCHEMA_PATH = array_path
            try:
                schema, error = schema_module._load_default_contract_schema_with_error()
            finally:
                schema_module.DEFAULT_CONTRACT_SCHEMA_PATH = original_path

        self.assertEqual(schema, {})
        self.assertIn("must be a JSON object", error or "")

    def test_load_contract_schema_surfaces_default_schema_error_on_fallback(self) -> None:
        schema_module = lint_skill_contracts.schema
        original_error = schema_module.DEFAULT_CONTRACT_SCHEMA_ERROR
        schema_module.DEFAULT_CONTRACT_SCHEMA_ERROR = "default contract schema: sentinel failure"
        try:
            failures: list[str] = []
            schema = lint_skill_contracts.load_contract_schema(
                Path("/tmp/repo"),
                {"contract_schema": "does-not-exist.json"},
                failures,
            )
        finally:
            schema_module.DEFAULT_CONTRACT_SCHEMA_ERROR = original_error

        self.assertEqual(schema, schema_module.DEFAULT_CONTRACT_SCHEMA)
        self.assertTrue(any("cannot read" in failure for failure in failures))
        self.assertIn("default contract schema: sentinel failure", failures)
