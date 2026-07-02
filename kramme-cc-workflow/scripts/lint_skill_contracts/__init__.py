from __future__ import annotations

from .checks import CHECKS, CheckFunc, CheckResult, LintContext, run, run_checks
from .checks.base_diff_scope import check_base_diff_scope
from .checks.basic import (
    check_file_identity,
    check_ordered_heading_contracts,
    check_required_file_contracts,
    check_text_contracts,
    extract_contract_value,
    heading_lines,
)
from .checks.epilogue import canonical_epilogue_heading, check_epilogue_order
from .checks.hooks_json import check_hooks_json
from .checks.marker_manifest import (
    allow_empty_field_keys,
    check_marker_manifests,
    marker_present,
    parse_sources_manifest,
)
from .checks.mechanical import check_mechanical
from .cli import add_arguments, load_registry, main, parse_cli
from .frontmatter import (
    expected_arguments,
    expected_invocation,
    parse_frontmatter,
    parse_frontmatter_bool,
)
from .io import read_text, rel, resolve, sha256, skill_paths
from .markdown import (
    escape_markdown_table_cell,
    normalize_markdown_cell,
    split_markdown_table_row,
)
from .readme import (
    SkillReference,
    check_readme_extra_skill_rows,
    check_readme_skill_sync,
    generated_readme_block_bounds,
    load_skill_references,
    readme_skill_rows,
    render_readme_skill_sync,
    render_skill_reference_row,
    skill_name_from_readme_cell,
    skill_reference_from_frontmatter,
)
from .schema import (
    DEFAULT_CONTRACT_SCHEMA,
    DEFAULT_CONTRACT_SCHEMA_PATH,
    contract_schema_path,
    load_contract_schema,
    load_contract_schema_file,
    load_default_contract_schema,
    schema_skill_frontmatter_fields,
    schema_source_manifest,
    skill_frontmatter_field_by_loader_property,
    skill_frontmatter_fields_by_type,
    skill_frontmatter_required_fields,
    source_manifest_one_of_fields,
    source_manifest_required_fields,
)
from .strings import is_empty_value, normalize_value, shorten, strip_quotes

__all__ = [
    "CHECKS",
    "DEFAULT_CONTRACT_SCHEMA",
    "DEFAULT_CONTRACT_SCHEMA_PATH",
    "CheckFunc",
    "CheckResult",
    "LintContext",
    "SkillReference",
    "add_arguments",
    "allow_empty_field_keys",
    "canonical_epilogue_heading",
    "check_base_diff_scope",
    "check_epilogue_order",
    "check_file_identity",
    "check_hooks_json",
    "check_marker_manifests",
    "check_mechanical",
    "check_ordered_heading_contracts",
    "check_readme_extra_skill_rows",
    "check_readme_skill_sync",
    "check_required_file_contracts",
    "check_text_contracts",
    "contract_schema_path",
    "escape_markdown_table_cell",
    "expected_arguments",
    "expected_invocation",
    "extract_contract_value",
    "generated_readme_block_bounds",
    "heading_lines",
    "is_empty_value",
    "load_contract_schema",
    "load_contract_schema_file",
    "load_default_contract_schema",
    "load_registry",
    "load_skill_references",
    "main",
    "marker_present",
    "normalize_markdown_cell",
    "normalize_value",
    "parse_cli",
    "parse_frontmatter",
    "parse_frontmatter_bool",
    "parse_sources_manifest",
    "read_text",
    "readme_skill_rows",
    "rel",
    "render_readme_skill_sync",
    "render_skill_reference_row",
    "resolve",
    "run",
    "run_checks",
    "schema_skill_frontmatter_fields",
    "schema_source_manifest",
    "sha256",
    "shorten",
    "skill_frontmatter_field_by_loader_property",
    "skill_frontmatter_fields_by_type",
    "skill_frontmatter_required_fields",
    "skill_name_from_readme_cell",
    "skill_paths",
    "skill_reference_from_frontmatter",
    "source_manifest_one_of_fields",
    "source_manifest_required_fields",
    "split_markdown_table_row",
    "strip_quotes",
]
