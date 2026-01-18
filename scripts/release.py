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

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def get_repo_root() -> Path:
    """Get the repository root directory."""
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(result.stdout.strip())


def get_current_version(repo_root: Path) -> str:
    """Read current version from plugin.json."""
    plugin_json = repo_root / ".claude-plugin" / "plugin.json"
    with open(plugin_json) as f:
        data = json.load(f)
    return data["version"]


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


def update_plugin_json(repo_root: Path, new_version: str, dry_run: bool) -> None:
    """Update version in plugin.json."""
    plugin_json = repo_root / ".claude-plugin" / "plugin.json"
    with open(plugin_json) as f:
        data = json.load(f)

    data["version"] = new_version

    if dry_run:
        print(f"  Would update {plugin_json} to version {new_version}")
    else:
        with open(plugin_json, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(f"  Updated {plugin_json}")


def run_tests(repo_root: Path) -> bool:
    """Run the test suite."""
    print("\nRunning tests...")
    result = subprocess.run(["make", "test"], cwd=repo_root)
    return result.returncode == 0


def git_commit_and_push_branch(
    repo_root: Path, version: str, dry_run: bool, ci_mode: bool
) -> str:
    """Create release branch with version bump commit. Returns branch name."""
    branch_name = f"release/v{version}"

    if dry_run:
        print(f"  Would run: git checkout -b {branch_name}")
        print(f"  Would run: git add .claude-plugin/plugin.json")
        print(f'  Would run: git commit -m "Release v{version}"')
        print(f"  Would run: git push origin {branch_name}")
    else:
        # Create release branch
        subprocess.run(
            ["git", "checkout", "-b", branch_name], cwd=repo_root, check=True
        )

        # Stage and commit
        subprocess.run(
            ["git", "add", ".claude-plugin/plugin.json"], cwd=repo_root, check=True
        )
        subprocess.run(
            ["git", "commit", "-m", f"Release v{version}"], cwd=repo_root, check=True
        )

        if ci_mode:
            subprocess.run(
                ["git", "push", "origin", branch_name], cwd=repo_root, check=True
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
        choices=["patch", "minor", "major"],
        nargs="?",
        help="Version bump type or explicit version (e.g., 1.0.0)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Show what would be done"
    )
    parser.add_argument(
        "--ci", action="store_true", help="CI mode (skip prompts, auto-push)"
    )

    args, remaining = parser.parse_known_args()

    # Handle explicit version as positional arg
    if remaining and re.match(r"^\d+\.\d+\.\d+$", remaining[0]):
        args.version_type = remaining[0]
    elif not args.version_type:
        args.version_type = "patch"

    repo_root = get_repo_root()
    current_version = get_current_version(repo_root)
    new_version = bump_version(current_version, args.version_type)

    print(f"Release: {current_version} -> {new_version}")
    if args.dry_run:
        print("(dry run - no changes will be made)\n")

    # Run tests first
    if not args.dry_run:
        if not run_tests(repo_root):
            print("\nTests failed. Aborting release.")
            return 1

    # Confirm in interactive mode
    if not args.ci and not args.dry_run:
        response = input(f"\nProceed with release v{new_version}? [y/N] ")
        if response.lower() != "y":
            print("Aborted.")
            return 0

    print("\nSteps:")

    # 1. Update version
    print("1. Updating version...")
    update_plugin_json(repo_root, new_version, args.dry_run)

    # 2. Git commit and push branch
    print("2. Creating release branch...")
    branch_name = git_commit_and_push_branch(repo_root, new_version, args.dry_run, args.ci)

    if args.ci:
        print(f"\nRelease branch {branch_name} pushed. PR will be created by workflow.")
    else:
        print(f"\nRelease branch {branch_name} created.")
        print("\nNext steps:")
        print(f"  1. Push branch: git push origin {branch_name}")
        print(f"  2. Create PR to main")
        print(f"  3. After PR merge, tag and release will be created automatically")

    return 0


if __name__ == "__main__":
    sys.exit(main())
