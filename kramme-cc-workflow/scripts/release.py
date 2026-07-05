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
import re
import subprocess
import sys
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


def _git_paths(git_root: Path, paths: list[Path]) -> list[str]:
    git_root = git_root.resolve()
    relative_paths = []
    for path in paths:
        resolved = path.resolve()
        try:
            relative_paths.append(str(resolved.relative_to(git_root)))
        except ValueError:
            relative_paths.append(str(resolved))
    return relative_paths


def reset_git_index(git_root: Path, paths: list[Path]) -> None:
    """Best-effort reset for release paths that may have been staged."""
    git_paths = _git_paths(git_root, paths)
    if not git_paths:
        return

    subprocess.run(
        ["git", "reset", "--", *git_paths],
        cwd=git_root,
        capture_output=True,
    )


def checkout_branch(git_root: Path, branch: str) -> bool:
    """Best-effort branch checkout for release rollback."""
    result = subprocess.run(
        ["git", "checkout", branch],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def checkout_detached_head(git_root: Path, head: str) -> bool:
    """Best-effort detached checkout for release rollback."""
    result = subprocess.run(
        ["git", "checkout", "--detach", head],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def restore_release_state(
    snapshot: dict[Path, bytes | None],
    start_branch: str | None,
    start_head: str | None,
) -> None:
    """Restore release files and best-effort Git state after release failure."""
    git_root = get_git_root()
    snapshot_paths = list(snapshot.keys())

    restore_files(snapshot)

    current_branch = get_current_git_branch(git_root)
    if start_branch and current_branch and current_branch != start_branch:
        if start_head:
            subprocess.run(
                ["git", "reset", "--mixed", start_head],
                cwd=git_root,
                capture_output=True,
            )
            restore_files(snapshot)
        if not checkout_branch(git_root, start_branch):
            reset_git_index(git_root, snapshot_paths)
            checkout_branch(git_root, start_branch)
        restore_files(snapshot)
    elif start_head and current_branch:
        subprocess.run(
            ["git", "reset", "--mixed", start_head],
            cwd=git_root,
            capture_output=True,
        )
        restore_files(snapshot)
        if not checkout_detached_head(git_root, start_head):
            reset_git_index(git_root, snapshot_paths)
            checkout_detached_head(git_root, start_head)
        restore_files(snapshot)

    reset_git_index(git_root, snapshot_paths)
    print("  Restored release files to their pre-release state.")


def run_verification(repo_root: Path) -> bool:
    """Run the full release verification gate."""
    result = subprocess.run(["make", "verify"], cwd=repo_root)
    return result.returncode == 0


def check_release_dependencies(repo_root: Path) -> bool:
    """Check release verification dependencies before mutating files."""
    result = subprocess.run(["make", "check-deps"], cwd=repo_root)
    return result.returncode == 0


def git_commit_and_push_branch(
    repo_root: Path, version: str, dry_run: bool, ci_mode: bool
) -> str:
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
        subprocess.run(
            ["git", "checkout", "-b", branch_name], cwd=git_root, check=True
        )

        # Stage and commit
        subprocess.run(
            ["git", "add", *stage_files],
            cwd=git_root,
            check=True,
        )
        subprocess.run(
            ["git", "commit", "-m", f"Release v{version}"], cwd=git_root, check=True
        )

        if ci_mode:
            subprocess.run(
                ["git", "push", "origin", branch_name], cwd=git_root, check=True
            )
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
    parser.add_argument(
        "--dry-run", action="store_true", help="Show what would be done"
    )
    parser.add_argument(
        "--ci", action="store_true", help="CI mode (skip prompts, auto-push)"
    )

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
            print(
                "\nRelease verification dependencies are missing. "
                "Aborting before changing files."
            )
            return 1

    # Confirm in interactive mode
    if not args.ci and not args.dry_run:
        response = input(f"\nProceed with release v{new_version}? [y/N] ")
        if response.lower() != "y":
            print("Aborted.")
            return 0

    release_snapshot = None
    release_start_branch = None
    release_start_head = None
    if not args.dry_run:
        git_root = get_git_root()
        release_start_branch = get_current_git_branch(git_root)
        release_start_head = get_current_git_head(git_root)
        release_snapshot = snapshot_files(get_release_mutation_paths(repo_root))

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
                restore_release_state(
                    release_snapshot,
                    release_start_branch,
                    release_start_head,
                )
            print("\nRelease verification failed. Aborting before creating release branch.")
            return 1

        # 4. Git commit and push branch
        print("4. Creating release branch...")
        branch_name = git_commit_and_push_branch(
            repo_root, new_version, args.dry_run, args.ci
        )
    except ChangelogHistoryError as exc:
        if release_snapshot is not None:
            restore_release_state(
                release_snapshot, release_start_branch, release_start_head
            )
        print(f"\nRelease changelog generation failed: {exc}")
        print("Aborting after restoring release files.")
        return 1
    except subprocess.CalledProcessError as exc:
        if release_snapshot is not None:
            restore_release_state(
                release_snapshot, release_start_branch, release_start_head
            )
        command = " ".join(str(part) for part in exc.cmd)
        print(f"\nRelease git step failed: {command}")
        print("Aborting after restoring release files.")
        return 1
    except Exception:
        if release_snapshot is not None:
            restore_release_state(
                release_snapshot, release_start_branch, release_start_head
            )
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
