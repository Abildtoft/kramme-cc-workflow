"""Minimum-runtime smoke tests for the session-search extractors."""

import subprocess
import sys
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = PLUGIN_ROOT / "skills" / "kramme:session:search" / "scripts"


class SessionSearchPython38Tests(unittest.TestCase):
    def test_extractors_start_with_empty_input(self):
        for name in (
            "extract-errors.py",
            "extract-metadata.py",
            "extract-skeleton.py",
        ):
            with self.subTest(name=name):
                result = subprocess.run(
                    [sys.executable, str(SCRIPTS / name)],
                    input="",
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
