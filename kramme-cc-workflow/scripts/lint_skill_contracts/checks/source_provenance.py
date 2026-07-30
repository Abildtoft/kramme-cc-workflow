from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from ..io import rel
from ..strings import is_empty_value
from .marker_manifest import parse_sources_manifest
from .types import CheckResult, LintContext

ALLOWED_SOURCE_USAGES = {"copied", "inspiration"}
COPIED_SOURCE_REVISION_FIELDS = (
    "upstream_commit",
    "baseline_commit",
    "upstream_revision",
    "upstream_release",
    "version",
)
COMMIT_FIELDS = {"baseline_commit", "upstream_commit"}
MOVING_REVISION_VALUES = {"head", "latest", "main", "master", "trunk"}


def _resolved_notice_path(skill_dir: Path, raw_notice: str) -> tuple[Path | None, str | None]:
    notice_value = raw_notice.split("#", 1)[0].strip()
    if not notice_value:
        return None, "must name a skill-local license or notice file"

    notice_path = Path(notice_value)
    if notice_path.is_absolute():
        return None, "must be relative to the skill directory"

    skill_root = skill_dir.resolve()
    resolved = (skill_dir / notice_path).resolve()
    try:
        resolved.relative_to(skill_root)
    except ValueError:
        return None, "must stay within the skill directory"
    return resolved, None


def _check_copied_source(
    result: CheckResult,
    root: Path,
    manifest_path: Path,
    entry: dict[str, Any],
    entry_id: str,
) -> None:
    manifest_relative = rel(manifest_path, root)
    for field in ("license", "notice", "upstream_path"):
        if is_empty_value(entry.get(field)):
            result.failures.append(
                f"source provenance: {manifest_relative} copied entry {entry_id!r} is missing non-empty {field!r}"
            )

    revisions = [
        (field, str(entry.get(field)).strip())
        for field in COPIED_SOURCE_REVISION_FIELDS
        if not is_empty_value(entry.get(field))
    ]
    if not revisions:
        fields = ", ".join(repr(field) for field in COPIED_SOURCE_REVISION_FIELDS)
        result.failures.append(
            f"source provenance: {manifest_relative} copied entry {entry_id!r} "
            f"is missing an immutable upstream revision; set one of {fields}"
        )
    for field, value in revisions:
        if value.lower() in MOVING_REVISION_VALUES:
            result.failures.append(
                f"source provenance: {manifest_relative} copied entry {entry_id!r} "
                f"{field!r} must be immutable, not {value!r}"
            )
        if field in COMMIT_FIELDS and re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", value) is None:
            result.failures.append(
                f"source provenance: {manifest_relative} copied entry {entry_id!r} "
                f"{field!r} must be a full 40- or 64-character commit hash"
            )

    notice = entry.get("notice")
    if is_empty_value(notice):
        return

    notice_path, error = _resolved_notice_path(manifest_path.parent.parent, str(notice))
    if error:
        result.failures.append(f"source provenance: {manifest_relative} copied entry {entry_id!r} notice {error}")
        return
    if notice_path is None or not notice_path.is_file():
        result.failures.append(
            f"source provenance: {manifest_relative} copied entry {entry_id!r} notice file does not exist: {notice}"
        )


def check_source_provenance(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("source_provenance")
    if not config:
        return result

    manifest_glob = config.get("manifest_glob", "kramme-cc-workflow/skills/*/references/sources.yaml")
    snapshot_globs = config.get(
        "forbidden_snapshot_globs",
        [
            "kramme-cc-workflow/skills/*/references/sources-snapshot",
            ".agents/skills/*/references/sources-snapshot",
        ],
    )

    for pattern in snapshot_globs:
        for path in sorted(context.root.glob(pattern)):
            result.failures.append(
                "source provenance: committed upstream source bodies are forbidden; "
                f"remove {rel(path, context.root)} and keep only provenance/license "
                "metadata, review date, hash, and original notes"
            )

    for manifest_path in sorted(context.root.glob(manifest_glob)):
        manifest_relative = rel(manifest_path, context.root)
        for index, entry in enumerate(parse_sources_manifest(manifest_path), start=1):
            entry_id = str(entry.get("id", f"entry-{index}"))
            usage = entry.get("usage")
            if is_empty_value(usage):
                result.failures.append(
                    f"source provenance: {manifest_relative} entry {entry_id!r} is missing non-empty 'usage'"
                )
                continue
            if usage not in ALLOWED_SOURCE_USAGES:
                result.failures.append(
                    f"source provenance: {manifest_relative} entry "
                    f"{entry_id!r} has invalid usage {usage!r}; expected "
                    "'inspiration' or 'copied'"
                )
                continue
            if usage == "copied":
                _check_copied_source(result, context.root, manifest_path, entry, entry_id)

    return result
