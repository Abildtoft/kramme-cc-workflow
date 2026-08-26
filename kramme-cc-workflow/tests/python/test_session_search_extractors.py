# ruff: noqa: E501 - JSONL fixtures stay one event per physical line.
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = PLUGIN_ROOT / "skills" / "kramme:session:search" / "scripts"


CODEX_SESSION = """\
{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta","payload":{"cwd":"/tmp/demo-repo","id":"codex-test-session","timestamp":"2026-06-06T10:00:00Z","source":"codex"}}
{"timestamp":"2026-06-06T10:01:00Z","type":"turn_context","payload":{"cwd":"/tmp/demo-repo","model":"gpt-test"}}
{"timestamp":"2026-06-06T10:02:00Z","type":"event_msg","payload":{"type":"user_message","message":"Please debug the authentication script carefully."}}
{"timestamp":"2026-06-06T10:03:00Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"I will inspect the failing authentication command."}]}}
{"timestamp":"2026-06-06T10:04:00Z","type":"event_msg","payload":{"type":"exec_command_end","command":["zsh","-lc","false"],"aggregated_output":"Process exited with code 1\\nfailed","stderr":"failed"}}
"""

CLAUDE_SESSION = """\
{"type":"user","timestamp":"2026-06-06T11:00:00Z","gitBranch":"main","sessionId":"claude-test-session","message":{"content":"Please inspect the synthetic Claude session."}}
{"type":"assistant","timestamp":"2026-06-06T11:01:00Z","message":{"content":[{"type":"text","text":"I will inspect this synthetic Claude session now."},{"type":"tool_use","id":"tool-1","name":"Read","input":{"file_path":"/tmp/example.py"}}]}}
{"type":"user","timestamp":"2026-06-06T11:02:00Z","message":{"content":[{"type":"tool_result","tool_use_id":"tool-1","is_error":false,"content":"ok"}]}}
"""

CURSOR_SESSION = """\
{"role":"user","message":{"content":[{"type":"text","text":"Please inspect the synthetic Cursor session."}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"I will inspect this synthetic Cursor session now."},{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/example.py"}}]}}
"""

CODEX_SKELETON = """\
[2026-06-06T10:02:00] [user] Please debug the authentication script carefully.
---
[2026-06-06T10:03:00] [assistant] I will inspect the failing authentication command.
---
[2026-06-06T10:04:00] [tool] exec false -> error(exit 1)
{"_meta": true, "lines": 5, "parse_errors": 0, "user": 1, "assistant": 1, "tool": 1}
"""

CODEX_ERRORS = """\
[2026-06-06T10:04:00] [error] exit=1 cmd=false: failed
---
{"_meta": true, "lines": 5, "parse_errors": 0, "errors_found": 1}
"""


class SessionExtractorTests(unittest.TestCase):
    def run_script(self, name, stdin="", *args, timeout=None):
        return subprocess.run(
            [sys.executable, str(SCRIPTS / name), *map(str, args)],
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )

    def run_skill_usage(self, stdin, *known_skills):
        args = tuple(argument for skill in known_skills for argument in ("--known-skill", skill))
        result = self.run_script("extract-skill-usage.py", stdin, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result, json.loads(result.stdout)

    def run_script_with_faulting_stdin(self, name, stdin, output_path):
        runner = """\
import os
import runpy
import sys

transcript = sys.argv[3]

class FaultingInput:
    def __iter__(self):
        yield from transcript.splitlines(keepends=True)
        raise OSError("synthetic transcript read failure")


script_path = sys.argv[1]
output_path = sys.argv[2]
sys.path.insert(0, os.path.dirname(script_path))
sys.argv = [script_path, "--output", output_path]
sys.stdin = FaultingInput()
runpy.run_path(script_path, run_name="__main__")
"""
        return subprocess.run(
            [
                sys.executable,
                "-c",
                runner,
                str(SCRIPTS / name),
                str(output_path),
                stdin,
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def run_atomic_output_script(self, name, output_path):
        process = subprocess.Popen(
            [sys.executable, str(SCRIPTS / name), "--output", str(output_path)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        def cleanup_process():
            if process.poll() is None:
                process.kill()
                process.wait()
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream and not stream.closed:
                    stream.close()

        self.addCleanup(cleanup_process)
        process.stdin.write(CODEX_SESSION)
        process.stdin.flush()

        deadline = time.monotonic() + 2
        temporary_pattern = f".{output_path.name}.*"
        while time.monotonic() < deadline:
            if output_path.read_text(encoding="utf-8") != "previous content":
                break
            if any(output_path.parent.glob(temporary_pattern)):
                break
            time.sleep(0.01)

        self.assertIsNone(process.poll(), "extractor exited before stdin closed")
        self.assertEqual(output_path.read_text(encoding="utf-8"), "previous content")

        process.stdin.close()
        stdout = process.stdout.read()
        stderr = process.stderr.read()
        returncode = process.wait(timeout=5)
        return subprocess.CompletedProcess(process.args, returncode, stdout, stderr)

    def test_skeleton_golden_output_and_atomic_output_parity(self):
        inline = self.run_script("extract-skeleton.py", CODEX_SESSION)
        self.assertEqual(inline.returncode, 0, inline.stderr)
        self.assertEqual(inline.stdout, CODEX_SKELETON)

        with tempfile.TemporaryDirectory() as directory:
            output_path = Path(directory) / "skeleton.txt"
            output_path.write_text("previous content", encoding="utf-8")
            written = self.run_atomic_output_script("extract-skeleton.py", output_path)
            self.assertEqual(written.returncode, 0, written.stderr)
            self.assertEqual(output_path.read_text(encoding="utf-8"), CODEX_SKELETON)
            status = json.loads(written.stdout)
            self.assertEqual(status["wrote"], str(output_path))
            self.assertEqual(status["bytes"], len(CODEX_SKELETON.encode()))
            self.assertEqual(status["lines"], 5)

    def test_errors_golden_output_and_atomic_output_parity(self):
        inline = self.run_script("extract-errors.py", CODEX_SESSION)
        self.assertEqual(inline.returncode, 0, inline.stderr)
        self.assertEqual(inline.stdout, CODEX_ERRORS)

        with tempfile.TemporaryDirectory() as directory:
            output_path = Path(directory) / "errors.txt"
            output_path.write_text("previous content", encoding="utf-8")
            written = self.run_atomic_output_script("extract-errors.py", output_path)
            self.assertEqual(written.returncode, 0, written.stderr)
            self.assertEqual(output_path.read_text(encoding="utf-8"), CODEX_ERRORS)
            status = json.loads(written.stdout)
            self.assertEqual(status["bytes"], len(CODEX_ERRORS.encode()))
            self.assertEqual(status["errors_found"], 1)

    def test_atomic_output_failure_preserves_destination_and_removes_temporary_file(self):
        for script_name in (
            "extract-skeleton.py",
            "extract-errors.py",
            "extract-skill-usage.py",
        ):
            with self.subTest(script=script_name), tempfile.TemporaryDirectory() as directory:
                output_path = Path(directory) / "extract.txt"
                output_path.mkdir()

                result = self.run_script(script_name, CODEX_SESSION, "--output", output_path)

                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(output_path.is_dir())
                self.assertEqual(list(output_path.parent.glob(f".{output_path.name}.*")), [])

    def test_atomic_output_read_failure_preserves_destination_and_removes_temporary_file(self):
        fixtures = {
            "extract-skeleton.py": "\n".join(CODEX_SESSION.splitlines()[:3]) + "\n",
            "extract-errors.py": "\n".join([CODEX_SESSION.splitlines()[0], CODEX_SESSION.splitlines()[-1]]) + "\n",
            "extract-skill-usage.py": "\n".join(CODEX_SESSION.splitlines()[:3]) + "\n",
        }
        for script_name, session in fixtures.items():
            with self.subTest(script=script_name), tempfile.TemporaryDirectory() as directory:
                output_path = Path(directory) / "extract.txt"
                output_path.write_text("previous content", encoding="utf-8")

                result = self.run_script_with_faulting_stdin(
                    script_name,
                    session,
                    output_path,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn("synthetic transcript read failure", result.stderr)
                self.assertEqual(
                    output_path.read_text(encoding="utf-8"),
                    "previous content",
                )
                self.assertEqual(
                    list(output_path.parent.glob(f".{output_path.name}.*")),
                    [],
                )

    def test_empty_output_path_uses_stdout(self):
        for script_name in (
            "extract-skeleton.py",
            "extract-errors.py",
            "extract-skill-usage.py",
        ):
            with self.subTest(script=script_name):
                inline = self.run_script(script_name, CODEX_SESSION)
                empty_path = self.run_script(
                    script_name,
                    CODEX_SESSION,
                    "--output",
                    "",
                )

                self.assertEqual(empty_path.returncode, 0, empty_path.stderr)
                self.assertEqual(empty_path.stdout, inline.stdout)
                self.assertEqual(empty_path.stderr, "")

    def test_skeleton_detects_each_platform(self):
        cases = (
            (
                CODEX_SESSION,
                (
                    "[2026-06-06T10:02:00] [user]",
                    "[2026-06-06T10:03:00] [assistant]",
                    "[2026-06-06T10:04:00] [tool] exec false -> error(exit 1)",
                ),
            ),
            (
                CLAUDE_SESSION,
                (
                    "[2026-06-06T11:00:00] [user]",
                    "[2026-06-06T11:01:00] [assistant]",
                    "[2026-06-06T11:01:00] [tool] Read /tmp/example.py -> ok",
                ),
            ),
            (
                CURSOR_SESSION,
                (
                    "[user] Please inspect the synthetic Cursor session.",
                    "[assistant] I will inspect this synthetic Cursor session now.",
                    "[tool] Read /tmp/example.py",
                ),
            ),
        )
        for session, markers in cases:
            with self.subTest(markers=markers):
                result = self.run_script("extract-skeleton.py", session)
                self.assertEqual(result.returncode, 0, result.stderr)
                for marker in markers:
                    self.assertIn(marker, result.stdout)
                meta = json.loads(result.stdout.splitlines()[-1])
                self.assertEqual(
                    {key: meta[key] for key in ("user", "assistant", "tool")},
                    {"user": 1, "assistant": 1, "tool": 1},
                )

    def test_skill_usage_detects_each_platform_without_payloads(self):
        secret = "sk-abcdefghijklmnopqrstuvwxyz123456"
        cases = (
            (
                """\
{"type":"user","timestamp":"2026-06-06T11:00:00Z","gitBranch":"main","sessionId":"claude-skill-session","message":{"content":"Use the QA skill."}}
{"type":"assistant","timestamp":"2026-06-06T11:01:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"kramme:qa","secret":"sk-abcdefghijklmnopqrstuvwxyz123456"}}]}}
""",
                "claude",
                ["kramme:qa"],
            ),
            (
                r"""\
{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta","payload":{"cwd":"/tmp/demo-repo","id":"codex-skill-session","timestamp":"2026-06-06T10:00:00Z","source":"codex"}}
{"timestamp":"2026-06-06T10:01:00Z","type":"response_item","payload":{"type":"custom_tool_call","name":"read_skill","arguments":"{\"name\":\"kramme:research\",\"secret\":\"sk-abcdefghijklmnopqrstuvwxyz123456\"}"}}
""",
                "codex",
                ["kramme:research"],
            ),
            (
                """\
{"role":"user","message":{"content":[{"type":"text","text":"Inspect the session skill."}]}}
{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/.agents/skills/kramme:session:search/SKILL.md","secret":"sk-abcdefghijklmnopqrstuvwxyz123456"}}]}}
""",
                "cursor",
                ["kramme:session:search"],
            ),
        )

        for session, platform, expected_skills in cases:
            with self.subTest(platform=platform):
                result, evidence = self.run_skill_usage(session, *expected_skills)
                self.assertEqual(evidence["platforms"], [platform])
                self.assertEqual(evidence["skills"], expected_skills)
                self.assertEqual(evidence["skill_events"], 1)
                self.assertEqual(evidence["unknown_skill_events"], 0)
                self.assertNotIn(secret, result.stdout)
                self.assertNotIn("/tmp/", result.stdout)

    def test_skill_usage_detects_user_slash_invocations_without_injected_text(self):
        cases = (
            (
                """\
{"type":"user","message":{"content":"<system_instruction>Run /kramme:ignored</system_instruction>\\n/kramme:qa now."}}
""",
                "claude",
            ),
            (
                """\
{"type":"event_msg","payload":{"type":"user_message","message":"/kramme:qa now."}}
""",
                "codex",
            ),
            (
                """\
{"role":"user","message":{"content":[{"type":"text","text":"  /kramme:qa now."}]}}
""",
                "cursor",
            ),
        )

        for session, platform in cases:
            with self.subTest(platform=platform):
                _, evidence = self.run_skill_usage(
                    session,
                    "kramme:qa",
                    "kramme:ignored",
                )
                self.assertEqual(evidence["skills"], ["kramme:qa"])
                self.assertEqual(evidence["skill_events"], 1)
                self.assertEqual(evidence["unknown_skill_events"], 0)

    def test_skill_usage_redacts_unknown_direct_skill_candidates(self):
        secret = "sk-abcdefghijklmnopqrstuvwxyz123456"
        session = f'''\
{{"type":"assistant","message":{{"content":[{{"type":"tool_use","name":"Skill","input":{{"skill":"{secret}"}}}}]}}}}
'''

        result, evidence = self.run_skill_usage(session, "kramme:qa")
        self.assertEqual(evidence["skills"], [])
        self.assertEqual(evidence["skill_events"], 0)
        self.assertEqual(evidence["unknown_skill_events"], 1)
        self.assertNotIn(secret, result.stdout)

    def test_skill_usage_ignores_skill_paths_in_non_read_tools(self):
        session = """\
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/tmp/.agents/skills/kramme:qa/SKILL.md","content":"example"}}]}}
"""

        _, evidence = self.run_skill_usage(session, "kramme:qa")
        self.assertEqual(evidence["skills"], [])
        self.assertEqual(evidence["skill_events"], 0)
        self.assertEqual(evidence["unknown_skill_events"], 0)

    def test_skill_usage_marks_malformed_tool_arguments_and_continues(self):
        session = "\n".join(
            (
                '{"type":"session_meta","payload":{"source":"codex"}}',
                '{"type":"response_item","payload":{"type":"custom_tool_call","name":"read_skill","arguments":"{not-json /tmp/.agents/skills/kramme:qa/SKILL.md"}}',
                r'{"type":"response_item","payload":{"type":"custom_tool_call","name":"read_skill","arguments":"{\"name\":\"kramme:qa\"}"}}',
            )
        )
        _, evidence = self.run_skill_usage(session, "kramme:qa")
        self.assertEqual(evidence["skills"], ["kramme:qa"])
        self.assertEqual(evidence["skill_events"], 1)
        self.assertEqual(evidence["unknown_skill_events"], 0)
        self.assertEqual(evidence["parse_errors"], 1)

    def test_skill_usage_ignores_skill_names_outside_tool_activity(self):
        session = CODEX_SESSION.replace(
            "Please debug the authentication script carefully.",
            "Please read /tmp/.codex/skills/kramme:qa/SKILL.md carefully.",
        )

        result = self.run_script("extract-skill-usage.py", session)

        self.assertEqual(result.returncode, 0, result.stderr)
        evidence = json.loads(result.stdout)
        self.assertEqual(evidence["skills"], [])
        self.assertEqual(evidence["skill_events"], 0)

    def test_errors_accepts_plain_claude_user_content(self):
        result = self.run_script("extract-errors.py", CLAUDE_SESSION)

        self.assertEqual(result.returncode, 0, result.stderr)
        meta = json.loads(result.stdout)
        self.assertEqual(meta["parse_errors"], 0)
        self.assertEqual(meta["errors_found"], 0)

    def test_errors_extracts_claude_tool_failures(self):
        session = CLAUDE_SESSION.replace(
            '"is_error":false,"content":"ok"',
            '"is_error":true,"content":"synthetic Claude failure"',
        )

        result = self.run_script("extract-errors.py", session)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "[2026-06-06T11:02:00] [error] synthetic Claude failure",
            result.stdout,
        )
        meta = json.loads(result.stdout.splitlines()[-1])
        self.assertEqual(meta["errors_found"], 1)
        self.assertEqual(meta["parse_errors"], 0)

    def test_empty_and_malformed_input_keep_metadata_shape(self):
        for name, expected in (
            (
                "extract-skeleton.py",
                {"lines": 0, "parse_errors": 0, "user": 0, "assistant": 0, "tool": 0},
            ),
            ("extract-errors.py", {"lines": 0, "parse_errors": 0, "errors_found": 0}),
            (
                "extract-skill-usage.py",
                {
                    "lines": 0,
                    "parse_errors": 0,
                    "skill_events": 0,
                    "skills": [],
                    "unknown_skill_events": 0,
                },
            ),
        ):
            with self.subTest(name=name, kind="empty"):
                result = self.run_script(name)
                self.assertEqual(result.returncode, 0, result.stderr)
                meta = json.loads(result.stdout)
                for key, value in expected.items():
                    self.assertEqual(meta[key], value)

            with self.subTest(name=name, kind="malformed"):
                result = self.run_script(name, "not-json\n" + CODEX_SESSION)
                self.assertEqual(result.returncode, 0, result.stderr)
                meta = json.loads(result.stdout.splitlines()[-1])
                self.assertEqual(meta["lines"], 6)
                self.assertEqual(meta["parse_errors"], 1)

    def test_stream_extractors_count_invalid_shapes_and_continue(self):
        fixtures = {
            "extract-skeleton.py": (
                "\n".join(
                    [
                        "42",
                        "[]",
                        CODEX_SESSION.splitlines()[0],
                        '{"type":"event_msg","payload":[]}',
                        ('{"type":"response_item","payload":{"type":"message","role":"assistant","content":[1]}}'),
                        *CODEX_SESSION.splitlines()[2:],
                    ]
                )
                + "\n",
                "[tool] exec false -> error(exit 1)",
            ),
            "extract-errors.py": (
                "\n".join(
                    [
                        "42",
                        "[]",
                        CODEX_SESSION.splitlines()[0],
                        '{"type":"event_msg","payload":[]}',
                        (
                            '{"type":"event_msg","payload":{"type":"exec_command_end",'
                            '"command":[1],"aggregated_output":"Process exited with code 1\\nfailed",'
                            '"stderr":"failed"}}'
                        ),
                        CODEX_SESSION.splitlines()[-1],
                    ]
                )
                + "\n",
                "[error] exit=1 cmd=false: failed",
            ),
        }

        for name, (session, success_marker) in fixtures.items():
            with self.subTest(name=name):
                result = self.run_script(name, session)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(success_marker, result.stdout)
                meta = json.loads(result.stdout.splitlines()[-1])
                self.assertEqual(meta["parse_errors"], 4)

    def test_rejected_claude_event_does_not_update_pending_tool_status(self):
        malformed_result = (
            '{"type":"user","timestamp":"2026-06-06T11:02:00Z",'
            '"message":{"content":['
            '{"type":"tool_result","tool_use_id":"tool-1","is_error":false,"content":"ok"},'
            '{"type":"text","text":42}]}}'
        )
        session = (
            "\n".join(
                [
                    CLAUDE_SESSION.splitlines()[1],
                    malformed_result,
                    (
                        '{"type":"user","timestamp":"2026-06-06T11:03:00Z",'
                        '"message":{"content":"Please continue after the malformed result."}}'
                    ),
                ]
            )
            + "\n"
        )

        result = self.run_script("extract-skeleton.py", session)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[tool] Read /tmp/example.py", result.stdout)
        self.assertNotIn("-> ok", result.stdout)
        meta = json.loads(result.stdout.splitlines()[-1])
        self.assertEqual(meta["parse_errors"], 1)

    def test_errors_rejects_null_command_elements_and_continues(self):
        malformed_command = (
            '{"timestamp":"2026-06-06T10:03:30Z","type":"event_msg",'
            '"payload":{"type":"exec_command_end","command":[null],'
            '"aggregated_output":"Process exited with code 1\\nfailed","stderr":"failed"}}'
        )
        session = (
            "\n".join(
                [
                    CODEX_SESSION.splitlines()[0],
                    malformed_command,
                    CODEX_SESSION.splitlines()[-1],
                ]
            )
            + "\n"
        )

        result = self.run_script("extract-errors.py", session)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("cmd=:", result.stdout)
        self.assertIn("cmd=false: failed", result.stdout)
        meta = json.loads(result.stdout.splitlines()[-1])
        self.assertEqual(meta["parse_errors"], 1)
        self.assertEqual(meta["errors_found"], 1)

    def test_metadata_counts_shape_read_and_scan_errors_without_suppressing_later_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixtures = {
                "scalar.jsonl": "42\n",
                "array.jsonl": "[]\n",
                "nested.jsonl": '{"type":"session_meta","payload":[]}\n',
                "partial.jsonl": ('{"type":"turn_context","payload":{"cwd":"/tmp/demo-repo","model":"gpt-test"}}\n'),
                "corrupt-then-valid.jsonl": "not-json\n" + CODEX_SESSION,
            }
            paths = []
            for name, content in fixtures.items():
                path = root / name
                path.write_text(content, encoding="utf-8")
                paths.append(path)
            unreadable = root / "missing.jsonl"
            paths.insert(-1, unreadable)

            result = self.run_script("extract-metadata.py", "", *paths)

            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(len(records), 2)
            self.assertEqual(records[0]["file"], str(paths[-1]))
            self.assertEqual(records[0]["platform"], "codex")
            self.assertEqual(records[-1]["files_processed"], len(paths))
            self.assertEqual(records[-1]["parse_errors"], 6)
            self.assertEqual(records[-1]["read_errors"], 1)

    def test_metadata_rejects_malformed_events_without_partial_updates(self):
        fixtures = {
            "session-meta": (
                "\n".join(
                    [
                        (
                            '{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta",'
                            '"payload":{"cwd":"/valid","id":"valid-session",'
                            '"timestamp":"2026-06-06T10:00:00Z","source":"valid",'
                            '"cli_version":"1"}}'
                        ),
                        (
                            '{"timestamp":"2026-06-06T10:01:00Z","type":"session_meta",'
                            '"payload":{"cwd":"/malformed","id":"malformed-session",'
                            '"timestamp":42,"source":"malformed","cli_version":"2"}}'
                        ),
                    ]
                )
                + "\n",
                {
                    "platform": "codex",
                    "cwd": "/valid",
                    "session": "valid-session",
                    "ts": "2026-06-06T10:00:00Z",
                    "source": "valid",
                    "cli_version": "1",
                },
            ),
            "turn-context": (
                "\n".join(
                    [
                        (
                            '{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta",'
                            '"payload":{"cwd":"","id":"valid-session",'
                            '"timestamp":"2026-06-06T10:00:00Z","source":"valid",'
                            '"cli_version":"1"}}'
                        ),
                        (
                            '{"timestamp":"2026-06-06T10:01:00Z","type":"turn_context",'
                            '"payload":{"cwd":[],"model":"malformed-model"}}'
                        ),
                    ]
                )
                + "\n",
                {
                    "platform": "codex",
                    "cwd": "",
                    "session": "valid-session",
                    "ts": "2026-06-06T10:00:00Z",
                    "source": "valid",
                    "cli_version": "1",
                },
            ),
        }

        for case, (session, expected) in fixtures.items():
            with self.subTest(case=case):
                result = self.run_script("extract-metadata.py", session)

                self.assertEqual(result.returncode, 0, result.stderr)
                records = [json.loads(line) for line in result.stdout.splitlines()]
                self.assertEqual(records[0], expected)
                self.assertEqual(records[-1]["parse_errors"], 1)

    def test_metadata_keeps_codex_sessions_with_object_sources(self):
        session = (
            "\n".join(
                [
                    (
                        '{"timestamp":"2026-06-06T10:00:00Z","type":"session_meta",'
                        '"payload":{"cwd":"/tmp/demo-repo","id":"subagent-session",'
                        '"timestamp":"2026-06-06T10:00:00Z","source":{"subagent":'
                        '{"thread_spawn":{"parent_thread_id":"parent"}}},'
                        '"cli_version":"1"}}'
                    ),
                    ('{"type":"turn_context","payload":{"cwd":"/tmp/demo-repo","model":"gpt-test"}}'),
                ]
            )
            + "\n"
        )

        result = self.run_script("extract-metadata.py", session)

        self.assertEqual(result.returncode, 0, result.stderr)
        records = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(
            records[0],
            {
                "platform": "codex",
                "cwd": "/tmp/demo-repo",
                "session": "subagent-session",
                "ts": "2026-06-06T10:00:00Z",
                "cli_version": "1",
                "model": "gpt-test",
            },
        )
        self.assertEqual(records[-1]["parse_errors"], 0)

    def test_metadata_tail_distinguishes_aligned_and_partial_records(self):
        session_meta = CODEX_SESSION.splitlines()[0] + "\n"

        def trailing_event(size):
            prefix = '{"type":"trailing","pad":"'
            suffix = '"}\n'
            return prefix + ("x" * (size - len(prefix) - len(suffix))) + suffix

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            aligned = root / "aligned.jsonl"
            boundary_event = (
                '{"timestamp":"2026-07-25T23:59:59Z","type":"event_msg","payload":{"type":"task_complete"}}\n'
            )
            aligned.write_text(
                session_meta + boundary_event + trailing_event(16384 - len(boundary_event)),
                encoding="utf-8",
            )

            aligned_result = self.run_script(
                "extract-metadata.py",
                "",
                aligned,
            )

            self.assertEqual(aligned_result.returncode, 0, aligned_result.stderr)
            aligned_records = [json.loads(line) for line in aligned_result.stdout.splitlines()]
            self.assertEqual(
                aligned_records[0]["last_ts"],
                "2026-07-25T23:59:59Z",
            )
            self.assertEqual(aligned_records[-1]["parse_errors"], 0)

            partial = root / "partial.jsonl"
            partial_event = (
                '{"timestamp":"2026-07-25T22:00:00Z","type":"event_msg",'
                '"payload":{"type":"note","text":"' + ("x" * 500) + '"}}\n'
            )
            offset = 100
            partial.write_text(
                session_meta + partial_event + trailing_event(16384 - len(partial_event[offset:])),
                encoding="utf-8",
            )

            partial_result = self.run_script(
                "extract-metadata.py",
                "",
                partial,
            )

            self.assertEqual(partial_result.returncode, 0, partial_result.stderr)
            partial_records = [json.loads(line) for line in partial_result.stdout.splitlines()]
            self.assertNotIn("last_ts", partial_records[0])
            self.assertEqual(partial_records[-1]["parse_errors"], 0)

    def test_metadata_keyword_scan_counts_bad_nested_content_and_keeps_valid_matches(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "keyword.jsonl"
            path.write_text(
                "\n".join(
                    [
                        CODEX_SESSION.splitlines()[0],
                        ('{"type":"response_item","payload":{"type":"message","role":"assistant","content":[1]}}'),
                        CODEX_SESSION.splitlines()[2],
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = self.run_script(
                "extract-metadata.py",
                "",
                "--keyword",
                "authentication",
                path,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(records[0]["match_count"], 1)
            self.assertEqual(records[-1]["files_matched"], 1)
            self.assertEqual(records[-1]["parse_errors"], 1)

    def test_metadata_streams_unicode_keyword_counts_for_each_platform(self):
        sessions = {
            "codex.jsonl": CODEX_SESSION.replace("authentication script carefully", "CAFÉ café carefully"),
            "claude.jsonl": CLAUDE_SESSION.replace("synthetic Claude session", "CAFÉ café Claude session"),
            "cursor.jsonl": CURSOR_SESSION.replace("synthetic Cursor session", "CAFÉ café Cursor session"),
        }
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for name, content in sessions.items():
                path = Path(directory) / name
                path.write_text(content, encoding="utf-8")
                if name == "cursor.jsonl":
                    os.utime(path, (1_700_000_000, 1_700_000_000))
                paths.append(path)

            result = self.run_script("extract-metadata.py", "", "--keyword", "café", *paths)
            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(
                [record["platform"] for record in records[:-1]],
                ["codex", "claude", "cursor"],
            )
            self.assertEqual([record["match_count"] for record in records[:-1]], [2, 4, 4])
            by_platform = {record["platform"]: record for record in records[:-1]}
            self.assertEqual(by_platform["codex"]["session"], "codex-test-session")
            self.assertEqual(
                by_platform["codex"]["last_ts"],
                "2026-06-06T10:04:00Z",
            )
            self.assertEqual(by_platform["claude"]["branch"], "main")
            self.assertEqual(
                by_platform["claude"]["session"],
                "claude-test-session",
            )
            self.assertEqual(
                by_platform["claude"]["last_ts"],
                "2026-06-06T11:02:00Z",
            )
            self.assertEqual(by_platform["cursor"]["session"], Path(directory).name)
            self.assertEqual(
                by_platform["cursor"]["ts"],
                "2023-11-14T22:13:20+00:00",
            )
            self.assertEqual(records[-1]["files_matched"], 3)
            self.assertNotIn("CAFÉ", result.stdout)

    def test_metadata_stdin_reads_only_the_detection_prefix(self):
        result = self.run_script("extract-metadata.py", CODEX_SESSION)
        self.assertEqual(result.returncode, 0, result.stderr)
        records = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(records[0]["platform"], "codex")
        self.assertEqual(records[-1], {"_meta": True, "files_processed": 1, "parse_errors": 0})

    def test_metadata_multi_keyword_scan_stays_responsive(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "large.jsonl"
            payload = "needle " + ("x" * 16300)
            event = json.dumps(
                {
                    "timestamp": "2026-06-06T10:03:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "assistant",
                        "content": [{"type": "output_text", "text": payload}],
                    },
                }
            )
            with path.open("w", encoding="utf-8") as fixture:
                fixture.write(CODEX_SESSION.splitlines()[0] + "\n")
                while fixture.tell() < 4 * 1024 * 1024:
                    fixture.write(event + "\n")

            keywords = "needle,missing-one,missing-two,missing-three,missing-four"
            result = self.run_script(
                "extract-metadata.py",
                "",
                "--keyword",
                keywords,
                path,
                timeout=3,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertGreater(records[0]["match_count"], 0)
            self.assertEqual(records[-1]["files_matched"], 1)

    def test_metadata_dense_keyword_scan_stays_responsive(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dense.jsonl"
            payload = "x" * (16 * 1024 * 1024)
            event = json.dumps(
                {
                    "timestamp": "2026-06-06T10:03:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "assistant",
                        "content": [{"type": "output_text", "text": payload}],
                    },
                }
            )
            path.write_text(CODEX_SESSION.splitlines()[0] + "\n" + event + "\n", encoding="utf-8")

            result = self.run_script(
                "extract-metadata.py",
                "",
                "--keyword",
                "x",
                path,
                timeout=2,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(records[0]["match_count"], len(payload))
            self.assertEqual(records[-1]["files_matched"], 1)

    @unittest.skipUnless(hasattr(os, "wait4"), "RSS accounting requires os.wait4")
    def test_large_synthetic_transcripts_have_bounded_rss(self):
        with tempfile.TemporaryDirectory() as directory:
            directory_path = Path(directory)
            large_path = directory_path / "large.jsonl"
            large_prefix_path = directory_path / "large-prefix.jsonl"
            output_path = directory_path / "extract.txt"
            payload = "needle " + ("x" * 16300)
            event = json.dumps(
                {
                    "timestamp": "2026-06-06T10:03:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "assistant",
                        "content": [{"type": "output_text", "text": payload}],
                    },
                }
            )
            with large_path.open("w", encoding="utf-8") as fixture:
                fixture.write(CODEX_SESSION.splitlines()[0] + "\n")
                while fixture.tell() < 12 * 1024 * 1024:
                    fixture.write(event + "\n")

            large_prefix_event = json.dumps(
                {
                    "timestamp": "2026-06-06T10:03:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "assistant",
                        "content": [
                            {
                                "type": "output_text",
                                "text": "x" * (1024 * 1024),
                            }
                        ],
                    },
                }
            )
            with large_prefix_path.open("w", encoding="utf-8") as fixture:
                fixture.write(CODEX_SESSION.splitlines()[0] + "\n")
                for _ in range(20):
                    fixture.write(large_prefix_event + "\n")

            commands = (
                (
                    "skeleton-output",
                    "extract-skeleton.py",
                    ["--output", output_path],
                    large_path,
                    8 * 1024 * 1024,
                ),
                (
                    "errors-output",
                    "extract-errors.py",
                    ["--output", output_path],
                    large_path,
                    8 * 1024 * 1024,
                ),
                (
                    "metadata-keyword",
                    "extract-metadata.py",
                    ["--keyword", "needle", large_path],
                    Path(os.devnull),
                    8 * 1024 * 1024,
                ),
                (
                    "metadata-stdin",
                    "extract-metadata.py",
                    [],
                    large_path,
                    8 * 1024 * 1024,
                ),
                (
                    "metadata-large-prefix",
                    "extract-metadata.py",
                    [large_prefix_path],
                    Path(os.devnull),
                    32 * 1024 * 1024,
                ),
            )
            for case, name, args, stdin_path, max_growth in commands:
                with self.subTest(case=case):
                    baseline = self._peak_rss(name, [], stdin_path=Path(os.devnull))
                    peak = self._peak_rss(name, args, stdin_path=stdin_path)
                    self.assertLess(
                        peak - baseline,
                        max_growth,
                        f"{case} RSS grew by {(peak - baseline) / (1024 * 1024):.1f} MiB",
                    )

    def _peak_rss(self, name, args, stdin_path):
        with stdin_path.open("rb") as stdin:
            process = subprocess.Popen(
                [sys.executable, str(SCRIPTS / name), *map(str, args)],
                stdin=stdin,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        self.assertEqual(process.returncode, 0)
        multiplier = 1 if sys.platform == "darwin" else 1024
        return usage.ru_maxrss * multiplier


if __name__ == "__main__":
    unittest.main()
