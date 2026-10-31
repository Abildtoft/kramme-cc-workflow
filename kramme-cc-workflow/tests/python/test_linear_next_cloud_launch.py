"""Behavioral tests for the kramme:linear:next Conductor cloud launcher.

Every Conductor call runs against a fake `conductor` placed first on PATH that records its argv and replays one
configured response per call.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import stat
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SKILL_DIR = Path(__file__).resolve().parents[2] / "skills" / "kramme:linear:next"
SCRIPT_PATH = SKILL_DIR / "scripts" / "cloud-launch.py"
SPEC = importlib.util.spec_from_file_location("linear_next_cloud_launch", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
cloud_launch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cloud_launch)

FAKE_CONDUCTOR = """#!{python}
import json, os, sys, time
with open(os.environ["FAKE_CONDUCTOR_LOG"], "a", encoding="utf-8") as handle:
    handle.write(json.dumps(sys.argv[1:]) + "\\n")
counter = os.environ["FAKE_CONDUCTOR_COUNTER"]
call = int(open(counter, encoding="utf-8").read()) if os.path.exists(counter) else 0
with open(counter, "w", encoding="utf-8") as handle:
    handle.write(str(call + 1))
responses = json.loads(os.environ["FAKE_CONDUCTOR_RESPONSES"])
response = responses[min(call, len(responses) - 1)]
time.sleep(response.get("sleep", 0))
sys.stdout.write(response.get("stdout", ""))
sys.stderr.write(response.get("stderr", ""))
sys.exit(response.get("exit", 0))
"""
WORKSPACE = {"stdout": json.dumps({"id": "ws_current", "projectId": "proj_1", "name": "current"})}
SESSION = {"stdout": json.dumps({"id": "sess_1", "model": "opus-5-5-1m"})}


def created(number: int) -> dict[str, Any]:
    answer = {"workspaceId": f"ws_{number}", "sessionId": f"sess_new_{number}", "deepLink": f"conductor://ws_{number}"}
    return {"stdout": json.dumps(answer)}


class CloudLaunchTest(unittest.TestCase):
    def setUp(self) -> None:
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        self.root = Path(holder.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "conductor"
        fake.write_text(FAKE_CONDUCTOR.replace("{python}", sys.executable), encoding="utf-8")
        fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
        self.log = self.root / "calls.jsonl"
        self.counter = self.root / "call-counter"
        self.env = {
            "PATH": f"{self.bin}{os.pathsep}{os.environ.get('PATH', '')}",
            "CONDUCTOR_IS_LOCAL": "0",
            "CONDUCTOR_WORKSPACE_ID": "ws_current",
            "CONDUCTOR_SESSION_ID": "sess_1",
            "FAKE_CONDUCTOR_LOG": str(self.log),
            "FAKE_CONDUCTOR_COUNTER": str(self.counter),
            "FAKE_CONDUCTOR_RESPONSES": json.dumps([{}]),
        }

    def run_helper(
        self, *argv: str, responses: list[dict[str, Any]] | None = None, **env: str | None
    ) -> tuple[int, Any]:
        """Run the helper in-process; an env value of None removes that variable for the call."""
        self.counter.unlink(missing_ok=True)
        overrides: dict[str, str | None] = {**self.env, **env}
        if responses is not None:
            overrides["FAKE_CONDUCTOR_RESPONSES"] = json.dumps(responses)
        values = {name: value for name, value in overrides.items() if value is not None}
        output = io.StringIO()
        with mock.patch.dict(os.environ, values), redirect_stdout(output):
            for name, value in overrides.items():
                if value is None:
                    os.environ.pop(name, None)
            code = cloud_launch.main(list(argv))
        return code, json.loads(output.getvalue())

    def calls(self) -> list[list[str]]:
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def test_detect_reports_not_cloud_for_local_and_non_conductor_sessions(self) -> None:
        code, result = self.run_helper("detect", CONDUCTOR_IS_LOCAL="1")
        self.assertEqual((code, result["status"], result["reason"]), (0, "not_cloud", "local_workspace"))
        code, result = self.run_helper("detect", CONDUCTOR_IS_LOCAL=None)
        self.assertEqual((code, result["status"], result["reason"]), (0, "not_cloud", "not_conductor"))
        self.assertEqual(self.calls(), [])

    def test_detect_reports_project_and_session_model_in_a_cloud_workspace(self) -> None:
        code, result = self.run_helper("detect", responses=[WORKSPACE, SESSION])
        self.assertEqual(code, 0)
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["project_id"], "proj_1")
        self.assertEqual(result["session_model"], "opus-5-5-1m")
        self.assertEqual(
            self.calls(), [["--json", "workspace", "get", "ws_current"], ["--json", "session", "get", "sess_1"]]
        )

    def test_detect_is_unavailable_without_a_usable_cli_or_workspace(self) -> None:
        empty = self.root / "empty"
        empty.mkdir()
        _, result = self.run_helper("detect", PATH=str(empty))
        self.assertEqual((result["status"], result["reason"]), ("unavailable", "cli_missing"))
        _, result = self.run_helper("detect", CONDUCTOR_WORKSPACE_ID="ws current; rm")
        self.assertEqual((result["status"], result["reason"]), ("unavailable", "workspace_id_invalid"))
        _, result = self.run_helper("detect", responses=[{"exit": 3, "stderr": "Unauthorized\n"}])
        self.assertEqual((result["status"], result["reason"]), ("unavailable", "auth_error"))
        _, result = self.run_helper("detect", responses=[{"exit": 1, "stderr": "boom\n"}])
        self.assertEqual(
            (result["status"], result["reason"], result["message"]), ("unavailable", "workspace_lookup_failed", "boom")
        )
        other = {"stdout": json.dumps({"id": "ws_other", "projectId": "proj_1"})}
        _, result = self.run_helper("detect", responses=[other])
        self.assertEqual((result["status"], result["reason"]), ("unavailable", "project_unknown"))

    def test_detect_leaves_an_unusable_session_model_unset(self) -> None:
        odd_model = {"stdout": json.dumps({"id": "sess_1", "model": "claude-opus[1m]"})}
        _, result = self.run_helper("detect", responses=[WORKSPACE, odd_model])
        self.assertEqual((result["status"], result["session_model"]), ("ok", None))
        _, result = self.run_helper("detect", responses=[WORKSPACE, {"exit": 1}])
        self.assertIsNone(result["session_model"])

    def test_launch_builds_each_first_message_for_its_agent(self) -> None:
        code, result = self.run_helper(
            "launch", "--project-id", "proj_1",
            "--item", "DISC-1", "claude", "opus-5-5-1m",
            "--item", "DISC-2", "codex", "gpt-5.5",
            responses=[created(1), created(2)],
        )  # fmt: skip
        self.assertEqual((code, result["status"]), (0, "ok"))
        self.assertEqual([entry["outcome"] for entry in result["results"]], ["created", "created"])
        self.assertEqual(result["results"][0]["deep_link"], "conductor://ws_1")
        self.assertEqual(
            self.calls(),
            [
                ["--json", "workspace", "create", "--project-id", "proj_1", "--name", "DISC-1", "--agent", "claude"]
                + ["--model", "opus-5-5-1m"]
                + ["--message", "/kramme-cc-workflow:kramme-linear-issue-to-pr DISC-1 --ship"],
                ["--json", "workspace", "create", "--project-id", "proj_1", "--name", "DISC-2", "--agent", "codex"]
                + ["--model", "gpt-5.5", "--message", "$kramme:linear:issue-to-pr DISC-2 --ship"],
            ],
        )

    def test_launch_retries_a_rate_limited_creation_after_the_named_wait(self) -> None:
        stderr = "error: Rate limit exceeded for workspace creation. Retry after 8 seconds. (HTTP 429)\n"
        limited = {"exit": 1, "stderr": stderr}
        with mock.patch.object(cloud_launch, "time") as clock:
            code, result = self.run_helper(
                "launch", "--project-id", "proj_1",
                "--item", "DISC-1", "claude", "opus-5-5-1m",
                "--item", "DISC-2", "claude", "opus-5-5-1m",
                responses=[created(1), limited, limited, created(2)],
            )  # fmt: skip
        self.assertEqual((code, result["status"]), (0, "ok"))
        self.assertEqual([entry["outcome"] for entry in result["results"]], ["created", "created"])
        self.assertEqual(clock.sleep.call_args_list, [mock.call(8), mock.call(8)])
        self.assertEqual(len(self.calls()), 4)

    def test_launch_stops_when_rate_limiting_outlasts_the_retries(self) -> None:
        limited = {"exit": 4, "stderr": "error: Rate limit exceeded. (HTTP 429)\n"}
        with mock.patch.object(cloud_launch, "time") as clock:
            code, result = self.run_helper(
                "launch", "--project-id", "proj_1",
                "--item", "DISC-1", "claude", "opus-5-5-1m",
                "--item", "DISC-2", "claude", "opus-5-5-1m",
                responses=[limited],
            )  # fmt: skip
        self.assertEqual((code, result["status"]), (1, "stopped"))
        self.assertEqual([entry["outcome"] for entry in result["results"]], ["rate_limited", "not_started"])
        self.assertNotIn("may exist", result["results"][0]["detail"])
        self.assertEqual(clock.sleep.call_count, cloud_launch.RATE_LIMIT_RETRIES)
        self.assertEqual(len(self.calls()), cloud_launch.RATE_LIMIT_RETRIES + 1)

    def test_launch_stops_retrying_once_the_run_wait_budget_is_spent(self) -> None:
        stderr = "error: Rate limit exceeded for workspace creation. Retry after 45 seconds. (HTTP 429)\n"
        limited = {"exit": 1, "stderr": stderr}
        with mock.patch.object(cloud_launch, "time") as clock:
            code, result = self.run_helper(
                "launch", "--project-id", "proj_1",
                "--item", "DISC-1", "claude", "opus-5-5-1m",
                "--item", "DISC-2", "claude", "opus-5-5-1m",
                "--item", "DISC-3", "claude", "opus-5-5-1m",
                responses=[limited, created(1), limited],
            )  # fmt: skip
        self.assertEqual((code, result["status"]), (1, "stopped"))
        self.assertEqual([entry["outcome"] for entry in result["results"]], ["created", "rate_limited", "not_started"])
        self.assertEqual(clock.sleep.call_args_list, [mock.call(45)])
        self.assertEqual(len(self.calls()), 3)

    def test_launch_stops_at_the_first_failure_and_never_retries(self) -> None:
        code, result = self.run_helper(
            "launch", "--project-id", "proj_1",
            "--item", "DISC-1", "claude", "opus-5-5-1m",
            "--item", "DISC-2", "claude", "opus-5-5-1m",
            "--item", "DISC-3", "claude", "opus-5-5-1m",
            responses=[created(1), {"exit": 3, "stderr": "Unauthorized\n"}],
        )  # fmt: skip
        self.assertEqual((code, result["status"]), (1, "stopped"))
        self.assertEqual([entry["outcome"] for entry in result["results"]], ["created", "auth_error", "not_started"])
        self.assertEqual(len(self.calls()), 2)

    def test_launch_treats_lost_or_garbled_answers_as_unknown(self) -> None:
        item = ["--item", "DISC-1", "claude", "opus-5-5-1m", "--item", "DISC-2", "claude", "opus-5-5-1m"]
        cases = {
            "timeout": [{"sleep": 3}],
            "invalid JSON": [{"stdout": "not json"}],
            "missing workspace id": [{"stdout": json.dumps({"sessionId": "sess_new"})}],
            "other failure": [{"exit": 1, "stderr": "server error\n"}],
        }
        for name, responses in cases.items():
            with self.subTest(name):
                self.log.unlink(missing_ok=True)
                code, result = self.run_helper(
                    "launch", "--project-id", "proj_1", *item, responses=responses, KRAMME_CONDUCTOR_TIMEOUT_SECONDS="1"
                )
                self.assertEqual(code, 1)
                self.assertEqual([entry["outcome"] for entry in result["results"]], ["unknown", "not_started"])
                self.assertIn("may exist", result["results"][0]["detail"])
                self.assertEqual(len(self.calls()), 1)

    def test_launch_reports_a_rejected_request(self) -> None:
        code, result = self.run_helper(
            "launch", "--project-id", "proj_1", "--item", "DISC-1", "claude", "opus-5-5-1m",
            responses=[{"exit": 2, "stderr": "Unknown option --model\n"}],
        )  # fmt: skip
        self.assertEqual(code, 1)
        self.assertEqual(result["results"][0]["outcome"], "rejected")
        self.assertEqual(result["results"][0]["detail"], "Unknown option --model")

    def test_launch_validates_every_item_before_calling_conductor(self) -> None:
        cases = {
            "issue_invalid": ["--project-id", "proj_1", "--item", "disc 1; rm", "claude", "opus-5-5-1m"],
            "agent_invalid": ["--project-id", "proj_1", "--item", "DISC-1", "cursor", "auto"],
            "model_invalid": ["--project-id", "proj_1", "--item", "DISC-1", "claude", "Opus 5"],
            "issue_duplicate": ["--project-id", "proj_1"] + ["--item", "DISC-1", "claude", "opus-5-5-1m"] * 2,
            "project_id_invalid": ["--project-id", "../proj", "--item", "DISC-1", "claude", "opus-5-5-1m"],
            "too_many_items": ["--project-id", "proj_1"]
            + [part for number in range(26) for part in ("--item", f"DISC-{number}", "claude", "opus-5-5-1m")],
            "usage": ["--project-id", "proj_1"],
        }
        for reason, argv in cases.items():
            with self.subTest(reason):
                code, result = self.run_helper("launch", *argv, responses=[created(1)])
                self.assertEqual((code, result["status"], result["reason"]), (2, "error", reason))
        self.assertEqual(self.calls(), [])

    def test_launch_refuses_to_run_outside_a_cloud_workspace(self) -> None:
        argv = ["launch", "--project-id", "proj_1", "--item", "DISC-1", "claude", "opus-5-5-1m"]
        code, result = self.run_helper(*argv, responses=[created(1)], CONDUCTOR_IS_LOCAL="1")
        self.assertEqual((code, result["reason"]), (2, "not_cloud"))
        empty = self.root / "empty"
        empty.mkdir()
        code, result = self.run_helper(*argv, responses=[created(1)], PATH=str(empty))
        self.assertEqual((code, result["reason"]), (2, "cli_missing"))
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
