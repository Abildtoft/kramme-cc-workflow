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

SKILL_DIR = Path(__file__).resolve().parents[2] / "skills" / "kramme:pr:triage-risk"
SCRIPT_PATH = SKILL_DIR / "scripts" / "risk-signals.py"
SPEC = importlib.util.spec_from_file_location("risk_signals", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
# The script imports its sibling risk_patterns module, which script-form runs find on sys.path[0].
sys.path.insert(0, str(SCRIPT_PATH.parent))
risk_signals = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = risk_signals
SPEC.loader.exec_module(risk_signals)

# Assembled at runtime so no credential-shaped literal is committed.
FAKE_AWS_KEY_ID = "AKIA" + "ABCDEFGHIJKLMNOP"
FAKE_PRIVATE_KEY_HEADER = "-----BEGIN " + "RSA PRIVATE KEY-----"


def lines(count: int, prefix: str = "value") -> str:
    return "".join(f"{prefix}_{index} = {index}\n" for index in range(count))


class RiskSignalsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = risk_signals
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name).resolve()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "Test")
        self.git("config", "commit.gpgsign", "false")
        self.write("README.md", "# Project\n")
        self.write("src/app.py", "print('hello')\n")
        self.base = self.commit("base")

    def git(self, *args: str) -> str:
        return subprocess.run(["git", *args], cwd=self.repo, text=True, capture_output=True, check=True).stdout.strip()

    def write(self, path: str, content: str) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", message)
        return self.git("rev-parse", "HEAD")

    def report(self, merge_base: str | None = None, policy_rev: str | None = None) -> dict[str, Any]:
        head = self.commit("change")
        base = merge_base or self.base
        result: dict[str, Any] = self.module.build_report(str(self.repo), base, head, policy_rev or base)
        return result

    def signals(self, report: dict[str, Any]) -> dict[str, dict[str, Any]]:
        return {signal["id"]: signal for signal in report["signals"]}

    def write_policy(self, policy: dict[str, Any] | str) -> None:
        content = policy if isinstance(policy, str) else json.dumps(policy)
        self.write(".github/pr-risk.json", content)
        self.base = self.commit("add policy")

    def test_docs_only_change_is_low(self) -> None:
        self.write("README.md", "# Project\n\n" + lines(300, "doc"))
        report = self.report()

        self.assertEqual(report["signals"], [])
        self.assertEqual((report["floor"], report["hard_floor"]), ("low", "low"))
        self.assertEqual(report["totals"]["code_lines"], 0)
        self.assertEqual(report["totals"]["kinds"], {"docs": 1})

    def test_small_code_change_with_tests_is_low(self) -> None:
        self.write("src/app.py", "print('hello')\n" + lines(30))
        self.write("tests/test_app.py", "def test_app():\n    assert True\n")
        report = self.report()

        self.assertEqual(report["signals"], [])
        self.assertEqual(report["floor"], "low")
        self.assertEqual(report["totals"]["kinds"], {"code": 1, "test": 1})

    def test_auth_path_is_high_but_discountable(self) -> None:
        self.write("src/auth/session.py", "TIMEOUT = 30\n")
        report = self.report()
        signal = self.signals(report)["path:auth"]

        self.assertEqual((signal["level"], signal["discountable"]), ("high", True))
        self.assertEqual(signal["evidence"], ["src/auth/session.py"])
        self.assertEqual((report["floor"], report["hard_floor"]), ("high", "low"))

    def test_path_words_split_camel_case_without_matching_substrings(self) -> None:
        self.assertIn("path:auth", self.module.code_path_signals("src/AuthService.ts"))
        self.assertIn("path:auth", self.module.code_path_signals("src/JWTVerifier.ts"))
        self.assertIn("path:auth", self.module.code_path_signals("src/OAuth2Client.ts"))
        self.assertIn("path:infra", self.module.code_path_signals("deploy/k8s/app.yaml"))
        self.assertNotIn("path:auth", self.module.code_path_signals("src/author.ts"))
        self.assertNotIn("path:auth", self.module.code_path_signals("src/tokenizer.py"))

    def test_test_and_docs_files_skip_built_in_path_categories(self) -> None:
        self.write("tests/auth/test_login.py", "def test_login():\n    assert True\n")
        self.write("docs/auth.md", "# Auth\n")
        report = self.report()

        self.assertNotIn("path:auth", self.signals(report))

    def test_sensitive_path_categories(self) -> None:
        self.write(".github/workflows/ci.yml", "on: push\n")
        self.write("CODEOWNERS", "* @team\n")
        self.write("db/migrations/001_users.sql", "ALTER TABLE users ADD COLUMN age int;\n")
        self.write("infra/main.tf", 'resource "x" "y" {}\n')
        self.write("Dockerfile", "FROM python:3.12\n")
        self.write(".env.production", "DEBUG=false\n")
        self.write(".env.example", "DEBUG=true\n")
        self.write("api/openapi.yaml", "openapi: 3.1.0\n")
        signals = self.signals(self.report())

        self.assertEqual(signals["path:ci"]["evidence"], [".github/workflows/ci.yml", "CODEOWNERS"])
        self.assertEqual(signals["path:database"]["evidence"], ["db/migrations/001_users.sql"])
        self.assertEqual(signals["path:infra"]["evidence"], ["Dockerfile", "infra/main.tf"])
        self.assertEqual(signals["path:secrets-config"]["evidence"], [".env.production"])
        self.assertEqual(signals["path:api-contract"]["evidence"], ["api/openapi.yaml"])

    def test_lockfile_only_change_raises_dependencies_without_code_lines(self) -> None:
        self.write("package-lock.json", '{\n  "lockfileVersion": 3\n}\n')
        report = self.report()
        signal = self.signals(report)["path:dependencies"]

        self.assertEqual((signal["level"], signal["evidence"]), ("medium", ["package-lock.json"]))
        self.assertEqual(report["totals"]["code_lines"], 0)
        self.assertEqual(report["totals"]["kinds"], {"lockfile": 1})

    def test_dependency_manifests_raise_dependencies_as_code(self) -> None:
        manifests = {
            "package.json": '{"name": "app"}\n',
            "pyproject.toml": '[project]\nname = "app"\n',
            "requirements-dev.txt": "pytest\n",
            "src/App.csproj": "<Project />\n",
        }
        for path, content in manifests.items():
            with self.subTest(path=path):
                self.write(path, content)
                report = self.report()
                files = {entry["path"]: entry for entry in report["files"]}

                self.assertEqual(self.signals(report)["path:dependencies"]["evidence"], [path])
                self.assertEqual(files[path]["kind"], "code")
                self.base = self.git("rev-parse", "HEAD")

    def test_secret_shapes_are_located_without_reproducing_the_value(self) -> None:
        self.write("docs/setup.md", f"# Setup\n\nkey = {FAKE_AWS_KEY_ID}\n")
        self.write("config/deploy_key", f"{FAKE_PRIVATE_KEY_HEADER}\n")
        report = self.report()
        signal = self.signals(report)["content:secret"]

        self.assertEqual((signal["level"], signal["discountable"]), ("high", False))
        self.assertEqual(
            signal["evidence"], ["config/deploy_key:1 (private-key)", "docs/setup.md:3 (aws-access-key-id)"]
        )
        self.assertEqual(report["hard_floor"], "high")
        serialized = json.dumps(report)
        self.assertNotIn(FAKE_AWS_KEY_ID, serialized)
        self.assertNotIn("PRIVATE KEY", serialized)

    def test_every_secret_pattern_matches_an_added_line(self) -> None:
        # Assembled at runtime so no credential-shaped literal is committed.
        fakes = {
            "private-key": FAKE_PRIVATE_KEY_HEADER,
            "aws-access-key-id": FAKE_AWS_KEY_ID,
            "github-token": "gh" + "p_" + "a" * 36,
            "slack-token": "xo" + "xb-" + "1" * 12,
            "stripe-live-key": "sk" + "_live_" + "A" * 24,
            "google-api-key": "AI" + "za" + "B" * 35,
            "provider-api-key": "sk-" + "ant-" + "c" * 40,
        }
        self.assertEqual(set(fakes), {name for name, _ in self.module.patterns.SECRET_PATTERNS})
        for name, value in fakes.items():
            with self.subTest(pattern=name):
                path = f"src/{name}.py"
                self.write(path, f"KEY = '{value}'\n")
                report = self.report()

                self.assertEqual(self.signals(report)["content:secret"]["evidence"], [f"{path}:1 ({name})"])
                self.assertNotIn(value, json.dumps(report))
                self.base = self.git("rev-parse", "HEAD")

    def test_removing_a_secret_is_not_flagged(self) -> None:
        self.write("src/config.py", f"KEY = '{FAKE_AWS_KEY_ID}'\n")
        self.base = self.commit("leaked key")
        self.write("src/config.py", "KEY = None\n")

        self.assertNotIn("content:secret", self.signals(self.report()))

    def test_dangerous_sinks_are_scanned_in_code_files_only(self) -> None:
        sink_lines = "el.innerHTML = html\nmodel.eval()\nconst out = eval(input)\n"
        self.write("src/render.js", sink_lines)
        self.write("tests/render.test.js", sink_lines)
        signal = self.signals(self.report())["content:dangerous-sink"]

        self.assertEqual(signal["evidence"], ["src/render.js:1 (raw-html)", "src/render.js:3 (eval)"])

    def test_disabled_tests_are_scanned_in_test_files_only(self) -> None:
        self.write("tests/app.test.js", "it.skip('works', () => {})\ndescribe.only('suite', () => {})\n")
        self.write("src/helper.js", "it.skip('not a test file', () => {})\n")
        signal = self.signals(self.report())["content:disabled-test"]

        self.assertEqual(signal["evidence"], ["tests/app.test.js:1 (skip)", "tests/app.test.js:2 (focus)"])

    def test_deleted_source_file(self) -> None:
        (self.repo / "src" / "app.py").unlink()
        signal = self.signals(self.report())["shape:deleted-source"]

        self.assertEqual(signal["evidence"], ["src/app.py"])

    def test_untested_source_requires_a_threshold_and_no_test_changes(self) -> None:
        self.write("src/feature.py", lines(25))
        without_tests = self.signals(self.report())
        self.assertEqual(without_tests["shape:untested-source"]["evidence"], ["src/feature.py"])

        self.write("src/feature.py", lines(26))
        self.write("tests/test_feature.py", "def test_feature():\n    assert True\n")
        with_tests = self.signals(self.report(merge_base=self.base))
        self.assertNotIn("shape:untested-source", with_tests)

    def test_untested_source_ignores_small_changes(self) -> None:
        self.write("src/feature.py", lines(5))
        self.assertNotIn("shape:untested-source", self.signals(self.report()))

    def test_deleting_a_test_does_not_count_as_touching_tests(self) -> None:
        self.write("tests/test_app.py", "def test_app():\n    assert True\n")
        self.base = self.commit("add test")
        (self.repo / "tests" / "test_app.py").unlink()
        self.write("src/feature.py", lines(30))
        signals = self.signals(self.report())

        self.assertEqual(signals["shape:untested-source"]["evidence"], ["src/feature.py"])

    def test_size_emits_only_the_largest_shape_signal(self) -> None:
        cases = ((150, "shape:non-trivial"), (500, "shape:large"), (1200, "shape:very-large"))
        for count, expected in cases:
            with self.subTest(count=count):
                self.write(f"src/size_{count}.py", lines(count))
                self.write(f"tests/test_size_{count}.py", "def test():\n    assert True\n")
                shape = [signal_id for signal_id in self.signals(self.report()) if signal_id.startswith("shape:")]
                self.assertEqual(shape, [expected])
                self.base = self.git("rev-parse", "HEAD")

    def test_file_count_alone_raises_size_signals(self) -> None:
        for count, expected in ((11, "shape:non-trivial"), (26, "shape:large")):
            with self.subTest(count=count):
                for index in range(count):
                    self.write(f"src/wide_{count}/module_{index}.py", "A = 1\n")
                self.write(f"tests/test_wide_{count}.py", "def test():\n    assert True\n")
                shape = [signal_id for signal_id in self.signals(self.report()) if signal_id.startswith("shape:")]
                self.assertEqual(shape, [expected])
                self.base = self.git("rev-parse", "HEAD")

    def test_policy_from_base_adds_non_discountable_paths(self) -> None:
        self.write_policy({"version": 1, "high_risk_paths": ["src/billing/"], "medium_risk_paths": ["src/*.py"]})
        self.write("src/billing/charge.py", "AMOUNT = 1\n")
        self.write("src/app.py", "print('changed')\n")
        report = self.report()
        signals = self.signals(report)

        self.assertEqual(report["policy"]["status"], "loaded")
        self.assertEqual(signals["policy:high-path"]["evidence"], ["src/billing/charge.py"])
        self.assertFalse(signals["policy:high-path"]["discountable"])
        self.assertEqual(signals["policy:medium-path"]["evidence"], ["src/app.py", "src/billing/charge.py"])
        self.assertEqual(report["hard_floor"], "high")

    def test_policy_added_on_the_branch_is_not_trusted(self) -> None:
        self.write(".github/pr-risk.json", json.dumps({"version": 1, "medium_risk_paths": ["src/"]}))
        self.write("src/app.py", "print('changed')\n")
        report = self.report()
        signals = self.signals(report)

        self.assertEqual(report["policy"]["status"], "absent")
        self.assertNotIn("policy:medium-path", signals)
        self.assertEqual(signals["policy:changed"]["evidence"], [".github/pr-risk.json"])
        self.assertEqual(report["hard_floor"], "high")

    def test_invalid_policy_escalates_instead_of_failing(self) -> None:
        cases = {
            "not json": "{",
            "unknown key": json.dumps({"version": 1, "high_risk_path": ["src/"]}),
            "missing version": json.dumps({"high_risk_paths": ["src/"]}),
            "leading slash": json.dumps({"version": 1, "high_risk_paths": ["/src/"]}),
            "dot slash": json.dumps({"version": 1, "high_risk_paths": ["./src/"]}),
            "backslash": json.dumps({"version": 1, "high_risk_paths": ["src\\billing\\"]}),
            "empty pattern": json.dumps({"version": 1, "generated_paths": [""]}),
            "not an object": json.dumps(["src/"]),
        }
        for label, content in cases.items():
            with self.subTest(label=label):
                self.write_policy(content)
                self.write("src/app.py", f"print({label!r})\n")
                report = self.report()

                self.assertEqual(report["policy"]["status"], "invalid")
                self.assertTrue(report["policy"]["error"])
                self.assertIn("policy:invalid", self.signals(report))
                self.assertEqual(report["hard_floor"], "high")

    def test_policy_symlink_is_invalid(self) -> None:
        self.write("real-policy.json", json.dumps({"version": 1}))
        (self.repo / ".github").mkdir()
        os.symlink("../real-policy.json", self.repo / ".github" / "pr-risk.json")
        self.base = self.commit("symlinked policy")
        self.write("src/app.py", "print('changed')\n")
        report = self.report()

        self.assertEqual(report["policy"]["status"], "invalid")
        self.assertEqual(report["policy"]["error"], "policy path is not a regular file")

    def test_generated_paths_leave_size_and_path_categories(self) -> None:
        self.write_policy({"version": 1, "generated_paths": ["src/client/"]})
        self.write("src/client/auth_api.ts", lines(500, "field") + "el.innerHTML = html\n")
        report = self.report()

        self.assertEqual(report["files"][0]["kind"], "generated")
        self.assertEqual(report["signals"], [])

    def test_generated_and_docs_files_keep_secret_and_policy_signals(self) -> None:
        self.write_policy(
            {"version": 1, "high_risk_paths": ["src/client/", "docs/billing/"], "generated_paths": ["src/client/"]}
        )
        self.write("src/client/api.ts", f"const key = '{FAKE_AWS_KEY_ID}'\n")
        self.write("docs/billing/refunds.md", "# Refunds\n")
        signals = self.signals(self.report())

        self.assertEqual(signals["content:secret"]["evidence"], ["src/client/api.ts:1 (aws-access-key-id)"])
        self.assertEqual(signals["policy:high-path"]["evidence"], ["docs/billing/refunds.md", "src/client/api.ts"])

    def test_ci_and_built_in_generated_names_cannot_hide_risk(self) -> None:
        self.write(".github/workflows/ci_test.yml", "on: pull_request\n")
        self.write(".github/actions/test/action.yml", "runs: {using: node20}\n")
        self.write("lib/__generated__/session.ts", "const out = eval(input)\n")
        self.write("db/migrations/0001.generated.sql", "DROP TABLE users;\n")
        report = self.report()
        signals = self.signals(report)

        self.assertEqual(
            signals["path:ci"]["evidence"], [".github/actions/test/action.yml", ".github/workflows/ci_test.yml"]
        )
        self.assertEqual(signals["path:auth"]["evidence"], ["lib/__generated__/session.ts"])
        self.assertEqual(signals["path:database"]["evidence"], ["db/migrations/0001.generated.sql"])
        self.assertEqual(signals["content:dangerous-sink"]["evidence"], ["lib/__generated__/session.ts:1 (eval)"])
        self.assertEqual(report["totals"]["kinds"], {"code": 4})

    def test_rename_out_of_a_sensitive_directory_flags_the_old_path(self) -> None:
        self.write("src/auth/store.py", "STORE = {}\n")
        self.base = self.commit("auth store")
        (self.repo / "src" / "util").mkdir()
        self.git("mv", "src/auth/store.py", "src/util/store.py")
        report = self.report()

        self.assertEqual(report["files"][0]["status"], "R")
        self.assertEqual(self.signals(report)["path:auth"]["evidence"], ["src/auth/store.py"])

    def test_rename_into_a_test_directory_keeps_the_old_path_category(self) -> None:
        self.write("src/auth/session.py", "TIMEOUT = 30\n")
        self.base = self.commit("auth session")
        (self.repo / "tests" / "legacy").mkdir(parents=True)
        self.git("mv", "src/auth/session.py", "tests/legacy/session.py")
        report = self.report()

        self.assertEqual((report["files"][0]["status"], report["files"][0]["kind"]), ("R", "test"))
        self.assertEqual(self.signals(report)["path:auth"]["evidence"], ["src/auth/session.py"])

    def test_type_mode_binary_and_quoted_paths_map_to_patch_sections(self) -> None:
        self.write("link.txt", "target\n")
        self.write("run.sh", "echo hi\n")
        (self.repo / "image.bin").write_bytes(b"\x00\x01binary")
        self.write("sp ace.py", "A = 1\n")
        self.base = self.commit("assorted files")
        (self.repo / "link.txt").unlink()
        os.symlink("run.sh", self.repo / "link.txt")
        (self.repo / "run.sh").chmod(0o755)
        (self.repo / "image.bin").write_bytes(b"\x00\x02binary")
        self.write("sp ace.py", "A = 1\nB = eval(x)\n")
        self.write("ünï.py", "C = eval(y)\n")
        report = self.report()
        files = {entry["path"]: entry for entry in report["files"]}

        self.assertEqual(files["link.txt"]["status"], "T")
        self.assertEqual((files["link.txt"]["added"], files["link.txt"]["deleted"]), (1, 1))
        self.assertEqual((files["run.sh"]["added"], files["run.sh"]["deleted"]), (0, 0))
        self.assertTrue(files["image.bin"]["binary"])
        self.assertEqual(
            self.signals(report)["content:dangerous-sink"]["evidence"], ["sp ace.py:2 (eval)", "ünï.py:1 (eval)"]
        )

    def test_branch_attributes_and_nul_bytes_cannot_hide_content(self) -> None:
        self.write(".gitattributes", "* -diff\n")
        self.write("src/auth/login.py", lines(1100) + f"KEY = '{FAKE_AWS_KEY_ID}'\n")
        (self.repo / "src" / "nul.py").write_bytes(b"# \x00\nout = eval(x)\n")
        report = self.report()
        signals = self.signals(report)
        files = {entry["path"]: entry for entry in report["files"]}

        self.assertEqual(signals["content:secret"]["evidence"], ["src/auth/login.py:1101 (aws-access-key-id)"])
        self.assertEqual(signals["content:dangerous-sink"]["evidence"], ["src/nul.py:2 (eval)"])
        self.assertIn("shape:very-large", signals)
        self.assertEqual((files["src/nul.py"]["binary"], files["src/nul.py"]["added"]), (True, 2))
        self.assertNotIn("binary", files["src/auth/login.py"])

    def test_submodule_moves_ignore_branch_and_user_ignore_settings(self) -> None:
        (self.repo / "vendor" / "lib").mkdir(parents=True)
        self.git("update-index", "--add", "--cacheinfo", f"160000,{self.base},vendor/lib")
        self.write(".gitmodules", '[submodule "lib"]\n\tpath = vendor/lib\n\turl = https://example.com/lib.git\n')
        self.base = self.commit("add submodule")
        self.git("config", "diff.ignoreSubmodules", "all")
        self.write(
            ".gitmodules",
            '[submodule "lib"]\n\tpath = vendor/lib\n\turl = https://example.com/lib.git\n\tignore = all\n',
        )
        self.git("add", "-A")
        self.git("update-index", "--cacheinfo", f"160000,{self.base},vendor/lib")
        report = self.report()
        files = {entry["path"]: entry for entry in report["files"]}

        self.assertTrue(files["vendor/lib"]["submodule"])
        self.assertEqual(self.signals(report)["path:dependencies"]["evidence"], [".gitmodules", "vendor/lib"])

    def test_diff_configuration_does_not_change_the_report(self) -> None:
        for key, value in (
            ("color.ui", "always"),
            ("diff.noprefix", "true"),
            ("diff.mnemonicPrefix", "true"),
            ("diff.relative", "true"),
            ("diff.submodule", "log"),
            ("diff.hide.textconv", "sh -c :"),
            ("diff.external", "true"),
        ):
            self.git("config", key, value)
        self.write(".gitattributes", "*.py diff=hide\n")
        self.write("src/auth/session.py", f"KEY = '{FAKE_AWS_KEY_ID}'\n")
        report = self.report()
        signals = self.signals(report)

        self.assertEqual(report["files"][1]["path"], "src/auth/session.py")
        self.assertIn("path:auth", signals)
        self.assertEqual(signals["content:secret"]["evidence"], ["src/auth/session.py:1 (aws-access-key-id)"])

    def test_main_prints_json_and_rejects_bad_revisions(self) -> None:
        self.write("src/auth/session.py", "TIMEOUT = 30\n")
        head = self.commit("change")
        cwd = os.getcwd()
        os.chdir(self.repo / "src")
        self.addCleanup(os.chdir, cwd)

        stdout = io.StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(self.module.main(["--merge-base", self.base, "--head", head]), 0)
        report = json.loads(stdout.getvalue())
        self.assertEqual(report["schema"], "kramme-pr-triage-risk-signals/v1")
        self.assertEqual(report["range"], {"merge_base": self.base, "head": head})

        script_run = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--merge-base", self.base], capture_output=True, text=True, check=False
        )
        self.assertEqual((script_run.returncode, json.loads(script_run.stdout)["range"]["head"]), (0, head))

        stderr = io.StringIO()
        with redirect_stderr(stderr):
            self.assertEqual(self.module.main(["--merge-base", "no-such-ref"]), 1)
        self.assertIn("cannot resolve 'no-such-ref' to a commit", stderr.getvalue())

        stdout = io.StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(self.module.main(["--merge-base", self.base, "--policy-rev", self.policy_on_main()]), 0)
        report = json.loads(stdout.getvalue())
        self.assertEqual(report["policy"]["status"], "loaded")
        self.assertIn("policy:high-path", self.signals(report))

        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as usage:
            self.module.main([])
        self.assertEqual(usage.exception.code, 2)

    def policy_on_main(self) -> str:
        """Commit a policy on a sibling branch forked at the merge base, as if main moved on after the fork."""
        branch = self.git("rev-parse", "--abbrev-ref", "HEAD")
        self.git("switch", "-q", "-c", "main-moved-on", self.base)
        self.write(".github/pr-risk.json", json.dumps({"version": 1, "high_risk_paths": ["src/auth/"]}))
        policy_commit = self.commit("policy on main")
        self.git("switch", "-q", branch)
        return policy_commit

    def test_policy_documentation_matches_the_policy_constants(self) -> None:
        signals_doc = (SKILL_DIR / "references" / "signals.md").read_text(encoding="utf-8")
        self.assertIn(f"`{self.module.POLICY_PATH}`", signals_doc)
        for key in self.module.POLICY_LIST_KEYS:
            self.assertIn(f'"{key}"', signals_doc)
        self.assertIn("`version` is required and must be `1`.", signals_doc)

    def test_every_signal_is_documented_and_levels_are_valid(self) -> None:
        signals_doc = (SKILL_DIR / "references" / "signals.md").read_text(encoding="utf-8")
        for signal_id, (level, discountable) in self.module.SIGNALS.items():
            with self.subTest(signal=signal_id):
                self.assertIn(level, self.module.LEVELS)
                row = f"| `{signal_id}` | {level} | {'yes' if discountable else 'no'} |"
                self.assertIn(row, signals_doc)


if __name__ == "__main__":
    unittest.main()
