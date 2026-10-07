"""Behavioral tests for the kramme:linear:issue-to-pr preflight helper.

Every Git check runs against a real temporary repository with a bare `origin`, and every GitHub check runs
against a fake `gh` placed first on PATH that records its argv and replays a configured response.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SKILL_DIR = Path(__file__).resolve().parents[2] / "skills" / "kramme:linear:issue-to-pr"
SCRIPT_PATH = SKILL_DIR / "scripts" / "preflight.py"
SPEC = importlib.util.spec_from_file_location("issue_to_pr_preflight", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)

BRANCH = "kramme/disc-1-add-widget"
GH_QUERY = ["pr", "list", "--head", BRANCH, "--state", "all", "--limit", "100"]
GH_QUERY += ["--json", "number,url,state,headRefName,headRefOid"]
FAKE_GH = """#!{python}
import json, os, sys
with open(os.environ["FAKE_GH_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
sys.stdout.write(os.environ["FAKE_GH_STDOUT"])
sys.stderr.write(os.environ["FAKE_GH_STDERR"])
sys.exit(int(os.environ["FAKE_GH_EXIT"]))
"""
REAL_GIT = shutil.which("git")
SYSTEM_TMP = tempfile.gettempdir()
# One committed repository plus bare `origin` per default branch, copied into each test because creating
# repositories dominates this suite's runtime. The work tree reaches its origin through `../origin.git`.
TEMPLATES: dict[str, Path] = {}
TEMPLATE_DIRECTORIES: list[tempfile.TemporaryDirectory[str]] = []


def tearDownModule() -> None:
    for directory in TEMPLATE_DIRECTORIES:
        directory.cleanup()


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def git_may_fail(cwd: Path, *args: str) -> int:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True).returncode


def template(default: str) -> Path:
    if default not in TEMPLATES:
        holder = tempfile.TemporaryDirectory(dir=SYSTEM_TMP)
        TEMPLATE_DIRECTORIES.append(holder)
        root = Path(holder.name).resolve()
        git(root, "init", "-q", "--bare", "-b", default, "origin.git")
        git(root, "init", "-q", "-b", default, "work")
        work = root / "work"
        for key, value in (("user.email", "test@example.com"), ("user.name", "Test"), ("commit.gpgsign", "false")):
            git(work, "config", key, value)
        (work / "tracked.txt").write_text("base\n", encoding="utf-8")
        git(work, "add", "tracked.txt")
        git(work, "commit", "-q", "-m", "initial")
        git(work, "remote", "add", "origin", "../origin.git")
        git(work, "push", "-q", "-u", "origin", default)
        git(work, "remote", "set-head", "origin", default)
        TEMPLATES[default] = root
    return TEMPLATES[default]


def origin_of(repo: Path) -> Path:
    return repo.parent / "origin.git"


def pull(state: str, number: int = 7, head: str = BRANCH) -> dict[str, Any]:
    url = f"https://github.com/acme/app/pull/{number}"
    return {"number": number, "url": url, "state": state, "headRefName": head, "headRefOid": "a" * 40}


class HelperCase(unittest.TestCase):
    def setUp(self) -> None:
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.tmp = Path(workspace.name).resolve()
        self.state_dir = self.tmp / "state"
        self.state_dir.mkdir()
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        fake_gh = bin_dir / "gh"
        fake_gh.write_text(FAKE_GH.format(python=sys.executable), encoding="utf-8")
        fake_gh.chmod(0o755)
        self.gh_log = self.tmp / "gh.log"
        global_config = self.tmp / "gitconfig"
        global_config.write_text("", encoding="utf-8")
        environment = {
            "PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}",
            "FAKE_GH_LOG": str(self.gh_log),
            "GIT_CONFIG_GLOBAL": str(global_config),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_EDITOR": "true",
            "CONDUCTOR_DEFAULT_BRANCH": "",
        }
        for patcher in (
            mock.patch.dict(os.environ, environment),
            mock.patch.object(tempfile, "tempdir", str(self.state_dir)),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)
        self.set_gh([])
        previous = os.getcwd()
        self.addCleanup(os.chdir, previous)

    def set_gh(self, payload: Any = None, raw: str | None = None, exit_code: int = 0, stderr: str = "") -> None:
        os.environ["FAKE_GH_STDOUT"] = json.dumps(payload) if raw is None else raw
        os.environ["FAKE_GH_EXIT"] = str(exit_code)
        os.environ["FAKE_GH_STDERR"] = stderr

    def gh_calls(self) -> list[list[str]]:
        if not self.gh_log.exists():
            return []
        return [json.loads(line) for line in self.gh_log.read_text(encoding="utf-8").splitlines()]

    def invoke(self, *argv: str) -> dict[str, Any]:
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = preflight.main(list(argv))
        output = stdout.getvalue()
        self.assertEqual(output.count("\n"), 1, output)
        payload: dict[str, Any] = json.loads(output)
        self.assertEqual(payload["schema_version"], 1)
        self.assertEqual(code, {"ok": 0, "blocked": 1, "error": 2}[payload["status"]], payload)
        return payload

    def start(self, raw: str) -> str:
        payload = self.invoke("args", "--", raw)
        self.assertEqual(payload["status"], "ok", payload)
        state_file: str = payload["state_file"]
        return state_file

    def capture(self, state: str) -> dict[str, Any]:
        return self.invoke("capture", "--state-file", state)

    def check(self, state: str, branch: str = BRANCH) -> dict[str, Any]:
        return self.invoke("check-branch", "--state-file", state, f"--branch={branch}")

    def assert_status(self, payload: dict[str, Any], status: str, reason: str | None = None) -> None:
        self.assertEqual((payload["status"], payload["reason"]), (status, reason), payload)


class RepoCase(HelperCase):
    def setUp(self) -> None:
        super().setUp()
        self.repo = self.make_repo("work")
        os.chdir(self.repo)

    def make_repo(self, name: str, default: str = "main") -> Path:
        shutil.copytree(template(default), self.tmp / name, symlinks=True)
        return self.tmp / name / "work"

    def write(self, repo: Path, path: str, content: str) -> None:
        target = repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def commit(self, repo: Path, message: str) -> str:
        git(repo, "add", "-A")
        git(repo, "commit", "-q", "--allow-empty", "-m", message)
        return git(repo, "rev-parse", "HEAD")

    def worktree_identity(self, repo: Path) -> tuple[str, str, str, str]:
        return (
            git(repo, "branch", "--show-current"),
            git(repo, "rev-parse", "HEAD"),
            git(repo, "status", "--porcelain=v1", "--untracked-files=all"),
            git(repo, "stash", "list"),
        )

    def continuation(self, repo: Path) -> str:
        """Put committed, staged, unstaged, and untracked issue work on the issue branch, then capture it."""
        os.chdir(repo)
        git(repo, "checkout", "-q", "-b", BRANCH)
        self.write(repo, "src/feature.txt", "feature\n")
        git(repo, "add", "src/feature.txt")
        git(repo, "commit", "-q", "-m", "DISC-1 add the widget")
        self.write(repo, "tracked.txt", "edited\n")
        self.write(repo, "staged.txt", "staged\n")
        git(repo, "add", "staged.txt")
        self.write(repo, "notes/todo.txt", "untracked\n")
        state = self.start("DISC-1 --continue")
        self.assert_status(self.capture(state), "ok")
        return state


class ArgumentTests(HelperCase):
    def test_defaults_normalize_the_issue_id_and_persist_private_state(self) -> None:
        payload = self.invoke("args", "--", "disc-202")
        expected = {
            "issue_id": "DISC-202",
            "continue_mode": False,
            "strict_review": False,
            "ship_mode": False,
            "cycles": 2,
            "cycles_explicit": False,
        }
        self.assertEqual({key: payload[key] for key in expected}, expected)
        state_file = Path(payload["state_file"])
        self.assertEqual(state_file.parent, self.state_dir)
        self.assertEqual(stat.S_IMODE(state_file.stat().st_mode), 0o600)
        self.assertEqual(json.loads(state_file.read_text(encoding="utf-8"))["args"], expected)

    def test_flags_parse_once_each_in_any_order(self) -> None:
        payload = self.invoke("args", "--", "--ship --cycles 5 abc-7 --strict --continue")
        self.assert_status(payload, "ok")
        self.assertEqual(payload["issue_id"], "ABC-7")
        self.assertTrue(payload["continue_mode"] and payload["strict_review"] and payload["ship_mode"])
        self.assertEqual((payload["cycles"], payload["cycles_explicit"]), (5, True))
        for value in "1234":
            self.assertEqual(self.invoke("args", "--", f"DISC-1 --cycles {value}")["cycles"], int(value))

    def test_split_and_joined_tokens_parse_identically(self) -> None:
        def facts(payload: dict[str, Any]) -> dict[str, Any]:
            return {key: value for key, value in payload.items() if key != "state_file"}

        joined = facts(self.invoke("args", "--", "DISC-9 --strict"))
        self.assertEqual(facts(self.invoke("args", "--", "DISC-9", "--strict")), joined)
        self.assertEqual(facts(self.invoke("args", " \tDISC-9\n --strict ")), joined)

    def test_invalid_arguments_are_rejected_without_state(self) -> None:
        cases = {
            "DISC-1 --ship --ship": "duplicate_flag",
            "--continue DISC-1 --continue": "duplicate_flag",
            "DISC-1 --cycles 2 --cycles 3": "duplicate_flag",
            "DISC-1 --force": "unknown_flag",
            "DISC-1 --cycles=3": "unknown_flag",
            "DISC-1 --STRICT": "unknown_flag",
            "DISC-1 -s": "unknown_flag",
            "-202": "unknown_flag",
            "DISC-1 --": "unknown_flag",
            "DISC-1 --cycles 0": "cycles_value_invalid",
            "DISC-1 --cycles 6": "cycles_value_invalid",
            "DISC-1 --cycles 10": "cycles_value_invalid",
            "DISC-1 --cycles -1": "cycles_value_invalid",
            "DISC-1 --cycles 3.5": "cycles_value_invalid",
            "DISC-1 --cycles 05": "cycles_value_invalid",
            "DISC-1 --cycles": "cycles_value_invalid",
            "--cycles --ship DISC-1": "cycles_value_invalid",
            "DISC-1 --cycles ３": "cycles_value_invalid",
            "DISC-1 --cycles ٣": "cycles_value_invalid",
            "": "issue_id_missing",
            "--ship --strict": "issue_id_missing",
            "DISC-1 DISC-2": "extra_positional",
            "DISC": "issue_id_invalid",
            "DISC-": "issue_id_invalid",
            "DISC_202": "issue_id_invalid",
            "DISC-20a": "issue_id_invalid",
            "DÏSC-1": "issue_id_invalid",
            "DISC-1;": "issue_id_invalid",
            "DISC-1'": "issue_id_invalid",
            "DISC-1 --ship": "issue_id_invalid",
        }
        for raw, reason in cases.items():
            with self.subTest(raw=raw):
                payload = self.invoke("args", "--", raw)
                self.assert_status(payload, "blocked", reason)
                self.assertEqual(payload["supported_flags"], ["--continue", "--strict", "--cycles <1-5>", "--ship"])
                self.assertNotIn("state_file", payload)
        self.assertEqual(list(self.state_dir.iterdir()), [])

    def test_state_directory_with_shell_sensitive_characters_is_refused(self) -> None:
        unsafe = self.tmp / "has space"
        unsafe.mkdir()
        with mock.patch.object(tempfile, "tempdir", str(unsafe)):
            payload = self.invoke("args", "--", "DISC-1")
        self.assert_status(payload, "error", "state_write_failed")
        self.assertEqual(list(unsafe.iterdir()), [])

    def test_helper_usage_errors_exit_two(self) -> None:
        for argv in ([], ["capture"], ["check-branch", "--state-file", "/tmp/x.json"], ["unknown"]):
            with self.subTest(argv=argv):
                self.assert_status(self.invoke(*argv), "error", "usage")

    def test_state_file_must_be_an_owned_helper_document(self) -> None:
        valid = Path(self.start("DISC-1"))
        document = json.loads(valid.read_text(encoding="utf-8"))
        candidates = {"missing": self.tmp / "missing.json", "relative": Path("state.json")}
        for name, content in (
            ("malformed", "{"),
            ("other-tool", json.dumps(dict(document, tool="other"))),
            ("bad-args", json.dumps(dict(document, args=dict(document["args"], cycles=9)))),
            ("old-schema", json.dumps(dict(document, schema_version=0))),
        ):
            candidates[name] = self.tmp / f"{name}.json"
            candidates[name].write_text(content, encoding="utf-8")
        candidates["symlink"] = self.tmp / "link.json"
        candidates["symlink"].symlink_to(valid)
        os.chdir(self.tmp)
        (self.tmp / "state.json").write_text(valid.read_text(encoding="utf-8"), encoding="utf-8")
        for name, path in candidates.items():
            with self.subTest(name=name):
                payload = self.capture(str(path))
                self.assert_status(payload, "error", "state_invalid")
                if name == "relative":
                    self.assertIn("not an absolute path", payload["message"])

    def test_cleanup_removes_only_a_helper_state_file(self) -> None:
        state = self.start("DISC-1")
        self.assert_status(self.invoke("cleanup", "--state-file", state), "ok")
        self.assertFalse(Path(state).exists())
        self.assert_status(self.invoke("cleanup", "--state-file", state), "error", "state_invalid")
        foreign = self.tmp / "foreign.json"
        foreign.write_text('{"keep": true}', encoding="utf-8")
        self.assert_status(self.invoke("cleanup", "--state-file", str(foreign)), "error", "state_invalid")
        self.assertTrue(foreign.exists())

    def test_unexpected_failures_still_print_one_error_document(self) -> None:
        with mock.patch.object(preflight, "parse_arguments", side_effect=RuntimeError("boom")):
            payload = self.invoke("args", "--", "DISC-1")
        self.assert_status(payload, "error", "internal_error")


class CaptureTests(RepoCase):
    def test_fresh_capture_records_the_entry_state(self) -> None:
        state = self.start("DISC-1")
        payload = self.capture(state)
        self.assert_status(payload, "ok")
        self.assertEqual(payload["entry_branch"], "main")
        self.assertEqual(payload["head"], git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual((payload["status_paths"], payload["git_operations"]), ([], []))
        saved = json.loads(Path(state).read_text(encoding="utf-8"))["capture"]
        self.assertEqual(saved["repo_root"], str(self.repo))

    def test_fresh_capture_requires_an_empty_status_and_clears_stale_capture(self) -> None:
        state = self.start("DISC-1")
        self.assert_status(self.capture(state), "ok")
        self.write(self.repo, "tracked.txt", "edited\n")
        self.write(self.repo, "staged.txt", "staged\n")
        git(self.repo, "add", "staged.txt")
        self.write(self.repo, "notes/todo.txt", "untracked\n")
        payload = self.capture(state)
        self.assert_status(payload, "blocked", "dirty_worktree")
        self.assertEqual(payload["details"]["status_paths"], ["notes/", "staged.txt", "tracked.txt"])
        self.assertNotIn("capture", json.loads(Path(state).read_text(encoding="utf-8")))
        self.assert_status(self.check(state), "error", "state_incomplete")

    def test_fresh_capture_sees_untracked_files_that_configuration_hides(self) -> None:
        git(self.repo, "config", "status.showUntrackedFiles", "no")
        self.write(self.repo, "notes/todo.txt", "untracked\n")
        payload = self.capture(self.start("DISC-1"))
        self.assert_status(payload, "blocked", "dirty_worktree")
        self.assertEqual(payload["details"]["status_paths"], ["notes/"])

    def test_fresh_capture_refuses_an_in_progress_operation_on_a_clean_tree(self) -> None:
        git(self.repo, "checkout", "-q", "--detach")
        git(self.repo, "bisect", "start")
        payload = self.capture(self.start("DISC-1"))
        self.assert_status(payload, "blocked", "git_operation_in_progress")
        self.assertEqual(payload["details"]["git_operations"], ["bisect"])

    def test_continue_capture_preserves_dirty_work_on_a_named_branch(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        self.write(self.repo, "tracked.txt", "edited\n")
        before = self.worktree_identity(self.repo)
        payload = self.capture(self.start("DISC-1 --continue"))
        self.assert_status(payload, "ok")
        self.assertEqual(payload["entry_branch"], BRANCH)
        self.assertEqual(payload["status_entries"], [{"xy": " M", "path": "tracked.txt"}])
        self.assertEqual(self.worktree_identity(self.repo), before)

    def test_continue_capture_requires_a_named_branch(self) -> None:
        git(self.repo, "checkout", "-q", "--detach")
        self.assert_status(self.capture(self.start("DISC-1 --continue")), "blocked", "detached_head")

    def test_continue_capture_refuses_each_in_progress_operation(self) -> None:
        def conflicting(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", "other")
            self.write(repo, "tracked.txt", "other\n")
            self.commit(repo, "other side")
            git(repo, "checkout", "-q", "-b", BRANCH, "main")
            self.write(repo, "tracked.txt", "feature\n")
            self.commit(repo, "feature side")

        def merge(repo: Path) -> None:
            conflicting(repo)
            self.assertEqual(git_may_fail(repo, "merge", "--no-edit", "other"), 1)

        def rebase(repo: Path) -> None:
            conflicting(repo)
            self.assertNotEqual(git_may_fail(repo, "rebase", "other"), 0)

        def cherry_pick(repo: Path) -> None:
            conflicting(repo)
            self.assertNotEqual(git_may_fail(repo, "cherry-pick", "other"), 0)

        def revert(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", BRANCH)
            self.write(repo, "tracked.txt", "first\n")
            first = self.commit(repo, "first")
            self.write(repo, "tracked.txt", "second\n")
            self.commit(repo, "second")
            self.assertNotEqual(git_may_fail(repo, "revert", "--no-edit", first), 0)

        def bisect(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", BRANCH)
            git(repo, "bisect", "start")

        def am(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", BRANCH)
            (repo / ".git" / "rebase-apply").mkdir()
            (repo / ".git" / "rebase-apply" / "applying").write_text("", encoding="utf-8")

        def sequencer(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", BRANCH)
            (repo / ".git" / "sequencer").mkdir()

        cases = {
            "merge": merge,
            "rebase": rebase,
            "cherry-pick": cherry_pick,
            "revert": revert,
            "bisect": bisect,
            "am": am,
            "sequencer": sequencer,
        }
        for operation, prepare in cases.items():
            with self.subTest(operation=operation):
                repo = self.make_repo(f"op-{operation}")
                os.chdir(repo)
                prepare(repo)
                payload = self.capture(self.start("DISC-1 --continue"))
                self.assert_status(payload, "blocked", "git_operation_in_progress")
                self.assertIn(operation, payload["details"]["git_operations"])

    def test_continue_capture_refuses_unmerged_paths_without_an_operation(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        blob = git(self.repo, "hash-object", "-w", "tracked.txt")
        stages = "".join(f"100644 {blob} {stage}\ttracked.txt\n" for stage in (1, 2, 3))
        index_info = f"0 {'0' * 40}\ttracked.txt\n{stages}"
        subprocess.run(["git", "update-index", "--index-info"], cwd=self.repo, input=index_info, text=True, check=True)
        payload = self.capture(self.start("DISC-1 --continue"))
        self.assert_status(payload, "blocked", "unmerged_paths")
        self.assertEqual(payload["details"]["unmerged_paths"], ["tracked.txt"])
        self.assertEqual(payload["details"]["git_operations"], [])

    def test_capture_outside_a_repository_fails_closed(self) -> None:
        outside = self.tmp / "outside"
        outside.mkdir()
        os.chdir(outside)
        self.assert_status(self.capture(self.start("DISC-1")), "blocked", "git_failed")


class FreshBranchTests(RepoCase):
    def setUp(self) -> None:
        super().setUp()
        self.state = self.start("DISC-1")
        self.assert_status(self.capture(self.state), "ok")

    def test_unpublished_branch_passes_without_touching_the_worktree(self) -> None:
        before = self.worktree_identity(self.repo)
        payload = self.check(self.state)
        self.assert_status(payload, "ok")
        self.assertEqual((payload["pull_requests"], payload["remote_branch"]), ([], "absent"))
        self.assertFalse(payload["continue_mode"])
        self.assertNotIn("continue_base_commit", payload)
        self.assertEqual(self.gh_calls(), [GH_QUERY])
        self.assertEqual(self.worktree_identity(self.repo), before)
        self.assertEqual(git(self.repo, "branch", "--list"), "* main")

    def test_names_outside_the_allowlist_are_refused_before_any_query(self) -> None:
        names = ["feat;touch pwned", "a$(touch pwned)", "a`touch pwned`", "a|b", "a&b", "a>b", "a b", "a\tb", "a\nb"]
        names += ["-a", "", ".hidden", "ä-branch", "a\\b", "a'b", 'a"b', "a*b", "a?b", "a:b", "a~1", "a^", "a@{1}"]
        for name in names:
            with self.subTest(name=name):
                self.assert_status(self.check(self.state, name), "blocked", "branch_name_invalid")
        self.assertEqual(self.gh_calls(), [])
        self.assertFalse((self.repo / "pwned").exists())

    def test_names_git_rejects_are_refused_before_any_query(self) -> None:
        for name in ("a..b", "a.lock", "a/", "a//b", "a/.b", "a.", "a/b.lock", "HEAD"):
            with self.subTest(name=name):
                payload = self.check(self.state, name)
                self.assert_status(payload, "blocked", "branch_ref_format_invalid")
                self.assertIn("not a valid branch name", payload["details"]["stderr"])
        self.assertEqual(self.gh_calls(), [])

    def test_github_failures_are_blockers_not_evidence_of_absence(self) -> None:
        git(self.repo, "remote", "set-url", "origin", str(self.tmp / "missing-origin.git"))
        cases = [
            ({"raw": "", "exit_code": 4, "stderr": "authentication required"}, "gh_failed"),
            ({"raw": "not json"}, "gh_output_malformed"),
            ({"payload": {"number": 1}}, "gh_output_malformed"),
            ({"payload": [1]}, "gh_output_malformed"),
            ({"payload": [pull("DRAFT")]}, "gh_output_malformed"),
            ({"payload": [pull("OPEN", head="other")]}, "gh_output_malformed"),
            ({"payload": [dict(pull("OPEN"), state=["OPEN"])]}, "gh_output_malformed"),
        ]
        for response, reason in cases:
            with self.subTest(response=response):
                self.set_gh(**response)
                self.assert_status(self.check(self.state), "blocked", reason)
        git_only = self.tmp / "git-only"
        git_only.mkdir()
        assert REAL_GIT is not None
        (git_only / "git").symlink_to(REAL_GIT)
        with mock.patch.dict(os.environ, {"PATH": str(git_only)}):
            self.assert_status(self.check(self.state), "blocked", "gh_failed")

    def test_existing_pull_requests_route_by_state(self) -> None:
        cases = [
            ([pull("OPEN")], "pull_request_open"),
            ([pull("CLOSED")], "pull_request_closed"),
            ([pull("MERGED")], "pull_request_closed"),
            ([pull("CLOSED", 1), pull("OPEN", 2)], "pull_request_open"),
        ]
        for pulls, reason in cases:
            with self.subTest(states=[item["state"] for item in pulls]):
                self.set_gh(pulls)
                payload = self.check(self.state)
                self.assert_status(payload, "blocked", reason)
                self.assertEqual(payload["details"]["pull_requests"], pulls)

    def test_existing_remote_branch_blocks(self) -> None:
        pushed = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "push", "-q", "origin", f"HEAD:refs/heads/{BRANCH}")
        payload = self.check(self.state)
        self.assert_status(payload, "blocked", "remote_branch_exists")
        self.assertEqual(payload["details"], {"ref": f"refs/heads/{BRANCH}", "object_id": pushed})

    def test_failed_or_ambiguous_ls_remote_blocks(self) -> None:
        origin = str(origin_of(self.repo))
        head = git(self.repo, "rev-parse", "HEAD")
        git(self.tmp, "--git-dir", origin, "update-ref", f"refs/heads/refs/heads/{BRANCH}", head)
        self.assert_status(self.check(self.state), "blocked", "ls_remote_malformed")
        git(self.tmp, "--git-dir", origin, "update-ref", f"refs/heads/{BRANCH}", head)
        self.assert_status(self.check(self.state), "blocked", "ls_remote_malformed")
        git(self.repo, "remote", "set-url", "origin", str(self.tmp / "missing-origin.git"))
        self.assert_status(self.check(self.state), "blocked", "ls_remote_failed")

    def test_remote_ref_parser_accepts_only_zero_lines_or_one_exact_line(self) -> None:
        sha1 = re.compile("[0-9a-f]{40}")
        ref = "refs/heads/x"
        self.assertIsNone(preflight.remote_ref_object(b"", ref, sha1))
        self.assertEqual(preflight.remote_ref_object(f"{'a' * 40}\t{ref}\n".encode(), ref, sha1), "a" * 40)
        malformed = ["\n", f"abc\t{ref}\n", f"{'A' * 40}\t{ref}\n", f"{'a' * 40} {ref}\n", f"{'a' * 40}\t{ref}"]
        malformed += [f"{'a' * 40}\t{ref}\n" * 2, f"{'a' * 40}\trefs/heads/y\n", f"{'a' * 40}\t{ref}\tx\n"]
        malformed += [f"{'a' * 64}\t{ref}\n"]
        for output in malformed:
            with self.subTest(output=output):
                with self.assertRaises(preflight.Stop) as raised:
                    preflight.remote_ref_object(output.encode(), ref, sha1)
                self.assertEqual(raised.exception.reason, "ls_remote_malformed")

    def test_check_branch_refuses_a_different_worktree(self) -> None:
        os.chdir(self.make_repo("elsewhere"))
        self.assert_status(self.check(self.state), "blocked", "repository_changed")


class ContinueBranchTests(RepoCase):
    def test_continuation_returns_the_resume_handoff_after_fetching_the_base(self) -> None:
        fork_point = git(self.repo, "rev-parse", "main")
        state = self.continuation(self.repo)
        upstream = self.tmp / "upstream"
        git(self.tmp, "clone", "-q", str(origin_of(self.repo)), str(upstream))
        git(
            upstream, "-c", "user.email=u@example.com", "-c", "user.name=U", "commit", "-q", "--allow-empty", "-m", "up"
        )
        git(upstream, "push", "-q", "origin", "main")
        before = self.worktree_identity(self.repo)
        payload = self.check(state)
        self.assert_status(payload, "ok")
        self.assertEqual((payload["base_branch"], payload["continue_base_commit"]), ("main", fork_point))
        self.assertEqual(payload["entry_head"], git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(payload["committed_paths"], ["src/feature.txt"])
        # issue-implement recomputes these with the helper's STATUS_ARGS and COMMITTED_DIFF_ARGS commands.
        self.assertEqual(payload["dirty_paths"], ["notes/", "staged.txt", "tracked.txt"])
        self.assertEqual(git(self.repo, "rev-parse", "refs/remotes/origin/main"), git(upstream, "rev-parse", "HEAD"))
        self.assertEqual(self.worktree_identity(self.repo), before)

    def test_continuation_paths_ignore_untracked_file_configuration(self) -> None:
        for setting in ("all", "no"):
            with self.subTest(setting=setting):
                repo = self.make_repo(f"untracked-{setting}")
                git(repo, "config", "status.showUntrackedFiles", setting)
                payload = self.check(self.continuation(repo))
                self.assert_status(payload, "ok")
                self.assertEqual(payload["dirty_paths"], ["notes/", "staged.txt", "tracked.txt"])
                self.assertEqual(payload["committed_paths"], ["src/feature.txt"])

    def test_continuation_accepts_committed_only_or_dirty_only_work(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        self.write(self.repo, "src/feature.txt", "feature\n")
        self.commit(self.repo, "DISC-1 add the widget")
        state = self.start("DISC-1 --continue")
        self.assert_status(self.capture(state), "ok")
        payload = self.check(state)
        self.assertEqual((payload["committed_paths"], payload["dirty_paths"]), (["src/feature.txt"], []))
        git(self.repo, "reset", "-q", "--hard", "main")
        self.write(self.repo, "tracked.txt", "edited\n")
        self.assert_status(self.capture(state), "ok")
        payload = self.check(state)
        self.assertEqual((payload["committed_paths"], payload["dirty_paths"]), ([], ["tracked.txt"]))

    def test_continuation_requires_local_work(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        state = self.start("DISC-1 --continue")
        self.assert_status(self.capture(state), "ok")
        self.assert_status(self.check(state), "blocked", "no_local_changes")

    def test_continuation_requires_the_entry_branch_to_be_the_issue_branch(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "kramme/other-work")
        self.write(self.repo, "tracked.txt", "edited\n")
        state = self.start("DISC-1 --continue")
        self.assert_status(self.capture(state), "ok")
        payload = self.check(state)
        self.assert_status(payload, "blocked", "continue_branch_mismatch")
        self.assertEqual(payload["details"], {"entry_branch": "kramme/other-work", "issue_branch": BRANCH})
        self.assertEqual(self.gh_calls(), [])

    def test_continuation_resolves_origin_head_then_verified_main_then_master(self) -> None:
        def set_head_develop(repo: Path) -> None:
            git(repo, "push", "-q", "origin", "main:develop")
            git(repo, "fetch", "-q", "origin")
            git(repo, "remote", "set-head", "origin", "develop")

        cases = [
            ("main", lambda repo: None, "main"),
            ("main", set_head_develop, "develop"),
            ("main", lambda repo: git(repo, "remote", "set-head", "origin", "-d"), "main"),
            ("master", lambda repo: git(repo, "remote", "set-head", "origin", "-d"), "master"),
        ]
        for index, (default, adjust, expected) in enumerate(cases):
            with self.subTest(expected=expected, default=default):
                repo = self.make_repo(f"base-{index}", default)
                adjust(repo)
                payload = self.check(self.continuation(repo))
                self.assert_status(payload, "ok")
                self.assertEqual(payload["base_branch"], expected)

    def test_continuation_uses_conductor_workbench_before_production_main(self) -> None:
        git(self.repo, "push", "-q", "origin", "main:development")
        git(self.repo, "fetch", "-q", "origin")
        os.environ["CONDUCTOR_DEFAULT_BRANCH"] = "development"
        payload = self.check(self.continuation(self.repo))
        self.assert_status(payload, "ok")
        self.assertEqual(payload["base_branch"], "development")

    def test_continuation_uses_repository_setting_before_conductor_workbench(self) -> None:
        git(self.repo, "push", "-q", "origin", "main:development")
        git(self.repo, "fetch", "-q", "origin")
        git(self.repo, "config", "--local", "kramme.baseBranch", "development")
        os.environ["CONDUCTOR_DEFAULT_BRANCH"] = "main"
        payload = self.check(self.continuation(self.repo))
        self.assert_status(payload, "ok")
        self.assertEqual(payload["base_branch"], "development")

    def test_continuation_refuses_an_unresolvable_base(self) -> None:
        trunk = self.make_repo("trunk", "trunk")
        git(trunk, "remote", "set-head", "origin", "-d")
        self.assert_status(self.check(self.continuation(trunk)), "blocked", "base_unresolved")
        foreign = self.make_repo("foreign")
        git(foreign, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/heads/main")
        self.assert_status(self.check(self.continuation(foreign)), "blocked", "base_unresolved")

    def test_continuation_refuses_a_base_that_cannot_be_fetched(self) -> None:
        git(self.repo, "push", "-q", "origin", "main:gone")
        git(self.repo, "fetch", "-q", "origin")
        git(self.repo, "remote", "set-head", "origin", "gone")
        git(self.tmp, "--git-dir", str(origin_of(self.repo)), "branch", "-q", "-D", "gone")
        self.assert_status(self.check(self.continuation(self.repo)), "blocked", "base_fetch_failed")

    def test_continuation_refuses_entry_state_changes_after_capture(self) -> None:
        def stage(repo: Path) -> None:
            git(repo, "add", "tracked.txt")

        def untracked(repo: Path) -> None:
            self.write(repo, "late.txt", "late\n")

        def commit(repo: Path) -> None:
            self.commit(repo, "late commit")

        def switch(repo: Path) -> None:
            git(repo, "checkout", "-q", "-b", "kramme/elsewhere")

        def bisect(repo: Path) -> None:
            git(repo, "bisect", "start")

        cases = [
            (stage, ["status_entries"]),
            (untracked, ["status_entries"]),
            (commit, ["head", "status_entries"]),
            (switch, ["branch"]),
            (bisect, ["git_operations"]),
        ]
        for change, fields in cases:
            with self.subTest(change=change.__name__):
                repo = self.make_repo(f"changed-{change.__name__}")
                state = self.continuation(repo)
                change(repo)
                payload = self.check(state)
                self.assert_status(payload, "blocked", "worktree_changed")
                self.assertEqual(payload["details"]["changed"], fields)

    def test_continuation_requires_shared_history_with_the_base(self) -> None:
        git(self.repo, "checkout", "-q", "--orphan", BRANCH)
        self.commit(self.repo, "unrelated root")
        state = self.start("DISC-1 --continue")
        self.assert_status(self.capture(state), "ok")
        self.assert_status(self.check(state), "blocked", "merge_base_unresolved")

    def test_continuation_requires_the_merge_base_to_be_an_ancestor(self) -> None:
        state = self.continuation(self.repo)
        real_git = preflight.git

        def not_an_ancestor(root: Path | None, *args: str, **options: Any) -> Any:
            if args[:2] == ("merge-base", "--is-ancestor"):
                return subprocess.CompletedProcess(["git", *args], 1, b"", b"")
            return real_git(root, *args, **options)

        with mock.patch.object(preflight, "git", side_effect=not_an_ancestor):
            self.assert_status(self.check(state), "blocked", "merge_base_not_ancestor")


class SkillContractTests(unittest.TestCase):
    def test_skill_invokes_each_helper_subcommand_in_order_through_the_plugin_root(self) -> None:
        text = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
        prefix = re.escape('python3 "${CLAUDE_PLUGIN_ROOT}/skills/kramme:linear:issue-to-pr/scripts/preflight.py" ')
        invoked = list(dict.fromkeys(re.findall(prefix + r"([a-z-]+)", text)))
        self.assertEqual(invoked, ["args", "capture", "check-branch", "cleanup"])
        parser = preflight.build_parser()
        subcommands = next(
            action for action in parser._actions if isinstance(action, preflight.argparse._SubParsersAction)
        )
        self.assertEqual(set(subcommands.choices), set(invoked))

    def test_skill_reads_only_fields_and_reasons_the_helper_emits(self) -> None:
        text = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
        preflight_text = text[text.index("## Step 1:") : text.index("7. Re-fetch `{issue-id}`")]
        names = set(re.findall(r"`([a-z]+(?:_[a-z]+)+)`", preflight_text))
        self.assertTrue({"state_file", "pull_request_open", "remote_branch_exists", "dirty_paths"} <= names, names)
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        self.assertEqual(sorted(name for name in names if f'"{name}"' not in source), [])

    def test_skill_treats_any_non_ok_helper_result_as_a_blocker(self) -> None:
        text = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
        self.assertRegex(text, r"For every helper call[^.]*`status` other than `ok` is a blocker")

    def test_issue_implement_recomputes_the_handoff_with_the_helper_commands(self) -> None:
        setup = SKILL_DIR.parent / "kramme:linear:issue-implement" / "references" / "branch-setup.md"
        text = setup.read_text(encoding="utf-8")
        self.assertIn("`git " + " ".join(preflight.STATUS_ARGS) + "`", text)
        self.assertIn("`git " + " ".join(preflight.COMMITTED_DIFF_ARGS) + " <captured base> HEAD`", text)

    def test_argument_hint_lists_exactly_the_supported_flags(self) -> None:
        text = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
        hint = re.search(r'^argument-hint: "(.*)"$', text, re.MULTILINE)
        assert hint is not None
        self.assertEqual(re.findall(r"\[(--[^\]]+)\]", hint.group(1)), preflight.SUPPORTED_FLAGS)


if __name__ == "__main__":
    unittest.main()
