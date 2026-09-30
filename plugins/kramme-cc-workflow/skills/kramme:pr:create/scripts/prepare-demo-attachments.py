#!/usr/bin/env python3
"""Validate demo-reel output before gh uploads it with a Pull Request."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


IMAGE_LIMIT = 10 * 1024 * 1024
VIDEO_LIMIT = 100 * 1024 * 1024
IMAGE_EXTENSIONS = {".gif", ".jpeg", ".jpg", ".png", ".svg", ".webp"}
VIDEO_EXTENSIONS = {".mov", ".mp4", ".webm"}


class ManifestError(ValueError):
    """Raised when captured evidence cannot safely become gh arguments."""


def require_plain_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"{field} must be a non-empty string")
    if "\x00" in value or "\n" in value or "\r" in value:
        raise ManifestError(f"{field} must be a single line")
    return value.strip()


def require_direct_path(path: Path, boundary: Path, field: str) -> Path:
    candidate = path if path.is_absolute() else boundary / path
    candidate = Path(os.path.abspath(candidate))
    try:
        candidate.relative_to(boundary)
    except ValueError as exc:
        raise ManifestError(f"{field} must stay below {boundary}") from exc

    current = candidate
    while current != boundary:
        if current.is_symlink():
            raise ManifestError(f"{field} must not traverse a symlink")
        current = current.parent
    if boundary.is_symlink():
        raise ManifestError(f"{field} boundary must not be a symlink")
    return candidate


def prepare(repo_root_arg: str, manifest_arg: str) -> dict[str, Any]:
    repo_root = Path(repo_root_arg).expanduser().resolve(strict=True)
    if not repo_root.is_dir():
        raise ManifestError("repo root must be a directory")

    evidence_root = require_direct_path(repo_root / ".context" / "demo-reels", repo_root, "evidence root")
    manifest_path = require_direct_path(Path(manifest_arg).expanduser(), evidence_root, "manifest")
    if manifest_path.name != "manifest.json":
        raise ManifestError("manifest must be named manifest.json")
    if not manifest_path.is_file() or manifest_path.is_symlink():
        raise ManifestError("manifest must be a direct regular file")

    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ManifestError(f"manifest is not readable JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ManifestError("manifest root must be an object")
    if payload.get("schema_version") != 1:
        raise ManifestError("manifest schema_version must be 1")

    tier = require_plain_string(payload.get("tier"), "tier")
    if tier not in {"static", "before-after", "browser-reel", "terminal-recording"}:
        raise ManifestError("manifest tier is not attachable")
    description = require_plain_string(payload.get("description"), "description")

    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise ManifestError("manifest artifacts must be a non-empty array")
    if len(artifacts) > 50:
        raise ManifestError("manifest exceeds gh's 50-file attachment limit")

    run_dir = manifest_path.parent
    attachments: list[dict[str, str]] = []
    seen_file_ids: set[tuple[int, int]] = set()
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            raise ManifestError(f"artifacts[{index}] must be an object")
        artifact_path_text = require_plain_string(artifact.get("path"), f"artifacts[{index}].path")
        if "#" in artifact_path_text:
            raise ManifestError(f"artifacts[{index}].path must not contain #")
        artifact_path = require_direct_path(Path(artifact_path_text), run_dir, f"artifacts[{index}].path")
        if not artifact_path.is_file() or artifact_path.is_symlink():
            raise ManifestError(f"artifacts[{index}].path must be a direct regular file")

        artifact_stat = artifact_path.stat()
        file_id = (artifact_stat.st_dev, artifact_stat.st_ino)
        if file_id in seen_file_ids:
            raise ManifestError(f"artifacts[{index}].path refers to a duplicated file")
        seen_file_ids.add(file_id)

        size = artifact_stat.st_size
        if size == 0:
            raise ManifestError(f"artifacts[{index}].path is empty")
        extension = artifact_path.suffix.lower()
        if extension in IMAGE_EXTENSIONS:
            kind = "image"
            limit = IMAGE_LIMIT
        elif extension in VIDEO_EXTENSIONS:
            kind = "video"
            limit = VIDEO_LIMIT
        else:
            raise ManifestError(f"artifacts[{index}].path has an unsupported file type")
        if size > limit:
            raise ManifestError(f"artifacts[{index}].path exceeds the {kind} size limit")
        if artifact.get("kind") != kind:
            raise ManifestError(f"artifacts[{index}].kind must be {kind}")

        artifact_description = require_plain_string(artifact.get("description"), f"artifacts[{index}].description")
        flag_value = str(artifact_path)
        if kind == "image":
            flag_value = f"{flag_value}#{artifact_description}"
        attachments.append(
            {
                "path": str(artifact_path),
                "kind": kind,
                "description": artifact_description,
                "flag_value": flag_value,
            }
        )

    return {
        "schema_version": 1,
        "manifest": str(manifest_path),
        "tier": tier,
        "description": description,
        "attachments": attachments,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--format", choices=("json", "nul"), default="json")
    args = parser.parse_args()
    try:
        result = prepare(args.repo_root, args.manifest)
    except (ManifestError, OSError) as exc:
        print(f"demo attachment validation failed: {exc}", file=sys.stderr)
        return 1
    if args.format == "nul":
        for attachment in result["attachments"]:
            sys.stdout.buffer.write(attachment["flag_value"].encode("utf-8") + b"\0")
    else:
        print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
