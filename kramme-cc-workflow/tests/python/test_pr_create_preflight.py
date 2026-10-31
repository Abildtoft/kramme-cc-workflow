"""Behavioral tests for the kramme:pr:create preflight helper.

Every Git check runs against a real temporary repository with a bare `origin`, and every GitHub check runs
against a fake `gh` placed first on PATH that records its argv and replays configured responses. Stack
membership runs the real shared resolver against that fake `gh`.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SKILL_DIR = Path(__file__).resolve().parents[2] / "skills" / "kramme:pr:create"
SCRIPT_PATH = SKILL_DIR / "scripts" / "pr-create-preflight.py"
SPEC = importlib.util.spec_from_file_location("pr_create_preflight", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)

BRANCH = "kramme/disc-1-add-widget"
FAKE_GH = """#!{python}
import json, os, subprocess, sys
args = sys.argv[1:]
with open(os.environ["FAKE_GH_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["auth", "status"]:
    sys.exit(int(os.environ.get("FAKE_GH_AUTH_EXIT", "0")))
if args[:2] == ["pr", "view"]:
    branch = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
    sys.stderr.write('no pull requests found for branch "%s"' % branch)
    sys.exit(1)
if args[:2] == ["pr", "list"] and "--jq" in args:
    sys.exit(0)
if args[:2] == ["pr", "list"]:
    sys.stdout.write(os.environ.get("FAKE_GH_PR_LIST", "[]"))
    sys.exit(int(os.environ.get("FAKE_GH_PR_LIST_EXIT", "0")))
if args[:2] == ["stack", "--version"] and os.environ.get("FAKE_GH_STACK_JSON"):
    print("gh stack version 0.1.0")
    sys.exit(0)
if args[:3] == ["stack", "view", "--json"]:
    print(os.environ["FAKE_GH_STACK_JSON"])
    sys.exit(0)
sys.exit(97)
"""
SYSTEM_TMP = tempfile.gettempdir()
TEMPLATES: dict[str, Path] = {}
TEMPLATE_DIRECTORIES: list[tempfile.TemporaryDirectory[str]] = []


def tearDownModule() -> None:
    for directory in TEMPLATE_DIRECTORIES:
        directory.cleanup()


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def template() -> Path:
    """One committed repository plus bare `origin`, copied into each test; the clone reaches `../origin.git`."""
    if "main" not in TEMPLATES:
        holder = tempfile.TemporaryDirectory(dir=SYSTEM_TMP)
        TEMPLATE_DIRECTORIES.append(holder)
        root = Path(holder.name).resolve()
        git(root, "init", "-q", "--bare", "-b", "main", "origin.git")
        git(root, "init", "-q", "-b", "main", "work")
        work = root / "work"
        for key, value in (("user.email", "test@example.com"), ("user.name", "Test"), ("commit.gpgsign", "false")):
            git(work, "config", key, value)
        (work / "tracked.txt").write_text("base\n", encoding="utf-8")
        git(work, "add", "tracked.txt")
        git(work, "commit", "-q", "-m", "initial")
        git(work, "remote", "add", "origin", "../origin.git")
        git(work, "push", "-q", "-u", "origin", "main")
        git(work, "remote", "set-head", "origin", "main")
        TEMPLATES["main"] = root
    return TEMPLATES["main"]


class PreflightCase(unittest.TestCase):
    def setUp(self) -> None:
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.tmp = Path(workspace.name).resolve()
        self.bin_dir = self.tmp / "bin"
        self.bin_dir.mkdir()
        fake_gh = self.bin_dir / "gh"
        fake_gh.write_text(FAKE_GH.format(python=sys.executable), encoding="utf-8")
        fake_gh.chmod(0o755)
        self.gh_log = self.tmp / "gh.log"
        global_config = self.tmp / "gitconfig"
        global_config.write_text("", encoding="utf-8")
        environment = {
            "PATH": f"{self.bin_dir}{os.pathsep}{os.environ.get('PATH', '')}",
            "FAKE_GH_LOG": str(self.gh_log),
            "GIT_CONFIG_GLOBAL": str(global_config),
            "GIT_CONFIG_NOSYSTEM": "1",
            "CONDUCTOR_DEFAULT_BRANCH": "",
            "FAKE_GH_PR_LIST": "[]",
            "FAKE_GH_STACK_JSON": "",
        }
        patcher = mock.patch.dict(os.environ, environment)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(os.chdir, os.getcwd())
        shutil.copytree(template(), self.tmp / "repo", symlinks=True)
        self.repo = self.tmp / "repo" / "work"
        self.origin = self.tmp / "repo" / "origin.git"
        os.chdir(self.repo)

    def invoke(self, *argv: str) -> dict[str, Any]:
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = preflight.main(list(argv))
        output = stdout.getvalue()
        self.assertEqual(output.count("\n"), 1, output)
        payload: dict[str, Any] = json.loads(output)
        self.assertEqual(payload["schema_version"], 1)
        self.assertEqual(code, preflight.EXIT_CODES[payload["status"]], payload)
        return payload

    def assert_status(self, payload: dict[str, Any], status: str, reason: str | None = None) -> None:
        self.assertEqual((payload["status"], payload["reason"]), (status, reason), payload)

    def gh_calls(self) -> list[list[str]]:
        if not self.gh_log.exists():
            return []
        return [json.loads(line) for line in self.gh_log.read_text(encoding="utf-8").splitlines()]

    def write(self, path: str, content: str) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def commit(self, message: str, path: str = "src/feature.txt") -> str:
        self.write(path, message + "\n")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", message)
        return git(self.repo, "rev-parse", "HEAD")

    def feature(self, message: str = "Add the widget") -> str:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        return self.commit(message)

    def identity(self) -> tuple[str, ...]:
        return (
            git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)"),
            git(self.repo, "symbolic-ref", "-q", "HEAD") if git(self.repo, "branch", "--show-current") else "",
            git(self.repo, "rev-parse", "HEAD"),
            git(self.repo, "status", "--porcelain", "--untracked-files=all"),
            git(self.repo, "config", "--local", "--list"),
            git(self.repo, "stash", "list"),
            git(self.origin, "for-each-ref", "--format=%(refname) %(objectname)"),
        )


class StepOneTests(PreflightCase):
    def test_missing_gh_blocks_before_any_other_check(self) -> None:
        git_only = self.tmp / "git-only"
        git_only.mkdir()
        real_git = shutil.which("git")
        assert real_git is not None
        (git_only / "git").symlink_to(real_git)
        with mock.patch.dict(os.environ, {"PATH": str(git_only)}):
            payload = self.invoke()
        self.assert_status(payload, "blocked", "gh_missing")
        self.assertIn("MISSING REQUIREMENT: gh CLI not installed", payload["message"])

    def test_unauthenticated_host_is_derived_from_each_origin_form_without_printing_the_url(self) -> None:
        os.environ["FAKE_GH_AUTH_EXIT"] = "1"
        cases = {
            "https://user:secret@ghe.example.com/acme/app.git": "ghe.example.com",
            "ssh://git@ghe.example.com:2222/acme/app.git": "ghe.example.com:2222",
            "git@ghe.example.com:acme/app.git": "ghe.example.com",
            "/srv/git/app.git": "github.com",
        }
        for url, host in cases.items():
            with self.subTest(url=url):
                git(self.repo, "remote", "set-url", "origin", url)
                self.gh_log.unlink(missing_ok=True)
                payload = self.invoke()
                self.assert_status(payload, "blocked", "gh_unauthenticated")
                self.assertEqual(payload["facts"]["gh_host"], host)
                self.assertIn(f"gh auth login --hostname {host}", payload["message"])
                self.assertEqual(self.gh_calls(), [["auth", "status", "--active", "--hostname", host]])
                self.assertNotIn("acme", json.dumps(payload))
                self.assertNotIn("secret", json.dumps(payload))

    def test_outside_a_repository_blocks(self) -> None:
        os.chdir(self.tmp)
        self.assert_status(self.invoke(), "blocked", "not_a_repository")

    def test_missing_origin_blocks(self) -> None:
        git(self.repo, "remote", "remove", "origin")
        self.assert_status(self.invoke(), "blocked", "origin_missing")
        self.assertEqual(self.gh_calls(), [])

    def test_unmerged_paths_block(self) -> None:
        self.feature()
        git(self.repo, "checkout", "-q", "main")
        self.commit("Conflict on main")
        subprocess.run(["git", "merge", "-q", BRANCH], cwd=self.repo, capture_output=True)
        payload = self.invoke()
        self.assert_status(payload, "blocked", "merge_conflict")
        self.assertEqual(payload["details"]["conflicted_paths"], ["src/feature.txt"])

    def test_rebase_in_progress_inside_a_linked_worktree_blocks(self) -> None:
        linked = self.tmp / "linked"
        git(self.repo, "worktree", "add", "-q", "-b", BRANCH, str(linked))
        self.assertTrue((linked / ".git").is_file())
        os.chdir(linked)
        marker = Path(git(linked, "rev-parse", "--path-format=absolute", "--git-path", "rebase-merge"))
        self.assertIn("worktrees", marker.parts)
        marker.mkdir()
        payload = self.invoke()
        self.assert_status(payload, "blocked", "operation_in_progress")
        self.assertEqual(payload["details"]["operations"], ["rebase"])
        marker.rmdir()
        (Path(git(linked, "rev-parse", "--path-format=absolute", "--git-path", "CHERRY_PICK_HEAD"))).write_text(
            git(linked, "rev-parse", "HEAD") + "\n", encoding="utf-8"
        )
        self.assertEqual(self.invoke()["details"]["operations"], ["cherry-pick"])


class BranchTests(PreflightCase):
    def test_current_feature_branch_with_absent_remote_is_fresh(self) -> None:
        head = self.feature()
        payload = self.invoke()
        self.assert_status(payload, "ok")
        facts = payload["facts"]
        base = git(self.repo, "rev-parse", "refs/remotes/origin/main")
        self.assertEqual(
            {key: facts[key] for key in ("entry_branch", "entry_commit", "feature_branch", "branch_action")},
            {"entry_branch": BRANCH, "entry_commit": head, "feature_branch": BRANCH, "branch_action": "use-current"},
        )
        self.assertEqual(
            (facts["base_source_ref"], facts["base_ref"], facts["base_branch"]),
            ("refs/remotes/origin/main", base, "main"),
        )
        self.assertEqual((facts["remote_mode"], facts["observed_origin_oid"]), ("fresh", None))
        self.assertEqual((facts["stack_membership"], facts["ahead_count"], facts["worktree_status"]), ("none", 1, ""))
        self.assertEqual(facts["linear_issue_id"], "DISC-1")
        self.assertIn(
            [
                "pr",
                "list",
                "--head",
                BRANCH,
                "--state",
                "open",
                "--limit",
                "100",
                "--json",
                "number,url,state,headRefName",
            ],
            self.gh_calls(),
        )

    def test_linear_override_wins_over_the_branch_name(self) -> None:
        self.feature()
        self.assertEqual(self.invoke("--linear-issue", "abc-42")["facts"]["linear_issue_id"], "ABC-42")
        self.assert_status(self.invoke("--linear-issue", "ABC_42"), "error", "usage")

    def test_explicit_base_is_resolved_and_pinned_to_a_full_object_id(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "develop")
        develop = self.commit("Start develop", "develop.txt")
        git(self.repo, "push", "-q", "origin", "develop")
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        self.commit("Add the widget")
        git(self.repo, "update-ref", "-d", "refs/remotes/origin/develop")
        facts = self.invoke("--base", "develop")["facts"]
        self.assertEqual(
            (facts["base_source_ref"], facts["base_ref"], facts["base_branch"], facts["ahead_count"]),
            ("refs/remotes/origin/develop", develop, "develop", 1),
        )

    def test_detached_entry_requires_a_feature_branch_name_then_creates_from_entry_head(self) -> None:
        self.feature()
        git(self.repo, "checkout", "-q", "--detach")
        self.write("notes/untracked.txt", "new\n")
        payload = self.invoke()
        self.assert_status(payload, "feature_branch_required", "feature_branch_required")
        self.assertEqual(payload["facts"]["entry_branch"], None)
        self.assertEqual(payload["facts"]["changed_paths"], ["notes/untracked.txt", "src/feature.txt"])
        payload = self.invoke("--feature-branch", "feature/widget")
        self.assert_status(payload, "ok")
        facts = payload["facts"]
        self.assertEqual(
            (facts["feature_branch"], facts["branch_action"]), ("feature/widget", "create-from-entry-head")
        )
        self.assertEqual((facts["remote_mode"], facts["stack_membership"]), ("fresh", "none"))
        self.assertEqual(git(self.repo, "branch", "--list", "feature/widget"), "")

    def test_entry_on_the_base_requires_a_feature_branch(self) -> None:
        self.commit("Work on main")
        payload = self.invoke()
        self.assert_status(payload, "feature_branch_required", "feature_branch_required")
        self.assertEqual(payload["facts"]["changed_paths"], ["src/feature.txt"])
        self.assert_status(self.invoke("--feature-branch", "main"), "blocked", "feature_branch_protected")

    def test_protected_branch_that_differs_from_the_base_blocks(self) -> None:
        for name, setup in (("master", None), ("release", "kramme"), ("prod", "conductor")):
            with self.subTest(name=name):
                git(self.repo, "checkout", "-q", "-B", name, "main")
                self.commit(f"Work on {name}")
                if setup == "kramme":
                    git(self.repo, "config", "--local", "kramme.baseBranch", name)
                    payload = self.invoke("--base", "main")
                    git(self.repo, "config", "--local", "--unset", "kramme.baseBranch")
                elif setup == "conductor":
                    with mock.patch.dict(os.environ, {"CONDUCTOR_DEFAULT_BRANCH": name}):
                        payload = self.invoke()
                else:
                    payload = self.invoke()
                self.assert_status(payload, "blocked", "protected_branch_conflict")

    def test_hostile_names_are_rejected_without_execution(self) -> None:
        self.commit("Work on main")
        canary = self.tmp / "pwned"
        for name in (f"$(touch {canary})", f"x;touch {canary}", "-rf", "a b", "feature/`id`"):
            with self.subTest(name=name):
                self.assert_status(self.invoke(f"--feature-branch={name}"), "blocked", "feature_branch_invalid")
                self.assert_status(self.invoke(f"--base={name}"), "blocked", "base_override_invalid")
        self.assert_status(self.invoke("--feature-branch", "feature..x"), "blocked", "feature_branch_invalid")
        self.assertFalse(canary.exists())

    def test_feature_branch_flag_must_match_the_current_feature_branch(self) -> None:
        self.feature()
        self.assert_status(self.invoke("--feature-branch", "other"), "blocked", "feature_branch_mismatch")
        self.assert_status(self.invoke("--feature-branch", BRANCH), "ok")

    def test_a_different_local_branch_with_the_selected_name_blocks(self) -> None:
        self.feature()
        git(self.repo, "checkout", "-q", "--detach")
        self.assert_status(self.invoke("--feature-branch", BRANCH), "blocked", "local_branch_exists")

    def test_a_remote_branch_that_is_not_current_blocks(self) -> None:
        self.feature()
        git(self.repo, "push", "-q", "origin", "HEAD:refs/heads/elsewhere")
        git(self.repo, "checkout", "-q", "--detach")
        self.assert_status(self.invoke("--feature-branch", "elsewhere"), "blocked", "remote_branch_not_current")


class RemoteModeTests(PreflightCase):
    def test_exact_tip_clean_is_recovery(self) -> None:
        head = self.feature()
        git(self.repo, "push", "-q", "origin", BRANCH)
        payload = self.invoke()
        self.assert_status(payload, "ok")
        facts = payload["facts"]
        self.assertEqual(
            (facts["branch_action"], facts["observed_origin_oid"], facts["remote_mode"]),
            ("reuse-existing-exact-tip", head, "recovery"),
        )
        self.assertNotIn("unpublished_commits", facts)

    def test_exact_tip_dirty_blocks_under_manual_and_needs_classification_by_default(self) -> None:
        self.feature()
        git(self.repo, "push", "-q", "origin", BRANCH)
        self.write("tracked.txt", "dirty\n")
        self.assert_status(self.invoke("--manual"), "blocked", "dirty_existing_remote")
        payload = self.invoke()
        self.assert_status(payload, "remote_classification_required", "remote_classification_required")
        self.assertEqual((payload["facts"]["remote_mode"], payload["facts"]["stack_membership"]), (None, "none"))

    def test_differing_remote_needs_classification(self) -> None:
        published = self.feature()
        git(self.repo, "push", "-q", "origin", BRANCH)
        self.commit("Add the widget tests", "tests/widget.txt")
        payload = self.invoke()
        self.assert_status(payload, "remote_classification_required", "remote_classification_required")
        self.assertEqual(
            (payload["facts"]["branch_action"], payload["facts"]["observed_origin_oid"]), (None, published)
        )

    def test_open_pull_request_blocks_with_its_url(self) -> None:
        self.feature()
        url = "https://github.com/acme/app/pull/7"
        os.environ["FAKE_GH_PR_LIST"] = json.dumps([{"number": 7, "url": url, "state": "OPEN", "headRefName": BRANCH}])
        payload = self.invoke()
        self.assert_status(payload, "blocked", "pull_request_open")
        self.assertEqual(payload["details"]["urls"], [url])

    def test_failing_or_malformed_pull_request_query_blocks(self) -> None:
        self.feature()
        for listing, exit_code in (("[]", "1"), ("not json", "0"), ('{"a": 1}', "0")):
            with self.subTest(listing=listing, exit_code=exit_code):
                os.environ.update(FAKE_GH_PR_LIST=listing, FAKE_GH_PR_LIST_EXIT=exit_code)
                self.assert_status(self.invoke(), "blocked", "gh_pr_list_failed")

    def test_no_changes_blocks(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        self.assert_status(self.invoke(), "blocked", "no_changes")

    @unittest.skipUnless(shutil.which("jq"), "resolve-stack-membership.sh needs jq")
    def test_stacked_branch_blocks(self) -> None:
        self.feature()
        git(self.repo, "remote", "add", "mirror", "https://github.com/acme/demo.git")
        stack = {"trunk": "main", "currentBranch": BRANCH, "branches": [{"name": BRANCH}]}
        os.environ["FAKE_GH_STACK_JSON"] = json.dumps(stack)
        payload = self.invoke()
        self.assert_status(payload, "blocked", "stacked_branch")
        self.assertIn("use kramme:pr:stack instead", payload["message"])

    def test_unresolved_stack_membership_blocks(self) -> None:
        self.feature()
        git(self.repo, "remote", "add", "mirror", "https://github.com/acme/demo.git")
        os.environ["FAKE_GH_STACK_JSON"] = "not json"
        self.assert_status(self.invoke(), "blocked", "stack_unresolved")


class CommitAndMutationTests(PreflightCase):
    def test_unpublished_commits_carry_their_flags_oldest_first(self) -> None:
        git(self.repo, "checkout", "-q", "-b", BRANCH)
        subjects = [
            "Add the widget",
            "WIP: more widget",
            "fixup! Add the widget",
            "Include uncommitted changes for PR creation",
            "Add widget docs\n\nCo-Authored-By: Claude <noreply@anthropic.com>",
            "Tidy the widget\n\n\U0001f916 Generated with Claude Code",
            "Misc cleanup",
        ]
        for index, message in enumerate(subjects):
            self.commit(message, f"src/file{index}.txt")
        git(self.repo, "checkout", "-q", "-b", "side", "main")
        self.commit("Side work", "side.txt")
        git(self.repo, "checkout", "-q", BRANCH)
        git(self.repo, "merge", "-q", "--no-ff", "-m", "Merge side", "side")
        commits = self.invoke()["facts"]["unpublished_commits"]
        by_subject = {commit["subject"]: commit["flags"] for commit in commits}
        self.assertEqual(
            by_subject,
            {
                "Add the widget": [],
                "WIP: more widget": ["placeholder"],
                "fixup! Add the widget": ["autosquash"],
                "Include uncommitted changes for PR creation": ["placeholder"],
                "Add widget docs": ["ai-attribution"],
                "Tidy the widget": ["ai-attribution"],
                "Misc cleanup": ["placeholder"],
                "Side work": [],
                "Merge side": ["merge"],
            },
        )
        self.assertEqual(commits[0]["subject"], "Add the widget")
        self.assertEqual(commits[-1]["subject"], "Merge side")
        self.assertEqual(len(commits[-1]["parents"]), 2)

    def test_preflight_never_mutates_the_repository(self) -> None:
        self.feature()
        self.write("tracked.txt", "dirty\n")
        self.write("notes/new.txt", "untracked\n")
        before = self.identity()
        for argv in ([], ["--manual"], ["--feature-branch", "other"]):
            self.invoke(*argv)
        git(self.repo, "checkout", "-q", "--detach")
        detached = self.identity()
        for argv in ([], ["--feature-branch", "feature/new"]):
            self.invoke(*argv)
        self.assertEqual(self.identity(), detached)
        git(self.repo, "checkout", "-q", BRANCH)
        self.assertEqual(self.identity(), before)


if __name__ == "__main__":
    unittest.main()
