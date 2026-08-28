#!/usr/bin/env python3
"""Read-only validation for kramme:code:plan-to-pr intake and retry state."""

from __future__ import annotations

import argparse
import json
import os
import posixpath
import re
import stat
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import NoReturn, Sequence

SCHEMA_VERSION = 1
ROOT_PLAN_RE = re.compile(r"^PR_PLAN_(W[0-9]{2}[A-Z])_([A-Z0-9_]+)\.md$")
ARCHIVE_PLAN_RE = re.compile(r"^PR_PLAN_([A-Z][0-9]{2}[A-Z])_([A-Z0-9_]+)\.md$")
LABEL_RE = re.compile(r"^[A-Z][0-9]{2}[A-Z]$")
BLOCKER_LABEL_RE = re.compile(r"^W[0-9]{2}[A-Z]$")
LABEL_TOKEN_RE = re.compile(
    r"(?i)^(?:W+[0-9]+[A-Z][A-Za-z0-9_-]*|W+[0-9]+[-_][A-Z][A-Za-z0-9_-]*|[A-Z][0-9]{2}[A-Z][A-Za-z0-9_-]*)$"
)
ATTACHMENT_PATH_RE = re.compile(r"^[A-Za-z0-9._/ -]+$")
ACTIVE_STATUSES = {"TODO", "READY", "IN_PROGRESS", "BLOCKED", "DRIFTED", "STALE"}
ALL_STATUSES = ACTIVE_STATUSES | {"MISSING", "DONE", "SUPERSEDED"}
RECOVERY_STATUSES = {"DRIFTED", "STALE"}
REQUIRED_PLAN_SECTIONS = (
    "### In Scope",
    "### Out of Scope",
    "## Completion Criteria",
    "## Test and Verification Plan",
    "## STOP Conditions",
)
CHECKPOINT_FIELDS = (
    "Stage",
    "Plan set",
    "Plan",
    "Branch",
    "Base commit",
    "Checkpoint head",
    "Checkpoint tree",
    "Scope paths",
)


class ValidationError(Exception):
    """A stable user-facing validation failure."""

    def __init__(self, code: str, message: str, details: dict[str, object] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or {}


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise ValidationError("ARGUMENT_INVALID", message)


@dataclass(frozen=True)
class GitContext:
    repo_root: Path
    requested_root: Path
    oid_length: int

    def oid_is_full(self, value: str) -> bool:
        return bool(re.fullmatch(rf"[0-9a-f]{{{self.oid_length}}}", value))


@dataclass(frozen=True)
class PlanMetadata:
    selected_basename: str
    execution_label: str
    status: str
    planned_at: str
    impact: str
    leverage: str
    blocked_by: tuple[str, ...]
    blocks: tuple[str, ...]
    parallel: tuple[str, ...]


@dataclass(frozen=True)
class IndexRow:
    label: str
    status: str
    filename: str
    sequencing: str


@dataclass(frozen=True)
class InputState:
    mode: str
    absolute_path: Path
    relative_path: str
    plan_set_id: str | None


@dataclass(frozen=True)
class ValidatedInput:
    plan_set_id: str
    scope_mode: str
    standalone: bool
    detached: bool
    source_oid: str | None
    index_row: IndexRow | None
    prerequisite_records: tuple[PrerequisiteRecord, ...]
    prerequisite_evidence: tuple[PrerequisiteEvidence, ...]


@dataclass(frozen=True)
class PrerequisiteRecord:
    label: str
    filename: str
    status: str
    execution_result: str

    def as_json(self) -> dict[str, str]:
        return {
            "label": self.label,
            "filename": self.filename,
            "status": self.status,
            "execution_result": self.execution_result,
        }


@dataclass(frozen=True)
class PrerequisiteEvidence:
    label: str
    required_base_state: str
    evidence_locations: str
    evidence_paths: tuple[str, ...]
    readiness_decision: str
    legacy: bool

    def as_json(self) -> dict[str, object]:
        return {
            "label": self.label,
            "required_base_state": self.required_base_state,
            "evidence_locations": self.evidence_locations,
            "evidence_paths": list(self.evidence_paths),
            "readiness_decision": self.readiness_decision,
            "legacy": self.legacy,
        }


def git_run(
    context: GitContext | Path,
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[bytes]:
    repo_root = context.repo_root if isinstance(context, GitContext) else context
    result = subprocess.run(
        ["git", "-C", str(repo_root), *arguments],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=False,
        check=False,
    )
    if check and result.returncode != 0:
        diagnostic = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValidationError(
            "GIT_CHECK_FAILED",
            f"Git validation failed for {arguments[0]}.",
            {"command": arguments[0], "diagnostic": diagnostic[:600]},
        )
    return result


def git_text(context: GitContext | Path, arguments: Sequence[str]) -> str:
    return git_run(context, arguments).stdout.decode("utf-8", errors="strict").strip()


def build_git_context(repo_root_arg: str) -> GitContext:
    requested_root = Path(repo_root_arg).expanduser().absolute()
    requested = requested_root.resolve(strict=True)
    if not requested.is_dir():
        raise ValidationError("REPOSITORY_INVALID", "Repository root is not a directory.")
    actual = Path(git_text(requested, ["rev-parse", "--show-toplevel"])).resolve(strict=True)
    if requested != actual:
        raise ValidationError(
            "REPOSITORY_ROOT_MISMATCH",
            "--repo-root must name the canonical Git worktree root.",
            {"actual": str(actual), "requested": str(requested)},
        )
    object_format = git_text(requested, ["rev-parse", "--show-object-format"])
    oid_length = {"sha1": 40, "sha256": 64}.get(object_format)
    if oid_length is None:
        raise ValidationError("OBJECT_FORMAT_UNSUPPORTED", f"Unsupported Git object format: {object_format}")
    return GitContext(requested, requested_root, oid_length)


def canonical_relative(repo_root: Path, path: Path, code: str) -> str:
    try:
        return path.relative_to(repo_root).as_posix()
    except ValueError as exc:
        raise ValidationError(code, "Path must remain below the repository root.", {"path": str(path)}) from exc


def lstat_mode(path: Path, missing_code: str, missing_message: str) -> int:
    try:
        return path.lstat().st_mode
    except (FileNotFoundError, NotADirectoryError) as exc:
        raise ValidationError(missing_code, missing_message, {"path": str(path)}) from exc
    except OSError as exc:
        raise ValidationError(
            "PATH_STAT_FAILED",
            "A filesystem path could not be inspected.",
            {"path": str(path), "errno": exc.errno, "required_code": missing_code},
        ) from exc


def require_real_parent_chain(repo_root: Path, parent: Path) -> None:
    relative = canonical_relative(repo_root, parent, "INPUT_OUTSIDE_REPOSITORY")
    cursor = repo_root
    for part in PurePosixPath(relative).parts:
        cursor /= part
        mode = lstat_mode(cursor, "INPUT_PARENT_MISSING", "An input parent directory is missing.")
        if stat.S_ISLNK(mode):
            raise ValidationError(
                "INPUT_PARENT_SYMLINK", "Input parent directories must not be symlinks.", {"path": str(cursor)}
            )
        if not stat.S_ISDIR(mode):
            raise ValidationError("INPUT_PARENT_INVALID", "An input parent is not a directory.", {"path": str(cursor)})
        if not cursor.resolve(strict=True).is_relative_to(repo_root):
            raise ValidationError("INPUT_OUTSIDE_REPOSITORY", "Input parent resolves outside the repository.")


def classify_input(context: GitContext, input_arg: str) -> InputState:
    raw = Path(input_arg).expanduser()
    if raw.is_absolute():
        lexical = Path(os.path.abspath(raw))
        try:
            relative_input = lexical.relative_to(context.requested_root)
        except ValueError:
            try:
                relative_input = lexical.relative_to(context.repo_root)
            except ValueError as exc:
                raise ValidationError(
                    "INPUT_OUTSIDE_REPOSITORY", "Plan input must remain below the repository root."
                ) from exc
        candidate = context.repo_root / relative_input
    else:
        candidate = Path(os.path.abspath(context.repo_root / raw))
    relative = canonical_relative(context.repo_root, candidate, "INPUT_OUTSIDE_REPOSITORY")
    require_real_parent_chain(context.repo_root, candidate.parent)
    mode = lstat_mode(candidate, "INPUT_MISSING", "Plan input does not exist.")
    if stat.S_ISLNK(mode):
        raise ValidationError("INPUT_SYMLINK", "Plan input must not be a symlink.", {"path": relative})
    if not stat.S_ISREG(mode):
        raise ValidationError("INPUT_NOT_REGULAR", "Plan input must be a regular file.", {"path": relative})

    parts = PurePosixPath(relative).parts
    if len(parts) == 1 and ROOT_PLAN_RE.fullmatch(parts[0]):
        return InputState("root", candidate, relative, None)
    if len(parts) >= 3 and parts[:2] == (".context", "attachments"):
        if not ATTACHMENT_PATH_RE.fullmatch(relative):
            raise ValidationError("ATTACHMENT_PATH_UNSAFE", "Attachment path contains unsupported characters.")
        return InputState("attachment", candidate, relative, None)
    if len(parts) == 5 and parts[:2] == (".context", "code-plan-to-pr") and parts[3] == "plans":
        plan_set_id = parts[2]
        expected = rf"ps-[0-9a-f]{{{context.oid_length}}}"
        if not re.fullmatch(expected, plan_set_id):
            raise ValidationError("ARCHIVE_ID_INVALID", "Archive directory does not contain a full plan-set object ID.")
        if not ARCHIVE_PLAN_RE.fullmatch(parts[4]):
            raise ValidationError(
                "PLAN_FILENAME_INVALID", "Archived plan filename does not match the canonical contract."
            )
        return InputState("archived", candidate, relative, plan_set_id)
    raise ValidationError(
        "INPUT_LOCATION_UNSUPPORTED", "Plan input is not in a supported root, attachment, or archive location."
    )


def read_utf8(path: Path) -> str:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValidationError("INPUT_READ_FAILED", "Plan input could not be read.", {"path": str(path)}) from exc
    if b"\0" in raw:
        raise ValidationError("INPUT_NUL", "Plan input must not contain NUL bytes.")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValidationError("INPUT_NOT_UTF8", "Plan input must be UTF-8 text.") from exc


def mask_fenced_blocks(text: str) -> str:
    """Replace fenced Markdown content with spaces while preserving offsets."""
    result: list[str] = []
    fence_character: str | None = None
    fence_length = 0
    for line in text.splitlines(keepends=True):
        boundary = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line.rstrip("\r\n"))
        if fence_character is None:
            if boundary is None:
                result.append(line)
                continue
            marker = boundary.group(1)
            fence_character = marker[0]
            fence_length = len(marker)
        elif boundary is not None:
            marker = boundary.group(1)
            if marker[0] == fence_character and len(marker) >= fence_length and not boundary.group(2).strip():
                fence_character = None
                fence_length = 0
        result.append(re.sub(r"[^\r\n]", " ", line))
    return "".join(result)


def opening_metadata(text: str) -> str:
    first_h2 = re.search(r"(?m)^## ", mask_fenced_blocks(text))
    return text[: first_h2.start()] if first_h2 else text


def one_match(pattern: str, text: str, field: str, *, optional: bool = False) -> str | None:
    matches = re.findall(pattern, text, flags=re.MULTILINE)
    if not matches and optional:
        return None
    if not matches:
        raise ValidationError("METADATA_MISSING", f"Missing canonical {field} field.", {"field": field})
    if len(matches) != 1:
        raise ValidationError("METADATA_DUPLICATE", f"Expected exactly one canonical {field} field.", {"field": field})
    value = matches[0]
    return value if isinstance(value, str) else value[0]


def free_metadata_field(metadata: str, field: str) -> str:
    escaped = re.escape(field)
    value = one_match(rf"\*\*{escaped}:\*\*\s*(.*?)(?=\s+\*\*[A-Z][^:*]*:\*\*|$)", metadata, field)
    assert value is not None
    return value.strip()


def dependency_labels(value: str, field: str) -> tuple[str, ...]:
    tokens = re.findall(r"[A-Za-z0-9_-]+", value)
    label_like = [token for token in tokens if BLOCKER_LABEL_RE.fullmatch(token)]
    permits_wave_label = field in {"Parallel group", "### Parallel Work", "Index sequencing"}
    malformed = {token for token in tokens if LABEL_TOKEN_RE.fullmatch(token) and token not in label_like}
    invalid = sorted(malformed)
    if invalid:
        raise ValidationError(
            "DEPENDENCY_LABEL_INVALID",
            f"{field} contains an invalid dependency label.",
            {"field": field, "labels": invalid},
        )
    explicitly_empty = (
        re.search(r"\bNone\b", value, flags=re.IGNORECASE) is not None
        or (field == "Index sequencing" and re.search(r"\bindependent\b", value, flags=re.IGNORECASE) is not None)
        or (
            permits_wave_label
            and re.search(r"\b(?:Wave|parallel\s+in)\s+W[0-9]{2}\b", value, flags=re.IGNORECASE) is not None
        )
    )
    if not label_like and not explicitly_empty:
        raise ValidationError(
            "DEPENDENCY_LABEL_INVALID",
            f"{field} must name canonical dependency labels or explicitly state None.",
            {"field": field},
        )
    if len(label_like) != len(set(label_like)):
        raise ValidationError(
            "DEPENDENCY_LABEL_DUPLICATE",
            f"{field} contains a duplicate dependency label.",
            {"field": field},
        )
    return tuple(label_like)


def section(text: str, heading: str) -> str | None:
    level = len(heading) - len(heading.lstrip("#"))
    pattern = re.compile(rf"(?m)^{re.escape(heading)}\s*$")
    structure = mask_fenced_blocks(text)
    matches = list(pattern.finditer(structure))
    if len(matches) > 1:
        raise ValidationError("SECTION_DUPLICATE", f"Section appears more than once: {heading}")
    if not matches:
        return None
    start = matches[0].end()
    next_heading = re.search(rf"(?m)^#{{1,{level}}}\s+", structure[start:])
    end = start + next_heading.start() if next_heading else len(text)
    return text[start:end].strip()


def normalize_repository_path(context: GitContext, raw_path: str, code: str) -> tuple[str, Path]:
    pure = PurePosixPath(raw_path)
    invalid = (
        not raw_path
        or pure.is_absolute()
        or raw_path.startswith("-")
        or "\\" in raw_path
        or any(part in {"", ".", ".."} for part in pure.parts)
        or any(ord(character) < 32 or ord(character) == 127 for character in raw_path)
    )
    if invalid:
        raise ValidationError(code, "Path is not a safe repository-relative literal.", {"path": raw_path})
    normalized = posixpath.normpath(raw_path)
    if PurePosixPath(normalized).parts[0].casefold() == ".git":
        raise ValidationError(code, "Path targets Git administration.", {"path": raw_path})
    resolved = (context.repo_root / normalized).resolve(strict=False)
    git_dir_text = git_text(context, ["rev-parse", "--git-dir"])
    git_dir = Path(git_dir_text)
    git_dir = (
        (context.repo_root / git_dir).resolve(strict=False)
        if not git_dir.is_absolute()
        else git_dir.resolve(strict=False)
    )
    if not resolved.is_relative_to(context.repo_root) or resolved == git_dir or resolved.is_relative_to(git_dir):
        raise ValidationError(
            code,
            "Path escapes the worktree or targets Git administration.",
            {"path": raw_path},
        )
    return normalized, resolved


def evidence_field(block: str, field: str) -> str:
    pattern = re.compile(
        rf"(?ms)^(?:[-*]\s+)?\*\*{re.escape(field)}:\*\*\s*(.*?)"
        rf"(?=^(?:[-*]\s+)?\*\*[A-Z][^:\n]*:\*\*|^#{{1,6}}\s+|\Z)"
    )
    matches = [match.group(1).strip() for match in pattern.finditer(block)]
    if len(matches) != 1 or not matches[0]:
        raise ValidationError(
            "PREREQUISITE_EVIDENCE_INVALID",
            f"Prerequisite evidence requires exactly one non-empty {field} field.",
            {"field": field},
        )
    return matches[0]


def parse_prerequisite_evidence(
    context: GitContext, text: str, blockers: tuple[str, ...]
) -> list[PrerequisiteEvidence]:
    if not blockers:
        return []
    evidence_section = section(text, "### Prerequisite Readiness Evidence")
    legacy = evidence_section is None
    evidence_text = text if legacy else evidence_section
    assert evidence_text is not None
    evidence_structure = mask_fenced_blocks(evidence_text)
    matches = list(re.finditer(r"(?m)^####\s+(W[0-9]{2}[A-Z])\s*$", evidence_structure))
    blocks: dict[str, list[str]] = {}
    for position, match in enumerate(matches):
        start = match.end()
        next_heading = re.search(r"(?m)^#{1,4}\s+", evidence_structure[start:])
        natural_end = start + next_heading.start() if next_heading else len(evidence_text)
        next_match = matches[position + 1].start() if position + 1 < len(matches) else len(evidence_text)
        end = min(natural_end, next_match)
        blocks.setdefault(match.group(1), []).append(evidence_text[start:end].strip())

    records: list[PrerequisiteEvidence] = []
    for blocker in blockers:
        matching_blocks = blocks.get(blocker, [])
        if len(matching_blocks) != 1:
            raise ValidationError(
                "PREREQUISITE_EVIDENCE_MISSING",
                "Each blocker requires exactly one prerequisite-readiness evidence entry.",
                {"label": blocker, "entries": len(matching_blocks)},
            )
        block = matching_blocks[0]
        required_base_state = evidence_field(block, "Required base state")
        evidence_locations = evidence_field(block, "Evidence locations")
        readiness_decision = evidence_field(block, "Readiness decision")
        raw_paths = re.findall(r"`([^`]+)`", evidence_locations)
        if not raw_paths:
            raise ValidationError(
                "PREREQUISITE_EVIDENCE_INVALID",
                "Prerequisite evidence must name at least one repository-relative path.",
                {"label": blocker},
            )
        normalized_paths = tuple(
            normalize_repository_path(context, raw_path, "PREREQUISITE_EVIDENCE_PATH_INVALID")[0]
            for raw_path in raw_paths
        )
        combined = "\n".join((required_base_state, evidence_locations, readiness_decision)).casefold()
        forbidden = ("pr_plan_index.md", "sibling plan", "workflow `done`", "pull request url", "landing metadata")
        if any(value in combined for value in forbidden):
            raise ValidationError(
                "PREREQUISITE_EVIDENCE_INVALID",
                "Prerequisite evidence must be decidable from repository base state alone.",
                {"label": blocker},
            )
        records.append(
            PrerequisiteEvidence(
                label=blocker,
                required_base_state=required_base_state,
                evidence_locations=evidence_locations,
                evidence_paths=normalized_paths,
                readiness_decision=readiness_decision,
                legacy=legacy,
            )
        )
    return records


def parse_metadata(text: str, mode: str, actual_basename: str) -> PlanMetadata:
    metadata = opening_metadata(text)
    filename = one_match(r"\*\*File:\*\*\s*`([^`]+)`", metadata, "File")
    status_value = one_match(r"\*\*Status:\*\*\s*([^\s*]+)(?=\s+\*\*|$)", metadata, "Status")
    label = one_match(r"\*\*Execution label:\*\*\s*`([^`]+)`", metadata, "Execution label")
    planned_at = one_match(r"\*\*Planned at:\*\*\s*commit\s*`([0-9a-f]{7,64})`", metadata, "Planned at")
    impact = one_match(
        r"\*\*Impact:\*\*\s*((?:UNVERIFIED:\s+)?(?:CRITICAL|HIGH|MED|LOW|NEGLIGIBLE))(?=\s+\*\*|$)",
        metadata,
        "Impact",
    )
    leverage = one_match(
        r"\*\*Leverage:\*\*\s*((?:UNVERIFIED:\s+)?(?:EXCEPTIONAL|HIGH|MED|LOW))(?=\s+\*\*|$)",
        metadata,
        "Leverage",
    )
    one_match(r"\*\*Scope contract:\*\*\s*([^*\n]+?)(?=\s+\*\*|$)", metadata, "Scope contract", optional=True)
    assert (
        filename is not None
        and status_value is not None
        and label is not None
        and planned_at is not None
        and impact is not None
        and leverage is not None
    )
    match = ARCHIVE_PLAN_RE.fullmatch(filename)
    if match is None:
        raise ValidationError(
            "PLAN_FILENAME_INVALID", "Canonical File metadata does not match the plan filename contract."
        )
    if not LABEL_RE.fullmatch(label) or match.group(1) != label:
        raise ValidationError("EXECUTION_LABEL_MISMATCH", "Execution label does not match the canonical filename.")
    if mode != "attachment" and filename != actual_basename:
        raise ValidationError("PLAN_FILENAME_MISMATCH", "Canonical File metadata does not match the selected filename.")
    if status_value not in ALL_STATUSES:
        raise ValidationError("STATUS_INVALID", f"Unknown lifecycle status: {status_value}")
    title_matches = re.findall(rf"(?m)^# PR Plan {re.escape(label)}:", mask_fenced_blocks(text))
    if len(title_matches) != 1:
        raise ValidationError("TITLE_INVALID", "Plan must contain exactly one canonical title for its execution label.")

    blocked_by = dependency_labels(free_metadata_field(metadata, "Blocked by"), "Blocked by")
    blocks = dependency_labels(free_metadata_field(metadata, "Blocks"), "Blocks")
    parallel = dependency_labels(free_metadata_field(metadata, "Parallel group"), "Parallel group")
    section_fields = (
        ("### Prerequisites (must land before this PR)", blocked_by, "Blocked by"),
        ("### Dependents (blocked until this PR lands)", blocks, "Blocks"),
        ("### Parallel Work", parallel, "Parallel group"),
    )
    for heading, expected, field in section_fields:
        body = section(text, heading)
        if body is None:
            raise ValidationError("DEPENDENCY_SECTION_MISSING", f"Missing dependency section: {heading}")
        actual = dependency_labels(body, heading)
        if set(actual) != set(expected):
            raise ValidationError(
                "DEPENDENCY_MISMATCH",
                f"{field} metadata and dependency section disagree.",
                {"metadata": list(expected), "section": list(actual)},
            )
    return PlanMetadata(
        selected_basename=filename,
        execution_label=label,
        status=status_value,
        planned_at=planned_at,
        impact=impact,
        leverage=leverage,
        blocked_by=blocked_by,
        blocks=blocks,
        parallel=parallel,
    )


def validate_body(text: str) -> None:
    for heading in REQUIRED_PLAN_SECTIONS:
        body = section(text, heading)
        if body is None or not body:
            raise ValidationError("PLAN_SECTION_MISSING", f"Plan requires a non-empty {heading} section.")
    if section(text, "## Implementation Setup") is not None:
        raise ValidationError(
            "IMPLEMENTATION_SETUP_UNSUPPORTED", "Plans with Implementation Setup use their originating workflow."
        )
    if re.search(
        r"(?m)^[ \t]*(?:(?:[-*+]|>)\s*)*(?:MISSING REQUIREMENT|CONFUSION):",
        mask_fenced_blocks(text),
    ):
        raise ValidationError(
            "PLAN_REQUIREMENT_UNRESOLVED", "Plan contains an unresolved requirement or confusion marker."
        )


def parse_index_rows(text: str) -> list[IndexRow]:
    rows: list[IndexRow] = []
    pattern = re.compile(
        r"(?m)^\|\s*`([A-Z][0-9]{2}[A-Z])`\s*\|\s*([A-Z_]+)\s*\|\s*`([^`]+)`\s*\|"
        r"\s*[^|]*\|\s*[^|]*\|\s*[^|]*\|\s*[^|]*\|\s*([^|]*)\|"
    )
    for match in pattern.finditer(text):
        rows.append(IndexRow(match.group(1), match.group(2), match.group(3), match.group(4).strip()))
    if not rows:
        raise ValidationError("INDEX_ROWS_MISSING", "Plan index does not contain a canonical plan row.")
    return rows


def validate_index_dependencies(row: IndexRow, metadata: PlanMetadata, rows: Sequence[IndexRow]) -> None:
    indexed = dependency_labels(row.sequencing, "Index sequencing")
    indexed_sets: dict[str, list[str]] = {"blocked_by": [], "blocks": [], "parallel": []}
    relation_pattern = re.compile(r"\b(blocked by|after|blocks|parallel(?: with| in)?)\b", re.IGNORECASE)
    for label in indexed:
        label_match = re.search(rf"\b{re.escape(label)}\b", row.sequencing)
        assert label_match is not None
        relations = list(relation_pattern.finditer(row.sequencing, 0, label_match.start()))
        if not relations:
            raise ValidationError(
                "INDEX_DEPENDENCY_FORMAT_INVALID",
                "Each index dependency label requires a sequencing relationship.",
                {"label": label, "sequencing": row.sequencing},
            )
        relation = relations[-1].group(1).casefold()
        if relation in {"blocked by", "after"}:
            indexed_sets["blocked_by"].append(label)
        elif relation == "blocks":
            indexed_sets["blocks"].append(label)
        else:
            indexed_sets["parallel"].append(label)
    parallel_waves = re.findall(r"\bparallel\s+in\s+(W[0-9]{2})\b", row.sequencing, flags=re.IGNORECASE)
    if len(parallel_waves) > 1 or (parallel_waves and not row.label.startswith(parallel_waves[0])):
        raise ValidationError(
            "INDEX_DEPENDENCY_FORMAT_INVALID",
            "Index parallel-wave sequencing must name the selected plan's wave exactly once.",
            {"label": row.label, "sequencing": row.sequencing},
        )
    if parallel_waves:
        indexed_sets["parallel"].extend(
            peer.label for peer in rows if peer.label != row.label and peer.label.startswith(parallel_waves[0])
        )
    planned_sets = {
        "blocked_by": list(metadata.blocked_by),
        "blocks": list(metadata.blocks),
        "parallel": list(metadata.parallel),
    }
    if any(set(indexed_sets[key]) != set(planned_sets[key]) for key in indexed_sets):
        raise ValidationError(
            "INDEX_DEPENDENCY_MISMATCH",
            "Plan and index dependency sequencing disagree.",
            {"index": indexed_sets, "plan": planned_sets},
        )


def validate_complete_set_rows(plan_root: Path, rows: Sequence[IndexRow], mode: str) -> None:
    labels = [row.label for row in rows]
    filenames = [row.filename for row in rows]
    if len(labels) != len(set(labels)) or len(filenames) != len(set(filenames)):
        raise ValidationError("INDEX_PLAN_MISMATCH", "Plan index labels and filenames must be unique.")
    for row in rows:
        filename_match = ROOT_PLAN_RE.fullmatch(row.filename)
        if filename_match is None or filename_match.group(1) != row.label or row.status not in ALL_STATUSES:
            raise ValidationError(
                "INDEX_PLAN_MISMATCH",
                "Every index row requires a canonical filename, label, and lifecycle status.",
                {"filename": row.filename, "label": row.label, "status": row.status},
            )
        plan_path = plan_root / row.filename
        require_regular_file(plan_path, "INDEX_PLAN_MISSING")
        plan_text = read_utf8(plan_path)
        plan_metadata = parse_metadata(plan_text, mode, row.filename)
        if plan_metadata.execution_label != row.label or plan_metadata.status != row.status:
            raise ValidationError(
                "INDEX_PLAN_MISMATCH",
                "Every plan's label and status must agree with its index row.",
                {
                    "filename": row.filename,
                    "index_label": row.label,
                    "index_status": row.status,
                    "plan_label": plan_metadata.execution_label,
                    "plan_status": plan_metadata.status,
                },
            )
        validate_index_dependencies(row, plan_metadata, rows)


def validate_complete_set_prerequisites(
    plan_root: Path,
    selected: PlanMetadata,
    rows: list[IndexRow],
    mode: str,
) -> list[PrerequisiteRecord]:
    records: list[PrerequisiteRecord] = []
    for label in selected.blocked_by:
        matching_rows = [row for row in rows if row.label == label]
        if len(matching_rows) != 1:
            raise ValidationError(
                "PREREQUISITE_INDEX_MISMATCH",
                "Each prerequisite must have exactly one matching index row.",
                {"label": label, "rows": len(matching_rows)},
            )
        row = matching_rows[0]
        if row.status != "DONE":
            raise ValidationError(
                "PREREQUISITE_NOT_DONE",
                "A complete-set prerequisite is not DONE in the index.",
                {"label": label, "status": row.status},
            )
        plan_path = plan_root / row.filename
        require_regular_file(plan_path, "PREREQUISITE_PLAN_MISSING")
        plan_text = read_utf8(plan_path)
        prerequisite = parse_metadata(plan_text, mode, row.filename)
        if prerequisite.execution_label != label or prerequisite.status != "DONE":
            raise ValidationError(
                "PREREQUISITE_PLAN_MISMATCH",
                "Prerequisite plan metadata must match the DONE index row.",
                {
                    "label": label,
                    "plan_label": prerequisite.execution_label,
                    "plan_status": prerequisite.status,
                },
            )
        execution_result = section(plan_text, "## Execution Result")
        if not execution_result:
            raise ValidationError(
                "PREREQUISITE_RESULT_MISSING",
                "A DONE prerequisite requires one non-empty Execution Result.",
                {"label": label, "filename": row.filename},
            )
        records.append(PrerequisiteRecord(label, row.filename, row.status, execution_result))
    return records


def require_regular_file(path: Path, code: str) -> None:
    mode = lstat_mode(path, code, "Required plan companion is missing.")
    if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
        raise ValidationError(code, "Required plan companion must be a non-symlink regular file.", {"path": str(path)})


def classify_scope_contracts(artifacts: Sequence[Path], artifact_kind: str) -> str:
    contracts: list[str | None] = []
    for artifact in artifacts:
        require_regular_file(artifact, "SCOPE_CONTRACT_ARTIFACT_INVALID")
        artifact_text = read_utf8(artifact)
        values = re.findall(
            r"\*\*Scope contract:\*\*\s*([^*\n]+?)(?=\s+\*\*|$)",
            opening_metadata(artifact_text),
            flags=re.MULTILINE,
        )
        if len(values) > 1:
            raise ValidationError(
                "SCOPE_CONTRACT_INVALID", f"{artifact_kind} artifact has duplicate scope-contract fields."
            )
        contracts.append(values[0].strip() if values else None)
    if all(value == "exact files" for value in contracts):
        return "exact-files"
    if all(value is None for value in contracts):
        return "containment"
    raise ValidationError(
        "SCOPE_CONTRACT_INVALID",
        f"{artifact_kind} plans and index must all declare exact files or all omit the field.",
        {"contracts": contracts},
    )


def hash_file(context: GitContext, path: Path) -> str:
    oid = git_text(context, ["hash-object", "--no-filters", "--", str(path)])
    if not context.oid_is_full(oid):
        raise ValidationError("OBJECT_ID_INVALID", "Git returned an invalid full object ID.")
    return oid


def hash_stdin(context: GitContext, payload: bytes) -> str:
    oid = git_run(context, ["hash-object", "--stdin"], input_bytes=payload).stdout.decode().strip()
    if not context.oid_is_full(oid):
        raise ValidationError("OBJECT_ID_INVALID", "Git returned an invalid manifest object ID.")
    return oid


def root_plan_identity(context: GitContext, metadata: PlanMetadata) -> ValidatedInput:
    index_path = context.repo_root / "PR_PLAN_INDEX.md"
    rejection_path = context.repo_root / "PR_PLAN_REJECTIONS.md"
    require_regular_file(index_path, "INDEX_MISSING")
    require_regular_file(rejection_path, "ROOT_REJECTIONS_MISSING")
    index_text = read_utf8(index_path)
    rows = parse_index_rows(index_text)
    matching = [row for row in rows if row.filename == metadata.selected_basename]
    if len(matching) != 1:
        raise ValidationError("INDEX_PLAN_MISMATCH", "Selected plan must appear exactly once in the index.")
    row = matching[0]
    if row.label != metadata.execution_label or row.status != metadata.status:
        raise ValidationError("INDEX_PLAN_MISMATCH", "Plan and index label or status disagree.")
    validate_index_dependencies(row, metadata, rows)

    implementation_files = sorted(path.name for path in context.repo_root.glob("PR_PLAN_W[0-9][0-9][A-Z]_*.md"))
    indexed_files = sorted(row.filename for row in rows)
    if implementation_files != indexed_files:
        raise ValidationError(
            "INDEX_INVENTORY_MISMATCH",
            "Root implementation-plan inventory does not match the index.",
            {"files": implementation_files, "index": indexed_files},
        )
    prerequisite_records = (
        []
        if metadata.status in RECOVERY_STATUSES
        else validate_complete_set_prerequisites(context.repo_root, metadata, rows, "root")
    )
    validate_complete_set_rows(context.repo_root, rows, "root")
    artifacts = sorted(context.repo_root.glob("PR_PLAN_*.md"), key=lambda path: path.name.encode())
    manifest = bytearray()
    for artifact in artifacts:
        require_regular_file(artifact, "ROOT_ARTIFACT_INVALID")
        manifest.extend(artifact.name.encode())
        manifest.append(0)
        manifest.extend(hash_file(context, artifact).encode())
        manifest.extend(b"\n")
    scope_mode = classify_scope_contracts(
        [index_path, *(context.repo_root / filename for filename in implementation_files)], "Root"
    )
    plan_set_id = f"ps-{hash_stdin(context, bytes(manifest))}"
    archive = context.repo_root / ".context" / "code-plan-to-pr" / plan_set_id / "plans"
    if archive.exists():
        raise ValidationError(
            "ARCHIVE_ALREADY_EXISTS",
            "This plan set already has an archive; use the archived plan.",
            {"archived_plan": f"{archive.relative_to(context.repo_root).as_posix()}/{metadata.selected_basename}"},
        )
    return ValidatedInput(
        plan_set_id=plan_set_id,
        scope_mode=scope_mode,
        standalone=False,
        detached=False,
        source_oid=None,
        index_row=row,
        prerequisite_records=tuple(prerequisite_records),
        prerequisite_evidence=(),
    )


def standalone_manifest(context: GitContext, basename: str, source_oid: str) -> str:
    payload = b"standalone-attachment\0" + basename.encode() + b"\0" + source_oid.encode() + b"\n"
    return f"ps-{hash_stdin(context, payload)}"


def remove_section(text: str, heading: str) -> str:
    structure = mask_fenced_blocks(text)
    occurrences = list(re.finditer(rf"(?m)^{re.escape(heading)}\s*$", structure))
    if len(occurrences) > 1:
        raise ValidationError("LIFECYCLE_DUPLICATE", f"Lifecycle section appears more than once: {heading}")
    if not occurrences:
        return text
    start = occurrences[0].start()
    next_h2 = re.search(r"(?m)^##\s+", structure[occurrences[0].end() :])
    end = occurrences[0].end() + next_h2.start() if next_h2 else len(text)
    prefix = text[:start].rstrip()
    suffix = text[end:].lstrip()
    return f"{prefix}\n\n{suffix}" if suffix else f"{prefix}\n"


def strip_lifecycle(text: str) -> str:
    result = text
    for heading in ("## Workflow State", "## Execution Result"):
        result = remove_section(result, heading)
    return result


def normalize_status(text: str) -> str:
    metadata = opening_metadata(text)
    matches = list(re.finditer(r"\*\*Status:\*\*\s*[A-Z_]+", metadata))
    if len(matches) != 1:
        raise ValidationError("METADATA_DUPLICATE", "Expected exactly one canonical Status field.")
    match = matches[0]
    return text[: match.start()] + "**Status:** {status}" + text[match.end() :]


def validate_standalone_lifecycle(text: str, status_value: str, detached: bool) -> None:
    workflow_state = section(text, "## Workflow State")
    execution_result = section(text, "## Execution Result")
    if status_value == "DONE":
        if not workflow_state or not execution_result:
            raise ValidationError(
                "ARCHIVE_LIFECYCLE_INVALID",
                "A DONE standalone archive requires non-empty Workflow State and Execution Result sections.",
            )
        stage = workflow_field(workflow_state, "Stage")
        if stage not in {"COMPLETE", "PUBLISHED_BLOCKED"}:
            raise ValidationError(
                "ARCHIVE_LIFECYCLE_INVALID",
                "A DONE standalone archive requires a terminal workflow stage.",
                {"stage": stage},
            )
        return
    if execution_result is not None:
        raise ValidationError(
            "ARCHIVE_LIFECYCLE_INVALID",
            "A nonterminal standalone archive cannot contain an Execution Result.",
            {"status": status_value},
        )
    if status_value in {"DRIFTED", "STALE", "MISSING", "SUPERSEDED"} and workflow_state is not None:
        raise ValidationError(
            "ARCHIVE_LIFECYCLE_INVALID",
            "This standalone archive status cannot carry workflow state.",
            {"status": status_value},
        )
    if status_value == "BLOCKED" and not detached:
        raise ValidationError("ARCHIVE_LIFECYCLE_INVALID", "Only a detached generated archive may remain BLOCKED.")


def validate_attachment(context: GitContext, state: InputState, metadata: PlanMetadata, text: str) -> ValidatedInput:
    if section(text, "## Workflow State") is not None or section(text, "## Execution Result") is not None:
        raise ValidationError("ATTACHMENT_LIFECYCLE_PRESENT", "Direct attachment intake cannot adopt workflow state.")
    detached = metadata.execution_label.startswith("W")
    if detached:
        if metadata.status == "BLOCKED" and not metadata.blocked_by:
            raise ValidationError("BLOCKED_WITHOUT_PREREQUISITE", "A blocked detached plan must name a prerequisite.")
        if metadata.status not in {"TODO", "READY", "BLOCKED", "DRIFTED", "STALE"}:
            raise ValidationError("STATUS_NOT_IMPLEMENTATION_READY", "Attachment status is not valid for intake.")
    elif metadata.status not in {"TODO", "READY", "DRIFTED", "STALE"}:
        raise ValidationError(
            "STATUS_NOT_IMPLEMENTATION_READY",
            "Independent attachment status must be TODO, READY, DRIFTED, or STALE.",
        )
    if not detached and (metadata.blocked_by or metadata.blocks or metadata.parallel):
        raise ValidationError(
            "INDEPENDENT_ATTACHMENT_DEPENDENCY", "Independent attachments cannot declare plan-set dependencies."
        )
    prerequisite_evidence = parse_prerequisite_evidence(context, text, metadata.blocked_by) if detached else []
    source_oid = hash_file(context, state.absolute_path)
    plan_set_id = standalone_manifest(context, metadata.selected_basename, source_oid)
    archive = context.repo_root / ".context" / "code-plan-to-pr" / plan_set_id / "plans"
    if archive.exists():
        raise ValidationError(
            "ARCHIVE_ALREADY_EXISTS",
            "This attachment already has a normalized archive; use the archived plan.",
            {"archived_plan": f"{archive.relative_to(context.repo_root).as_posix()}/{metadata.selected_basename}"},
        )
    return ValidatedInput(
        plan_set_id=plan_set_id,
        scope_mode="exact-files",
        standalone=True,
        detached=detached,
        source_oid=source_oid,
        index_row=None,
        prerequisite_records=(),
        prerequisite_evidence=tuple(prerequisite_evidence),
    )


def validate_archive(context: GitContext, state: InputState, metadata: PlanMetadata, text: str) -> ValidatedInput:
    assert state.plan_set_id is not None
    archive = state.absolute_path.parent
    index_path = archive / "PR_PLAN_INDEX.md"
    rejection_path = archive / "PR_PLAN_REJECTIONS.md"
    source_path = archive / "ATTACHMENT_SOURCE.md"
    require_regular_file(index_path, "INDEX_MISSING")
    index_text = read_utf8(index_path)
    require_regular_file(rejection_path, "ARCHIVE_REJECTIONS_MISSING")
    rejection_text = read_utf8(rejection_path)
    rows = parse_index_rows(index_text)
    matching = [row for row in rows if row.filename == metadata.selected_basename]
    if len(matching) != 1:
        raise ValidationError("INDEX_PLAN_MISMATCH", "Selected archived plan must appear exactly once in the index.")
    row = matching[0]
    if row.label != metadata.execution_label:
        raise ValidationError("INDEX_PLAN_MISMATCH", "Archived plan and index execution labels disagree.")
    workflow_present = (
        section(text, "## Workflow State") is not None or section(text, "## Execution Result") is not None
    )
    status_repair_required = row.status != metadata.status
    if status_repair_required:
        if workflow_present or row.status not in ALL_STATUSES or metadata.status not in ALL_STATUSES:
            raise ValidationError("INDEX_PLAN_MISMATCH", "Archived plan and index statuses disagree.")
    validate_index_dependencies(row, metadata, rows)

    standalone_evidence = (
        "**Input mode:** standalone attachment" in index_text
        or "**Input mode:** standalone attachment" in rejection_text
        or "**Attachment contract:**" in index_text
        or os.path.lexists(source_path)
        or not metadata.execution_label.startswith("W")
    )
    if not standalone_evidence:
        if ROOT_PLAN_RE.fullmatch(metadata.selected_basename) is None:
            raise ValidationError("ARCHIVE_KIND_INVALID", "Complete generated archive requires a W##L plan filename.")
        implementation_files = sorted(path.name for path in archive.glob("PR_PLAN_W[0-9][0-9][A-Z]_*.md"))
        indexed_files = sorted(index_row.filename for index_row in rows)
        if implementation_files != indexed_files:
            raise ValidationError(
                "ARCHIVE_INVENTORY_MISMATCH",
                "Generated archive plan inventory does not match its index.",
                {"files": implementation_files, "index": indexed_files},
            )
        prerequisite_records = (
            []
            if row.status in RECOVERY_STATUSES
            else validate_complete_set_prerequisites(archive, metadata, rows, "archived")
        )
        validate_complete_set_rows(archive, rows, "archived")
        generated_scope_mode = classify_scope_contracts(
            [index_path, *(archive / filename for filename in implementation_files)], "Generated archive"
        )
        if status_repair_required:
            raise ValidationError(
                "STATUS_REPAIR_REQUIRED",
                "Archived plan has a verified status-only mismatch; skill-owned atomic repair is required.",
                {"verified": True, "plan_status": metadata.status, "index_status": row.status},
            )
        return ValidatedInput(
            plan_set_id=state.plan_set_id,
            scope_mode=generated_scope_mode,
            standalone=False,
            detached=False,
            source_oid=None,
            index_row=row,
            prerequisite_records=tuple(prerequisite_records),
            prerequisite_evidence=(),
        )
    input_markers = index_text.count("**Input mode:** standalone attachment")
    if input_markers != 1:
        raise ValidationError(
            "ARCHIVE_INPUT_MARKER_INVALID", "Standalone archive requires exactly one input-mode marker."
        )
    detached = metadata.execution_label.startswith("W")
    contract_values = re.findall(
        r"\*\*Attachment contract:\*\*\s*([^*\n]+?)(?=\s+\*\*|$)", opening_metadata(index_text)
    )
    legacy_migration = not contract_values and not detached
    if len(contract_values) > 1 or (not contract_values and detached):
        raise ValidationError(
            "ARCHIVE_CONTRACT_INVALID",
            "Standalone archive attachment-contract metadata is missing, duplicated, or contradictory.",
        )
    expected_contract = "detached generated plan" if detached else "independent plan"
    if contract_values and contract_values[0].strip() != expected_contract:
        raise ValidationError("ARCHIVE_CONTRACT_INVALID", "Attachment contract does not match the plan identity.")
    source_values = re.findall(r"\*\*Source object:\*\*\s*`([0-9a-f]+)`", opening_metadata(index_text))
    if len(source_values) != 1 or not context.oid_is_full(source_values[0]):
        raise ValidationError("ARCHIVE_SOURCE_ID_INVALID", "Archive index requires one full source object ID.")
    if index_text.count("**Source snapshot:** `ATTACHMENT_SOURCE.md`") != 1:
        raise ValidationError(
            "ARCHIVE_SOURCE_SNAPSHOT_INVALID", "Archive index source snapshot is missing or duplicated."
        )
    require_regular_file(source_path, "ARCHIVE_SOURCE_MISSING")
    source_text = read_utf8(source_path)
    source_oid = hash_file(context, source_path)
    if source_oid != source_values[0]:
        raise ValidationError(
            "ARCHIVE_SOURCE_HASH_MISMATCH", "Immutable archive source does not match its recorded object ID."
        )
    recomputed_id = standalone_manifest(context, metadata.selected_basename, source_oid)
    if recomputed_id != state.plan_set_id:
        raise ValidationError("ARCHIVE_ID_MISMATCH", "Archive path does not match immutable source identity.")
    plans = list(archive.glob("PR_PLAN_[A-Z][0-9][0-9][A-Z]_*.md"))
    if len(rows) != 1 or len(plans) != 1 or plans[0].name != metadata.selected_basename:
        raise ValidationError(
            "ARCHIVE_INVENTORY_MISMATCH", "Standalone archive must contain exactly one indexed implementation plan."
        )
    if rejection_text.count("**Input mode:** standalone attachment") != 1:
        raise ValidationError("ARCHIVE_REJECTIONS_INVALID", "Standalone rejection record has an invalid input marker.")
    validate_standalone_lifecycle(text, row.status if status_repair_required else metadata.status, detached)
    if normalize_status(strip_lifecycle(text)) != normalize_status(source_text):
        raise ValidationError(
            "ARCHIVE_SOURCE_DIVERGED", "Mutable archived plan contains changes outside lifecycle-owned fields."
        )
    if not detached and (metadata.blocked_by or metadata.blocks or metadata.parallel):
        raise ValidationError(
            "INDEPENDENT_ATTACHMENT_DEPENDENCY", "Independent archive cannot declare plan-set dependencies."
        )
    prerequisite_evidence = parse_prerequisite_evidence(context, text, metadata.blocked_by) if detached else []
    if status_repair_required:
        raise ValidationError(
            "STATUS_REPAIR_REQUIRED",
            "Archived plan has a verified status-only mismatch; skill-owned atomic repair is required.",
            {"verified": True, "plan_status": metadata.status, "index_status": row.status},
        )
    if legacy_migration:
        raise ValidationError(
            "ARCHIVE_MIGRATION_REQUIRED",
            "Legacy independent archive passed read-only proofs and requires skill-owned index migration.",
            {"verified": True, "index_path": index_path.relative_to(context.repo_root).as_posix()},
        )
    return ValidatedInput(
        plan_set_id=state.plan_set_id,
        scope_mode="exact-files",
        standalone=True,
        detached=detached,
        source_oid=source_oid,
        index_row=row,
        prerequisite_records=(),
        prerequisite_evidence=tuple(prerequisite_evidence),
    )


def resolve_planned_at(context: GitContext, planned_at: str) -> str:
    resolved = git_text(context, ["rev-parse", "--verify", f"{planned_at}^{{commit}}"])
    if not context.oid_is_full(resolved):
        raise ValidationError("PLANNED_AT_INVALID", "Planned-at value does not resolve to a full commit ID.")
    return resolved


def require_planned_at_ancestor(context: GitContext, planned_commit: str) -> None:
    ancestor = git_run(context, ["merge-base", "--is-ancestor", planned_commit, "HEAD"], check=False)
    if ancestor.returncode == 1:
        raise ValidationError("PLANNED_AT_NOT_ANCESTOR", "Planned-at commit is not an ancestor of HEAD.")
    if ancestor.returncode != 0:
        diagnostic = ancestor.stderr.decode("utf-8", errors="replace").strip()
        raise ValidationError(
            "GIT_CHECK_FAILED",
            "Git validation failed for merge-base.",
            {"command": "merge-base", "diagnostic": diagnostic[:600]},
        )


def validate_scope(context: GitContext, text: str, scope_mode: str) -> tuple[list[str], list[str]]:
    body = section(text, "### In Scope")
    assert body is not None
    raw_paths = re.findall(r"`([^`]+)`", body)
    if not raw_paths:
        raise ValidationError("SCOPE_EMPTY", "In Scope must contain at least one literal backticked path.")
    paths: list[str] = []
    seen: set[str] = set()
    for raw_path in raw_paths:
        normalized, resolved = normalize_repository_path(context, raw_path, "SCOPE_PATH_INVALID")
        if normalized in seen:
            raise ValidationError(
                "SCOPE_PATH_DUPLICATE", "Scope contains duplicate normalized paths.", {"path": normalized}
            )
        seen.add(normalized)
        if scope_mode == "exact-files" and resolved.is_dir():
            raise ValidationError(
                "SCOPE_DIRECTORY_INVALID", "Exact-file scope cannot name an existing directory.", {"path": normalized}
            )
        paths.append(normalized)

    if scope_mode == "exact-files":
        ignored = git_run(
            context,
            ["check-ignore", "--index", "-z", "--stdin"],
            input_bytes=b"\0".join(p.encode() for p in paths) + b"\0",
            check=False,
        )
        if ignored.returncode == 0:
            ignored_paths = [item.decode() for item in ignored.stdout.split(b"\0") if item]
            unexpected = [path for path in ignored_paths if path not in seen]
            if unexpected:
                raise ValidationError("CHECK_IGNORE_OUTPUT_INVALID", "git check-ignore returned an unvalidated path.")
            raise ValidationError("SCOPE_PATH_IGNORED", "An exact scope path is ignored.", {"path": ignored_paths[0]})
        if ignored.returncode != 1:
            diagnostic = ignored.stderr.decode("utf-8", errors="replace").strip()
            raise ValidationError(
                "CHECK_IGNORE_FAILED",
                "git check-ignore failed while validating scope paths.",
                {"command": "check-ignore", "returncode": ignored.returncode, "diagnostic": diagnostic[:600]},
            )
    return paths, [f":(literal){path}" for path in paths]


def derive_branch(plan_set_id: str, metadata: PlanMetadata) -> str:
    match = ARCHIVE_PLAN_RE.fullmatch(metadata.selected_basename)
    assert match is not None
    suffix = match.group(2).lower()
    slug = re.sub(r"[^a-z0-9]+", "-", suffix).strip("-")[:48].rstrip("-")
    branch = f"plan/{plan_set_id[3:19]}-{metadata.execution_label.lower()}-{slug}"
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", branch) or branch.startswith("-"):
        raise ValidationError("BRANCH_INVALID", "Derived plan branch is invalid.")
    return branch


def sequencing_summary(metadata: PlanMetadata) -> str:
    relationships: list[str] = []
    if metadata.blocked_by:
        relationships.append(f"after {', '.join(metadata.blocked_by)}")
    if metadata.blocks:
        relationships.append(f"blocks {', '.join(metadata.blocks)}")
    if metadata.parallel:
        relationships.append(f"parallel with {', '.join(metadata.parallel)}")
    return "; ".join(relationships) if relationships else "none"


def workflow_field(block: str, name: str) -> str | None:
    pattern = rf"(?m)^- \*\*{re.escape(name)}:\*\*\s*([^\n]+?)\s*$"
    matches: list[str] = re.findall(pattern, block)
    if len(matches) != 1:
        return None
    value = matches[0].strip()
    if name != "Scope paths" and value.startswith("`") and value.endswith("`") and value.count("`") == 2:
        return value[1:-1]
    return value


def validate_checkpoint(
    context: GitContext,
    state: InputState,
    text: str,
    metadata: PlanMetadata,
    plan_set_id: str,
    branch: str,
    scope_mode: str,
    scope_paths: list[str],
) -> tuple[bool, dict[str, object] | None]:
    block = section(text, "## Workflow State")
    if block is None:
        return False, None
    if state.mode != "archived":
        raise ValidationError("CHECKPOINT_LOCATION_INVALID", "Workflow checkpoints are valid only in archived plans.")
    values = {field: workflow_field(block, field) for field in CHECKPOINT_FIELDS}
    missing = [field for field, value in values.items() if value is None]
    if missing:
        raise ValidationError(
            "CHECKPOINT_PARTIAL", "Workflow checkpoint is missing required fields.", {"missing": missing}
        )
    stage = values["Stage"]
    base = values["Base commit"]
    head = values["Checkpoint head"]
    tree = values["Checkpoint tree"]
    recorded_scope = re.findall(r"`([^`]+)`", values["Scope paths"] or "")
    assert stage is not None and base is not None and head is not None and tree is not None
    if stage not in {"IMPLEMENTED", "QUALITY_BLOCKED"}:
        raise ValidationError("CHECKPOINT_STAGE_INVALID", "Checkpoint stage must be IMPLEMENTED or QUALITY_BLOCKED.")
    comparisons = {
        "Plan set": plan_set_id,
        "Plan": metadata.selected_basename,
        "Branch": branch,
    }
    for field, expected in comparisons.items():
        if values[field] != expected:
            raise ValidationError("CHECKPOINT_IDENTITY_MISMATCH", f"Checkpoint {field} does not match validated state.")
    if metadata.status not in {"TODO", "READY", "IN_PROGRESS", "BLOCKED"}:
        raise ValidationError("CHECKPOINT_STATUS_INVALID", "Checkpoint requires an accepted nonterminal plan status.")
    if not all(context.oid_is_full(value) for value in (base, head, tree)):
        raise ValidationError("CHECKPOINT_OID_INVALID", "Checkpoint object IDs must be full lowercase IDs.")
    if recorded_scope != scope_paths:
        raise ValidationError("CHECKPOINT_SCOPE_MISMATCH", "Checkpoint scope does not match validated plan scope.")
    resolved_base = git_text(context, ["rev-parse", "--verify", f"{base}^{{commit}}"])
    resolved_head = git_text(context, ["rev-parse", "--verify", f"{head}^{{commit}}"])
    if resolved_base != base or resolved_head != head:
        raise ValidationError("CHECKPOINT_OID_MISMATCH", "Checkpoint commit IDs do not resolve exactly.")
    if git_text(context, ["rev-parse", f"{head}^{{tree}}"]) != tree:
        raise ValidationError("CHECKPOINT_TREE_MISMATCH", "Checkpoint tree does not match checkpoint head.")
    ancestry = git_run(context, ["merge-base", "--is-ancestor", base, head], check=False)
    if ancestry.returncode == 1:
        raise ValidationError("CHECKPOINT_BASE_INVALID", "Checkpoint base is not an ancestor of checkpoint head.")
    if ancestry.returncode != 0:
        diagnostic = ancestry.stderr.decode("utf-8", errors="replace").strip()
        raise ValidationError(
            "GIT_CHECK_FAILED",
            "Git validation failed for merge-base.",
            {"command": "merge-base", "diagnostic": diagnostic[:600]},
        )
    branch_tip = git_text(context, ["rev-parse", "--verify", f"refs/heads/{branch}^{{commit}}"])
    if branch_tip != head:
        raise ValidationError("CHECKPOINT_BRANCH_MISMATCH", "Derived local branch tip does not match checkpoint head.")
    committed = git_text(context, ["diff", "--name-only", f"{base}..{head}"])
    committed_paths = committed.splitlines() if committed else []
    exact_mismatch = scope_mode == "exact-files" and committed_paths != sorted(scope_paths)
    containment_mismatch = scope_mode == "containment" and (
        not committed_paths
        or any(
            not any(path == allowed or path.startswith(f"{allowed.rstrip('/')}/") for allowed in scope_paths)
            for path in committed_paths
        )
    )
    if exact_mismatch or containment_mismatch:
        raise ValidationError(
            "CHECKPOINT_COMMITTED_SCOPE_MISMATCH",
            "Checkpoint committed paths do not match the validated scope mode.",
            {
                "committed_paths": committed_paths,
                "scope_mode": scope_mode,
                "scope_paths": sorted(scope_paths),
            },
        )
    return True, {"verified": True, "stage": stage, "base_commit": base, "head": head, "tree": tree}


def validate_drift(context: GitContext, planned_commit: str, git_paths: list[str]) -> None:
    worktree = git_text(context, ["status", "--short", "--", *git_paths])
    if worktree:
        raise ValidationError(
            "WORKTREE_DRIFT", "In-scope staged, unstaged, or untracked drift is present.", {"status": worktree}
        )
    committed = git_text(context, ["diff", "--stat", planned_commit, "--", *git_paths])
    if committed:
        raise ValidationError(
            "COMMITTED_DRIFT", "Committed in-scope drift is present since Planned at.", {"stat": committed}
        )


def validate(args: argparse.Namespace) -> dict[str, object]:
    context = build_git_context(str(args.repo_root))
    state = classify_input(context, str(args.plan))
    text = read_utf8(state.absolute_path)
    metadata = parse_metadata(text, state.mode, state.absolute_path.name)
    validate_body(text)

    if state.mode == "root":
        validated = root_plan_identity(context, metadata)
    elif state.mode == "attachment":
        validated = validate_attachment(context, state, metadata, text)
    else:
        validated = validate_archive(context, state, metadata, text)
    plan_set_id = validated.plan_set_id
    scope_mode = validated.scope_mode
    standalone = validated.standalone
    detached = validated.detached
    source_oid = validated.source_oid
    index_row = validated.index_row
    prerequisite_records = validated.prerequisite_records
    prerequisite_evidence = validated.prerequisite_evidence
    archive_source_verified = state.mode == "archived" and source_oid is not None

    planned_commit = resolve_planned_at(context, metadata.planned_at)
    scope_paths, git_paths = validate_scope(context, text, scope_mode)
    branch = derive_branch(plan_set_id, metadata)
    terminal_retry_required = metadata.status == "DONE"
    terminal_execution_result = section(text, "## Execution Result") if terminal_retry_required else None
    if terminal_retry_required and not terminal_execution_result:
        raise ValidationError("TERMINAL_RESULT_MISSING", "A DONE plan requires one non-empty Execution Result.")
    if terminal_retry_required:
        completion_resume, checkpoint = False, None
    else:
        completion_resume, checkpoint = validate_checkpoint(
            context, state, text, metadata, plan_set_id, branch, scope_mode, scope_paths
        )
    detached_recovery_required = (
        state.mode == "archived"
        and standalone
        and detached
        and metadata.status == "IN_PROGRESS"
        and not completion_resume
    )
    lifecycle_recovery = metadata.status in RECOVERY_STATUSES
    if not completion_resume and not terminal_retry_required and not lifecycle_recovery:
        require_planned_at_ancestor(context, planned_commit)
    if terminal_retry_required:
        drift_check_reason = "terminal-retry"
    elif completion_resume:
        drift_check_reason = "checkpoint-resume"
    elif lifecycle_recovery:
        drift_check_reason = "lifecycle-recovery"
    elif args.allow_worktree_drift:
        if state.mode != "archived" or metadata.status != "IN_PROGRESS":
            raise ValidationError(
                "ARGUMENT_INVALID",
                "--allow-worktree-drift is valid only for archived IN_PROGRESS staging revalidation.",
            )
        drift_check_reason = "implementation-drift-bypass"
    elif detached_recovery_required:
        drift_check_reason = "detached-recovery"
    else:
        drift_check_reason = "checked"
    if drift_check_reason == "checked":
        try:
            validate_drift(context, planned_commit, git_paths)
        except ValidationError as exc:
            exc.details.update(
                {
                    "plan_input_mode": state.mode,
                    "standalone_attachment": standalone,
                    "selected_basename": metadata.selected_basename,
                }
            )
            raise

    plan_set_root = f".context/code-plan-to-pr/{plan_set_id}/plans"
    facts: dict[str, object] = {
        "archive_source_verified": archive_source_verified,
        "checkpoint": checkpoint,
        "completion_resume": completion_resume,
        "detached_generated_plan": detached,
        "detached_recovery_required": detached_recovery_required,
        "drift_check_reason": drift_check_reason,
        "drift_check_skipped": drift_check_reason != "checked",
        "execution_label": metadata.execution_label,
        "git_paths": git_paths,
        "index_status": index_row.status if index_row else None,
        "plan_branch": branch,
        "plan_input_mode": state.mode,
        "plan_path": state.relative_path,
        "plan_set_id": plan_set_id,
        "plan_set_root": plan_set_root,
        "plan_set_short": plan_set_id[3:19],
        "plan_status": metadata.status,
        "plan_impact": metadata.impact,
        "plan_leverage": metadata.leverage,
        "planned_at": metadata.planned_at,
        "planned_commit": planned_commit,
        "scope_mode": scope_mode,
        "scope_paths": scope_paths,
        "selected_basename": metadata.selected_basename,
        "source_object_id": source_oid,
        "standalone_attachment": standalone,
        "attachment_contract": (
            "detached generated plan" if standalone and detached else "independent plan" if standalone else None
        ),
        "sequencing_summary": sequencing_summary(metadata),
        "strict_review": bool(args.strict),
        "ship_mode": bool(args.ship),
        "terminal_retry_required": terminal_retry_required,
        "terminal_execution_result": terminal_execution_result,
        "prerequisites": list(metadata.blocked_by),
        "prerequisite_records": [record.as_json() for record in prerequisite_records],
        "prerequisite_evidence": [record.as_json() for record in prerequisite_evidence],
        "dependents": list(metadata.blocks),
        "parallel_peers": list(metadata.parallel),
    }
    return {"ok": True, "schema_version": SCHEMA_VERSION, "facts": facts}


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = JsonArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, help="Canonical repository root.")
    parser.add_argument("--strict", action="store_true", help="Report strict review mode.")
    parser.add_argument("--ship", action="store_true", help="Report shipping mode.")
    parser.add_argument(
        "--allow-worktree-drift",
        action="store_true",
        help="Skip only planned-at/worktree drift checks while revalidating scope eligibility.",
    )
    parser.add_argument("plan", help="Root, attachment, or archived plan path.")
    return parser.parse_args(argv)


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def main(argv: Sequence[str] | None = None) -> int:
    try:
        args = parse_args(sys.argv[1:] if argv is None else argv)
        emit(validate(args))
        return 0
    except ValidationError as exc:
        emit(
            {
                "ok": False,
                "schema_version": SCHEMA_VERSION,
                "error": {"code": exc.code, "message": exc.message, "details": exc.details},
            }
        )
        return 2
    except (OSError, UnicodeError, subprocess.SubprocessError) as exc:
        emit(
            {
                "ok": False,
                "schema_version": SCHEMA_VERSION,
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "Validator could not complete a read-only check.",
                    "details": {"type": type(exc).__name__},
                },
            }
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
