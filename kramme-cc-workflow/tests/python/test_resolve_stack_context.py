"""Behavioral tests for the shared Pull Request stack-context helper.

Every Git check runs against a real temporary repository whose `origin` is a GitHub URL with locally
created remote-tracking refs, so the helper never needs the network. Every GitHub check runs against a
fake `gh` placed first on PATH that replays configured responses and records its argv.
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

SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "resolve-stack-context.py"
SPEC = importlib.util.spec_from_file_location("resolve_stack_context", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
stack_context = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stack_context)

PR_LIST = f"pr list --state open --limit 20 --json {stack_context.PR_FIELDS}"
FAKE_GH = """#!{python}
import json, os, sys
args = sys.argv[1:]
with open(os.environ["FAKE_GH_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\\n")
with open(os.environ["FAKE_GH_RESPONSES"], encoding="utf-8") as handle:
    responses = json.load(handle)
key = " ".join(args)
for pattern, response in responses:
    if key == pattern or (pattern.endswith("*") and key.startswith(pattern[:-1])):
        sys.stdout.write(response.get("stdout", ""))
        sys.stderr.write(response.get("stderr", ""))
        sys.exit(response.get("exit", 0))
sys.stderr.write("unexpected gh call: " + key)
sys.exit(97)
"""
NO_STACK_EXTENSION = ("stack --version", {"exit": 1, "stderr": 'unknown command "stack" for "gh"'})


def heads(branch: str) -> str:
    return f"{PR_LIST} --head {branch}"


def bases(branch: str) -> str:
    return f"{PR_LIST} --base {branch}"


def pulls(*items: tuple[int, str, str]) -> dict[str, str]:
    rows = [
        {
            "number": number,
            "url": f"https://github.com/acme/demo/pull/{number}",
            "headRefName": head,
            "baseRefName": base,
            "isCrossRepository": False,
        }
        for number, head, base in items
    ]
    return {"stdout": json.dumps(rows)}


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class StackContextCase(unittest.TestCase):
    def setUp(self) -> None:
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.tmp = Path(workspace.name).resolve()
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        fake_gh = bin_dir / "gh"
        fake_gh.write_text(FAKE_GH.format(python=sys.executable), encoding="utf-8")
        fake_gh.chmod(0o755)
        self.gh_log = self.tmp / "gh.log"
        self.responses = self.tmp / "responses.json"
        global_config = self.tmp / "gitconfig"
        global_config.write_text("", encoding="utf-8")
        environment = {
            "PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}",
            "FAKE_GH_LOG": str(self.gh_log),
            "FAKE_GH_RESPONSES": str(self.responses),
            "GIT_CONFIG_GLOBAL": str(global_config),
            "GIT_CONFIG_NOSYSTEM": "1",
            "CONDUCTOR_DEFAULT_BRANCH": "",
        }
        patcher = mock.patch.dict(os.environ, environment)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(os.chdir, os.getcwd())
        self.repo = self.tmp / "work"
        git(self.tmp, "init", "-q", "-b", "main", "work")
        for key, value in (("user.email", "test@example.com"), ("user.name", "Test"), ("commit.gpgsign", "false")):
            git(self.repo, "config", key, value)
        self.commit("base.txt")
        git(self.repo, "remote", "add", "origin", "https://github.com/acme/demo.git")
        git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        git(self.repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        os.chdir(self.repo)
        self.respond()

    def commit(self, name: str, content: str = "") -> str:
        (self.repo / name).write_text(content or f"{name}\n", encoding="utf-8")
        git(self.repo, "add", name)
        git(self.repo, "commit", "-q", "-m", f"add {name}")
        return git(self.repo, "rev-parse", "HEAD")

    def branch(self, name: str, start: str, file_name: str) -> str:
        git(self.repo, "switch", "-q", "-c", name, start)
        return self.commit(file_name)

    def layers(self) -> dict[str, str]:
        """main <- layer-a <- layer-b <- layer-c, with layer-b checked out; returns each layer's tip."""
        tips = {"main": git(self.repo, "rev-parse", "main")}
        tips["layer-a"] = self.branch("layer-a", "main", "a.txt")
        tips["layer-b"] = self.branch("layer-b", "layer-a", "b.txt")
        tips["layer-c"] = self.branch("layer-c", "layer-b", "c.txt")
        git(self.repo, "switch", "-q", "layer-b")
        return tips

    def respond(self, *responses: tuple[str, dict[str, Any]]) -> None:
        self.responses.write_text(json.dumps([list(item) for item in responses]), encoding="utf-8")

    def stack_view(self, branches: list[dict[str, Any]], current: str = "layer-b") -> list[tuple[str, dict[str, Any]]]:
        view = {"trunk": "main", "currentBranch": current, "branches": branches}
        return [
            ("stack --version", {"stdout": "gh stack version 0.2.1\n"}),
            ("stack view --json", {"stdout": json.dumps(view)}),
        ]

    def invoke(self, *argv: str) -> dict[str, Any]:
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = stack_context.main(list(argv))
        self.assertEqual(code, 0)
        payload: dict[str, Any] = json.loads(stdout.getvalue())
        self.assertEqual(payload["schema_version"], 1)
        return payload

    def gh_calls(self) -> list[str]:
        if not self.gh_log.exists():
            return []
        return [" ".join(json.loads(line)) for line in self.gh_log.read_text(encoding="utf-8").splitlines()]


class GhStackTracking(StackContextCase):
    def entry(self, name: str, base: str, **fields: Any) -> dict[str, Any]:
        return {
            "name": name,
            "base": base,
            "isCurrent": name == "layer-b",
            "isMerged": False,
            "isQueued": False,
            "needsRebase": False,
            **fields,
        }

    def test_unsubmitted_middle_layer_is_reviewed_against_its_parent(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"]),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual(
            (context["state"], context["source"], context["position"], context["size"]), ("stacked", "gh-stack", 2, 3)
        )
        self.assertEqual(context["parent"], {"branch": "layer-a", "pr": None, "ref": "refs/heads/layer-a"})
        self.assertEqual([entry["branch"] for entry in context["upstack"]], ["layer-c"])
        self.assertEqual(context["review_base"], {"branch": "layer-a", "commit": tips["layer-a"]})
        self.assertFalse(context["needs_restack"])
        self.assertEqual(
            context["summary"], "Layer 2 of 3 in a gh-stack stack on `main`. Parent: `layer-a`. Above: `layer-c`."
        )

    def test_gh_stack_trunk_entry_is_not_counted_as_a_layer(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("main", tips["main"]),
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"]),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual((context["position"], context["size"]), (2, 3))
        self.assertEqual([entry["branch"] for entry in context["downstack"]], ["layer-a"])

    def test_multiple_pull_requests_for_a_gh_stack_layer_are_unknown(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"]),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(
            *self.stack_view(branches),
            (heads("layer-b"), pulls((12, "layer-b", "layer-a"), (14, "layer-b", "main"))),
        )

        context = self.invoke()

        self.assertEqual(context["state"], "unknown")
        self.assertIn("matches 2 open Pull Requests", context["reason"])

    def test_layer_with_an_open_pull_request_keeps_the_default_base(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("layer-a", tips["main"], pr={"number": 11, "state": "OPEN"}),
            self.entry("layer-b", tips["layer-a"], pr={"number": 12, "state": "OPEN"}),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), pulls((12, "layer-b", "layer-a"))))

        context = self.invoke()

        self.assertIsNone(context["review_base"])
        self.assertEqual(context["pr"]["number"], 12)
        self.assertEqual(context["parent"]["pr"], 11)
        self.assertIn("Parent: `layer-a` (#11).", context["summary"])

    def test_restack_pins_the_recorded_base_after_the_parent_is_rewritten(self) -> None:
        tips = self.layers()
        git(self.repo, "switch", "-q", "layer-a")
        git(self.repo, "commit", "-q", "--amend", "-m", "rewrite layer-a")
        git(self.repo, "switch", "-q", "layer-b")
        branches = [
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"], needsRebase=True),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), pulls((12, "layer-b", "layer-a"))))

        context = self.invoke()

        self.assertTrue(context["needs_restack"])
        self.assertEqual(context["review_base"], {"branch": "layer-a", "commit": tips["layer-a"]})
        self.assertIn("Needs a restack", context["summary"])

    def test_merged_parent_moves_the_base_past_the_recorded_one(self) -> None:
        tips = self.layers()
        git(self.repo, "switch", "-q", "layer-a")
        newer_parent = self.commit("a2.txt")
        git(self.repo, "switch", "-q", "layer-b")
        git(self.repo, "merge", "-q", "--no-edit", "layer-a")
        branches = [
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"]),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual(context["review_base"]["commit"], newer_parent)

    def test_bottom_layer_without_a_pull_request_targets_the_stack_trunk(self) -> None:
        tips = self.layers()
        git(self.repo, "switch", "-q", "layer-a")
        branches = [self.entry("layer-a", tips["main"]), self.entry("layer-b", tips["layer-a"])]
        self.respond(*self.stack_view(branches, current="layer-a"), (heads("layer-a"), {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual((context["position"], context["size"]), (1, 2))
        self.assertIsNone(context["parent"])
        self.assertEqual(context["review_base"], {"branch": "main", "commit": None})
        self.assertIn("Parent: the trunk `main`.", context["summary"])

    def test_merged_lower_layers_do_not_count(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("layer-a", tips["main"], isMerged=True),
            self.entry("layer-b", tips["layer-a"]),
            self.entry("layer-c", tips["layer-b"]),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), pulls((12, "layer-b", "main"))))

        context = self.invoke()

        self.assertEqual((context["position"], context["size"], context["parent"]), (1, 2, None))
        self.assertIsNone(context["review_base"])

    def test_only_unmerged_layer_is_unstacked(self) -> None:
        tips = self.layers()
        branches = [self.entry("layer-a", tips["main"], isMerged=True), self.entry("layer-b", tips["layer-a"])]
        self.respond(*self.stack_view(branches), (heads("layer-b"), {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual(context["state"], "unstacked")
        self.assertEqual(context["review_base"], {"branch": "main", "commit": None})

    def test_pull_request_lookup_failure_falls_back_to_the_stack_record(self) -> None:
        tips = self.layers()
        branches = [
            self.entry("layer-a", tips["main"]),
            self.entry("layer-b", tips["layer-a"], pr={"number": 12, "state": "OPEN"}),
        ]
        self.respond(*self.stack_view(branches), (heads("layer-b"), {"exit": 1, "stderr": "HTTP 502"}))

        context = self.invoke()

        self.assertEqual(context["state"], "stacked")
        self.assertEqual(context["pr"], {"number": 12, "url": None, "base": None})
        self.assertIsNone(context["review_base"])
        self.assertTrue(any("HTTP 502" in note for note in context["notes"]))

    def test_stack_that_does_not_contain_the_branch_falls_through_to_pull_requests(self) -> None:
        tips = self.layers()
        git(self.repo, "switch", "-q", "-c", "elsewhere", "main")
        branches = [self.entry("layer-a", tips["main"]), self.entry("layer-b", tips["layer-a"])]
        self.respond(
            *self.stack_view(branches, current="elsewhere"),
            (heads("elsewhere"), {"stdout": "[]"}),
            (bases("elsewhere"), {"stdout": "[]"}),
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["source"]), ("unstacked", "pull-requests"))

    def test_malformed_stack_view_is_noted_and_skipped(self) -> None:
        self.layers()
        self.respond(
            ("stack --version", {"stdout": "gh stack version 0.2.1\n"}),
            ("stack view --json", {"stdout": '{"trunk": "main", "branches": "nope"}'}),
            (heads("layer-b"), {"stdout": "[]"}),
            (bases("layer-b"), {"stdout": "[]"}),
        )

        context = self.invoke()

        self.assertEqual(context["source"], "pull-requests")
        self.assertIn("gh stack view printed an unexpected stack shape; used Pull Requests", context["notes"])


class PullRequestChain(StackContextCase):
    def test_chained_pull_requests_form_a_stack(self) -> None:
        self.layers()
        self.respond(
            NO_STACK_EXTENSION,
            (heads("layer-b"), pulls((12, "layer-b", "layer-a"))),
            (bases("layer-b"), pulls((13, "layer-c", "layer-b"))),
            (bases("layer-c"), {"stdout": "[]"}),
            (heads("layer-a"), pulls((11, "layer-a", "main"))),
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["source"], context["trunk"]), ("stacked", "pull-requests", "main"))
        self.assertEqual((context["position"], context["size"]), (2, 3))
        self.assertEqual(context["parent"], {"branch": "layer-a", "pr": 11, "ref": "refs/heads/layer-a"})
        self.assertEqual(context["upstack"], [{"branch": "layer-c", "pr": 13, "ref": "refs/heads/layer-c"}])
        self.assertIsNone(context["review_base"])
        self.assertIsNone(context["needs_restack"])
        self.assertEqual(
            context["summary"],
            "Layer 2 of 3 in a chain of stacked Pull Requests on `main`. "
            "Parent: `layer-a` (#11). Above: `layer-c` (#13).",
        )

    def test_pull_request_into_the_trunk_without_children_is_unstacked(self) -> None:
        self.layers()
        self.respond(
            NO_STACK_EXTENSION, (heads("layer-b"), pulls((12, "layer-b", "main"))), (bases("layer-b"), {"stdout": "[]"})
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["trunk"]), ("unstacked", "main"))
        self.assertEqual(context["summary"], "Not part of a Pull Request stack.")

    def test_configured_workbench_with_a_release_pull_request_stops_the_walk(self) -> None:
        self.layers()
        git(self.repo, "config", "--local", "kramme.baseBranch", "layer-a")
        self.respond(
            NO_STACK_EXTENSION,
            (heads("layer-b"), pulls((12, "layer-b", "layer-a"))),
            (bases("layer-b"), {"stdout": "[]"}),
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["trunk"]), ("unstacked", "layer-a"))
        self.assertNotIn(heads("layer-a"), self.gh_calls())

    def test_branch_without_a_pull_request_reports_the_layers_above(self) -> None:
        self.layers()
        self.respond(
            NO_STACK_EXTENSION,
            (heads("layer-b"), {"stdout": "[]"}),
            (bases("layer-b"), pulls((13, "layer-c", "layer-b"))),
            (bases("layer-c"), {"stdout": "[]"}),
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["position"], context["size"]), ("stacked", None, None))
        self.assertTrue(context["summary"].startswith("Open Pull Requests build on this branch: `layer-c` (#13)."))

    def test_several_children_note_a_branching_stack(self) -> None:
        self.layers()
        self.respond(
            NO_STACK_EXTENSION,
            (heads("layer-b"), pulls((12, "layer-b", "main"))),
            (bases("layer-b"), pulls((13, "layer-c", "layer-b"), (14, "layer-d", "layer-b"))),
        )

        context = self.invoke()

        self.assertEqual([entry["pr"] for entry in context["upstack"]], [13, 14])
        self.assertIn("2 open Pull Requests target `layer-b`, so the stack branches above it", context["notes"])

    def test_cross_repository_pull_requests_are_ignored(self) -> None:
        self.layers()
        fork = {"number": 9, "url": "u", "headRefName": "layer-b", "baseRefName": "main", "isCrossRepository": True}
        self.respond(
            NO_STACK_EXTENSION, (heads("layer-b"), {"stdout": json.dumps([fork])}), (bases("layer-b"), {"stdout": "[]"})
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["pr"]), ("unstacked", None))

    def test_query_failure_reports_an_unknown_stack(self) -> None:
        self.layers()
        self.respond(
            NO_STACK_EXTENSION, (heads("layer-b"), {"exit": 1, "stderr": "gh: To use GitHub CLI, run gh auth login"})
        )

        context = self.invoke()

        self.assertEqual(context["state"], "unknown")
        self.assertIn("gh auth login", context["reason"])
        self.assertTrue(
            context["summary"].startswith("Stack status unknown: could not query open Pull Requests from `layer-b`")
        )

    def test_malformed_pull_request_entry_reports_an_unknown_stack(self) -> None:
        self.layers()
        broken = {"number": "12", "headRefName": "layer-b", "baseRefName": "main", "isCrossRepository": False}
        self.respond(NO_STACK_EXTENSION, (heads("layer-b"), {"stdout": json.dumps([broken])}))

        self.assertEqual(self.invoke()["state"], "unknown")

    def test_explicit_head_skips_local_stack_tracking(self) -> None:
        self.layers()
        self.respond(
            (heads("layer-c"), pulls((13, "layer-c", "layer-b"))),
            (bases("layer-c"), {"stdout": "[]"}),
            (heads("layer-b"), pulls((12, "layer-b", "main"))),
        )

        context = self.invoke("--head", "layer-c")

        self.assertEqual((context["head"], context["position"], context["size"]), ("layer-c", 2, 2))
        self.assertFalse(any(call.startswith("stack ") for call in self.gh_calls()))

    def test_detached_head_is_matched_to_its_pull_request(self) -> None:
        tips = self.layers()
        git(self.repo, "switch", "-q", "--detach", "layer-b")
        repo = {"full_name": "acme/demo"}
        match = {
            "number": 12,
            "state": "open",
            "html_url": "https://github.com/acme/demo/pull/12",
            "head": {"sha": tips["layer-b"], "ref": "layer-b", "repo": repo},
            "base": {"ref": "layer-a", "repo": repo},
        }
        self.respond(
            (f"api repos/{{owner}}/{{repo}}/commits/{tips['layer-b']}/pulls", {"stdout": json.dumps([match])}),
            (bases("layer-b"), {"stdout": "[]"}),
            (heads("layer-a"), pulls((11, "layer-a", "main"))),
        )

        context = self.invoke()

        self.assertEqual((context["state"], context["head"], context["position"]), ("stacked", "layer-b", 2))

    def test_detached_head_without_a_pull_request_is_unstacked(self) -> None:
        self.layers()
        git(self.repo, "switch", "-q", "--detach", "layer-b")
        self.respond(("api repos/*", {"stdout": "[]"}))

        context = self.invoke()

        self.assertEqual((context["state"], context["head"]), ("unstacked", None))


class Preconditions(StackContextCase):
    def test_repository_without_a_github_remote_is_unstacked_without_calling_gh(self) -> None:
        git(self.repo, "remote", "set-url", "origin", "https://gitlab.com/acme/demo.git")

        context = self.invoke()

        self.assertEqual((context["state"], context["reason"]), ("unstacked", "no GitHub remote"))
        self.assertEqual(self.gh_calls(), [])

    def test_missing_gh_reports_an_unknown_stack(self) -> None:
        with mock.patch.object(stack_context.shutil, "which", return_value=None):
            context = self.invoke()

        self.assertEqual(context["state"], "unknown")
        self.assertIn("(gh) is unavailable", context["reason"])

    def test_invalid_head_is_a_usage_error(self) -> None:
        stdout = io.StringIO()
        with redirect_stdout(stdout), mock.patch("sys.stderr", io.StringIO()):
            code = stack_context.main(["--head", "@{-1}"])

        self.assertEqual((code, stdout.getvalue()), (2, ""))

    def test_timeouts_become_a_reported_failure(self) -> None:
        with mock.patch.object(stack_context.subprocess, "run", side_effect=subprocess.TimeoutExpired(["gh"], 1)):
            result = stack_context.run(["gh", "pr", "list"], 1)

        self.assertEqual((result.returncode, result.stderr), (124, "timed out after 1s"))


if __name__ == "__main__":
    unittest.main()
