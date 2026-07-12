#!/usr/bin/env python3
"""
Release script for kramme-cc-workflow plugin.

Usage:
    python scripts/release.py patch      # 0.2.0 -> 0.2.1
    python scripts/release.py minor      # 0.2.0 -> 0.3.0
    python scripts/release.py major      # 0.2.0 -> 1.0.0
    python scripts/release.py 1.0.0      # explicit version

Options:
    --dry-run    Show what would be done without making changes
    --ci         Running in CI (skip interactive prompts, no gh release)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from changelog import ChangelogHistoryError, generate_changelog


def get_repo_root() -> Path:
    """Get the plugin root directory (parent of scripts/)."""
    return Path(__file__).resolve().parent.parent


def get_git_root() -> Path:
    """Get the git repository root (parent of plugin root)."""
    return get_repo_root().parent


def get_version_files(repo_root: Path) -> list[Path]:
    """Return versioned JSON files for the main plugin."""
    files = [repo_root / ".claude-plugin" / "plugin.json"]
    package_json = repo_root / "package.json"
    if package_json.exists():
        files.append(package_json)
    return files


def get_sibling_version_files() -> list[Path]:
    """Discover sibling plugin version files from marketplace.json."""
    git_root = get_git_root()
    marketplace_path = git_root / ".claude-plugin" / "marketplace.json"
    if not marketplace_path.exists():
        return []

    with open(marketplace_path) as f:
        marketplace = json.load(f)

    main_plugin_json = get_repo_root() / ".claude-plugin" / "plugin.json"
    sibling_files = []
    for plugin in marketplace.get("plugins", []):
        source = plugin.get("source", ".")
        plugin_json = (git_root / source / ".claude-plugin" / "plugin.json").resolve()
        if plugin_json.exists() and plugin_json.resolve() != main_plugin_json.resolve():
            sibling_files.append(plugin_json)
    return sibling_files


def read_version(path: Path) -> str:
    """Read version from a JSON file."""
    with open(path) as f:
        data = json.load(f)
    return data["version"]


def get_current_version(repo_root: Path) -> str:
    """Read current version, ensuring all version files match."""
    files = get_version_files(repo_root)
    versions = {path: read_version(path) for path in files}
    base_version = next(iter(versions.values()))
    mismatched = {path: version for path, version in versions.items() if version != base_version}
    if mismatched:
        details = ", ".join(f"{path}: {version}" for path, version in mismatched.items())
        raise ValueError(f"Version mismatch detected ({details}).")
    return base_version


def bump_version(current: str, bump_type: str) -> str:
    """Calculate new version based on bump type."""
    # Check if bump_type is an explicit version
    if re.match(r"^\d+\.\d+\.\d+$", bump_type):
        return bump_type

    parts = list(map(int, current.split(".")))
    if len(parts) != 3:
        raise ValueError(f"Invalid version format: {current}")

    major, minor, patch = parts

    if bump_type == "major":
        return f"{major + 1}.0.0"
    elif bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    elif bump_type == "patch":
        return f"{major}.{minor}.{patch + 1}"
    else:
        raise ValueError(f"Invalid bump type: {bump_type}")


def update_version_files(repo_root: Path, new_version: str, dry_run: bool) -> None:
    """Update version in all version files (main plugin + siblings)."""
    all_files = get_version_files(repo_root) + get_sibling_version_files()
    for path in all_files:
        with open(path) as f:
            data = json.load(f)
        data["version"] = new_version

        if dry_run:
            print(f"  Would update {path} to version {new_version}")
        else:
            with open(path, "w") as f:
                json.dump(data, f, indent=2)
                f.write("\n")
            print(f"  Updated {path}")


def get_release_mutation_paths(repo_root: Path) -> list[Path]:
    """Return files the release flow may mutate before verification completes."""
    paths = get_version_files(repo_root) + get_sibling_version_files()
    paths.append(repo_root / "CHANGELOG.md")

    unique_paths = []
    seen = set()
    for path in paths:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        unique_paths.append(path)
    return unique_paths


def snapshot_files(paths: list[Path]) -> dict[Path, bytes | None]:
    """Capture file contents so release mutations can be rolled back on failure."""
    return {path: path.read_bytes() if path.exists() else None for path in paths}


def restore_files(snapshot: dict[Path, bytes | None]) -> None:
    """Restore files captured by snapshot_files."""
    for path, contents in snapshot.items():
        if contents is None:
            if path.exists():
                path.unlink()
            continue

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)


def get_current_git_branch(git_root: Path) -> str | None:
    """Return the current branch name, or None when detached or unavailable."""
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None

    branch = result.stdout.strip()
    if not branch or branch == "HEAD":
        return None
    return branch


def get_current_git_head(git_root: Path) -> str | None:
    """Return the current commit hash, or None when unavailable."""
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "HEAD"],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None

    head = result.stdout.strip()
    return head or None


def get_git_index_path(git_root: Path) -> Path:
    """Return the index path for the current repository or linked worktree."""
    result = subprocess.run(
        ["git", "rev-parse", "--git-path", "index"],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError("Could not locate the Git index before release.")

    raw_path = Path(result.stdout.strip())
    if not raw_path.is_absolute():
        raw_path = git_root / raw_path
    return raw_path.resolve()


def restore_git_index(path: Path, contents: bytes | None, mode: int | None) -> None:
    """Atomically restore the exact captured Git index contents."""
    if contents is None:
        if path.exists():
            path.unlink()
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temporary.write(contents)
        temporary_path = Path(temporary.name)
    try:
        if mode is not None:
            temporary_path.chmod(mode)
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def run_git_recovery_command(git_root: Path, args: list[str]) -> bool:
    """Run one recovery command and report whether Git accepted it."""
    result = subprocess.run(
        ["git", *args],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


@dataclass(frozen=True)
class ReleaseStateSnapshot:
    """Repository state that must be observed after a release rollback."""

    files: dict[Path, bytes | None]
    branch: str | None
    head: str | None
    index_path: Path
    index_contents: bytes | None
    index_mode: int | None


@dataclass(frozen=True)
class RecoveryCommandOutcome:
    """Observed result of a checked, optionally retried recovery command."""

    args: tuple[str, ...]
    attempts: int
    succeeded: bool


@dataclass(frozen=True)
class RollbackResult:
    """Command and final-state evidence for a release rollback."""

    commands: tuple[RecoveryCommandOutcome, ...]
    state_matches: bool

    @property
    def succeeded(self) -> bool:
        return self.state_matches and all(command.succeeded for command in self.commands)


def capture_release_state(repo_root: Path) -> ReleaseStateSnapshot:
    """Capture release files, checkout, HEAD, and the complete Git index."""
    git_root = get_git_root()
    head = get_current_git_head(git_root)
    index_path = get_git_index_path(git_root)

    return ReleaseStateSnapshot(
        files=snapshot_files(get_release_mutation_paths(repo_root)),
        branch=get_current_git_branch(git_root),
        head=head,
        index_path=index_path,
        index_contents=index_path.read_bytes() if index_path.exists() else None,
        index_mode=(stat.S_IMODE(index_path.stat().st_mode) if index_path.exists() else None),
    )


def _retry_recovery_command(git_root: Path, args: list[str]) -> RecoveryCommandOutcome:
    """Retry a checked recovery command once for transient Git failures."""
    if run_git_recovery_command(git_root, args):
        return RecoveryCommandOutcome(tuple(args), attempts=1, succeeded=True)
    return RecoveryCommandOutcome(
        tuple(args),
        attempts=2,
        succeeded=run_git_recovery_command(git_root, args),
    )


def _files_match_snapshot(snapshot: dict[Path, bytes | None]) -> bool:
    for path, expected in snapshot.items():
        if expected is None:
            if path.exists():
                return False
        elif not path.exists() or path.read_bytes() != expected:
            return False
    return True


def _write_recovery_backups(snapshot: dict[Path, bytes | None]) -> dict[Path, Path]:
    """Persist original file bytes so printed manual commands are actionable."""
    backup_root = Path(tempfile.mkdtemp(prefix="release-recovery-"))
    backups = {}
    for index, (path, contents) in enumerate(snapshot.items()):
        if contents is None:
            continue
        backup = backup_root / f"{index}-{path.name}"
        backup.write_bytes(contents)
        backups[path] = backup
    return backups


def _shell_command(parts: list[str | Path]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def print_manual_recovery(git_root: Path, snapshot: ReleaseStateSnapshot) -> None:
    """Print exact, quoted commands that reproduce the captured state."""
    backups = _write_recovery_backups(snapshot.files)
    index_backup = None
    if snapshot.index_contents is not None:
        index_backup = next(iter(backups.values()), None)
        backup_root = (
            index_backup.parent if index_backup is not None else Path(tempfile.mkdtemp(prefix="release-recovery-"))
        )
        index_backup = backup_root / "git-index"
        index_backup.write_bytes(snapshot.index_contents)
    print("  Automatic rollback was incomplete. Run these recovery commands:")
    print("    " + _shell_command(["rm", "-rf", "--", snapshot.index_path]))
    if snapshot.head is not None:
        print("    " + _shell_command(["git", "-C", git_root, "reset", "--mixed", snapshot.head]))
        if snapshot.branch is None:
            checkout = ["git", "-C", git_root, "checkout", "--detach", snapshot.head]
        else:
            checkout = ["git", "-C", git_root, "checkout", snapshot.branch]
        print("    " + _shell_command(checkout))
    if index_backup is None:
        print("    " + _shell_command(["rm", "-f", "--", snapshot.index_path]))
    else:
        print("    " + _shell_command(["cp", "--", index_backup, snapshot.index_path]))
        if snapshot.index_mode is not None:
            print("    " + _shell_command(["chmod", f"{snapshot.index_mode:o}", snapshot.index_path]))
    for path, contents in snapshot.files.items():
        if contents is None:
            print("    " + _shell_command(["rm", "-f", "--", path]))
        else:
            print("    " + _shell_command(["cp", "--", backups[path], path]))


def restore_release_state(
    snapshot: ReleaseStateSnapshot,
) -> RollbackResult:
    """Restore and verify all captured release state after a failure."""
    git_root = get_git_root()
    command_outcomes = []
    file_operations_ok = True

    try:
        restore_files(snapshot.files)

        if snapshot.head is not None and get_current_git_head(git_root) != snapshot.head:
            command_outcomes.append(_retry_recovery_command(git_root, ["reset", "--mixed", snapshot.head]))
            restore_files(snapshot.files)

        current_branch = get_current_git_branch(git_root)
        if snapshot.branch is not None and current_branch != snapshot.branch:
            command_outcomes.append(_retry_recovery_command(git_root, ["checkout", snapshot.branch]))
        elif snapshot.branch is None and (
            current_branch is not None or get_current_git_head(git_root) != snapshot.head
        ):
            command_outcomes.append(_retry_recovery_command(git_root, ["checkout", "--detach", snapshot.head]))

        restore_files(snapshot.files)
        restore_git_index(snapshot.index_path, snapshot.index_contents, snapshot.index_mode)
    except OSError:
        file_operations_ok = False

    try:
        state_matches = file_operations_ok and (
            get_current_git_branch(git_root) == snapshot.branch
            and get_current_git_head(git_root) == snapshot.head
            and (snapshot.index_path.read_bytes() if snapshot.index_path.exists() else None) == snapshot.index_contents
            and _files_match_snapshot(snapshot.files)
        )
    except OSError:
        state_matches = False
    result = RollbackResult(tuple(command_outcomes), state_matches)
    if result.succeeded:
        print("  Restored release files to their pre-release state.")
        return result

    print_manual_recovery(git_root, snapshot)
    return result


def run_verification(repo_root: Path) -> bool:
    """Run the full release verification gate."""
    result = subprocess.run(["make", "verify"], cwd=repo_root)
    return result.returncode == 0


def check_release_dependencies(repo_root: Path) -> bool:
    """Check release verification dependencies before mutating files."""
    result = subprocess.run(["make", "check-deps"], cwd=repo_root)
    return result.returncode == 0


def git_commit_and_push_branch(repo_root: Path, version: str, dry_run: bool, ci_mode: bool) -> str:
    """Create release branch with version bump commit. Returns branch name."""
    branch_name = f"release/v{version}"
    git_root = get_git_root()

    # Collect all files to stage
    stage_files = [
        str(repo_root / ".claude-plugin" / "plugin.json"),
        str(repo_root / "package.json"),
        str(repo_root / "CHANGELOG.md"),
    ]
    for sibling_file in get_sibling_version_files():
        stage_files.append(str(sibling_file))

    if dry_run:
        print(f"  Would clean up existing branch: {branch_name} (if exists)")
        print(f"  Would run: git checkout -b {branch_name}")
        print(f"  Would stage: {', '.join(stage_files)}")
        print(f'  Would run: git commit -m "Release v{version}"')
        print(f"  Would run: git push origin {branch_name}")
    else:
        # Clean up any existing release branch (from failed previous attempts)
        subprocess.run(
            ["git", "branch", "-D", branch_name],
            cwd=git_root,
            capture_output=True,
        )
        subprocess.run(
            ["git", "push", "origin", "--delete", branch_name],
            cwd=git_root,
            capture_output=True,
        )

        # Create release branch
        subprocess.run(["git", "checkout", "-b", branch_name], cwd=git_root, check=True)

        # Stage and commit
        subprocess.run(
            ["git", "add", *stage_files],
            cwd=git_root,
            check=True,
        )
        subprocess.run(["git", "commit", "-m", f"Release v{version}"], cwd=git_root, check=True)

        if ci_mode:
            subprocess.run(["git", "push", "origin", branch_name], cwd=git_root, check=True)
            print(f"  Pushed branch {branch_name}")
        else:
            print(f"  Created branch {branch_name}")
            print(f"  Run: git push origin {branch_name}")

    return branch_name


def main() -> int:
    parser = argparse.ArgumentParser(description="Release kramme-cc-workflow plugin")
    parser.add_argument(
        "version_type",
        nargs="?",
        metavar="version_type",
        help="Version bump type or explicit version (e.g., 1.0.0)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    parser.add_argument("--ci", action="store_true", help="CI mode (skip prompts, auto-push)")

    args = parser.parse_args()

    if not args.version_type:
        args.version_type = "patch"

    repo_root = get_repo_root()
    current_version = get_current_version(repo_root)
    try:
        new_version = bump_version(current_version, args.version_type)
    except ValueError as exc:
        parser.error(str(exc))

    print(f"Release: {current_version} -> {new_version}")
    if args.dry_run:
        print("(dry run - no changes will be made)\n")

    if not args.dry_run:
        print("\nChecking release verification dependencies...")
        if not check_release_dependencies(repo_root):
            print("\nRelease verification dependencies are missing. Aborting before changing files.")
            return 1

    # Confirm in interactive mode
    if not args.ci and not args.dry_run:
        response = input(f"\nProceed with release v{new_version}? [y/N] ")
        if response.lower() != "y":
            print("Aborted.")
            return 0

    release_snapshot = None
    if not args.dry_run:
        release_snapshot = capture_release_state(repo_root)

    try:
        print("\nSteps:")

        # 1. Update version
        print("1. Updating version...")
        update_version_files(repo_root, new_version, args.dry_run)

        # 2. Generate changelog
        print("2. Generating changelog...")
        changelog_updated = generate_changelog(
            repo_root,
            new_version,
            dry_run=args.dry_run,
            fail_on_history_error=True,
        )
        if not changelog_updated and not args.dry_run:
            print("  Changelog already up to date or no changes found")

        # 3. Verify the final generated release state before committing or pushing.
        print("3. Running release verification...")
        if args.dry_run:
            print("  Would run: make verify")
        elif not run_verification(repo_root):
            if release_snapshot is not None:
                if not restore_release_state(release_snapshot).succeeded:
                    print("\nRelease verification failed and rollback was incomplete.")
                    return 2
            print("\nRelease verification failed. Aborting before creating release branch.")
            return 1

        # 4. Git commit and push branch
        print("4. Creating release branch...")
        branch_name = git_commit_and_push_branch(repo_root, new_version, args.dry_run, args.ci)
    except ChangelogHistoryError as exc:
        if release_snapshot is not None:
            if not restore_release_state(release_snapshot).succeeded:
                print(f"\nRelease changelog generation failed: {exc}")
                print("Aborting with incomplete rollback.")
                return 2
        print(f"\nRelease changelog generation failed: {exc}")
        print("Aborting after restoring release files.")
        return 1
    except subprocess.CalledProcessError as exc:
        if release_snapshot is not None:
            if not restore_release_state(release_snapshot).succeeded:
                command = " ".join(str(part) for part in exc.cmd)
                print(f"\nRelease git step failed: {command}")
                print("Aborting with incomplete rollback.")
                return 2
        command = " ".join(str(part) for part in exc.cmd)
        print(f"\nRelease git step failed: {command}")
        print("Aborting after restoring release files.")
        return 1
    except Exception as exc:
        if release_snapshot is not None:
            if not restore_release_state(release_snapshot).succeeded:
                print(f"\nRelease failed: {exc}")
                print("Aborting with incomplete rollback.")
                return 2
        raise

    if args.ci:
        print(f"\nRelease branch {branch_name} pushed. PR will be created by workflow.")
    else:
        print(f"\nRelease branch {branch_name} created.")
        print("\nNext steps:")
        print(f"  1. Push branch: git push origin {branch_name}")
        print("  2. Create PR to main")
        print("  3. After PR merge, tag and release will be created automatically")

    return 0


if __name__ == "__main__":
    sys.exit(main())
