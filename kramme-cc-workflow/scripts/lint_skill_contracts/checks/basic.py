from __future__ import annotations

import re

from ..frontmatter import parse_frontmatter
from ..io import read_text, rel, resolve, sha256, skill_paths
from ..strings import normalize_value, strip_quotes
from .types import CheckResult, LintContext


def extract_contract_value(
    text: str,
    regex: str,
    normalizer: str | None,
) -> tuple[str, int] | None:
    source = text.replace("`", "")
    match = re.search(regex, source, flags=re.MULTILINE)
    if not match:
        return None
    value = match.group(1) if match.lastindex else match.group(0)
    line = source.count("\n", 0, match.start()) + 1
    return normalize_value(value, normalizer), line


def check_text_contracts(context: LintContext) -> CheckResult:
    result = CheckResult()
    root = context.root
    for group in context.registry.get("text_contracts", []):
        name = group["name"]
        regex = group["extract_regex"]
        normalizer = group.get("normalizer")
        inventory = group.get("inventory")
        if inventory is not None:
            inventory_result = check_text_contract_inventory(
                context, name, group["paths"], inventory
            )
            result.failures.extend(inventory_result.failures)
        reference: tuple[str, str, int] | None = None
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                result.failures.append(f"{name}: registered path is missing: {copy}")
                continue
            extracted = extract_contract_value(read_text(path), regex, normalizer)
            if extracted is None:
                result.failures.append(f"{name}: no registered contract match in {copy}")
                continue
            value, line = extracted
            if reference is None:
                reference = (value, copy, line)
                continue
            ref_value, ref_path, ref_line = reference
            if value != ref_value:
                result.failures.append(
                    f"{name}: {copy}:{line} differs from {ref_path}:{ref_line}; "
                    f"expected {ref_value!r}, got {value!r}"
                )
    return result


def check_text_contract_inventory(
    context: LintContext,
    name: str,
    registered_paths: list[str],
    inventory: object,
) -> CheckResult:
    result = CheckResult()
    if not isinstance(inventory, dict):
        result.failures.append(f"{name}: inventory must be an object")
        return result

    pattern = inventory.get("glob")
    marker = inventory.get("marker")
    if not isinstance(pattern, str) or not pattern:
        result.failures.append(f"{name}: inventory glob must be a non-empty string")
        return result
    if not isinstance(marker, str) or not marker:
        result.failures.append(f"{name}: inventory marker must be a non-empty string")
        return result

    registered = set(registered_paths)
    if len(registered) != len(registered_paths):
        result.failures.append(f"{name}: registered inventory contains duplicate paths")

    discovered: set[str] = set()
    for path in skill_paths(context.root, pattern):
        marker_count = read_text(path).count(marker)
        if marker_count == 0:
            continue
        relative = rel(path, context.root)
        discovered.add(relative)
        if marker_count != 1:
            result.failures.append(
                f"{name}: {relative} contains {marker_count} inventory markers; expected exactly 1"
            )

    for path in sorted(discovered - registered):
        result.failures.append(f"{name}: discovered unregistered contract copy: {path}")
    for path in sorted(registered - discovered):
        result.failures.append(f"{name}: registered contract copy is not discoverable: {path}")
    if len(registered_paths) != len(discovered):
        result.failures.append(
            f"{name}: registered inventory count {len(registered_paths)} "
            f"does not equal discovered count {len(discovered)}"
        )

    return result


def heading_lines(text: str) -> list[tuple[int, str]]:
    matches = []
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if re.match(r"^#{1,6}\s+\S", stripped):
            matches.append((number, stripped))
    return matches


def check_ordered_heading_contracts(context: LintContext) -> CheckResult:
    result = CheckResult()
    root = context.root
    for group in context.registry.get("ordered_heading_contracts", []):
        name = group["name"]
        expected = group["headings"]
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                result.failures.append(f"{name}: registered path is missing: {copy}")
                continue
            headings = heading_lines(read_text(path))
            last_index = -1
            for heading in expected:
                found = next(
                    (
                        (index, line_no)
                        for index, (line_no, actual) in enumerate(headings)
                        if index > last_index and actual == heading
                    ),
                    None,
                )
                if found is None:
                    result.failures.append(
                        f"{name}: missing or out-of-order heading {heading!r} in {copy}"
                    )
                    break
                last_index = found[0]
    return result


def check_file_identity(context: LintContext) -> CheckResult:
    result = CheckResult()
    root = context.root
    for group in context.registry.get("file_identity_groups", []):
        name = group["name"]
        reference: tuple[str, str] | None = None
        for copy in group["paths"]:
            path = resolve(root, copy)
            if not path.exists():
                result.failures.append(f"{name}: registered path is missing: {copy}")
                continue
            current_hash = sha256(path)
            if reference is None:
                reference = (current_hash, copy)
                continue
            ref_hash, ref_path = reference
            if current_hash != ref_hash:
                result.failures.append(
                    f"{name}: {copy} hash {current_hash} differs from {ref_path} hash {ref_hash}; "
                    "sync all registered copies"
                )
    return result


def check_required_file_contracts(context: LintContext) -> CheckResult:
    result = CheckResult()
    root = context.root
    for contract in context.registry.get("required_file_contracts", []):
        name = contract["name"]
        copy = contract["path"]
        path = resolve(root, copy)
        if not path.exists():
            result.failures.append(f"{name}: registered path is missing: {copy}")
            continue

        text = read_text(path)
        frontmatter_contract = contract.get("frontmatter", {})
        if frontmatter_contract:
            frontmatter = parse_frontmatter(text)
            if frontmatter is None:
                result.failures.append(f"{name}: {copy} is missing YAML frontmatter")
            else:
                for field, expected in frontmatter_contract.items():
                    actual = frontmatter.get(field)
                    expected_text = strip_quotes(str(expected))
                    if actual != expected_text:
                        result.failures.append(
                            f"{name}: {copy} frontmatter field {field!r} expected "
                            f"{expected_text!r}, got {actual!r}"
                        )

        for required_text in contract.get("contains", []):
            if required_text not in text:
                result.failures.append(f"{name}: {copy} is missing required text {required_text!r}")
    return result
