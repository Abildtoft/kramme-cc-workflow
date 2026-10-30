"""Behavioral tests for the GitHub review stack-overview helper.

Every Git check runs against a real temporary repository whose `origin` is a local bare repository holding
the stack's branches and `refs/pull/<number>/head` refs, so fetching needs no network. Every GitHub check runs
against a fake `gh` placed first on PATH that replays configured Pull Request views.
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
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "skills" / "kramme:pr:github-review" / "scripts" / "stack-overview.py"
)
SPEC = importlib.util.spec_from_file_location("stack_overview", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
# Keep compiled bytecode out of the skill directory, which skill scanners and the converter read.
sys.dont_write_bytecode = True
stack_overview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stack_overview)

FAKE_GH = """#!{python}
import json, os, sys
key = " ".join(sys.argv[1:])
with open(os.environ["FAKE_GH_RESPONSES"], encoding="utf-8") as handle:
    responses = json.load(handle)
if key in responses:
    sys.stdout.write(responses[key])
    sys.exit(0)
sys.stderr.write("unexpected gh call: " + key)
sys.exit(97)
"""
SERVICE = "".join(f"line {number}\n" for number in range(1, 11))


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class OverviewCase(unittest.TestCase):
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
        policy = json.dumps({"version": 1, "generated_paths": ["gen/"]})
        self.commit({".github/pr-risk.json": policy, "db/migrations/0001_init.sql": "create table a;\n"})
        os.chdir(self.repo)
        self.views: dict[int, dict[str, Any]] = {}

    def commit(self, files: dict[str, str], message: str = "change") -> str:
        for name, content in files.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            git(self.repo, "add", name)
        git(self.repo, "commit", "-q", "-m", message)
        return git(self.repo, "rev-parse", "HEAD")

    def layer(self, branch: str, start: str, files: dict[str, str]) -> str:
        git(self.repo, "switch", "-q", "-c", branch, start)
        return self.commit(files, f"build {branch}")

    def stack(self) -> dict[str, str]:
        """main <- layer-a <- layer-b <- layer-c; the trunk gains a migration after the stack branched."""
        tips = {
            "a": self.layer(
                "layer-a", "main", {"src/service.ts": SERVICE, "db/migrations/0002_a.sql": "alter a;\nalter b;\n"}
            ),
            "b": self.layer(
                "layer-b",
                "layer-a",
                {
                    "src/service.ts": SERVICE + "".join(f"more {n}\n" for n in range(5)),
                    "src/service.spec.ts": "a\nb\nc\nd\n",
                    "docs/notes.md": "x\ny\nz\n",
                    "gen/schema.json": "1\n2\n3\n4\n5\n6\n",
                },
            ),
        }
        trimmed = SERVICE.replace("line 1\n", "").replace("line 2\n", "changed\n")
        tips["c"] = self.layer(
            "layer-c",
            "layer-b",
            {
                "src/service.ts": trimmed + "".join(f"more {n}\n" for n in range(5)),
                "package-lock.json": "{\n}\n\n",
            },
        )
        git(self.repo, "switch", "-q", "main")
        self.commit({"db/migrations/0002_trunk.sql": "alter c;\n"}, "trunk migration")
        return tips

    def publish(self, tips: dict[str, str], **overrides: dict[str, Any]) -> None:
        """Push the stack to origin and answer `gh pr view` for #11, #12, and #13."""
        git(self.repo, "push", "-q", "origin", "main")
        for number, (branch, base) in {11: ("a", "main"), 12: ("b", "layer-a"), 13: ("c", "layer-b")}.items():
            git(self.repo, "push", "-q", "-f", "origin", f"{tips[branch]}:refs/pull/{number}/head")
            view = {
                "number": number,
                "title": f"Layer {branch}",
                "url": f"https://github.com/acme/demo/pull/{number}",
                "state": "OPEN",
                "isDraft": False,
                "headRefName": f"layer-{branch}",
                "headRefOid": tips[branch],
                "baseRefName": base,
                "reviewDecision": "REVIEW_REQUIRED",
                "statusCheckRollup": [],
            }
            view.update(overrides.get(str(number), {}))
            self.views[number] = view
        key = f"--repo acme/demo --json {stack_overview.PR_FIELDS}"
        responses = {f"pr view {number} {key}": json.dumps(view) for number, view in self.views.items()}
        self.responses.write_text(json.dumps(responses), encoding="utf-8")

    def context(self, **overrides: Any) -> Path:
        context = {
            "schema_version": 1,
            "state": "stacked",
            "head": "layer-b",
            "trunk": "main",
            "position": 2,
            "size": 3,
            "pr": {"number": 12, "url": "https://github.com/acme/demo/pull/12", "base": "layer-a"},
            "downstack": [{"branch": "layer-a", "pr": 11, "ref": None}],
            "upstack": [{"branch": "layer-c", "pr": 13, "ref": None}],
            "summary": "Layer 2 of 3 in a chain of stacked Pull Requests on `main`.",
        }
        context.update(overrides)
        path = self.tmp / "context.json"
        path.write_text(json.dumps(context), encoding="utf-8")
        return path

    def invoke(self, context: Path) -> dict[str, Any]:
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = stack_overview.main(["--repo", "acme/demo", "--context", str(context)])
        self.assertEqual(code, 0)
        payload: dict[str, Any] = json.loads(stdout.getvalue())
        self.assertEqual(payload["schema_version"], 1)
        return payload

    def failure(self, context: Path) -> str:
        stdout, stderr = io.StringIO(), io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = stack_overview.main(["--repo", "acme/demo", "--context", str(context)])
        self.assertEqual((code, stdout.getvalue()), (1, ""))
        return stderr.getvalue()


class Overview(OverviewCase):
    def test_layers_are_measured_against_their_parents_in_groups(self) -> None:
        self.publish(self.stack())

        payload = self.invoke(self.context())

        self.assertEqual((payload["trunk"], payload["size"], payload["reviewed_position"]), ("main", 3, 2))
        layers = payload["layers"]
        self.assertEqual([layer["pr"] for layer in layers], [11, 12, 13])
        self.assertEqual(layers[0]["added"], {"production": 10, "tests": 0, "database": 2, "generated": 0, "other": 0})
        self.assertEqual(layers[1]["added"], {"production": 5, "tests": 4, "database": 0, "generated": 6, "other": 3})
        self.assertEqual((layers[2]["added"]["production"], layers[2]["deleted"]["production"]), (1, 2))
        self.assertEqual(layers[2]["added"]["generated"], 3)
        self.assertEqual(payload["totals"]["added"]["production"], 16)
        self.assertEqual([layer["needs_restack"] for layer in layers], [False, False, False])
        self.assertEqual([layer["commits"] for layer in layers], [1, 1, 1])

    def test_shared_files_report_their_size_at_the_top_and_later_rewrites(self) -> None:
        self.publish(self.stack())

        payload = self.invoke(self.context())

        hot = payload["hot_files"]
        self.assertEqual([entry["path"] for entry in hot], ["src/service.ts"])
        self.assertEqual([entry["position"] for entry in hot[0]["layers"]], [1, 2, 3])
        self.assertEqual((hot[0]["end_lines"], hot[0]["created_in_stack"], hot[0]["churn"]), (14, True, 2))
        self.assertEqual([layer["extended_by"] for layer in payload["layers"]], [[2, 3], [3], []])

    def test_database_changes_report_trunk_drift_and_number_collisions(self) -> None:
        self.publish(self.stack())

        database = self.invoke(self.context())["database"]

        self.assertEqual(database["trunk_added_since_base"], ["db/migrations/0002_trunk.sql"])
        self.assertEqual(
            database["number_collisions"],
            [{"position": 1, "path": "db/migrations/0002_a.sql", "trunk_path": "db/migrations/0002_trunk.sql"}],
        )
        self.assertEqual(database["out_of_order"], [])

    def test_a_lower_number_in_a_later_layer_is_out_of_order(self) -> None:
        tips = {"a": self.layer("layer-a", "main", {"db/migrations/0003_a.sql": "x;\n"})}
        tips["b"] = self.layer("layer-b", "layer-a", {"db/migrations/0002_b.sql": "y;\n"})
        tips["c"] = self.layer("layer-c", "layer-b", {"src/app.ts": "z\n"})
        self.publish(tips)

        database = self.invoke(self.context())["database"]

        self.assertEqual(
            database["out_of_order"],
            [{"position": 2, "path": "db/migrations/0002_b.sql", "after": "db/migrations/0003_a.sql"}],
        )

    def test_duplicate_migration_numbers_in_different_layers_are_collisions(self) -> None:
        tips = {"a": self.layer("layer-a", "main", {"db/migrations/0002_a.sql": "x;\n"})}
        tips["b"] = self.layer("layer-b", "layer-a", {"db/migrations/0002_b.sql": "y;\n"})
        tips["c"] = self.layer("layer-c", "layer-b", {"src/app.ts": "z\n"})
        self.publish(tips)

        database = self.invoke(self.context())["database"]

        self.assertEqual(
            database["number_collisions"],
            [
                {
                    "position": 2,
                    "path": "db/migrations/0002_b.sql",
                    "other_position": 1,
                    "other_path": "db/migrations/0002_a.sql",
                }
            ],
        )

    def test_all_migrations_and_collisions_are_reported_beyond_fifty(self) -> None:
        files = {f"db/migrations/{number:04}_a.sql": "x;\n" for number in range(2, 53)}
        tips = {"a": self.layer("layer-a", "main", files)}
        tips["b"] = self.layer("layer-b", "layer-a", {"src/b.ts": "b\n"})
        tips["c"] = self.layer("layer-c", "layer-b", {"src/c.ts": "c\n"})
        git(self.repo, "switch", "-q", "main")
        self.commit({f"db/migrations/{number:04}_trunk.sql": "y;\n" for number in range(2, 53)})
        self.publish(tips)

        payload = self.invoke(self.context())

        self.assertEqual(len(payload["layers"][0]["database_files"]), 51)
        self.assertEqual(len(payload["database"]["trunk_added_since_base"]), 51)
        self.assertEqual(len(payload["database"]["number_collisions"]), 51)
        self.assertEqual(payload["database"]["number_collisions"][-1]["path"], "db/migrations/0052_a.sql")

    def test_a_layer_whose_parent_moved_needs_a_restack(self) -> None:
        tips = self.stack()
        git(self.repo, "switch", "-q", "layer-b")
        tips["b"] = self.commit({"src/fix.ts": "fix\n"}, "fix layer-b")
        self.publish(tips)

        layers = self.invoke(self.context())["layers"]

        self.assertEqual([layer["needs_restack"] for layer in layers], [False, False, True])
        self.assertEqual(layers[2]["added"]["generated"], 3)

    def test_review_state_and_checks_are_reported_per_layer(self) -> None:
        failing = [{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "FAILURE"}]
        self.publish(
            self.stack(),
            **{"11": {"reviewDecision": "APPROVED", "isDraft": True}, "13": {"statusCheckRollup": failing}},
        )

        layers = self.invoke(self.context())["layers"]

        self.assertEqual(
            [layer["review_decision"] for layer in layers], ["APPROVED", "REVIEW_REQUIRED", "REVIEW_REQUIRED"]
        )
        self.assertEqual([layer["draft"] for layer in layers], [True, False, False])
        self.assertEqual([layer["checks"] for layer in layers], ["none", "none", "failing"])

    def test_check_rollups_reduce_to_one_state(self) -> None:
        def run(name: str, started: str = "2026-10-29T09:00:00Z", **fields: str) -> dict[str, str]:
            check = {"__typename": "CheckRun", "name": name, "workflowName": "CI", "startedAt": started}
            check.update({"status": "COMPLETED", "conclusion": "SUCCESS"}, **fields)
            return check

        cancelled = run("build", conclusion="CANCELLED")
        cases = [
            ([run("lint"), {"__typename": "StatusContext", "context": "ci", "state": "PENDING"}], "pending"),
            ([run("lint"), {"__typename": "StatusContext", "context": "ci", "state": "ERROR"}], "failing"),
            ([run("lint"), run("build", status="IN_PROGRESS", conclusion="")], "pending"),
            ([run("lint"), run("build", conclusion="SKIPPED")], "passing"),
            ([cancelled, run("build", started="2026-10-29T09:05:00Z")], "passing"),
            ([run("build"), run("build", started="2026-10-29T09:05:00Z", conclusion="CANCELLED")], "failing"),
            (None, "none"),
        ]
        for rollup, expected in cases:
            with self.subTest(rollup=rollup):
                self.assertEqual(stack_overview.checks(rollup), expected)

    def test_lockfiles_are_left_out_of_shared_files(self) -> None:
        tips = {"a": self.layer("layer-a", "main", {"src/a.ts": "a\n", "package-lock.json": "{}\n"})}
        tips["b"] = self.layer("layer-b", "layer-a", {"src/a.ts": "a\nb\n", "package-lock.json": "{ }\n"})
        tips["c"] = self.layer("layer-c", "layer-b", {"src/c.ts": "c\n"})
        self.publish(tips)

        hot = self.invoke(self.context())["hot_files"]

        self.assertEqual([entry["path"] for entry in hot], ["src/a.ts"])


class Refusals(OverviewCase):
    def test_a_truncated_stack_context_is_refused(self) -> None:
        self.publish(self.stack())
        for direction in ("above", "below"):
            with self.subTest(direction=direction):
                note = f"stopped after 16 layers {direction}"
                message = self.failure(self.context(notes=[note]))
                self.assertIn(note, message)
                self.assertIn("incomplete", message)

    def test_a_branch_outside_a_stack_is_refused(self) -> None:
        message = self.failure(self.context(state="unstacked", summary="Not part of a Pull Request stack."))

        self.assertIn("this is not a stack whose layers are all known: Not part of a Pull Request stack.", message)

    def test_a_layer_without_a_pull_request_is_refused(self) -> None:
        message = self.failure(self.context(upstack=[{"branch": "layer-c", "pr": None, "ref": None}]))

        self.assertIn("layer `layer-c` has no open Pull Request", message)

    def test_layers_that_do_not_chain_are_refused(self) -> None:
        self.publish(self.stack(), **{"12": {"baseRefName": "main"}})

        message = self.failure(self.context())

        self.assertIn("#12 targets `main`, not `layer-a`, so the layers do not form one linear stack", message)

    def test_a_closed_layer_is_refused(self) -> None:
        self.publish(self.stack(), **{"13": {"state": "CLOSED"}})

        self.assertIn("Pull Request #13 is closed, not open", self.failure(self.context()))

    def test_a_head_that_moved_during_the_fetch_is_refused(self) -> None:
        self.publish(self.stack(), **{"13": {"headRefOid": "f" * 40}})

        self.assertIn("#13 moved while it was fetched", self.failure(self.context()))

    def test_an_advanced_pull_ref_is_refused_even_when_the_old_commit_still_exists(self) -> None:
        self.publish(self.stack())
        git(self.repo, "switch", "-q", "layer-c")
        head = self.commit({"src/new.ts": "new\n"})
        git(self.repo, "push", "-q", "origin", f"{head}:refs/pull/13/head")

        self.assertIn("#13 moved while it was fetched", self.failure(self.context()))

    def test_a_force_pushed_pull_ref_is_refused_even_when_the_old_commit_still_exists(self) -> None:
        self.publish(self.stack())
        head = self.layer("rewritten-c", "layer-b", {"src/replacement.ts": "replacement\n"})
        git(self.repo, "push", "-q", "-f", "origin", f"{head}:refs/pull/13/head")

        self.assertIn("#13 moved while it was fetched", self.failure(self.context()))

    def test_an_invalid_repository_is_a_usage_error(self) -> None:
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            stack_overview.main(["--repo", "acme", "--context", "-"])

        self.assertEqual(raised.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
