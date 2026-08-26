import json
import subprocess
import sys
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[2]
EXTRACTOR = (
    PLUGIN_ROOT
    / "skills"
    / "kramme:session:search"
    / "scripts"
    / "extract-skill-usage.py"
)


class SessionSkillUsageTests(unittest.TestCase):
    def run_skill_usage(self, session, *known_skills):
        args = [item for skill in known_skills for item in ("--known-skill", skill)]
        result = subprocess.run(
            [sys.executable, str(EXTRACTOR), *args],
            input=session,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_ignores_slash_command_mentions_in_user_prose(self):
        session = """\
{"type":"user","message":{"content":"Document /kramme:qa but do not invoke it."}}
"""

        evidence = self.run_skill_usage(session, "kramme:qa")
        self.assertEqual(evidence["skills"], [])
        self.assertEqual(evidence["skill_events"], 0)
        self.assertEqual(evidence["unknown_skill_events"], 0)

    def test_ignores_unsupported_raw_custom_tool_inputs(self):
        session = "\n".join(
            (
                json.dumps(
                    {
                        "type": "session_meta",
                        "payload": {"source": "codex"},
                    }
                ),
                json.dumps(
                    {
                        "type": "response_item",
                        "payload": {
                            "type": "custom_tool_call",
                            "name": "exec",
                            "input": (
                                "const result = await tools.exec_command({cmd: "
                                "\"rtk sed -n '1,80p' "
                                "/tmp/.codex/skills/kramme:qa/SKILL.md\"});"
                            ),
                        },
                    }
                ),
            )
        )

        evidence = self.run_skill_usage(session, "kramme:qa")
        self.assertEqual(evidence["skills"], [])
        self.assertEqual(evidence["skill_events"], 0)
        self.assertEqual(evidence["unknown_skill_events"], 0)
        self.assertEqual(evidence["parse_errors"], 0)

    def test_requires_skill_path_in_same_read_only_shell_segment(self):
        cases = (
            ("sed -n '1,80p' /tmp/.codex/skills/kramme:qa/SKILL.md", ["kramme:qa"]),
            ("cat > /tmp/.codex/skills/kramme:qa/SKILL.md <<EOF", []),
            (
                "printf x > /tmp/.codex/skills/kramme:qa/SKILL.md && cat README.md",
                [],
            ),
            ("cat README.md && rm /tmp/.codex/skills/kramme:qa/SKILL.md", []),
            ("cat README.md\nrm /tmp/.codex/skills/kramme:qa/SKILL.md", []),
            ("sed -i.bak s/old/new/ /tmp/.codex/skills/kramme:qa/SKILL.md", []),
        )

        for command, expected_skills in cases:
            with self.subTest(command=command):
                session = json.dumps(
                    {
                        "type": "assistant",
                        "message": {
                            "content": [
                                {
                                    "type": "tool_use",
                                    "name": "Bash",
                                    "input": {"command": command},
                                }
                            ]
                        },
                    }
                )
                evidence = self.run_skill_usage(session, "kramme:qa")
                self.assertEqual(evidence["skills"], expected_skills)
                self.assertEqual(evidence["skill_events"], int(bool(expected_skills)))
                self.assertEqual(evidence["unknown_skill_events"], 0)
                self.assertEqual(evidence["parse_errors"], 0)


if __name__ == "__main__":
    unittest.main()
