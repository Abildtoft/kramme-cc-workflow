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
{"type":"assistant","timestamp":"2026-06-06T11:01:00Z","message":{"content":[{"type":"text","text":"I will inspect this synthetic Claude session now."}]}}
"""

CURSOR_SESSION = """\
{"role":"user","message":{"content":[{"type":"text","text":"Please inspect the synthetic Cursor session."}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"I will inspect this synthetic Cursor session now."}]}}
"""

FAILURE_SESSION = '{"type":"user","message":{"content":[1]}}\n'

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
        for script_name in ("extract-skeleton.py", "extract-errors.py"):
            with self.subTest(script=script_name), tempfile.TemporaryDirectory() as directory:
                output_path = Path(directory) / "extract.txt"
                output_path.write_text("previous content", encoding="utf-8")

                result = self.run_script(script_name, FAILURE_SESSION, "--output", output_path)

                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output_path.read_text(encoding="utf-8"), "previous content")
                self.assertEqual(list(output_path.parent.glob(f".{output_path.name}.*")), [])

    def test_skeleton_detects_each_platform(self):
        expected_markers = (
            (CODEX_SESSION, "[2026-06-06T10:02:00] [user]"),
            (CLAUDE_SESSION, "[2026-06-06T11:00:00] [user]"),
            (CURSOR_SESSION, "[user] Please inspect the synthetic Cursor session."),
        )
        for session, marker in expected_markers:
            with self.subTest(marker=marker):
                result = self.run_script("extract-skeleton.py", session)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(marker, result.stdout)

    def test_empty_and_malformed_input_keep_metadata_shape(self):
        for name, expected in (
            (
                "extract-skeleton.py",
                {"lines": 0, "parse_errors": 0, "user": 0, "assistant": 0, "tool": 0},
            ),
            ("extract-errors.py", {"lines": 0, "parse_errors": 0, "errors_found": 0}),
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
                paths.append(path)

            result = self.run_script("extract-metadata.py", "", "--keyword", "café", *paths)
            self.assertEqual(result.returncode, 0, result.stderr)
            records = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(
                [record["platform"] for record in records[:-1]],
                ["codex", "claude", "cursor"],
            )
            self.assertEqual([record["match_count"] for record in records[:-1]], [2, 4, 4])
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

            commands = (
                (
                    "skeleton-output",
                    "extract-skeleton.py",
                    ["--output", output_path],
                    large_path,
                ),
                (
                    "errors-output",
                    "extract-errors.py",
                    ["--output", output_path],
                    large_path,
                ),
                (
                    "metadata-keyword",
                    "extract-metadata.py",
                    ["--keyword", "needle", large_path],
                    Path(os.devnull),
                ),
                ("metadata-stdin", "extract-metadata.py", [], large_path),
            )
            for case, name, args, stdin_path in commands:
                with self.subTest(case=case):
                    baseline = self._peak_rss(name, [], stdin_path=Path(os.devnull))
                    peak = self._peak_rss(name, args, stdin_path=stdin_path)
                    self.assertLess(
                        peak - baseline,
                        8 * 1024 * 1024,
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
