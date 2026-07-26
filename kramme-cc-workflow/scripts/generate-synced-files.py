#!/usr/bin/env python3
"""Check or synchronize canonical file-identity groups.

Every registered group declares one explicit canonical path and two or more
paths whose bytes and permission bits must match. Checks are read-only by
default. Pass --write to update declared mirrors from their canonical source.
"""

from __future__ import annotations

import argparse
import stat
import tempfile
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from json_object import load_json_object


@dataclass(frozen=True)
class IdentityGroup:
    name: str
    canonical: str
    paths: tuple[str, ...]

    @property
    def mirrors(self) -> tuple[str, ...]:
        return tuple(path for path in self.paths if path != self.canonical)


@dataclass(frozen=True)
class ValidatedPath:
    relative: str
    absolute: Path
    exists: bool


@dataclass(frozen=True)
class SyncAction:
    group: str
    target: str
    target_path: Path
    source_bytes: bytes
    source_mode: int
    reason: str


@dataclass(frozen=True)
class OutputStyle:
    description: str
    success_subject: str
    failure_subject: str
    synced_label: str
    command: str
    no_groups_message: str


GENERIC_OUTPUT = OutputStyle(
    description="Check or sync declared file mirrors from explicit canonical sources",
    success_subject="declared file mirrors",
    failure_subject="synced file sync",
    synced_label="file mirror(s)",
    command="scripts/generate-synced-files.py",
    no_groups_message="no file identity groups found in registry",
)


def parse_cli(
    argv: Sequence[str] | None = None,
    *,
    output: OutputStyle = GENERIC_OUTPUT,
) -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=output.description)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=script_dir.parent.parent,
        help="Repository root. Defaults to two directories above this script.",
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=script_dir / "synced-contracts.yaml",
        help="Path to synced-contracts.yaml.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="Check mirrors without writing. This is the default.",
    )
    mode.add_argument(
        "--write",
        action="store_true",
        help="Write canonical bytes and modes to out-of-sync mirrors.",
    )
    return parser.parse_args(argv)


def load_registry(path: Path) -> dict[str, Any]:
    return load_json_object(path, "registry")


def parse_identity_groups(
    registry: dict[str, Any],
    *,
    group_prefix: str | None = None,
) -> tuple[list[IdentityGroup], list[str]]:
    raw_groups = registry.get("file_identity_groups")
    if not isinstance(raw_groups, list):
        return [], ["file_identity_groups must be an array"]

    selected: list[tuple[int, object]] = []
    for index, raw_group in enumerate(raw_groups):
        if group_prefix is None:
            selected.append((index, raw_group))
            continue
        if not isinstance(raw_group, dict):
            continue
        name = raw_group.get("name")
        if isinstance(name, str) and name.startswith(group_prefix):
            selected.append((index, raw_group))

    groups: list[IdentityGroup] = []
    failures: list[str] = []
    seen_names: set[str] = set()
    seen_paths: dict[str, str] = {}
    for index, raw_group in selected:
        label = f"file_identity_groups[{index}]"
        if not isinstance(raw_group, dict):
            failures.append(f"{label}: group must be an object")
            continue

        name = raw_group.get("name")
        if not isinstance(name, str) or not name:
            failures.append(f"{label}: name must be a non-empty string")
            continue
        if name in seen_names:
            failures.append(f"{name}: group name must be unique")
        seen_names.add(name)

        canonical = raw_group.get("canonical")
        paths_value = raw_group.get("paths")
        group_failures: list[str] = []
        if not isinstance(canonical, str) or not canonical:
            group_failures.append(f"{name}: canonical must be a non-empty string")
        if not isinstance(paths_value, list) or len(paths_value) < 2:
            group_failures.append(f"{name}: paths must be an array with at least two entries")
            paths: tuple[str, ...] = ()
        elif not all(isinstance(path, str) and path for path in paths_value):
            group_failures.append(f"{name}: paths must contain only non-empty strings")
            paths = ()
        else:
            paths = tuple(paths_value)
            if len(set(paths)) != len(paths):
                group_failures.append(f"{name}: paths must not contain duplicates")

        if isinstance(canonical, str) and canonical and paths.count(canonical) != 1:
            group_failures.append(
                f"{name}: canonical path must appear exactly once in paths"
            )
        if not group_failures:
            for path in paths:
                normalized = str(Path(path))
                owner = seen_paths.get(normalized)
                if owner is not None:
                    group_failures.append(
                        f"{name}: path {path} is already registered in group {owner}"
                    )

        failures.extend(group_failures)
        if not group_failures and isinstance(canonical, str):
            groups.append(IdentityGroup(name=name, canonical=canonical, paths=paths))
            seen_paths.update((str(Path(path)), name) for path in paths)

    return groups, failures


def is_within_root(root: Path, path: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def validate_registered_path(
    root: Path,
    group: str,
    relative: str,
    *,
    canonical: bool,
) -> tuple[ValidatedPath | None, list[str]]:
    failures: list[str] = []
    lexical = Path(relative)
    if lexical.is_absolute():
        return None, [f"{group}: absolute paths are not allowed: {relative}"]
    if ".." in lexical.parts:
        return None, [f"{group}: parent traversal is not allowed: {relative}"]

    candidate = root / lexical
    current = root
    exists = True
    for index, part in enumerate(lexical.parts):
        current /= part
        try:
            metadata = current.lstat()
        except FileNotFoundError:
            exists = False
            break
        except OSError as exc:
            failures.append(f"{group}: cannot inspect registered path {relative}: {exc}")
            return None, failures

        if stat.S_ISLNK(metadata.st_mode):
            failures.append(f"{group}: registered path must not be a symlink: {relative}")
            return None, failures
        if index < len(lexical.parts) - 1 and not stat.S_ISDIR(metadata.st_mode):
            failures.append(
                f"{group}: registered path ancestor must be a directory: {relative}"
            )
            return None, failures

    try:
        resolved = candidate.resolve(strict=False)
    except (OSError, RuntimeError) as exc:
        failures.append(f"{group}: cannot resolve registered path {relative}: {exc}")
        return None, failures
    if not is_within_root(root, resolved):
        failures.append(f"{group}: registered path resolves outside repo root: {relative}")

    if failures:
        return None, failures
    if not exists:
        if canonical:
            return None, [f"{group}: canonical path is missing: {relative}"]
        return ValidatedPath(relative=relative, absolute=candidate, exists=False), []

    try:
        metadata = candidate.lstat()
    except OSError as exc:
        return None, [f"{group}: cannot inspect registered path {relative}: {exc}"]
    if not stat.S_ISREG(metadata.st_mode):
        return None, [f"{group}: registered path must be a regular file: {relative}"]

    return ValidatedPath(relative=relative, absolute=candidate, exists=True), []


def planned_actions(
    root: Path,
    groups: Sequence[IdentityGroup],
) -> tuple[list[SyncAction], list[str]]:
    actions: list[SyncAction] = []
    failures: list[str] = []

    for group in groups:
        validated: dict[str, ValidatedPath] = {}
        for relative in group.paths:
            path, path_failures = validate_registered_path(
                root,
                group.name,
                relative,
                canonical=relative == group.canonical,
            )
            failures.extend(path_failures)
            if path is not None:
                validated[relative] = path

        if any(relative not in validated for relative in group.paths):
            continue

        source = validated[group.canonical]
        try:
            source_bytes = source.absolute.read_bytes()
            source_mode = stat.S_IMODE(source.absolute.lstat().st_mode)
        except OSError as exc:
            failures.append(
                f"{group.name}: cannot read canonical path {group.canonical}: {exc}"
            )
            continue

        for mirror_relative in group.mirrors:
            mirror = validated[mirror_relative]
            if not mirror.exists:
                actions.append(
                    SyncAction(
                        group=group.name,
                        target=mirror.relative,
                        target_path=mirror.absolute,
                        source_bytes=source_bytes,
                        source_mode=source_mode,
                        reason=f"is missing; canonical {group.canonical}",
                    )
                )
                continue

            try:
                mirror_bytes = mirror.absolute.read_bytes()
                mirror_mode = stat.S_IMODE(mirror.absolute.lstat().st_mode)
            except OSError as exc:
                failures.append(
                    f"{group.name}: cannot read mirror path {mirror.relative}: {exc}"
                )
                continue

            reasons: list[str] = []
            if mirror_bytes != source_bytes:
                reasons.append(f"content differs from canonical {group.canonical}")
            if mirror_mode != source_mode:
                reasons.append(
                    f"mode {mirror_mode:04o} differs from canonical mode {source_mode:04o}"
                )
            if reasons:
                actions.append(
                    SyncAction(
                        group=group.name,
                        target=mirror.relative,
                        target_path=mirror.absolute,
                        source_bytes=source_bytes,
                        source_mode=source_mode,
                        reason="; ".join(reasons),
                    )
                )

    return actions, failures


def write_actions(root: Path, actions: Sequence[SyncAction]) -> list[str]:
    failures: list[str] = []
    for action in actions:
        _, path_failures = validate_registered_path(
            root,
            action.group,
            action.target,
            canonical=False,
        )
        failures.extend(path_failures)
    if failures:
        return failures

    for action in actions:
        temporary_path: Path | None = None
        try:
            action.target_path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                dir=action.target_path.parent,
                prefix=f".{action.target_path.name}.",
                delete=False,
            ) as temporary:
                temporary_path = Path(temporary.name)
                temporary.write(action.source_bytes)
            temporary_path.chmod(action.source_mode)
            temporary_path.replace(action.target_path)
        except OSError as exc:
            failure = f"{action.group}: cannot sync mirror {action.target}: {exc}"
            if temporary_path is not None:
                try:
                    temporary_path.unlink(missing_ok=True)
                except OSError as cleanup_exc:
                    failure += f"; cannot remove temporary file: {cleanup_exc}"
            failures.append(failure)
            break
    return failures


def report_actions(actions: Sequence[SyncAction]) -> None:
    for action in actions:
        print(f"{action.group}: {action.target} {action.reason}")


def report_failures(output: OutputStyle, failures: Sequence[str]) -> None:
    print(f"{output.failure_subject} failed:")
    for failure in failures:
        print(f"::error::{failure}")


def run_cli(
    argv: Sequence[str] | None = None,
    *,
    group_prefix: str | None = None,
    output: OutputStyle = GENERIC_OUTPUT,
) -> int:
    args = parse_cli(argv, output=output)
    root = args.repo_root.resolve()
    if not root.is_dir():
        report_failures(output, [f"repository root is not a directory: {root}"])
        return 1

    registry = load_registry(args.registry.resolve())
    groups, failures = parse_identity_groups(registry, group_prefix=group_prefix)
    if not groups and not failures:
        failures.append(output.no_groups_message)

    actions, path_failures = planned_actions(root, groups)
    failures.extend(path_failures)
    if failures:
        report_failures(output, failures)
        return 1

    if args.write:
        write_failures = write_actions(root, actions)
        if write_failures:
            report_failures(output, write_failures)
            return 1
        if actions:
            report_actions(actions)
            print(f"synced {len(actions)} {output.synced_label}.")
        else:
            print(f"{output.success_subject} are in sync.")
        return 0

    if actions:
        print(f"{output.failure_subject} check failed:")
        report_actions(actions)
        print(f"run {output.command} --write to sync copies")
        return 1

    print(f"{output.success_subject} are in sync.")
    return 0


def main() -> int:
    return run_cli()


if __name__ == "__main__":
    raise SystemExit(main())
