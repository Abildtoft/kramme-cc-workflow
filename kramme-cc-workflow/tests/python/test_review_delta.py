"""Behavioral tests for the GitHub review re-review scope helper.

Every Git check runs against a real temporary repository whose `origin` is an empty local bare repository,
so fetching a missing commit fails without the network. Every GitHub check runs against a fake `gh` placed
first on PATH that replays a configured reviews response.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SCRIPT_PATH = Path(__file__).resolve().parents[2] / "skills" / "kramme:pr:github-review" / "scripts" / "review-delta.py"
SPEC = importlib.util.spec_from_file_location("review_delta", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
# Keep compiled bytecode out of the skill directory, which skill scanners and the converter read.
sys.dont_write_bytecode = True
review_delta = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(review_delta)

REVIEWS_CALL = "api --paginate --slurp repos/acme/demo/pulls/12/reviews"
FAKE_GH = """#!{python}
import json, os, sys
key = " ".join(sys.argv[1:])
with open(os.environ["FAKE_GH_RESPONSES"], encoding="utf-8") as handle:
    responses = json.load(handle)
if key in responses:
    response = responses[key]
    sys.stdout.write(response.get("stdout", ""))
    sys.stderr.write(response.get("stderr", ""))
    sys.exit(response.get("exit", 0))
sys.stderr.write("unexpected gh call: " + key)
sys.exit(97)
"""


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class DeltaCase(unittest.TestCase):
    def setUp(self) -> None:
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.tmp = Path(workspace.name).resolve()
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        fake_gh = bin_dir / "gh"
        fake_gh.write_text(FAKE_GH.format(python=sys.executable), encoding="utf-8")
        fake_gh.chmod(0o755)
        self.responses = self.tmp / "responses.json"
        global_config = self.tmp / "gitconfig"
        global_config.write_text("", encoding="utf-8")
        environment = {
            "PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}",
            "FAKE_GH_RESPONSES": str(self.responses),
            "GIT_CONFIG_GLOBAL": str(global_config),
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        patcher = mock.patch.dict(os.environ, environment)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(os.chdir, os.getcwd())
        git(self.tmp, "init", "-q", "--bare", "origin.git")
        self.repo = self.tmp / "work"
        git(self.tmp, "init", "-q", "-b", "main", "work")
        for key, value in (("user.email", "test@example.com"), ("user.name", "Test"), ("commit.gpgsign", "false")):
            git(self.repo, "config", key, value)
        git(self.repo, "remote", "add", "origin", str(self.tmp / "origin.git"))
        self.commit("base.txt")
        os.chdir(self.repo)

    def commit(self, name: str, content: str = "") -> str:
        (self.repo / name).write_text(content or f"{name}\n", encoding="utf-8")
        git(self.repo, "add", name)
        git(self.repo, "commit", "-q", "-m", f"add {name}")
        return git(self.repo, "rev-parse", "HEAD")

    def stack(self) -> dict[str, str]:
        """main <- layer-a (a1) <- layer-b (b1, b2), with layer-b checked out; returns each commit."""
        git(self.repo, "switch", "-q", "-c", "layer-a", "main")
        tips = {"a1": self.commit("a1.txt")}
        git(self.repo, "switch", "-q", "-c", "layer-b")
        tips["b1"] = self.commit("b1.txt")
        tips["b2"] = self.commit("b2.txt")
        return tips

    def restack_with_parent_fix(self) -> str:
        """Add a commit to layer-a and rebase layer-b onto it; returns the new layer-b head."""
        git(self.repo, "switch", "-q", "layer-a")
        self.commit("a2.txt")
        git(self.repo, "switch", "-q", "layer-b")
        git(self.repo, "rebase", "-q", "layer-a")
        return git(self.repo, "rev-parse", "HEAD")

    def reviewed(self, *reviews: dict[str, Any], exit_code: int = 0, stderr: str = "") -> None:
        response = {"stdout": json.dumps([list(reviews)]), "exit": exit_code, "stderr": stderr}
        self.responses.write_text(json.dumps({REVIEWS_CALL: response}), encoding="utf-8")

    def review(self, commit: str, **fields: Any) -> dict[str, Any]:
        review = {
            "id": 1,
            "user": {"login": "me"},
            "state": "CHANGES_REQUESTED",
            "body": "",
            "commit_id": commit,
            "submitted_at": "2026-10-01T10:00:00Z",
        }
        review.update(fields)
        return review

    def invoke(self, head: str, base: str, trunk: str = "main") -> dict[str, Any]:
        argv = ["--repo", "acme/demo", "--pr", "12", "--self", "me", "--head", head, "--base", base, "--trunk", trunk]
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = review_delta.main(argv)
        self.assertEqual(code, 0)
        payload: dict[str, Any] = json.loads(stdout.getvalue())
        self.assertEqual(payload["schema_version"], 1)
        return payload

    def statuses(self, payload: dict[str, Any]) -> list[str]:
        return [entry["status"] for entry in payload["commits"]]


class LastReview(DeltaCase):
    def test_no_review_from_you_is_a_first_review(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["b1"], user={"login": "someone-else"}))

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual((payload["scope"], payload["last_review"]), ("first", None))

    def test_comment_reviews_without_a_summary_do_not_count(self) -> None:
        tips = self.stack()
        self.reviewed(
            self.review(tips["b1"], id=1, submitted_at="2026-10-01T10:00:00Z"),
            self.review(tips["b2"], id=2, state="COMMENTED", submitted_at="2026-10-02T10:00:00Z"),
        )

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual(payload["last_review"]["id"], 1)
        self.assertEqual(payload["review_base"], tips["b1"])

    def test_newest_code_review_wins_including_comment_reviews_with_a_summary(self) -> None:
        tips = self.stack()
        self.reviewed(
            self.review(tips["b1"], id=1, state="APPROVED", submitted_at="2026-10-01T10:00:00Z"),
            self.review(
                tips["b2"], id=2, state="COMMENTED", body="Two questions inline.", submitted_at="2026-10-03T10:00:00Z"
            ),
            self.review(tips["b1"], id=3, state="PENDING", submitted_at=None),
        )

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual((payload["last_review"]["id"], payload["scope"]), (2, "unchanged"))

    def test_dismissed_reviews_count(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["b1"], state="DISMISSED"))

        self.assertEqual(self.invoke(tips["b2"], tips["a1"])["scope"], "delta")

    def test_unreadable_reviews_fall_back_to_a_full_review(self) -> None:
        tips = self.stack()
        self.reviewed(exit_code=1, stderr="HTTP 502")

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual(payload["scope"], "full")
        self.assertIn("HTTP 502", payload["reason"])


class AppendedCommits(DeltaCase):
    def test_no_new_commits_is_unchanged(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual(payload["scope"], "unchanged")
        self.assertEqual(payload["reason"], "no commits were pushed since your last review")

    def test_new_commits_are_reviewed_from_the_last_reviewed_head(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["b1"]))

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual((payload["scope"], payload["review_base"]), ("delta", tips["b1"]))
        self.assertEqual(self.statuses(payload), ["unchanged", "changed"])
        self.assertFalse(payload["lower_layers_changed"])

    def test_a_review_of_the_empty_layer_needs_a_full_review(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["a1"]))

        self.assertEqual(self.invoke(tips["b2"], tips["a1"])["scope"], "full")

    def test_merge_commits_fall_back_to_a_full_review(self) -> None:
        tips = self.stack()
        git(self.repo, "switch", "-q", "main")
        self.commit("trunk.txt")
        git(self.repo, "switch", "-q", "layer-b")
        git(self.repo, "merge", "-q", "--no-edit", "main")
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(git(self.repo, "rev-parse", "HEAD"), tips["a1"])

        self.assertEqual(
            (payload["scope"], payload["reason"]), ("full", "merge commits arrived since your last review")
        )


class RewrittenCommits(DeltaCase):
    def test_restack_without_changes_is_unchanged(self) -> None:
        tips = self.stack()
        head = self.restack_with_parent_fix()
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(head, git(self.repo, "rev-parse", "layer-a"))

        self.assertEqual(payload["scope"], "unchanged")
        self.assertEqual(self.statuses(payload), ["unchanged", "unchanged"])
        self.assertTrue(payload["lower_layers_changed"])
        self.assertEqual(payload["last_review"]["commit"], tips["b2"])

    def test_commit_added_after_a_restack_is_the_only_delta(self) -> None:
        tips = self.stack()
        self.restack_with_parent_fix()
        restacked_top = git(self.repo, "rev-parse", "HEAD")
        head = self.commit("b3.txt")
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(head, git(self.repo, "rev-parse", "layer-a"))

        self.assertEqual((payload["scope"], payload["review_base"]), ("delta", restacked_top))
        self.assertEqual(self.statuses(payload), ["unchanged", "unchanged", "changed"])

    def test_changed_middle_commit_with_a_replaced_patch_needs_a_full_review(self) -> None:
        tips = self.stack()
        git(self.repo, "switch", "-q", "layer-b")
        tips["b3"] = self.commit("b3.txt")
        git(self.repo, "switch", "-q", "-c", "rewrite", tips["b1"])
        self.commit("b2.txt", "rewritten\n")
        git(self.repo, "cherry-pick", tips["b3"])
        self.reviewed(self.review(tips["b3"]))

        payload = self.invoke(git(self.repo, "rev-parse", "HEAD"), tips["a1"])

        self.assertEqual((payload["scope"], payload["review_base"]), ("full", None))
        self.assertEqual(self.statuses(payload), ["unchanged", "changed", "unchanged"])
        self.assertEqual([entry["oid"] for entry in payload["dropped"]], [tips["b2"]])

    def test_semantic_whitespace_changes_are_reviewed(self) -> None:
        cases = {
            "literal": ('message = "access denied"\n', 'message = "accessdenied"\n'),
            "indentation": ("if allowed:\n    grant()\n    log()\n", "if allowed:\n    grant()\nlog()\n"),
        }
        base = git(self.repo, "rev-parse", "main")
        for name, (old_content, new_content) in cases.items():
            with self.subTest(name=name):
                git(self.repo, "switch", "-q", "-c", f"old-{name}", base)
                old = self.commit("app.py", old_content)
                git(self.repo, "switch", "-q", "-c", f"new-{name}", base)
                head = self.commit("app.py", new_content)
                self.reviewed(self.review(old))

                payload = self.invoke(head, base)

                self.assertEqual(payload["scope"], "full")
                self.assertEqual(self.statuses(payload), ["changed"])

    def test_removing_a_reviewed_commit_needs_a_full_review(self) -> None:
        tips = self.stack()
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(tips["b1"], tips["a1"])

        self.assertEqual((payload["scope"], payload["review_base"]), ("full", None))
        self.assertEqual([entry["oid"] for entry in payload["dropped"]], [tips["b2"]])

    def test_a_removed_commit_before_a_new_suffix_needs_a_full_review(self) -> None:
        tips = self.stack()
        old = self.commit("b3.txt")
        git(self.repo, "switch", "-q", "-c", "rewrite", tips["b1"])
        git(self.repo, "cherry-pick", old)
        head = self.commit("b4.txt")
        self.reviewed(self.review(old))

        payload = self.invoke(head, tips["a1"])

        self.assertEqual((payload["scope"], payload["review_base"]), ("full", None))
        self.assertEqual([entry["oid"] for entry in payload["dropped"]], [tips["b2"]])

    def test_changed_first_commit_needs_a_full_review(self) -> None:
        tips = self.stack()
        git(self.repo, "switch", "-q", "-c", "rewrite", "layer-a")
        self.commit("b1.txt", "rewritten\n")
        git(self.repo, "cherry-pick", tips["b2"])
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(git(self.repo, "rev-parse", "HEAD"), tips["a1"])

        self.assertEqual(payload["scope"], "full")
        self.assertEqual(self.statuses(payload), ["changed", "unchanged"])

    def test_commit_moved_up_from_inside_the_layer_below_counts_as_changed(self) -> None:
        git(self.repo, "switch", "-q", "-c", "layer-a", "main")
        a1 = self.commit("a1.txt")
        self.commit("a2.txt")
        git(self.repo, "switch", "-q", "-c", "layer-b")
        old_top = self.commit("b1.txt")
        git(self.repo, "switch", "-q", "-c", "new-a", "main")
        self.commit("a2.txt")
        new_base = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "cherry-pick", a1)
        git(self.repo, "cherry-pick", old_top)
        self.reviewed(self.review(old_top))

        payload = self.invoke(git(self.repo, "rev-parse", "HEAD"), new_base)

        self.assertEqual(self.statuses(payload), ["changed", "unchanged"])
        self.assertEqual(payload["scope"], "full")

    def test_unknown_layer_start_falls_back_to_a_full_review(self) -> None:
        tips = self.stack()
        git(self.repo, "switch", "-q", "-c", "new-a", "main")
        self.commit("a1.txt", "rewritten\n")
        new_base = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "cherry-pick", tips["b1"], tips["b2"])
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(git(self.repo, "rev-parse", "HEAD"), new_base)

        self.assertEqual(payload["scope"], "full")
        self.assertIn("layers below were rewritten", payload["reason"])

    def test_unresolvable_trunk_falls_back_to_a_full_review(self) -> None:
        tips = self.stack()
        head = self.restack_with_parent_fix()
        self.reviewed(self.review(tips["b2"]))

        payload = self.invoke(head, git(self.repo, "rev-parse", "layer-a"), trunk="origin/missing")

        self.assertEqual(
            (payload["scope"], payload["reason"]), ("full", "the trunk `origin/missing` does not resolve to a commit")
        )


class Preconditions(DeltaCase):
    def test_last_reviewed_commit_that_cannot_be_fetched_needs_a_full_review(self) -> None:
        tips = self.stack()
        self.reviewed(self.review("e" * 40))

        payload = self.invoke(tips["b2"], tips["a1"])

        self.assertEqual(payload["scope"], "full")
        self.assertEqual(payload["reason"], f"your last reviewed commit {'e' * 12} is no longer available")

    def test_invalid_arguments_are_a_usage_error(self) -> None:
        for flag, value in (
            ("--head", "HEAD"),
            ("--pr", "0"),
            ("--repo", "acme"),
            ("--trunk", "a..b"),
            ("--self", "-x"),
        ):
            argv = {"--repo": "acme/demo", "--pr": "12", "--self": "me", "--head": "a" * 40, "--base": "b" * 40}
            argv["--trunk"] = "main"
            argv[flag] = value
            stdout = io.StringIO()
            with self.subTest(flag=flag), redirect_stdout(stdout), mock.patch("sys.stderr", io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    review_delta.main([item for pair in argv.items() for item in pair])
                self.assertEqual((raised.exception.code, stdout.getvalue()), (2, ""))


if __name__ == "__main__":
    unittest.main()
