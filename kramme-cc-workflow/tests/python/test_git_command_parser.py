from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

PARSER_PATH = (
    Path(__file__).resolve().parents[2] / "hooks" / "lib" / "git_command_parser.py"
)

INTERACTIVE_COMMIT_REASON = (
    'git commit without a message source may open an editor. Use: git commit -m '
    '"your message" (or --no-edit for amend)'
)
RM_RF_REASON = (
    "rm -rf is blocked. Use `trash` instead (install: brew install trash). "
    "Files go to Trash for recovery."
)
XARGS_RM_RF_REASON = "xargs rm -rf is blocked. Use `trash` instead."
FIND_DELETE_REASON = (
    "find -delete is blocked. Use `trash` instead for recoverable deletion."
)
FIND_EXEC_RM_RF_REASON = "find -exec rm -rf is blocked. Use `trash` instead."
SHRED_REASON = "shred is blocked. Use `trash` instead for recoverable deletion."
UNLINK_REASON = "unlink is blocked. Use `trash` instead for recoverable deletion."


def load_parser_module():
    spec = importlib.util.spec_from_file_location("git_command_parser", PARSER_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def json_line(value) -> str:
    return json.dumps(value) + "\n"


def subprocess_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("GIT_"):
            env.pop(key)
    return env


PARSER = load_parser_module()


class GitCommandLexerTest(unittest.TestCase):
    def test_read_dollar_substitution_preserves_escaped_quote_and_space(self) -> None:
        command = r'$(printf "a\"b" a\ b)'

        inner, end = PARSER.read_dollar_substitution(command, 0)

        self.assertEqual(inner, r'printf "a\"b" a\ b')
        self.assertEqual(end, len(command))

    def test_read_dollar_substitution_preserves_nested_substitutions(self) -> None:
        command = r'$(outer $(inner one))'

        inner, end = PARSER.read_dollar_substitution(command, 0)

        self.assertEqual(inner, r"outer $(inner one)")
        self.assertEqual(end, len(command))

    def test_read_backtick_substitution_preserves_escaped_backtick(self) -> None:
        command = r"`printf a\`b`"

        inner, end = PARSER.read_backtick_substitution(command, 0)

        self.assertEqual(inner, r"printf a\`b")
        self.assertEqual(end, len(command))

    def test_strip_heredoc_bodies_handles_quoted_unquoted_and_dashed_forms(self) -> None:
        cases = [
            (
                "unquoted",
                "cat <<EOF\n$(git commit)\nEOF\n",
                "cat <<EOF\n\nEOF\n",
                ["git commit"],
            ),
            (
                "quoted",
                "cat <<'EOF'\n$(git commit)\nEOF\n",
                "cat <<'EOF'\n\nEOF\n",
                [],
            ),
            (
                "dashed",
                "cat <<-EOF\n\t$(git commit)\n\tEOF\n",
                "cat <<-EOF\n\n\tEOF\n",
                ["git commit"],
            ),
        ]

        for name, command, expected_command, expected_substitutions in cases:
            with self.subTest(name=name):
                stripped, substitutions = PARSER.strip_heredoc_bodies(command)

                self.assertEqual(stripped, expected_command)
                self.assertEqual(substitutions, expected_substitutions)

    def test_strip_heredoc_bodies_preserves_shell_stdin_heredoc_body(self) -> None:
        stripped, substitutions = PARSER.strip_heredoc_bodies(
            "bash <<'EOF'\nrm -rf directory/\nEOF\n"
        )

        self.assertEqual(stripped, "bash <<'EOF'\nrm -rf directory/\nEOF\n")
        self.assertEqual(substitutions, [])

    def test_replace_command_substitutions_collects_placeholder_contents(self) -> None:
        sanitized, substitutions = PARSER.replace_command_substitutions(
            r'git commit -m "$(printf a\ b)"'
        )

        self.assertEqual(sanitized, 'git commit -m "__CMD_SUBST_0__"')
        self.assertEqual(substitutions, [r"printf a\ b"])

    def test_tokenize_and_split_segments_for_multi_segment_input(self) -> None:
        tokens = PARSER.tokenize("printf start; git commit -m x && git status")

        self.assertEqual(
            tokens,
            ["printf", "start", ";", "git", "commit", "-m", "x", "&&", "git", "status"],
        )
        self.assertEqual(
            list(PARSER.split_segments(tokens)),
            [
                (["printf", "start"], ";"),
                (["git", "commit", "-m", "x"], "&&"),
                (["git", "status"], None),
            ],
        )

    def test_extract_placeholder_indexes_preserves_first_seen_order(self) -> None:
        indexes = PARSER.extract_placeholder_indexes(
            ["__CMD_SUBST_2__", "x__CMD_SUBST_1__", "__CMD_SUBST_2__"]
        )

        self.assertEqual(indexes, [2, 1])

    def test_shared_lexer_helpers_are_defined_once(self) -> None:
        source = PARSER_PATH.read_text(encoding="utf-8")
        helpers = [
            "_extract_body_substitutions",
            "strip_heredoc_bodies",
            "normalize_newlines",
            "tokenize",
            "split_segments",
            "read_dollar_substitution",
            "read_backtick_substitution",
            "replace_command_substitutions",
            "extract_placeholder_indexes",
        ]

        for helper in helpers:
            with self.subTest(helper=helper):
                self.assertEqual(source.count(f"def {helper}"), 1)


class GitCommandParserCliTest(unittest.TestCase):
    maxDiff = None

    CASES = [
        (
            "plain git command",
            "git status",
            json_line({"block": None}),
            json_line([]),
        ),
        (
            "commit without message",
            "git commit",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "commit with inline message",
            "git commit -m x",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "env-prefixed git dir",
            "GIT_DIR=.git git commit -m x",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": ["GIT_DIR=.git"]}]),
        ),
        (
            "git option before subcommand",
            "git -C repo commit --message=x",
            json_line({"block": None}),
            json_line([{"git_args": ["-C", "repo"], "git_env": []}]),
        ),
        (
            "substitution with escaped quote",
            'git commit -m "$(printf "a\\"b")"',
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "substitution with escaped space",
            r'git commit -m "$(printf a\ b)"',
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "nested substitution",
            'git commit -m "$(printf "$(echo nested)")"',
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "backtick substitution",
            r"git commit -m `printf a\`b`",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "multi-segment command",
            "printf start; git commit -m x && git status",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "pipeline into commit",
            "git add . | git commit -F -",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "shell inline command",
            'sh -c "git commit -m x"',
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "env command with git index",
            "env GIT_INDEX_FILE=/tmp/index git commit -m x",
            json_line({"block": None}),
            json_line(
                [{"git_args": [], "git_env": ["GIT_INDEX_FILE=/tmp/index"]}]
            ),
        ),
        (
            "unquoted heredoc body substitution",
            "cat <<EOF\n$(git commit)\nEOF",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "quoted heredoc body with later commit",
            "cat <<'EOF'\n$(git commit)\nEOF\ngit commit -m x",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
    ]

    def run_parser(self, mode: str, command: str) -> subprocess.CompletedProcess[str]:
        args = [sys.executable, str(PARSER_PATH), mode, command]
        if mode == "commit-contexts":
            args.append("parse failed")
        return subprocess.run(
            args,
            check=False,
            capture_output=True,
            env=subprocess_env(),
            text=True,
        )

    def test_noninteractive_cli_contracts(self) -> None:
        for name, command, expected_stdout, _expected_commit_contexts in self.CASES:
            with self.subTest(name=name):
                result = self.run_parser("noninteractive", command)

                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, expected_stdout)

    def test_commit_contexts_cli_contracts(self) -> None:
        for name, command, _expected_noninteractive, expected_stdout in self.CASES:
            with self.subTest(name=name):
                result = self.run_parser("commit-contexts", command)

                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, expected_stdout)


class RmRfParserCliTest(unittest.TestCase):
    maxDiff = None

    CASES = [
        (
            "plain rm -rf",
            "rm -rf directory/",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "xargs rm -rf",
            "find . -name '*.tmp' | xargs rm -rf",
            json_line({"block": XARGS_RM_RF_REASON}),
        ),
        (
            "xargs arg file rm -rf",
            "xargs --arg-file files rm -rf",
            json_line({"block": XARGS_RM_RF_REASON}),
        ),
        (
            "find delete",
            "find . -name '*.tmp' -delete",
            json_line({"block": FIND_DELETE_REASON}),
        ),
        (
            "find exec rm -rf",
            "find . -type d -exec rm -rf {} \\;",
            json_line({"block": FIND_EXEC_RM_RF_REASON}),
        ),
        (
            "shred",
            "sudo shred -u file.txt",
            json_line({"block": SHRED_REASON}),
        ),
        (
            "unlink",
            "/bin/unlink file.txt",
            json_line({"block": UNLINK_REASON}),
        ),
        (
            "git rm allowed",
            "git rm -rf directory/",
            json_line({"block": None}),
        ),
        (
            "quoted text allowed",
            'echo "rm -rf is dangerous"',
            json_line({"block": None}),
        ),
        (
            "rm -r without force allowed",
            "rm -r directory/",
            json_line({"block": None}),
        ),
        (
            "multiline rm -r before unrelated force flag allowed",
            "rm -r build\ntar -cf archive.tar src",
            json_line({"block": None}),
        ),
        (
            "escaped quote before unrelated force flag allowed",
            'rm -r dir\\"name\ncurl -fsSL https://example.com | head',
            json_line({"block": None}),
        ),
        (
            "backslash continued force flag",
            "rm -r build \\\n-f",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "multiline quoted argument before force flag",
            'rm -r "dir\nname" -f',
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "nested sh command",
            "sh -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "sudo directory option shell command",
            "sudo -D /tmp bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "sudo role option shell command",
            "sudo -R role bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "sudo chroot option shell command",
            "sudo --chroot /tmp bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "sudo login class option shell command",
            "sudo --login-class staff bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "nohup shell command",
            "nohup bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "time output shell command",
            "time -o out bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "timeout option terminator shell command",
            "timeout -- 1 bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "xargs shell command",
            "xargs -I{} bash -c 'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "find exec shell command",
            "find . -type d -exec bash -c 'rm -rf directory/' \\;",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "eval command",
            'bash -c "eval rm -rf directory/"',
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "shell function command",
            "bash -c 'f(){ rm -rf directory/; }; f'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "shell function keyword command",
            "bash -c 'function f { rm -rf directory/; }; f'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "command substitution",
            "echo $(rm -rf directory/)",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "backtick substitution",
            "echo `rm -rf directory/`",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "command substituted shell payload",
            'bash -c "$(echo rm -rf directory/)"',
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "safe command substitution with rm text",
            'echo "$(echo rm -rf is dangerous)"',
            json_line({"block": None}),
        ),
        (
            "process substitution",
            'bash -c "cat <(rm -rf directory/)"',
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "non-shell heredoc allowed",
            "cat > script.sh <<'EOF'\nrm -rf \"$tmp\"\nEOF",
            json_line({"block": None}),
        ),
        (
            "shell heredoc blocked",
            "bash <<'EOF'\nrm -rf directory/\nEOF",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "shell heredoc after command list blocked",
            "echo ok; bash <<'EOF'\nrm -rf directory/\nEOF",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "shell heredoc after pipeline blocked",
            "cat /dev/null | bash <<'EOF'\nrm -rf directory/\nEOF",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "mixed heredocs with second shell blocked",
            "cat <<A; bash <<B\nsafe\nA\nrm -rf directory/\nB",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "mixed heredocs with second non-shell allowed",
            'bash <<A; cat > script.sh <<B\necho safe\nA\nrm -rf "$tmp"\nB',
            json_line({"block": None}),
        ),
        (
            "shell heredoc after stdout redirection blocked",
            "bash > out <<'EOF'\nrm -rf directory/\nEOF",
            json_line({"block": RM_RF_REASON}),
        ),
    ]

    def run_parser(self, command: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(PARSER_PATH), "rm-rf", command],
            check=False,
            capture_output=True,
            env=subprocess_env(),
            text=True,
        )

    def test_rm_rf_cli_contracts(self) -> None:
        for name, command, expected_stdout in self.CASES:
            with self.subTest(name=name):
                result = self.run_parser(command)

                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, expected_stdout)
