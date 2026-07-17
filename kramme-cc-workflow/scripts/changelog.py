#!/usr/bin/env python3
"""
Changelog generator for kramme-cc-workflow plugin.

Generates "Keep a Changelog" format entries from conventional commits.
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from datetime import date
from pathlib import Path


@dataclass
class Commit:
    """Represents a parsed git commit."""

    hash: str
    subject: str
    body: str
    pr_number: str | None = None


@dataclass
class ChangelogEntry:
    """A single changelog entry."""

    category: str  # Added, Changed, Fixed, Removed, Security, Deprecated
    message: str
    pr_number: str | None = None


class ChangelogHistoryError(RuntimeError):
    """Raised when git history cannot be read for changelog generation."""


def _git_log_error_message(exc: subprocess.CalledProcessError) -> str:
    details = (exc.stderr or exc.stdout or "").strip()
    lower_details = details.lower()
    if (
        "does not have any commits" in lower_details
        or "ambiguous argument 'head'" in lower_details
        or "unknown revision or path not in the working tree" in lower_details
    ):
        return (
            "No commits found in repository history; create an initial commit "
            "before generating a changelog."
        )

    if details:
        return f"Unable to read git history: {details}"
    return "Unable to read git history."


class CommitParser:
    """Parses git commit messages into changelog entries."""

    CONVENTIONAL_PATTERN = re.compile(
        r"^(?P<type>feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)"
        r"(?:\((?P<scope>[^)]+)\))?"
        r"(?P<breaking>!)?"
        r":\s*(?P<description>.+)$",
        re.IGNORECASE,
    )

    PR_PATTERN = re.compile(r"\(#(\d+)\)$")

    TYPE_TO_CATEGORY = {
        "feat": "Added",
        "fix": "Fixed",
        "docs": "Changed",
        "style": "Changed",
        "refactor": "Changed",
        "perf": "Changed",
        "revert": "Changed",
    }

    EXCLUDED_TYPES = {"test", "build", "ci", "chore"}

    KEYWORD_HINTS = {
        "Added": ["add", "new", "create", "implement", "introduce", "initial"],
        "Fixed": ["fix", "resolve", "correct", "repair", "patch", "bug"],
        "Changed": [
            "update",
            "modify",
            "change",
            "improve",
            "enhance",
            "rename",
            "refactor",
            "upgrade",
            "bump",
            "expand",
        ],
        "Removed": ["remove", "delete", "drop", "deprecate"],
        "Security": ["security", "vulnerability", "cve"],
    }

    def parse(self, commit: Commit) -> ChangelogEntry | None:
        """Parse a commit into a changelog entry."""
        subject = commit.subject.strip()

        # Skip release commits
        if subject.lower().startswith("release v"):
            return None

        # Extract PR number if present
        pr_match = self.PR_PATTERN.search(subject)
        pr_number = pr_match.group(1) if pr_match else commit.pr_number

        # Remove PR number from subject for parsing
        clean_subject = self.PR_PATTERN.sub("", subject).strip()

        # Try conventional commit format first
        match = self.CONVENTIONAL_PATTERN.match(clean_subject)
        if match:
            commit_type = match.group("type").lower()

            # Skip excluded types
            if commit_type in self.EXCLUDED_TYPES:
                return None

            description = match.group("description")
            is_breaking = (
                match.group("breaking") == "!" or "BREAKING" in commit.body.upper()
            )

            category = self.TYPE_TO_CATEGORY.get(commit_type, "Changed")

            if is_breaking:
                description = f"**BREAKING:** {description}"

            return ChangelogEntry(
                category=category,
                message=self._format_message(description),
                pr_number=pr_number,
            )

        # Fall back to keyword-based categorization
        return self._categorize_by_keywords(clean_subject, pr_number)

    def _categorize_by_keywords(
        self, subject: str, pr_number: str | None
    ) -> ChangelogEntry | None:
        """Categorize non-conventional commits by keywords."""
        lower_subject = subject.lower()

        for category, keywords in self.KEYWORD_HINTS.items():
            for keyword in keywords:
                if lower_subject.startswith(
                    keyword
                ) or f" {keyword} " in f" {lower_subject} ":
                    return ChangelogEntry(
                        category=category,
                        message=self._format_message(subject),
                        pr_number=pr_number,
                    )

        # Default to Changed if no keywords match
        return ChangelogEntry(
            category="Changed",
            message=self._format_message(subject),
            pr_number=pr_number,
        )

    def _format_message(self, message: str) -> str:
        """Format message for changelog (capitalize first letter)."""
        if not message:
            return message
        breaking_prefix = "**BREAKING:** "
        if message.startswith(breaking_prefix):
            description = message[len(breaking_prefix) :]
            if not description:
                return message
            return f"{breaking_prefix}{description[0].upper()}{description[1:]}"
        return message[0].upper() + message[1:]


class ChangelogGenerator:
    """Generates changelog content from git commits."""

    CATEGORY_ORDER = ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]

    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.parser = CommitParser()

    def get_commits_since_tag(self, tag: str | None = None) -> list[Commit]:
        """Get commits since the specified tag (or all commits if no tag)."""
        if tag:
            range_spec = f"{tag}..HEAD"
        else:
            range_spec = "HEAD"

        try:
            result = subprocess.run(
                ["git", "log", range_spec, "--format=%H%x00%s%x00%b%x1e"],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as exc:
            raise ChangelogHistoryError(_git_log_error_message(exc)) from exc

        commits = []
        for entry in result.stdout.strip().split("\x1e"):
            entry = entry.strip()
            if not entry:
                continue
            parts = entry.split("\x00")
            if len(parts) >= 2:
                commits.append(
                    Commit(
                        hash=parts[0],
                        subject=parts[1],
                        body=parts[2] if len(parts) > 2 else "",
                    )
                )

        return commits

    def get_latest_tag(self) -> str | None:
        """Get the most recent version tag."""
        result = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0", "--match", "v*"],
            cwd=self.repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None

    def generate_entries(self, commits: list[Commit]) -> dict[str, list[ChangelogEntry]]:
        """Generate categorized changelog entries from commits."""
        categorized: dict[str, list[ChangelogEntry]] = {
            cat: [] for cat in self.CATEGORY_ORDER
        }

        for commit in commits:
            entry = self.parser.parse(commit)
            if entry and entry.category in categorized:
                categorized[entry.category].append(entry)

        # Remove empty categories
        return {k: v for k, v in categorized.items() if v}

    def format_version_section(
        self,
        version: str,
        entries: dict[str, list[ChangelogEntry]],
        release_date: date | None = None,
    ) -> str:
        """Format entries as a changelog version section."""
        if release_date is None:
            release_date = date.today()

        lines = [f"## [{version}] - {release_date.isoformat()}", ""]

        for category in self.CATEGORY_ORDER:
            if category not in entries:
                continue

            lines.extend([f"### {category}", ""])
            for entry in entries[category]:
                pr_ref = f" (#{entry.pr_number})" if entry.pr_number else ""
                lines.append(f"- {entry.message}{pr_ref}")
            lines.append("")

        return "\n".join(lines)

    def format_link_reference(
        self, version: str, repo_url: str, prev_version: str | None = None
    ) -> str:
        """Generate the link reference for the version."""
        if prev_version:
            return f"[{version}]: {repo_url}/compare/{prev_version}...v{version}"
        else:
            return f"[{version}]: {repo_url}/releases/tag/v{version}"


class ChangelogUpdater:
    """Updates CHANGELOG.md file idempotently."""

    VERSION_HEADER_PATTERN = re.compile(r"^## \[(\d+\.\d+\.\d+)\]", re.MULTILINE)
    LINK_PATTERN = re.compile(r"^\[(\d+\.\d+\.\d+)\]:")

    def __init__(self, changelog_path: Path):
        self.changelog_path = changelog_path

    def read(self) -> str:
        """Read existing changelog content."""
        if self.changelog_path.exists():
            return self.changelog_path.read_text()
        return self._default_header()

    def _default_header(self) -> str:
        """Return default changelog header."""
        return """# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

"""

    def version_exists(self, version: str) -> bool:
        """Check if a version entry already exists."""
        content = self.read()
        return f"## [{version}]" in content

    def get_previous_version(self) -> str | None:
        """Get the most recent version from the changelog."""
        content = self.read()
        match = self.VERSION_HEADER_PATTERN.search(content)
        return match.group(1) if match else None

    def update(
        self,
        version: str,
        version_section: str,
        link_reference: str,
        dry_run: bool = False,
    ) -> bool:
        """
        Update changelog with new version section.

        Returns True if updated, False if version already exists.
        """
        if self.version_exists(version):
            return False

        content = self.read()
        lines = content.split("\n")

        # Find insertion point before the first released version.
        insert_idx = len(lines)
        needs_leading_blank = False
        for i, line in enumerate(lines):
            if self.VERSION_HEADER_PATTERN.match(line):
                insert_idx = i
                break
        else:
            # No existing versions, insert after any existing header content.
            while insert_idx > 0 and not lines[insert_idx - 1].strip():
                insert_idx -= 1
            needs_leading_blank = insert_idx > 0

        # Insert version section
        version_lines = version_section.strip().split("\n")
        if needs_leading_blank:
            version_lines = [""] + version_lines
        lines[insert_idx:insert_idx] = version_lines + [""]

        # Find and update link references section
        link_insert_idx: int | None = None
        for i, line in enumerate(lines):
            if self.LINK_PATTERN.match(line.strip()):
                link_insert_idx = i
                break

        # Insert link reference
        if link_insert_idx is None:
            while lines and not lines[-1].strip():
                lines.pop()
            lines.extend(["", link_reference])
        else:
            lines.insert(link_insert_idx, link_reference)

        new_content = "\n".join(lines).rstrip() + "\n"

        if dry_run:
            print(f"  Would update {self.changelog_path}")
            print("  --- New version section ---")
            print(version_section)
            print("  --- Link reference ---")
            print(f"  {link_reference}")
        else:
            self.changelog_path.write_text(new_content)
            print(f"  Updated {self.changelog_path}")

        return True


def get_repo_url(repo_root: Path) -> str:
    """Get GitHub repository URL from git remote."""
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return "https://github.com/Abildtoft/kramme-cc-workflow"

    url = result.stdout.strip()
    # Convert SSH to HTTPS format
    if url.startswith("git@github.com:"):
        url = url.replace("git@github.com:", "https://github.com/")
    if url.endswith(".git"):
        url = url[:-4]
    return url


def generate_changelog(
    repo_root: Path,
    version: str,
    repo_url: str | None = None,
    dry_run: bool = False,
    *,
    fail_on_history_error: bool = False,
) -> bool:
    """
    Main entry point for changelog generation.

    Returns True if changelog was updated, False if version already exists.
    When fail_on_history_error is true, git history read failures are raised so
    callers that require a changelog can abort instead of treating them as no-op.
    """
    changelog_path = repo_root / "CHANGELOG.md"

    if repo_url is None:
        repo_url = get_repo_url(repo_root)

    generator = ChangelogGenerator(repo_root)
    updater = ChangelogUpdater(changelog_path)

    # Check idempotency
    if updater.version_exists(version):
        print(f"  Version {version} already exists in changelog, skipping")
        return False

    # Get commits since last tag
    last_tag = generator.get_latest_tag()
    try:
        commits = generator.get_commits_since_tag(last_tag)
    except ChangelogHistoryError as exc:
        if fail_on_history_error:
            raise
        print(f"  {exc}")
        return False

    if not commits:
        print("  No commits found since last tag")
        return False

    # Generate entries
    entries = generator.generate_entries(commits)

    if not entries:
        print("  No changelog-worthy commits found")
        return False

    # Get previous version for compare link
    prev_version = updater.get_previous_version()
    if prev_version:
        prev_tag = f"v{prev_version}"
    else:
        prev_tag = last_tag

    # Format content
    version_section = generator.format_version_section(version, entries)
    link_reference = generator.format_link_reference(version, repo_url, prev_tag)

    # Update changelog
    return updater.update(version, version_section, link_reference, dry_run=dry_run)
