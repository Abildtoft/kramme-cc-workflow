"""Behavioral tests for the kramme:code:audit-practice session-signal extractor.

Every test writes synthetic Claude Code and Codex transcripts into temporary host directories and runs the
script's entry point against them, so discovery, parsing, and the aggregate summary are exercised together.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import re
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any

SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "skills" / "kramme:code:audit-practice" / "scripts" / "session-signals.py"
)
SPEC = importlib.util.spec_from_file_location("session_signals", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
# The script imports its sibling signal_patterns module, which script-form runs find on sys.path[0].
sys.path.insert(0, str(SCRIPT_PATH.parent))
signals = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(signals)


def user(text: Any, **fields: Any) -> dict[str, Any]:
    return {"type": "user", "message": {"role": "user", "content": text}, **fields}


def tool_use(call_id: str, name: str, request: str = "r1", **tool_input: Any) -> dict[str, Any]:
    block = {"type": "tool_use", "id": call_id, "name": name, "input": tool_input}
    return {"type": "assistant", "requestId": request, "message": {"content": [block]}}


def tool_result(call_id: str, content: Any = "ok") -> dict[str, Any]:
    return user([{"type": "tool_result", "tool_use_id": call_id, "content": content}])


class SessionSignalsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.claude = self.root / "claude" / "projects"
        self.codex = self.root / "codex" / "sessions"
        self.repo = str(self.root / "work" / "repo")
        self.counter = 0

    def write_claude(self, records: list[dict[str, Any]], cwd: str = "", age_days: float = 0) -> Path:
        cwd = cwd or self.repo
        self.counter += 1
        path = self.claude / re.sub(r"[^A-Za-z0-9]", "-", cwd) / f"session-{self.counter}.jsonl"
        lines = [json.dumps({"cwd": cwd, "timestamp": "2026-10-20T10:00:00Z", **record}) for record in records]
        return self.write(path, lines, age_days)

    def write_codex(self, records: list[dict[str, Any]], age_days: float = 0) -> Path:
        self.counter += 1
        path = self.codex / "2026" / "10" / "20" / f"rollout-{self.counter}.jsonl"
        lines = [json.dumps({"timestamp": "2026-10-20T10:00:00Z", **record}) for record in records]
        return self.write(path, lines, age_days)

    def write(self, path: Path, lines: list[str], age_days: float) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        stamp = time.time() - age_days * 86400 - self.counter
        os.utime(path, (stamp, stamp))
        return path

    def run_signals(self, *extra: str) -> tuple[dict[str, Any], str]:
        argv = ["--cwd-prefix", self.repo, "--claude-projects", str(self.claude), "--codex-sessions", str(self.codex)]
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(signals.main([*argv, *extra]), 0)
        return json.loads(stdout.getvalue()), stdout.getvalue()

    def test_prompt_classification_counts_only_human_turns(self) -> None:
        self.write_claude(
            [
                user("Add a login form with validation"),
                user("continue"),
                user("No, I meant the signup form"),
                user("[Request interrupted by user for tool use]"),
                user("<system_instruction>workspace rules</system_instruction>\nok, go ahead"),
                user("<command-name>/kramme:pr:create</command-name><command-args></command-args>"),
                user("<local-command-stdout>done</local-command-stdout>"),
                user("injected context", isMeta=True),
                user("background notice", promptSource="system"),
                user("subagent prompt", isSidechain=True),
                user("This session is being continued from a previous conversation.", isCompactSummary=True),
            ]
        )
        prompts = self.run_signals()[0]["prompts"]
        self.assertEqual(prompts["total"], 5)
        self.assertEqual(prompts["short_nudges"], 2)
        self.assertEqual(prompts["corrections"], 1)
        self.assertEqual(prompts["interrupts"], 1)
        self.assertEqual(prompts["slash_commands"], 1)
        self.assertEqual(prompts["median_first_prompt_chars"], len("Add a login form with validation"))

    def test_checks_after_the_last_edit_mark_a_session_verified(self) -> None:
        self.write_claude([tool_use("e1", "Edit"), tool_use("b1", "Bash", command="npm test"), tool_use("e2", "Write")])
        self.write_claude(
            [
                tool_use("e3", "Edit"),
                tool_use("b2", "Bash", command="cd app && rtk make -C pkg test-smoke"),
                tool_use("s1", "Skill", skill="kramme-cc-workflow:kramme-verify-run"),
            ]
        )
        verification = self.run_signals()[0]["verification"]
        self.assertEqual(verification["check_runs"], 3)
        self.assertEqual(verification["sessions_with_edits_and_checks"], 2)
        self.assertEqual(verification["sessions_ending_after_unchecked_edits"], 1)

    def test_command_classification(self) -> None:
        cases = {
            "pytest -q": (True, "pytest"),
            "cd x && npm run lint": (True, "npm"),
            "FOO=1 uv run pytest tests": (True, "pytest"),
            "python3 -m mypy src": (True, "mypy"),
            "timeout 60 cargo test": (True, "cargo"),
            "./gradlew :app:test": (True, "gradlew"),
            "git commit -m 'fix tests'": (False, "git"),
            "npm install": (False, "npm"),
            "npm ci": (False, "npm"),
            "npm run ci": (True, "npm"),
            "make -C build-tools install": (False, "make"),
            "cat tests/foo.bats": (False, "cat"),
            "go build ./...": (False, "go"),
        }
        for command, expected in cases.items():
            with self.subTest(command=command):
                self.assertEqual(signals.patterns.classify_command(command), expected)

    def test_alignment_review_and_exploration_signals(self) -> None:
        self.write_claude(
            [
                tool_use("q1", "AskUserQuestion"),
                tool_use("q2", "mcp__conductor__AskUserQuestion"),
                tool_use("p1", "ExitPlanMode"),
                tool_use("r1", "Read"),
                tool_use("g1", "Bash", command="rg -n pattern src"),
                tool_use("e1", "Edit"),
                tool_use("a1", "Agent", subagent_type="code-reviewer"),
            ]
        )
        self.write_claude(
            [
                tool_use("e2", "Edit"),
                user("That's not what I asked for"),
                tool_use("s1", "Skill", skill="kramme-cc-workflow:kramme-pr-resolve-review"),
                tool_use("s2", "Skill", skill="kramme-cc-workflow:kramme-pr-github-review-reply"),
            ]
        )
        summary = self.run_signals()[0]
        self.assertEqual(summary["alignment"]["questions"], 2)
        self.assertEqual(summary["alignment"]["plan_approvals"], 1)
        self.assertEqual(summary["alignment"]["sessions_with_edits_and_alignment"], 1)
        self.assertEqual(summary["alignment"]["sessions_corrected_without_alignment"], 1)
        self.assertEqual(summary["review"]["sessions_with_edits_and_automated_review"], 1)
        self.assertEqual(summary["changes"]["median_exploration_calls_before_first_edit"], 1.0)
        self.assertEqual(summary["subagents"]["by_type"], {"code-reviewer": 1})

    def test_effort_and_models_count_each_request_once(self) -> None:
        def reply(request: str, effort: str, model: str = "claude-test") -> dict[str, Any]:
            return {
                "type": "assistant",
                "requestId": request,
                "effort": effort,
                "thinkingDurationMs": 4000,
                "message": {"model": model, "content": [{"type": "text", "text": "..."}]},
            }

        self.write_claude(
            [reply("r1", "max"), reply("r1", "max"), reply("r2", "high"), reply("r3", "high", "<synthetic>")]
        )
        summary = self.run_signals()[0]
        self.assertEqual(summary["effort"]["requests_by_level"], {"high": 2, "max": 1})
        self.assertEqual(summary["effort"]["median_thinking_seconds"], 4.0)
        self.assertEqual(summary["models"], {"claude-test": 2})

    def test_tool_output_is_attributed_to_tools_mcp_servers_and_shell_programs(self) -> None:
        self.write_claude(
            [
                tool_use("m1", "mcp__linear__get_issue"),
                tool_result("m1", "x" * 600),
                tool_use("b1", "Bash", command="git log --oneline"),
                tool_result("b1", [{"type": "text", "text": "y" * 300}]),
                tool_use("r1", "Read"),
                tool_result("r1", "z" * 100),
                tool_result("missing", "w"),
            ]
        )
        output = self.run_signals()[0]["tool_output"]
        self.assertEqual(output["total_chars"], 1001)
        self.assertEqual(output["mcp_share"], 0.599)
        self.assertEqual(output["by_tool"][0], {"tool": "mcp__linear", "calls": 1, "chars": 600, "max_chars": 600})
        self.assertEqual(output["by_shell_program"], [{"program": "git", "calls": 1, "chars": 300}])
        self.assertIn("unknown", [row["tool"] for row in output["by_tool"]])

    def test_discovery_keeps_recent_sessions_under_the_prefix(self) -> None:
        self.write_claude([user("old work")], age_days=40)
        self.write_claude([user("neighbor repo")], cwd=self.repo + "-other")
        self.write_claude([user("older recent work")], age_days=2)
        self.write_claude([user("newest work")], cwd=self.repo + "/packages/app")
        summary = self.run_signals("--days", "30")[0]
        self.assertEqual(summary["sessions"]["analyzed"], 2)
        self.assertEqual(summary["diagnostics"]["sessions_outside_prefix"], 1)
        limited = self.run_signals("--limit", "1")[0]
        self.assertEqual(limited["sessions"]["analyzed"], 1)
        self.assertEqual(limited["prompts"]["median_first_prompt_chars"], len("newest work"))

    def test_codex_rollouts_supply_settings_prompts_and_tools(self) -> None:
        meta = {"type": "session_meta", "payload": {"id": "s1", "cwd": self.repo}}
        self.write_codex(
            [
                meta,
                {
                    "type": "turn_context",
                    "payload": {"effort": "xhigh", "model": "codex-test", "approval_policy": "on-request"},
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": [{"type": "input_text", "text": "# AGENTS.md instructions for repo"}],
                    },
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": [{"type": "input_text", "text": "Fix the flaky test"}],
                    },
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "custom_tool_call",
                        "name": "apply_patch",
                        "call_id": "c1",
                        "input": "*** Begin Patch",
                    },
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "function_call",
                        "name": "shell",
                        "call_id": "c2",
                        "arguments": json.dumps({"command": ["bash", "-lc", "pytest -q"]}),
                    },
                },
                {
                    "type": "response_item",
                    "payload": {"type": "function_call_output", "call_id": "c2", "output": "1 passed"},
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "function_call",
                        "name": "request_user_input_async",
                        "call_id": "c3",
                        "arguments": "{}",
                    },
                },
                {"type": "event_msg", "payload": {"type": "turn_aborted"}},
            ]
        )
        self.write_codex([{"type": "session_meta", "payload": {"cwd": self.repo, "thread_source": "subagent"}}])
        self.write_codex([{"type": "session_meta", "payload": {"cwd": "/elsewhere"}}])
        summary = self.run_signals()[0]
        self.assertEqual(summary["sessions"]["by_platform"], {"codex": 1})
        self.assertEqual(summary["effort"]["requests_by_level"], {"xhigh": 1})
        self.assertEqual(summary["permissions"]["codex_approval_policies"], {"on-request": 1})
        self.assertEqual(summary["prompts"]["total"], 1)
        self.assertEqual(summary["prompts"]["interrupts"], 1)
        self.assertEqual(summary["alignment"]["questions"], 1)
        self.assertEqual(summary["verification"]["sessions_with_edits_and_checks"], 1)
        self.assertEqual(summary["diagnostics"]["skipped_subagent_threads"], 1)
        self.assertEqual(summary["diagnostics"]["sessions_outside_prefix"], 1)

    def test_output_never_contains_transcript_text(self) -> None:
        self.write_claude(
            [
                user("SENTINEL-PROMPT please refactor"),
                tool_use("b1", "Bash", command="grep SENTINEL-COMMAND /secret/SENTINEL-PATH"),
                tool_result("b1", "SENTINEL-OUTPUT"),
                user([{"type": "text", "text": "no, SENTINEL-CORRECTION"}]),
            ]
        )
        _, raw = self.run_signals()
        self.assertNotIn("SENTINEL", raw)

    def test_malformed_lines_are_counted_without_failing(self) -> None:
        path = self.write_claude([user("Ship the fix")])
        with path.open("a", encoding="utf-8") as handle:
            handle.write("not json\n[1, 2]\n")
        summary = self.run_signals()[0]
        self.assertEqual(summary["sessions"]["analyzed"], 1)
        self.assertEqual(summary["diagnostics"]["unparsed_lines"], 2)

    def test_missing_host_directories_yield_an_empty_summary(self) -> None:
        summary = self.run_signals()[0]
        self.assertEqual(summary["sessions"], {"analyzed": 0, "by_platform": {}, "first_date": None, "last_date": None})
        self.assertEqual(summary["tool_output"]["mcp_share"], 0)

    def test_invalid_arguments_exit_with_usage_errors(self) -> None:
        for argv in (["--days", "0", "--cwd-prefix", self.repo], ["--limit", "x", "--cwd-prefix", self.repo], []):
            with self.subTest(argv=argv), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                signals.main(argv)
            self.assertEqual(raised.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
