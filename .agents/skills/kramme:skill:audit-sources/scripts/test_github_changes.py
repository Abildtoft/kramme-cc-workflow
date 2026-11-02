#!/usr/bin/env python3

from __future__ import annotations

import io
import json
import re
import subprocess
import unittest
from collections.abc import Callable, Mapping
from contextlib import redirect_stderr, redirect_stdout
from typing import Any
from unittest.mock import patch

from github_changes import UnsupportedUrl, main, parse_github_url

Key = tuple[str, tuple[tuple[str, str], ...]]
Responses = dict[Key, Any]

RAW_URL = "https://raw.githubusercontent.com/o/r/main/skills/review/SKILL.md"
PINNED_URL = "https://raw.githubusercontent.com/o/r/v0.1.0/skills/review/SKILL.md"
TARGET = "skills/review/SKILL.md"
BASELINE_DATE = "2026-07-20T08:00:00Z"
ALLOWED_ENDPOINT = re.compile(r"repos/[^/]+/[^/]+(?:/commits(?:/[^/]+)?|/git/trees/[0-9a-f]{40})?")
FORBIDDEN = ("contents", "readme", "compare", "git/blobs", "tarball", "zipball")


def sha(number: int) -> str:
    return f"{number:040x}"


BASELINE = sha(1)
HEAD = sha(99)


def commit(number: int, timestamp: str = "2026-08-01T00:00:00Z", message: str = "Update") -> dict[str, Any]:
    return {"sha": sha(number), "commit": {"message": message, "committer": {"date": timestamp}}}


def key(endpoint: str, params: Mapping[str, str] | None = None) -> Key:
    return endpoint, tuple(sorted((params or {}).items()))


def recorded(full_name: str = "o/r") -> tuple[Key, Any]:
    return key(f"repos/{full_name}/commits/{BASELINE}"), commit(1, BASELINE_DATE)


def pinned(ref: str = "v0.1.0") -> tuple[Key, Any]:
    return key(f"repos/o/r/commits/{ref}"), commit(1, BASELINE_DATE)


def derived(day: str = "2026-07-29", branch: str = "main") -> tuple[Key, Any]:
    params = {"sha": branch, "until": f"{day}T23:59:59Z", "per_page": "1"}
    return key("repos/o/r/commits", params), [commit(1, BASELINE_DATE)]


def gh_responses(
    baseline: tuple[Key, Any],
    *,
    history: list[dict[str, Any]] | None = None,
    path: str = TARGET,
    tree: list[dict[str, str]] | None = None,
    truncated: bool = False,
    tracked: str = "main",
    requested: str = "o/r",
    full_name: str = "o/r",
    default_branch: str = "main",
) -> Responses:
    responses: Responses = {
        key(f"repos/{requested}"): {"full_name": full_name, "default_branch": default_branch},
        key(f"repos/{full_name}/commits/{tracked}"): commit(99, "2026-10-30T12:00:00Z"),
        baseline[0]: baseline[1],
    }
    params = {"sha": tracked, "since": BASELINE_DATE, "per_page": "100"}
    if path:
        params["path"] = path
    # The `since` window is inclusive, so the API also returns the baseline commit itself.
    responses[key(f"repos/{full_name}/commits", params)] = [*(history or []), commit(1, BASELINE_DATE)]
    if path:
        entries = tree if tree is not None else [{"path": path, "type": "blob"}]
        responses[key(f"repos/{full_name}/git/trees/{HEAD}", {"recursive": "1"})] = {
            "truncated": truncated,
            "tree": entries,
        }
    return responses


class FakeGh:
    """Serve canned `gh api` results and record every endpoint; unexpected calls fail the test."""

    def __init__(self, responses: Responses) -> None:
        self.responses = responses
        self.calls: list[Key] = []

    def __call__(self, endpoint: str, params: Mapping[str, str]) -> subprocess.CompletedProcess[str]:
        call = key(endpoint, params)
        self.calls.append(call)
        if call not in self.responses:
            raise AssertionError(f"unexpected gh api call: {call}")
        response = self.responses[call]
        if isinstance(response, subprocess.CompletedProcess):
            return response
        return subprocess.CompletedProcess(["gh"], 0, json.dumps(response), "")


def run_cli(responses: Responses, *args: str) -> tuple[int, str, str, FakeGh]:
    fake = FakeGh(responses)
    stdout, stderr = io.StringIO(), io.StringIO()
    with patch("github_changes.run_gh_api", fake), redirect_stdout(stdout), redirect_stderr(stderr):
        code = main(list(args))
    return code, stdout.getvalue(), stderr.getvalue(), fake


def run_report(responses: Responses, *args: str) -> tuple[dict[str, Any], FakeGh]:
    code, stdout, stderr, fake = run_cli(responses, *args)
    if code != 0:
        raise AssertionError(f"exit {code}: {stderr}")
    report: dict[str, Any] = json.loads(stdout)
    return report, fake


class ParseTests(unittest.TestCase):
    def test_accepts_supported_forms(self) -> None:
        cases = [
            (RAW_URL, "raw", "main", TARGET, False),
            ("https://raw.githubusercontent.com/o/r/refs/heads/main/a/b.md", "raw", "main", "a/b.md", False),
            ("https://raw.githubusercontent.com/o/r/refs/tags/stable/a/b.md", "raw", "stable", "a/b.md", True),
            (f"https://raw.githubusercontent.com/o/r/{BASELINE}/cmd/x.go", "raw", BASELINE, "cmd/x.go", True),
            ("https://raw.githubusercontent.com/o/r/v0.1.0/cmd/x.go", "raw", "v0.1.0", "cmd/x.go", True),
            ("https://github.com/o/r/tree/main/skills/my%20skill", "tree", "main", "skills/my skill", False),
            (f"https://github.com/o/r/blob/{BASELINE}/README.md", "blob", BASELINE, "README.md", True),
            ("https://github.com/o/r/tree/1.2.3", "tree", "1.2.3", "", True),
            ("https://github.com/o/r.git/", "repository", None, "", False),
        ]
        for url, kind, ref, path, is_pinned in cases:
            with self.subTest(url=url):
                source = parse_github_url(url)
                self.assertEqual(
                    (source.owner, source.repo, source.kind, source.ref, source.path, source.pinned),
                    ("o", "r", kind, ref, path, is_pinned),
                )

    def test_rejects_other_urls(self) -> None:
        for url in (
            "https://example.com/x",
            "https://github.com/o/r/issues/1",
            "http://github.com/o/r",
            "https://github.com/o",
            "https://raw.githubusercontent.com/o/r/main",
            "https://github.com/o/r/tree/..%2F..%2Fcontents%2FREADME.md/x",
            "https://raw.githubusercontent.com/o/r/../contents/x",
            "https://github.com/../..",
        ):
            with self.subTest(url=url), self.assertRaises(UnsupportedUrl):
                parse_github_url(url)

    def test_cli_exits_2_for_unsupported_url_without_calling_gh(self) -> None:
        for url in ("https://example.com/x", "https://github.com/o/r/issues/1"):
            with self.subTest(url=url):
                code, stdout, stderr, fake = run_cli({}, "--url", url, "--last-reviewed-at", "2026-10-31")
                self.assertEqual((code, stdout, fake.calls), (2, "", []))
                self.assertTrue(stderr.startswith("github_changes.py: "))


class BaselineTests(unittest.TestCase):
    def test_recorded_baseline_wins_over_pin(self) -> None:
        responses = gh_responses(recorded())
        url = PINNED_URL
        report, fake = run_report(
            responses, "--url", url, "--baseline-commit", BASELINE.upper(), "--last-reviewed-at", "2026-07-29"
        )
        self.assertEqual((report["baseline_source"], report["baseline_commit"]), ("recorded", BASELINE))
        self.assertNotIn(key("repos/o/r/commits/v0.1.0"), fake.calls)

    def test_pin_wins_over_derived_and_tracks_default_branch(self) -> None:
        responses = gh_responses(pinned(), tracked="trunk", default_branch="trunk", history=[commit(5)])
        report, _ = run_report(responses, "--url", PINNED_URL, "--last-reviewed-at", "2026-07-29")
        self.assertEqual(report["baseline_source"], "pinned")
        self.assertEqual(report["baseline_date"], "2026-07-20")
        self.assertTrue(report["pinned"])
        self.assertEqual(report["tracked_branch"], "trunk")
        self.assertEqual(report["head_commit"], HEAD)
        self.assertEqual(report["head_url"], f"https://raw.githubusercontent.com/o/r/{HEAD}/{TARGET}")
        self.assertEqual(report["status"], "changed")

    def test_derives_baseline_from_last_commit_at_or_before_review_date(self) -> None:
        report, fake = run_report(
            gh_responses(derived("2026-07-29")), "--url", RAW_URL, "--last-reviewed-at", "2026-07-29"
        )
        self.assertEqual((report["baseline_source"], report["baseline_commit"]), ("derived", BASELINE))
        self.assertIn(derived("2026-07-29")[0], fake.calls)

    def test_exits_1_without_baseline_or_date_for_unpinned_url(self) -> None:
        code, stdout, stderr, fake = run_cli({}, "--url", RAW_URL)
        self.assertEqual((code, stdout, fake.calls), (1, "", []))
        self.assertIn("--baseline-commit or --last-reviewed-at", stderr)

    def test_exits_1_for_invalid_arguments(self) -> None:
        for args in (
            ("--last-reviewed-at", "2026-13-01"),
            ("--last-reviewed-at", "yesterday"),
            ("--baseline-commit", "abc123"),
            ("--last-reviewed-at", "2026-07-29", "--max-commits", "101"),
        ):
            with self.subTest(args=args):
                code, _, _, fake = run_cli({}, "--url", RAW_URL, *args)
                self.assertEqual((code, fake.calls), (1, []))

    def test_exits_1_when_no_commit_precedes_review_date(self) -> None:
        day = "2020-01-01"
        responses = gh_responses(derived(day))
        responses[derived(day)[0]] = []
        code, _, stderr, _ = run_cli(responses, "--url", RAW_URL, "--last-reviewed-at", day)
        self.assertEqual(code, 1)
        self.assertIn("no commit on main at or before 2020-01-01", stderr)


class CommitListTests(unittest.TestCase):
    def test_excludes_baseline_keeps_newest_first_and_bounds_titles(self) -> None:
        history = [
            commit(4, "2026-09-03T00:00:00Z", "x" * 130 + "\n\nBody text"),
            commit(3, "2026-09-02T00:00:00Z", "Second change"),
            commit(2, "2026-09-01T00:00:00Z", "First change"),
        ]
        report, _ = run_report(
            gh_responses(recorded(), history=history), "--url", RAW_URL, "--baseline-commit", BASELINE
        )
        self.assertEqual(report["commit_count"], 3)
        self.assertEqual(
            report["commits"],
            [
                {"sha": sha(4)[:7], "date": "2026-09-03", "title": "x" * 120},
                {"sha": sha(3)[:7], "date": "2026-09-02", "title": "Second change"},
                {"sha": sha(2)[:7], "date": "2026-09-01", "title": "First change"},
            ],
        )
        self.assertFalse(report["commits_truncated"])

    def test_max_commits_bounds_the_list(self) -> None:
        history = [commit(number) for number in range(10, 2, -1)]
        responses = gh_responses(recorded(), history=history)
        report, _ = run_report(responses, "--url", RAW_URL, "--baseline-commit", BASELINE, "--max-commits", "3")
        self.assertEqual(report["commit_count"], 8)
        self.assertEqual([entry["sha"] for entry in report["commits"]], [sha(n)[:7] for n in (10, 9, 8)])
        self.assertTrue(report["commits_truncated"])

    def test_full_api_page_marks_truncation(self) -> None:
        history = [commit(number) for number in range(200, 101, -1)]
        report, _ = run_report(
            gh_responses(recorded(), history=history), "--url", RAW_URL, "--baseline-commit", BASELINE
        )
        self.assertEqual((report["commit_count"], len(report["commits"])), (99, 20))
        self.assertTrue(report["commits_truncated"])


def unchanged_scenario() -> tuple[Responses, list[str]]:
    return gh_responses(recorded()), ["--url", RAW_URL, "--baseline-commit", BASELINE]


def changed_scenario() -> tuple[Responses, list[str]]:
    return gh_responses(recorded(), history=[commit(2)]), ["--url", RAW_URL, "--baseline-commit", BASELINE]


def moved_scenario() -> tuple[Responses, list[str]]:
    target = "skills/in-progress/wizard/SKILL.md"
    tree = [
        {"path": "skills/wizard/SKILL.md", "type": "blob"},
        {"path": "skills/other/SKILL.md", "type": "blob"},
        {"path": "archive/wizard/SKILL.md", "type": "tree"},
        {"path": target, "type": "tree"},
    ]
    url = f"https://github.com/o/r/blob/main/{target}"
    return gh_responses(derived(), path=target, tree=tree, history=[commit(2)]), [
        "--url",
        url,
        "--last-reviewed-at",
        "2026-07-29",
    ]


def gone_scenario() -> tuple[Responses, list[str]]:
    tree = [{"path": "skills/review", "type": "tree"}, {"path": "skills/other/SKILL.md", "type": "blob"}]
    return gh_responses(recorded(), tree=tree, history=[commit(2)]), ["--url", RAW_URL, "--baseline-commit", BASELINE]


def truncated_scenario() -> tuple[Responses, list[str]]:
    responses = gh_responses(recorded(), tree=[{"path": "other.md", "type": "blob"}], truncated=True)
    return responses, ["--url", RAW_URL, "--baseline-commit", BASELINE]


def tree_scenario() -> tuple[Responses, list[str]]:
    path = "skills/review"
    responses = gh_responses(recorded(), path=path, tree=[{"path": path, "type": "tree"}], history=[commit(2)])
    return responses, ["--url", f"https://github.com/o/r/tree/main/{path}", "--baseline-commit", BASELINE]


def root_scenario() -> tuple[Responses, list[str]]:
    return gh_responses(recorded(), path=""), ["--url", "https://github.com/o/r", "--baseline-commit", BASELINE]


def renamed_scenario() -> tuple[Responses, list[str]]:
    responses = gh_responses(recorded("new-owner/r"), requested="o/r", full_name="new-owner/r", history=[commit(2)])
    return responses, ["--url", RAW_URL, "--baseline-commit", BASELINE]


def pinned_scenario() -> tuple[Responses, list[str]]:
    responses = gh_responses(pinned(), history=[commit(2)])
    return responses, ["--url", PINNED_URL, "--last-reviewed-at", "2026-07-29"]


SCENARIOS: list[Callable[[], tuple[Responses, list[str]]]] = [
    unchanged_scenario,
    changed_scenario,
    moved_scenario,
    gone_scenario,
    truncated_scenario,
    tree_scenario,
    root_scenario,
    renamed_scenario,
    pinned_scenario,
]


class StatusTests(unittest.TestCase):
    def report(self, scenario: Callable[[], tuple[Responses, list[str]]]) -> dict[str, Any]:
        responses, args = scenario()
        return run_report(responses, *args)[0]

    def test_unchanged_when_only_the_baseline_touched_the_path(self) -> None:
        report = self.report(unchanged_scenario)
        self.assertEqual((report["status"], report["path_status"], report["commit_count"]), ("unchanged", "present", 0))

    def test_changed_when_a_later_commit_touched_the_path(self) -> None:
        report = self.report(changed_scenario)
        self.assertEqual((report["status"], report["commit_count"]), ("changed", 1))

    def test_moved_lists_same_type_candidates_with_matching_trailing_segments(self) -> None:
        report = self.report(moved_scenario)
        self.assertEqual((report["status"], report["path_status"]), ("moved", "missing"))
        self.assertEqual(report["move_candidates"], ["skills/wizard/SKILL.md"])

    def test_gone_when_missing_without_candidates(self) -> None:
        report = self.report(gone_scenario)
        self.assertEqual((report["status"], report["path_status"], report["move_candidates"]), ("gone", "missing", []))

    def test_truncated_tree_reports_unknown_and_decides_from_commits(self) -> None:
        report = self.report(truncated_scenario)
        self.assertEqual((report["status"], report["path_status"]), ("unchanged", "unknown"))

    def test_tree_url_matches_tree_entries_and_links_tree_at_head(self) -> None:
        report = self.report(tree_scenario)
        self.assertEqual((report["status"], report["path_status"]), ("changed", "present"))
        self.assertEqual(report["head_url"], f"https://github.com/o/r/tree/{HEAD}/skills/review")

    def test_repository_root_is_present_without_reading_the_tree(self) -> None:
        responses, args = root_scenario()
        report, fake = run_report(responses, *args)
        self.assertEqual((report["path_status"], report["tracked_branch"]), ("present", "main"))
        self.assertEqual(report["head_url"], f"https://github.com/o/r/tree/{HEAD}")
        self.assertFalse(any("git/trees" in endpoint for endpoint, _ in fake.calls))

    def test_renamed_repository_uses_new_full_name(self) -> None:
        responses, args = renamed_scenario()
        report, fake = run_report(responses, *args)
        self.assertEqual((report["repository"], report["renamed_to"]), ("o/r", "new-owner/r"))
        self.assertEqual(report["head_url"], f"https://raw.githubusercontent.com/new-owner/r/{HEAD}/{TARGET}")
        self.assertTrue(all(endpoint.startswith("repos/new-owner/r/") for endpoint, _ in fake.calls[1:]))

    def test_output_has_only_documented_keys(self) -> None:
        report = self.report(changed_scenario)
        self.assertEqual(
            list(report),
            [
                "url",
                "repository",
                "full_name",
                "renamed_to",
                "path",
                "ref",
                "pinned",
                "tracked_branch",
                "head_commit",
                "head_url",
                "baseline_commit",
                "baseline_source",
                "baseline_date",
                "path_status",
                "move_candidates",
                "commit_count",
                "commits_truncated",
                "commits",
                "status",
            ],
        )


class CliErrorTests(unittest.TestCase):
    def test_exits_1_when_gh_fails(self) -> None:
        for returncode, stderr_text in ((1, "gh: Not Found (HTTP 404)"), (124, "timed out"), (127, "No such file")):
            with self.subTest(returncode=returncode):
                failure = subprocess.CompletedProcess(["gh"], returncode, '{"message": "body"}', stderr_text)
                code, stdout, stderr, _ = run_cli(
                    {key("repos/o/r"): failure}, "--url", RAW_URL, "--baseline-commit", BASELINE
                )
                self.assertEqual((code, stdout), (1, ""))
                self.assertTrue(stderr.startswith("github_changes.py: "))
                self.assertNotIn("body", stderr)

    def test_exits_1_on_malformed_json(self) -> None:
        malformed = subprocess.CompletedProcess(["gh"], 0, "not json", "")
        code, _, stderr, _ = run_cli({key("repos/o/r"): malformed}, "--url", RAW_URL, "--baseline-commit", BASELINE)
        self.assertEqual(code, 1)
        self.assertIn("malformed JSON", stderr)


class SafetyTests(unittest.TestCase):
    def test_only_metadata_endpoints_are_requested(self) -> None:
        endpoints: list[str] = []
        for scenario in SCENARIOS:
            responses, args = scenario()
            _, fake = run_report(responses, *args)
            self.assertGreaterEqual(len(fake.calls), 4, scenario.__name__)
            endpoints.extend(endpoint for endpoint, _ in fake.calls)

        self.assertTrue(any("/git/trees/" in endpoint for endpoint in endpoints))
        for endpoint in endpoints:
            with self.subTest(endpoint=endpoint):
                self.assertTrue(ALLOWED_ENDPOINT.fullmatch(endpoint))
                for fragment in FORBIDDEN:
                    self.assertNotIn(fragment, endpoint)


if __name__ == "__main__":
    unittest.main()
