from __future__ import annotations

import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "skills" / "kramme:pr:review-convergence" / "scripts" / "convergence-state.py"
)
RISK_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "risk-signals.py"


def load_module():
    spec = importlib.util.spec_from_file_location("convergence_state", SCRIPT_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, text=True, capture_output=True, check=True).stdout.strip()


class ConvergenceStateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name).resolve()
        run_git(self.repo, "init", "-q", "-b", "main")
        run_git(self.repo, "config", "user.email", "test@example.com")
        run_git(self.repo, "config", "user.name", "Test")
        run_git(self.repo, "config", "commit.gpgsign", "false")
        (self.repo / ".gitignore").write_text(".context/\n", encoding="utf-8")
        (self.repo / "src.txt").write_text("one\n", encoding="utf-8")
        run_git(self.repo, "add", ".")
        run_git(self.repo, "commit", "-q", "-m", "initial")
        self.previous_cwd = Path.cwd()
        os.chdir(self.repo)
        self.addCleanup(os.chdir, self.previous_cwd)

    def invoke(self, *argv: str) -> tuple[int, dict, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = self.module.main(list(argv))
        payload = json.loads(out.getvalue()) if out.getvalue().strip() else {}
        return code, payload, err.getvalue()

    def test_validate_archive_creates_real_ignored_directories(self) -> None:
        code, payload, _ = self.invoke("validate-archive", "--archive-key", "pr-review-convergence")
        self.assertEqual(code, 0)
        self.assertEqual(payload["review_archive"], ".context/pr-review-convergence/reviews")
        archive = self.repo / ".context" / "pr-review-convergence" / "reviews"
        self.assertTrue(archive.is_dir())
        self.assertEqual(Path(payload["canonical"]), archive.resolve())

    def test_validate_archive_rejects_unlisted_key(self) -> None:
        code, _, err = self.invoke("validate-archive", "--archive-key", "../escape")
        self.assertEqual(code, 1)
        self.assertIn("not allowlisted", err)

    def test_validate_archive_rejects_symlink_component(self) -> None:
        outside = self.repo.parent / "outside-context"
        outside.mkdir(exist_ok=True)
        self.addCleanup(lambda: outside.rmdir() if outside.exists() else None)
        (self.repo / ".context").symlink_to(outside, target_is_directory=True)
        code, _, err = self.invoke("validate-archive", "--archive-key", "pr-review-convergence")
        self.assertEqual(code, 1)
        self.assertIn("symlink", err)

    def test_validate_archive_requires_git_ignore(self) -> None:
        (self.repo / ".gitignore").write_text("", encoding="utf-8")
        code, _, err = self.invoke("validate-archive", "--archive-key", "linear-issue-to-pr")
        self.assertEqual(code, 1)
        self.assertIn("not ignored", err)

    def test_ledger_records_and_summarizes_cost(self) -> None:
        key = "code-plan-to-pr"
        self.assertEqual(
            self.invoke("ledger", "init", "--archive-key", key, "--work-id", "W1", "--max-cycles", "2")[0], 0
        )
        entries = [
            {"kind": "round", "round_kind": "full"},
            {"kind": "gate", "gate": "code-review", "agents_launched": 9},
            {"kind": "gate", "gate": "convention-review", "agents_launched": 3},
            {"kind": "cycle", "fingerprints_before": 2, "fingerprints_after": 0},
            {"kind": "round", "round_kind": "delta"},
            {"kind": "gate", "gate": "code-review", "agents_launched": 4},
        ]
        for entry in entries:
            code, payload, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", json.dumps(entry))
            self.assertEqual(code, 0, err)
        code, summary, _ = self.invoke("ledger", "summary", "--archive-key", key)
        self.assertEqual(code, 0)
        self.assertEqual(summary["cycles_used"], 1)
        self.assertEqual(summary["rounds"], {"full": 1, "delta": 1, "closing": 0, "validation-only": 0})
        self.assertEqual(summary["agents_launched"], {"code-review": 13, "convention-review": 3})
        self.assertEqual(
            summary["review_cost_line"],
            "Review cost: 16 agents across 2 rounds (full×1, delta×1); per gate: code-review 13, convention-review 3",
        )

    def test_ledger_rejects_malformed_entries_and_budget_overrun(self) -> None:
        key = "pr-review-convergence"
        self.invoke("ledger", "init", "--archive-key", key, "--work-id", "W1", "--max-cycles", "1")
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", '{"kind": "gate", "gate": "x"}')
        self.assertEqual(code, 1)
        self.assertIn("agents_launched", err)
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", '{"kind": "round"}')
        self.assertEqual(code, 1)
        self.assertIn("round_kind", err)
        self.assertEqual(self.invoke("ledger", "record", "--archive-key", key, "--entry", '{"kind": "cycle"}')[0], 0)
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", '{"kind": "cycle"}')
        self.assertEqual(code, 1)
        self.assertIn("exceeds the budget", err)

    def test_ledger_records_a_batch_in_one_call(self) -> None:
        key = "linear-issue-to-pr"
        self.invoke("ledger", "init", "--archive-key", key, "--work-id", "W1", "--max-cycles", "1")
        batch = [
            {"kind": "round", "round_kind": "closing"},
            {"kind": "gate", "gate": "code-review", "agents_launched": 5},
            {"kind": "gate", "gate": "overengineering-review", "agents_launched": 1},
        ]
        code, payload, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", json.dumps(batch))
        self.assertEqual(code, 0, err)
        self.assertEqual((payload["recorded"], payload["sequence"]), (3, 3))
        _, summary, _ = self.invoke("ledger", "summary", "--archive-key", key)
        self.assertEqual(summary["rounds"]["closing"], 1)
        self.assertEqual(summary["total_agents"], 6)

    def test_ledger_batch_is_all_or_nothing(self) -> None:
        key = "linear-issue-to-pr"
        self.invoke("ledger", "init", "--archive-key", key, "--work-id", "W1", "--max-cycles", "1")
        bad = [{"kind": "round", "round_kind": "full"}, {"kind": "gate", "gate": "code-review"}]
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", json.dumps(bad))
        self.assertEqual(code, 1)
        self.assertIn("agents_launched", err)
        over_budget = [{"kind": "cycle"}, {"kind": "cycle"}]
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", json.dumps(over_budget))
        self.assertEqual(code, 1)
        self.assertIn("exceeds the budget", err)
        code, _, err = self.invoke("ledger", "record", "--archive-key", key, "--entry", "[]")
        self.assertEqual(code, 1)
        self.assertIn("at least one entry", err)
        _, summary, _ = self.invoke("ledger", "summary", "--archive-key", key)
        self.assertEqual((summary["cycles_used"], sum(summary["rounds"].values())), (0, 0))

    def test_ledger_record_requires_init(self) -> None:
        code, _, err = self.invoke(
            "ledger",
            "record",
            "--archive-key",
            "pr-review-convergence",
            "--entry",
            '{"kind": "round", "round_kind": "full"}',
        )
        self.assertEqual(code, 1)
        self.assertIn("ledger init", err)

    def _init_ledger(self, key: str = "pr-review-convergence") -> None:
        self.invoke("ledger", "init", "--archive-key", key, "--work-id", "ABC-1", "--max-cycles", "3")

    def test_commit_boundary_commits_only_named_paths(self) -> None:
        self._init_ledger()
        (self.repo / "src.txt").write_text("two\n", encoding="utf-8")
        code, payload, err = self.invoke(
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "Fix review finding for ABC-1",
            "--",
            "src.txt",
        )
        self.assertEqual(code, 0, err)
        self.assertEqual(payload["commit"], run_git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(payload["tree"], run_git(self.repo, "rev-parse", "HEAD^{tree}"))
        self.assertFalse(payload["hook_changed_tree"])
        self.assertTrue(payload["worktree_clean"])
        self.assertEqual(run_git(self.repo, "log", "-1", "--format=%s"), "Fix review finding for ABC-1")
        _, summary, _ = self.invoke("ledger", "summary", "--archive-key", "pr-review-convergence")
        self.assertEqual(summary["commits"][0]["commit"], payload["commit"])

    def test_commit_boundary_stops_on_unrelated_dirty_paths(self) -> None:
        self._init_ledger()
        (self.repo / "src.txt").write_text("two\n", encoding="utf-8")
        (self.repo / "stray.txt").write_text("leftover\n", encoding="utf-8")
        code, _, err = self.invoke(
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "ABC-1 fix",
            "--",
            "src.txt",
        )
        self.assertEqual(code, 1)
        self.assertIn("stray.txt", err)
        self.assertEqual(run_git(self.repo, "log", "-1", "--format=%s"), "initial")

    def test_commit_boundary_requires_work_id_and_changes(self) -> None:
        self._init_ledger()
        code, _, err = self.invoke(
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "x",
            "--",
            "src.txt",
        )
        self.assertEqual(code, 1)
        self.assertIn("work ID", err)
        code, _, err = self.invoke(
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "ABC-1",
            "--",
            "src.txt",
        )
        self.assertEqual(code, 1)
        self.assertIn("no changes", err)

    def test_commit_boundary_enforces_exact_file_scope(self) -> None:
        self._init_ledger()
        (self.repo / "src.txt").write_text("two\n", encoding="utf-8")
        base = [
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "ABC-1 fix",
            "--scope-mode",
            "exact-files",
            "--scope-path",
            "other.txt",
            "--",
            "src.txt",
        ]
        code, _, err = self.invoke(*base)
        self.assertEqual(code, 1)
        self.assertIn("exact scope", err)
        base[base.index("other.txt")] = "src.txt"
        self.assertEqual(self.invoke(*base)[0], 0)

    def test_commit_boundary_rejects_unsafe_paths(self) -> None:
        self._init_ledger()
        for bad in ("../src.txt", "/src.txt", "-src.txt"):
            code, _, err = self.invoke(
                "commit-boundary",
                "--archive-key",
                "pr-review-convergence",
                "--work-id",
                "ABC-1",
                "--message",
                "ABC-1",
                "--",
                bad,
            )
            self.assertEqual(code, 1, bad)

    def test_commit_boundary_reports_hook_changed_tree(self) -> None:
        self._init_ledger()
        hooks = self.repo / ".git" / "hooks"
        hook = hooks / "pre-commit"
        hook.write_text("#!/bin/sh\nprintf 'hooked\\n' >> src.txt\ngit add src.txt\n", encoding="utf-8")
        hook.chmod(0o755)
        (self.repo / "src.txt").write_text("two\n", encoding="utf-8")
        code, payload, _ = self.invoke(
            "commit-boundary",
            "--archive-key",
            "pr-review-convergence",
            "--work-id",
            "ABC-1",
            "--message",
            "ABC-1 fix",
            "--",
            "src.txt",
        )
        self.assertEqual(code, 3)
        self.assertTrue(payload["hook_changed_tree"])
        self.assertNotEqual(payload["staged_tree"], payload["tree"])

    def _branch_with(self, files: dict[str, str]) -> None:
        run_git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        run_git(self.repo, "switch", "-q", "-c", "feature")
        for name, content in files.items():
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        run_git(self.repo, "add", ".")
        run_git(self.repo, "commit", "-q", "-m", "feature work")

    def _profile(self, *extra: str) -> tuple[int, dict, str]:
        return self.invoke(
            "profile",
            "--archive-key",
            "linear-issue-to-pr",
            "--base-ref",
            "refs/remotes/origin/main",
            "--risk-script",
            str(RISK_SCRIPT),
            *extra,
        )

    def test_profile_maps_the_risk_floor(self) -> None:
        cases = {
            "light": {"notes.txt": "a small change\n"},
            "balanced": {"src/app.py": "".join(f"value_{index} = {index}\n" for index in range(120))},
            "full": {".github/workflows/ci.yml": "on: push\n"},
        }
        for expected, files in cases.items():
            with self.subTest(profile=expected):
                run_git(self.repo, "switch", "-q", "main")
                subprocess.run(["git", "branch", "-D", "feature"], cwd=self.repo, capture_output=True, check=False)
                self._branch_with(files)
                self._init_ledger("linear-issue-to-pr")
                code, payload, err = self._profile()
                self.assertEqual(code, 0, err)
                self.assertEqual(payload["profile"], expected)
                self.assertEqual(payload["policy_ref"], "refs/remotes/origin/main")
                _, summary, _ = self.invoke("ledger", "summary", "--archive-key", "linear-issue-to-pr")
                self.assertEqual(summary["profile"], expected)
                self.assertTrue(summary["review_cost_line"].endswith(f"; profile {expected}"))

    def test_profile_options_only_raise_and_never_lower_within_a_run(self) -> None:
        self._branch_with({"notes.txt": "a small change\n"})
        self._init_ledger("linear-issue-to-pr")
        self.assertEqual(self._profile()[1]["profile"], "light")
        code, payload, err = self._profile("--raise", "balanced", "--reason", "accepted Critical finding")
        self.assertEqual(code, 0, err)
        self.assertEqual(payload["profile"], "balanced")
        self.assertIn("--raise balanced: accepted Critical finding", payload["reasons"])
        code, payload, _ = self._profile()
        self.assertEqual(payload["profile"], "balanced")
        self.assertIn("kept earlier balanced; a profile never lowers within a run", payload["reasons"])
        self.assertEqual(self._profile("--depth", "full")[1]["profile"], "full")
        self._init_ledger("linear-issue-to-pr")
        self.assertEqual(self._profile("--strict")[1]["profile"], "full")

    def test_profile_entries_come_only_from_the_profile_subcommand(self) -> None:
        self._branch_with({"notes.txt": "a small change\n"})
        self._init_ledger("linear-issue-to-pr")
        forged = json.dumps({"kind": "profile", "profile": "light", "floor": "low"})
        code, _, err = self.invoke("ledger", "record", "--archive-key", "linear-issue-to-pr", "--entry", forged)
        self.assertEqual(code, 1)
        self.assertIn("only by the `profile` subcommand", err)
        ledger_file = self.repo / ".context" / "linear-issue-to-pr" / "reviews" / "cycle-ledger.json"
        data = json.loads(ledger_file.read_text(encoding="utf-8"))
        data["entries"] = [
            {"kind": "profile", "profile": "full", "floor": "high", "sequence": 1},
            {"kind": "profile", "profile": "light", "floor": "low", "sequence": 2},
        ]
        ledger_file.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(self.invoke("ledger", "summary", "--archive-key", "linear-issue-to-pr")[1]["profile"], "full")
        self.assertEqual(self._profile()[1]["profile"], "full")

    def test_profile_rejects_unpaired_raise_and_foreign_scripts(self) -> None:
        self._branch_with({"notes.txt": "a small change\n"})
        self._init_ledger("linear-issue-to-pr")
        code, _, err = self._profile("--raise", "full")
        self.assertEqual(code, 1)
        self.assertIn("--reason", err)
        code, _, err = self._profile("--depth", "light")
        self.assertEqual(code, 2)
        other = self.repo / "other.py"
        other.write_text("print('{}')\n", encoding="utf-8")
        code, _, err = self.invoke(
            "profile",
            "--archive-key",
            "linear-issue-to-pr",
            "--base-ref",
            "refs/remotes/origin/main",
            "--risk-script",
            str(other),
        )
        self.assertEqual(code, 1)
        self.assertIn("risk-signals.py", err)

    def test_profile_requires_a_trusted_policy_ref(self) -> None:
        run_git(self.repo, "switch", "-q", "-c", "feature")
        (self.repo / "notes.txt").write_text("change\n", encoding="utf-8")
        run_git(self.repo, "add", ".")
        run_git(self.repo, "commit", "-q", "-m", "feature work")
        run_git(self.repo, "update-ref", "refs/remotes/upstream/main", "main")
        self._init_ledger("linear-issue-to-pr")
        code, _, err = self.invoke(
            "profile",
            "--archive-key",
            "linear-issue-to-pr",
            "--base-ref",
            "refs/remotes/upstream/main",
            "--risk-script",
            str(RISK_SCRIPT),
        )
        self.assertEqual(code, 1)
        self.assertIn("origin/HEAD, origin/main, or origin/master", err)

    def test_usage_errors_exit_two(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = self.module.main(["ledger"])
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
