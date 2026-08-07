from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

PARSER_PATH = Path(__file__).resolve().parents[2] / "hooks" / "lib" / "git_command_parser.py"

INTERACTIVE_COMMIT_REASON = (
    'git commit without a message source may open an editor. Use: git commit -m "your message" (or --no-edit for amend)'
)
RM_RF_REASON = "rm -rf is blocked. Use `trash` instead (install: brew install trash). Files go to Trash for recovery."
XARGS_RM_RF_REASON = "xargs rm -rf is blocked. Use `trash` instead."
FIND_DELETE_REASON = "find -delete is blocked. Use `trash` instead for recoverable deletion."
FIND_EXEC_RM_RF_REASON = "find -exec rm -rf is blocked. Use `trash` instead."
SHRED_REASON = "shred is blocked. Use `trash` instead for recoverable deletion."
UNLINK_REASON = "unlink is blocked. Use `trash` instead for recoverable deletion."
INTERACTIVE_REBASE_REASON = "Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ..."
NONINTERACTIVE_PARSE_ERROR_REASON = "Unable to safely parse command. Refusing potentially interactive git command."
COMMIT_PARSE_ERROR_REASON = "parse failed"


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
        command = r"$(outer $(inner one))"

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
        stripped, substitutions = PARSER.strip_heredoc_bodies("bash <<'EOF'\nrm -rf directory/\nEOF\n")

        self.assertEqual(stripped, "bash <<'EOF'\nrm -rf directory/\nEOF\n")
        self.assertEqual(substitutions, [])

    def test_replace_command_substitutions_collects_placeholder_contents(self) -> None:
        sanitized, substitutions = PARSER.replace_command_substitutions(r'git commit -m "$(printf a\ b)"')

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
        indexes = PARSER.extract_placeholder_indexes(["__CMD_SUBST_2__", "x__CMD_SUBST_1__", "__CMD_SUBST_2__"])

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
            "_decode_ansi_c_string",
            "_expand_ansi_c_quoted_strings",
            "_is_assignment",
            "_skip_xargs_options",
        ]

        for helper in helpers:
            with self.subTest(helper=helper):
                self.assertEqual(source.count(f"def {helper}"), 1)

        # W02A: these were formerly separate byte-identical regex constants
        # (ASSIGNMENT_WORD, NONINTERACTIVE_ASSIGNMENT, COMMIT_ASSIGNMENT) now
        # canonicalized to a single ASSIGNMENT_WORD definition.
        self.assertEqual(source.count("ASSIGNMENT_WORD = re.compile"), 1)
        self.assertNotIn("NONINTERACTIVE_ASSIGNMENT", source)
        self.assertNotIn("COMMIT_ASSIGNMENT", source)

    def test_expand_ansi_c_quoted_strings_decodes_shell_escapes(self) -> None:
        cases = [
            (r"bash -c $'git\x20commit'", "bash -c 'git commit'"),
            (r"bash -c $'git\tcommit'", "bash -c 'git\tcommit'"),
            (r"bash -c $'echo ok\ngit commit'", "bash -c 'echo ok\ngit commit'"),
            (r"printf $'it\'s safe'", "printf 'it'\"'\"'s safe'"),
            (r'''bash -c "$'git\x20commit'"''', r'''bash -c "$'git\x20commit'"'''),
            (r"bash -c '$git commit'", r"bash -c '$git commit'"),
        ]

        for command, expected in cases:
            with self.subTest(command=command):
                self.assertEqual(PARSER._expand_ansi_c_quoted_strings(command), expected)


class GitCommandPrimitiveEquivalenceTest(unittest.TestCase):
    """Pins the cross-mode primitive invariants W02A must preserve.

    These primitives currently exist as separate copies for the
    `noninteractive`, `commit-contexts`, and `rm-rf` parser modes. Some
    copies are byte-identical (safe to canonicalize); others carry an
    intentional behavioral delta (must stay explicit, not be erased). This
    test class pins both kinds before any consolidation.
    """

    ASSIGNMENT_CASES = [
        ("FOO=bar", True),
        ("FOO=", True),
        ("_FOO9=bar=baz", True),
        ("9FOO=bar", False),
        ("FOO", False),
        ("FOO.BAR=baz", False),
        ("=bar", False),
        ("", False),
    ]

    def test_assignment_predicate_is_canonical_across_modes(self) -> None:
        # ASSIGNMENT_WORD/_is_assignment is the single canonical primitive
        # shared by the noninteractive, commit-contexts, and rm-rf modes
        # (formerly three byte-identical copies: ASSIGNMENT_WORD,
        # NONINTERACTIVE_ASSIGNMENT, COMMIT_ASSIGNMENT).
        for token, expected in self.ASSIGNMENT_CASES:
            with self.subTest(token=token):
                self.assertIs(PARSER._is_assignment(token), expected)
                self.assertIs(bool(PARSER.ASSIGNMENT_WORD.match(token)), expected)

    def test_shell_reserved_words_and_keyword_sets_differ_only_by_closing_paren(self) -> None:
        # SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE is now the single canonical set
        # shared by the noninteractive and commit-contexts modes (formerly
        # two byte-identical copies: NONINTERACTIVE_SHELL_KEYWORDS and
        # COMMIT_SHELL_KEYWORDS). It differs from SHELL_RESERVED_COMMAND_WORDS
        # (used by the shared command-prefix normalizer) by exactly a
        # trailing ")" — an intentional mode delta, not accidental drift.
        self.assertEqual(PARSER.SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE - PARSER.SHELL_RESERVED_COMMAND_WORDS, {")"})
        self.assertEqual(PARSER.SHELL_RESERVED_COMMAND_WORDS - PARSER.SHELL_KEYWORDS_WITH_SUBSHELL_CLOSE, set())
        source = PARSER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("NONINTERACTIVE_SHELL_KEYWORDS", source)
        self.assertNotIn("COMMIT_SHELL_KEYWORDS", source)

    def test_xargs_option_vocabulary_is_canonical_across_modes(self) -> None:
        # XARGS_OPTIONS_WITH_VALUE/_skip_xargs_options are now the single
        # canonical xargs-option-consumption primitive shared by the
        # noninteractive and rm-rf modes (formerly a byte-identical-looking
        # but actually incomplete NONINTERACTIVE_XARGS_OPTIONS_WITH_VALUE
        # copy, plus a separate, fuller inline vocabulary in _detect_xargs).
        # See XargsOptionVocabularyParityTest for the behavioral fix this
        # consolidation carries: the incomplete copy silently hid `git
        # commit` behind `xargs -a`/`-J` from the noninteractive gate.
        source = PARSER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("NONINTERACTIVE_XARGS_OPTIONS_WITH_VALUE", source)
        self.assertEqual(source.count("XARGS_OPTIONS_WITH_VALUE = "), 1)
        self.assertEqual(source.count("def _skip_xargs_options"), 1)

    def test_shell_executable_set_is_canonical_across_modes(self) -> None:
        # SHELL_EXECUTABLES is now the single canonical set shared by the
        # command-prefix normalizer, rm-rf detector, and noninteractive
        # parser (formerly a byte-identical NONINTERACTIVE_SHELL_EXECUTABLES
        # copy).
        self.assertEqual(PARSER.SHELL_EXECUTABLES, {"sh", "bash", "zsh", "dash", "ksh"})
        source = PARSER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("NONINTERACTIVE_SHELL_EXECUTABLES", source)

    BASENAME_CASES = [
        # token, _basename() result, _basename_no_unescape() result
        ("git", "git", "git"),
        ("/usr/bin/git", "git", "git"),
        (r"\git", "git", r"\git"),
        (r"\ls", "ls", r"\ls"),
        ("sh", "sh", "sh"),
    ]

    def test_basename_helpers_differ_only_in_backslash_unescaping(self) -> None:
        # _basename() strips a leading backslash (so a backslash-escaped
        # invocation like `\rm -rf` is still recognized as `rm` by the rm-rf
        # detector); _basename_no_unescape() does not. It is now the single
        # canonical helper shared by the noninteractive mode and the
        # commit-contexts mode's git/alias/export/unset checks (formerly a
        # private _noninteractive_basename plus two bare os.path.basename()
        # calls duplicated inline in the commit-contexts path).
        for token, expected_basename, expected_no_unescape in self.BASENAME_CASES:
            with self.subTest(token=token):
                self.assertEqual(PARSER._basename(token), expected_basename)
                self.assertEqual(PARSER._basename_no_unescape(token), expected_no_unescape)
                self.assertEqual(os.path.basename(token), expected_no_unescape)

        source = PARSER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("_noninteractive_basename", source)
        self.assertEqual(source.count("def _basename_no_unescape"), 1)


class GitCommandNoninteractiveHelperTest(unittest.TestCase):
    """Direct tests for the option-consumption helpers W02A promoted out of
    run_noninteractive's closure to module scope."""

    def test_has_long_option_matches_bare_and_attached_forms(self) -> None:
        self.assertTrue(PARSER._has_long_option(["--no-edit"], "--no-edit"))
        self.assertTrue(PARSER._has_long_option(["--message=x"], "--message"))
        self.assertFalse(PARSER._has_long_option(["--", "--no-edit"], "--no-edit"))
        self.assertFalse(PARSER._has_long_option(["--no-edits"], "--no-edit"))

    def test_has_short_option_scans_clustered_flags_until_separator(self) -> None:
        self.assertTrue(PARSER._has_short_option(["-pi"], "p"))
        self.assertFalse(PARSER._has_short_option(["--", "-p"], "p"))
        self.assertFalse(PARSER._has_short_option(["-"], "p"))

    def test_short_option_consumes_next_value_only_when_trailing(self) -> None:
        value_opts = PARSER.COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE
        self.assertTrue(PARSER._short_option_consumes_next_value("-m", value_opts))
        self.assertTrue(PARSER._short_option_consumes_next_value("-am", value_opts))
        self.assertFalse(PARSER._short_option_consumes_next_value("-ma", value_opts))
        self.assertFalse(PARSER._short_option_consumes_next_value("--message", value_opts))

    def test_classify_commit_fixup_distinguishes_safe_and_interactive_values(self) -> None:
        self.assertEqual(PARSER._classify_commit_fixup(["--fixup=amend:HEAD"]), "interactive")
        self.assertEqual(PARSER._classify_commit_fixup(["--fixup=reword:HEAD"]), "interactive")
        self.assertEqual(PARSER._classify_commit_fixup(["--fixup", "HEAD"]), "safe")
        self.assertEqual(PARSER._classify_commit_fixup(["-m", "amend:not-a-fixup-value"]), "none")
        self.assertEqual(PARSER._classify_commit_fixup(["--", "--fixup=amend:HEAD"]), "none")

    def test_commit_requests_editor_detects_clustered_and_separate_flags(self) -> None:
        self.assertTrue(PARSER._commit_requests_editor(["-e"]))
        self.assertTrue(PARSER._commit_requests_editor(["--edit"]))
        self.assertTrue(PARSER._commit_requests_editor(["-ae"]))
        self.assertFalse(PARSER._commit_requests_editor(["-m", "message"]))
        self.assertFalse(PARSER._commit_requests_editor(["--message=x"]))

    def test_merge_edit_is_safe_requires_ff_only_without_no_ff(self) -> None:
        self.assertTrue(PARSER._merge_edit_is_safe(["--ff-only"]))
        self.assertFalse(PARSER._merge_edit_is_safe(["--ff-only", "--no-ff"]))
        self.assertFalse(PARSER._merge_edit_is_safe([]))

    def test_evaluate_noninteractive_commands_stops_recursion_at_depth_limit(self) -> None:
        reason = PARSER._evaluate_noninteractive_commands([], [], depth=5)

        self.assertEqual(reason, PARSER.NONINTERACTIVE_PARSE_ERROR_REASON)


class GitCommandParserBoundaryTest(unittest.TestCase):
    def test_parse_env_wrapped_segment_exposes_wrapper_state(self) -> None:
        result = PARSER.parse_env_wrapped_segment(
            [
                "env",
                "GIT_EDITOR=true",
                "sudo",
                "-D",
                "/tmp",
                "bash",
                "-c",
                "git commit",
            ],
            inherited_env={"GIT_SEQUENCE_EDITOR": "false"},
        )

        self.assertEqual(
            result,
            PARSER.NoninteractiveParseResult(
                env={"GIT_SEQUENCE_EDITOR": "false", "GIT_EDITOR": "true"},
                subcmd="__shell_c__",
                args=["git commit"],
            ),
        )

    def test_normalize_command_prefix_preserves_large_environment_order(self) -> None:
        assignments = [f"KEY_{idx}=initial" for idx in range(2_000)]
        normalized = PARSER.normalize_command_prefix(
            [
                *assignments,
                "env",
                "KEY_0=updated",
                "EXTRA=value",
                "git",
                "status",
            ]
        )

        self.assertEqual(normalized.executable, "git")
        self.assertEqual(normalized.arguments, ["status"])
        self.assertEqual(
            normalized.environment,
            [
                *assignments[1:],
                "KEY_0=updated",
                "EXTRA=value",
            ],
        )

    def test_normalize_command_prefix_applies_exec_environment_options(self) -> None:
        for option in ("-c", "-cl", "-lc"):
            with self.subTest(option=option):
                normalized = PARSER.normalize_command_prefix(
                    ["exec", option, "git", "rebase", "-i", "main"],
                    inherited_environment=[
                        "GIT_DIR=/tmp/other/.git",
                        "GIT_SEQUENCE_EDITOR=true",
                    ],
                )

                self.assertEqual(normalized.executable, "git")
                self.assertEqual(normalized.arguments, ["rebase", "-i", "main"])
                self.assertEqual(normalized.environment, [])

        argv0 = PARSER.normalize_command_prefix(
            ["exec", "-acommand", "git", "status"],
            inherited_environment=["GIT_DIR=/tmp/other/.git"],
        )

        self.assertEqual(argv0.executable, "git")
        self.assertEqual(argv0.arguments, ["status"])
        self.assertEqual(argv0.environment, ["GIT_DIR=/tmp/other/.git"])

        grouped_argv0 = PARSER.normalize_command_prefix(
            ["exec", "-ca", "custom-name", "git", "status"],
            inherited_environment=["GIT_DIR=/tmp/other/.git"],
        )

        self.assertEqual(grouped_argv0.executable, "git")
        self.assertEqual(grouped_argv0.arguments, ["status"])
        self.assertEqual(grouped_argv0.environment, [])

    def test_normalize_command_prefix_limits_nested_env_split_strings(self) -> None:
        allowed = "--split-string=" * PARSER.MAX_ENV_SPLIT_STRING_EXPANSIONS + "printf"
        normalized = PARSER.normalize_command_prefix(["env", allowed, "safe"])

        self.assertEqual(normalized.executable, "printf")
        self.assertEqual(normalized.arguments, ["safe"])

        excessive = "--split-string=" + allowed
        with self.assertRaisesRegex(ValueError, "env split-string expansion limit exceeded"):
            PARSER.normalize_command_prefix(["env", excessive, "safe"])

        oversized = "x" * (PARSER.MAX_ENV_SPLIT_STRING_EXPANSION_WORK + 1)
        with self.assertRaisesRegex(ValueError, "env split-string expansion limit exceeded"):
            PARSER.normalize_command_prefix(["env", f"--split-string={oversized}"])

    def test_parse_env_wrapped_segment_marks_aliases_as_parse_errors(self) -> None:
        result = PARSER.parse_env_wrapped_segment(["alias", "git=git -c alias.x=commit"])

        self.assertEqual(
            result,
            PARSER.NoninteractiveParseResult(
                env={},
                subcmd=PARSER.NONINTERACTIVE_PARSE_ERROR_SUBCOMMAND,
                args=[],
            ),
        )

    def test_parse_commit_segment_exposes_commit_and_persisted_state(self) -> None:
        result = PARSER.parse_commit_segment(
            ["env", "GIT_DIR=/tmp/repo", "git", "-C", "worktree", "commit"],
            git_args=[],
            git_env=[],
            shell_git_vars=[],
        )

        self.assertEqual(
            result,
            PARSER.CommitSegmentResult(
                contexts=[
                    {
                        "git_args": ["-C", "worktree"],
                        "git_env": ["GIT_DIR=/tmp/repo"],
                    }
                ],
                persisted_git_env=[],
                persisted_shell_git_vars=[],
            ),
        )

    def test_parse_commit_segment_does_not_mutate_git_args(self) -> None:
        git_args = ["--literal-pathspecs"]

        result = PARSER.parse_commit_segment(
            ["git", "-C", "worktree", "commit"],
            git_args=git_args,
            git_env=[],
            shell_git_vars=[],
        )

        self.assertEqual(git_args, ["--literal-pathspecs"])
        self.assertEqual(
            result.contexts[0]["git_args"],
            ["--literal-pathspecs", "-C", "worktree"],
        )
        self.assertIsNot(result.contexts[0]["git_args"], git_args)

    def test_parse_commit_segment_preserves_content_selection(self) -> None:
        cases = [
            (
                "all long",
                ["git", "commit", "--all", "--message=test"],
                {"selection_mode": "all", "pathspecs": []},
            ),
            (
                "all short cluster",
                ["git", "commit", "-am", "test"],
                {"selection_mode": "all", "pathspecs": []},
            ),
            (
                "include long",
                ["git", "commit", "--include", "-m", "test", "one.txt"],
                {"selection_mode": "include", "pathspecs": ["one.txt"]},
            ),
            (
                "include short",
                ["git", "commit", "-i", "-m", "test", "one.txt"],
                {"selection_mode": "include", "pathspecs": ["one.txt"]},
            ),
            (
                "only long",
                ["git", "commit", "--only", "-m", "test", "one.txt"],
                {"selection_mode": "only", "pathspecs": ["one.txt"]},
            ),
            (
                "only short",
                ["git", "commit", "-o", "-m", "test", "one.txt"],
                {"selection_mode": "only", "pathspecs": ["one.txt"]},
            ),
            (
                "implicit pathspec",
                ["git", "commit", "-m", "test", "one.txt"],
                {"selection_mode": "only", "pathspecs": ["one.txt"]},
            ),
            (
                "separator preserves option-like pathspec",
                ["git", "commit", "-m", "test", "--", "-a"],
                {"selection_mode": "only", "pathspecs": ["-a"]},
            ),
            (
                "line-delimited pathspec file",
                [
                    "git",
                    "commit",
                    "-m",
                    "test",
                    "--pathspec-from-file",
                    "paths.txt",
                ],
                {
                    "selection_mode": "only",
                    "pathspecs": [],
                    "pathspec_from_file": "paths.txt",
                    "pathspec_file_nul": False,
                },
            ),
            (
                "nul-delimited pathspec file",
                [
                    "git",
                    "commit",
                    "-m",
                    "test",
                    "--pathspec-from-file=paths.bin",
                    "--pathspec-file-nul",
                ],
                {
                    "selection_mode": "only",
                    "pathspecs": [],
                    "pathspec_from_file": "paths.bin",
                    "pathspec_file_nul": True,
                },
            ),
        ]

        for name, tokens, expected_selection in cases:
            with self.subTest(name=name):
                result = PARSER.parse_commit_segment(
                    tokens,
                    git_args=[],
                    git_env=[],
                    shell_git_vars=[],
                )

                self.assertEqual(
                    result.contexts,
                    [{"git_args": [], "git_env": [], **expected_selection}],
                )

    def test_parse_commit_segment_marks_unmodelled_selection(self) -> None:
        cases = [
            ["git", "commit", "--patch", "-m", "test"],
            ["git", "commit", "--interactive", "-m", "test"],
            ["git", "commit", "--mes", "notes.txt"],
            ["git", "commit", "--all", "--only", "-m", "test", "one.txt"],
            [
                "git",
                "commit",
                "-m",
                "test",
                "--pathspec-from-file=paths.txt",
                "one.txt",
            ],
        ]

        for tokens in cases:
            with self.subTest(tokens=tokens):
                result = PARSER.parse_commit_segment(
                    tokens,
                    git_args=[],
                    git_env=[],
                    shell_git_vars=[],
                )

                self.assertIn("selection_error", result.contexts[0])

    def test_parse_commit_segment_exposes_exported_replay_state(self) -> None:
        result = PARSER.parse_commit_segment(
            ["export", "GIT_DIR=/tmp/repo"],
            git_args=[],
            git_env=[],
            shell_git_vars=[],
        )

        self.assertEqual(
            result,
            PARSER.CommitSegmentResult(
                contexts=[],
                persisted_git_env=["GIT_DIR=/tmp/repo"],
                persisted_shell_git_vars=["GIT_DIR=/tmp/repo"],
            ),
        )

    def test_external_wrappers_do_not_persist_shell_builtin_state(self) -> None:
        for prefix in ("timeout 1", "nice", "nohup", "env", "sudo", "command time"):
            with self.subTest(prefix=prefix):
                contexts = PARSER.parse_commit_contexts(
                    (f"{prefix} export GIT_DIR=/tmp/other/.git GIT_WORK_TREE=/tmp/other; git commit -m test"),
                    inherited_git_env=[],
                    inherited_shell_git_vars=[],
                )

                self.assertEqual(
                    contexts,
                    [{"git_args": [], "git_env": []}],
                )

    def test_nonbare_time_uses_external_command_semantics(self) -> None:
        for prefix in (
            r"\time",
            '"time"',
            "'time'",
            r"t\ime",
            '"ti"me',
            "t'i'me",
            "$'time'",
            "t$'i'me",
        ):
            with self.subTest(prefix=prefix):
                contexts = PARSER.parse_commit_contexts(
                    (f"{prefix} export GIT_DIR=/tmp/other/.git GIT_WORK_TREE=/tmp/other; git commit -m test"),
                    inherited_git_env=[],
                    inherited_shell_git_vars=[],
                )

                self.assertEqual(
                    contexts,
                    [{"git_args": [], "git_env": []}],
                )

    def test_wrapper_without_payload_does_not_persist_prefixed_state(self) -> None:
        contexts = PARSER.parse_commit_contexts(
            (
                "GIT_DIR=/tmp/other/.git GIT_WORK_TREE=/tmp/other env -i; "
                "export GIT_DIR GIT_WORK_TREE; git commit -m test"
            ),
            inherited_git_env=[],
            inherited_shell_git_vars=[],
        )

        self.assertEqual(
            contexts,
            [{"git_args": [], "git_env": []}],
        )

    def test_time_keyword_persists_shell_builtin_state(self) -> None:
        contexts = PARSER.parse_commit_contexts(
            ("time export GIT_DIR=/tmp/other/.git GIT_WORK_TREE=/tmp/other; git commit -m test"),
            inherited_git_env=[],
            inherited_shell_git_vars=[],
        )

        self.assertEqual(
            contexts,
            [
                {
                    "git_args": [],
                    "git_env": [
                        "GIT_DIR=/tmp/other/.git",
                        "GIT_WORK_TREE=/tmp/other",
                    ],
                }
            ],
        )


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
            "shell inline commit without message",
            "bash -c 'git commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "ansi c shell inline commit",
            "bash -c $'git commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "ansi c hex escaped shell inline commit",
            r"bash -c $'git\x20commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "multiline ansi c shell inline commit",
            "bash -c $'echo ok\ngit commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "option bearing ansi c shell inline commit",
            "bash -O extglob -c $'git commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "environment wrapped ansi c shell inline commit",
            "env FOO=bar bash -c $'git commit'",
            json_line({"block": INTERACTIVE_COMMIT_REASON}),
            json_line([{"git_args": [], "git_env": []}]),
        ),
        (
            "safe ansi c shell inline command",
            "bash -c $'echo safe'",
            json_line({"block": None}),
            json_line([]),
        ),
        (
            "env command with git index",
            "env GIT_INDEX_FILE=/tmp/index git commit -m x",
            json_line({"block": None}),
            json_line([{"git_args": [], "git_env": ["GIT_INDEX_FILE=/tmp/index"]}]),
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

    def test_malformed_payloads_fail_closed(self) -> None:
        excessive_split_string = "--split-string=" * (PARSER.MAX_ENV_SPLIT_STRING_EXPANSIONS + 1) + "printf"
        commands = [
            "bash -c $'git commit",
            "env -S '\"git commit'",
            "env --split-string='\"git commit'",
            f"env {excessive_split_string} safe",
        ]

        for command in commands:
            with self.subTest(command=command):
                noninteractive = self.run_parser("noninteractive", command)
                commit_contexts = self.run_parser("commit-contexts", command)

                self.assertEqual(noninteractive.returncode, 0)
                self.assertEqual(noninteractive.stderr, "")
                self.assertEqual(
                    noninteractive.stdout,
                    json_line(
                        {"block": "Unable to safely parse command. Refusing potentially interactive git command."}
                    ),
                )
                self.assertEqual(commit_contexts.returncode, 0)
                self.assertEqual(commit_contexts.stderr, "")
                self.assertEqual(
                    commit_contexts.stdout,
                    json_line([{"parse_error": "parse failed"}]),
                )


class GitGlobalOptionPrefixTest(unittest.TestCase):
    """Both parser modes must resolve the same subcommand behind Git globals.

    A global option that takes a separated value hides the real subcommand from
    any walker that mistakes the value for it, which bypasses the
    interactive-command and review-artifact gates. This corpus pins one shared
    vocabulary for both modes: every prefix either resolves the subcommand in
    both modes, or fails closed in both.
    """

    maxDiff = None

    # (name, global options before the subcommand, git_args the commit mode
    # records). ``None`` marks a prefix whose value semantics are unknowable, so
    # both modes must fail closed instead of guessing.
    PREFIX_CASES = [
        ("no globals", [], []),
        ("separated -C", ["-C", "repo"], ["-C", "repo"]),
        ("attached -C", ["-Crepo"], ["-Crepo"]),
        ("separated -c", ["-c", "core.pager=cat"], ["-c", "core.pager=cat"]),
        ("attached -c", ["-ccore.pager=cat"], ["-ccore.pager=cat"]),
        ("separated --git-dir", ["--git-dir", "repo/.git"], ["--git-dir", "repo/.git"]),
        ("equals --git-dir", ["--git-dir=repo/.git"], ["--git-dir=repo/.git"]),
        ("separated --work-tree", ["--work-tree", "repo"], ["--work-tree", "repo"]),
        ("equals --work-tree", ["--work-tree=repo"], ["--work-tree=repo"]),
        ("separated --namespace", ["--namespace", "ns"], ["--namespace", "ns"]),
        ("equals --namespace", ["--namespace=ns"], ["--namespace=ns"]),
        (
            "separated --shallow-file",
            ["--shallow-file", ".git/shallow"],
            ["--shallow-file", ".git/shallow"],
        ),
        (
            "equals --shallow-file",
            ["--shallow-file=.git/shallow"],
            ["--shallow-file=.git/shallow"],
        ),
        (
            "separated --config-env",
            ["--config-env", "core.pager=PAGER_VAR"],
            ["--config-env", "core.pager=PAGER_VAR"],
        ),
        (
            "equals --config-env",
            ["--config-env=core.pager=PAGER_VAR"],
            ["--config-env=core.pager=PAGER_VAR"],
        ),
        (
            "separated --exec-path",
            ["--exec-path", "/usr/libexec/git-core"],
            ["--exec-path", "/usr/libexec/git-core"],
        ),
        (
            "equals --exec-path",
            ["--exec-path=/usr/libexec/git-core"],
            ["--exec-path=/usr/libexec/git-core"],
        ),
        ("separated --attr-source", ["--attr-source", "HEAD"], ["--attr-source", "HEAD"]),
        ("equals --attr-source", ["--attr-source=HEAD"], ["--attr-source=HEAD"]),
        ("valueless --bare", ["--bare"], ["--bare"]),
        ("valueless --no-pager", ["--no-pager"], ["--no-pager"]),
        (
            "valueless --literal-pathspecs",
            ["--literal-pathspecs"],
            ["--literal-pathspecs"],
        ),
        (
            "valueless --no-literal-pathspecs",
            ["--no-literal-pathspecs"],
            ["--no-literal-pathspecs"],
        ),
        (
            "valueless --no-optional-locks",
            ["--no-optional-locks"],
            ["--no-optional-locks"],
        ),
        ("short -p", ["-p"], ["-p"]),
        (
            "combined globals",
            ["-C", "repo", "--attr-source", "HEAD", "--no-pager"],
            ["-C", "repo", "--attr-source", "HEAD", "--no-pager"],
        ),
        (
            "separated legacy --super-prefix",
            ["--super-prefix", "sub/"],
            ["--super-prefix", "sub/"],
        ),
        (
            "equals legacy --super-prefix",
            ["--super-prefix=sub/"],
            ["--super-prefix=sub/"],
        ),
        ("unknown long option", ["--future-global", "value"], None),
        # An attached value is self-contained, so no token is ambiguous.
        ("unknown long option with equals", ["--future-global=value"], ["--future-global=value"]),
    ]

    def run_parser(self, mode: str, command: str) -> subprocess.CompletedProcess[str]:
        args = [sys.executable, str(PARSER_PATH), mode, command]
        if mode == "commit-contexts":
            args.append(COMMIT_PARSE_ERROR_REASON)
        return subprocess.run(
            args,
            check=False,
            capture_output=True,
            env=subprocess_env(),
            text=True,
        )

    def test_noninteractive_resolves_subcommand_behind_globals(self) -> None:
        for name, prefix, git_args in self.PREFIX_CASES:
            command = " ".join(["git", *prefix, "rebase", "-i", "HEAD~3"])
            expected = INTERACTIVE_REBASE_REASON if git_args is not None else NONINTERACTIVE_PARSE_ERROR_REASON
            with self.subTest(name=name):
                result = self.run_parser("noninteractive", command)

                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, json_line({"block": expected}))

    def test_commit_contexts_resolves_subcommand_behind_globals(self) -> None:
        for name, prefix, git_args in self.PREFIX_CASES:
            command = " ".join(["git", *prefix, "commit", "-m", "x"])
            expected = (
                [{"git_args": git_args, "git_env": []}]
                if git_args is not None
                else [{"parse_error": COMMIT_PARSE_ERROR_REASON}]
            )
            with self.subTest(name=name):
                result = self.run_parser("commit-contexts", command)

                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, json_line(expected))

    def test_modes_agree_on_the_same_command(self) -> None:
        # `git commit` with no message source is blocked only when a mode
        # resolved `commit`, and a commit context is emitted only then, so one
        # command exposes both modes' prefix resolution.
        for name, prefix, git_args in self.PREFIX_CASES:
            command = " ".join(["git", *prefix, "commit"])
            with self.subTest(name=name):
                noninteractive = self.run_parser("noninteractive", command)
                commit_contexts = self.run_parser("commit-contexts", command)

                if git_args is not None:
                    self.assertEqual(
                        noninteractive.stdout,
                        json_line({"block": INTERACTIVE_COMMIT_REASON}),
                    )
                    self.assertEqual(
                        commit_contexts.stdout,
                        json_line([{"git_args": git_args, "git_env": []}]),
                    )
                else:
                    self.assertEqual(
                        noninteractive.stdout,
                        json_line({"block": NONINTERACTIVE_PARSE_ERROR_REASON}),
                    )
                    self.assertEqual(
                        commit_contexts.stdout,
                        json_line([{"parse_error": COMMIT_PARSE_ERROR_REASON}]),
                    )

    def test_attr_source_cannot_hide_an_interactive_command(self) -> None:
        for command in (
            "git --attr-source HEAD rebase -i HEAD~3",
            "git --attr-source=HEAD rebase -i HEAD~3",
        ):
            with self.subTest(command=command):
                result = self.run_parser("noninteractive", command)

                self.assertEqual(result.stdout, json_line({"block": INTERACTIVE_REBASE_REASON}))

    def test_attr_source_cannot_hide_a_commit_context(self) -> None:
        for command, git_args in (
            ("git --attr-source HEAD commit -m x", ["--attr-source", "HEAD"]),
            ("git --attr-source=HEAD commit -m x", ["--attr-source=HEAD"]),
        ):
            with self.subTest(command=command):
                result = self.run_parser("commit-contexts", command)

                self.assertEqual(
                    result.stdout,
                    json_line([{"git_args": git_args, "git_env": []}]),
                )

    def test_known_globals_do_not_block_safe_commands(self) -> None:
        # Fail-closed handling must stay scoped to ambiguous options; every
        # known global still resolves a safe subcommand normally.
        for name, prefix, git_args in self.PREFIX_CASES:
            if git_args is None:
                continue
            command = " ".join(["git", *prefix, "status"])
            with self.subTest(name=name):
                noninteractive = self.run_parser("noninteractive", command)
                commit_contexts = self.run_parser("commit-contexts", command)

                self.assertEqual(noninteractive.stdout, json_line({"block": None}))
                self.assertEqual(commit_contexts.stdout, json_line([]))


class XargsOptionVocabularyParityTest(unittest.TestCase):
    """The noninteractive and rm-rf modes share one xargs option-consumption
    vocabulary via _skip_xargs_options().

    Membership in XARGS_OPTIONS_WITH_VALUE means "this option's value is a
    separate token, skip it too", and both directions of error hide the
    invoked command from either gate. Omitting a mandatory-value option makes
    the walker read that value as the command; listing an optional-value
    option makes it skip past the command itself. This corpus pins both
    arities against the bare and separate-token forms that distinguish them.
    """

    maxDiff = None

    # Value is a mandatory separate token: `xargs -a FILE git commit`.
    SEPARATE_TOKEN_VALUE_OPTIONS = ["-a", "--arg-file", "-J", "--process-slot-var", "-I", "-E", "-L"]
    # GNU value is optional and attached-only, so the next token is the
    # command: `xargs -i git commit` really does run `git commit`.
    OPTIONAL_ATTACHED_VALUE_OPTIONS = ["-i", "--replace", "--eof", "--max-lines"]

    def run_parser(self, mode: str, command: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(PARSER_PATH), mode, command],
            check=False,
            capture_output=True,
            env=subprocess_env(),
            text=True,
        )

    def test_skip_xargs_options_advances_past_every_separate_token_value_option(self) -> None:
        for option in self.SEPARATE_TOKEN_VALUE_OPTIONS:
            with self.subTest(option=option):
                args = [option, "VALUE", "git", "commit"]

                idx = PARSER._skip_xargs_options(args)

                self.assertEqual(args[idx:], ["git", "commit"])

    def test_skip_xargs_options_keeps_the_command_after_an_optional_value_option(self) -> None:
        for option in self.OPTIONAL_ATTACHED_VALUE_OPTIONS:
            with self.subTest(option=option):
                args = [option, "git", "commit"]

                idx = PARSER._skip_xargs_options(args)

                self.assertEqual(args[idx:], ["git", "commit"])

    def test_xargs_wrapped_commit_without_message_source_is_blocked(self) -> None:
        for option in self.SEPARATE_TOKEN_VALUE_OPTIONS:
            command = f"xargs {option} VALUE git commit"
            with self.subTest(command=command):
                result = self.run_parser("noninteractive", command)

                self.assertEqual(result.stdout, json_line({"block": INTERACTIVE_COMMIT_REASON}))

    def test_bare_optional_value_option_cannot_hide_a_commit(self) -> None:
        for option in self.OPTIONAL_ATTACHED_VALUE_OPTIONS:
            for command in (f"xargs {option} git commit", f"xargs {option}=VALUE git commit"):
                with self.subTest(command=command):
                    result = self.run_parser("noninteractive", command)

                    self.assertEqual(result.stdout, json_line({"block": INTERACTIVE_COMMIT_REASON}))

    def test_attached_short_optional_value_option_cannot_hide_a_commit(self) -> None:
        result = self.run_parser("noninteractive", "xargs -i{} git commit")

        self.assertEqual(result.stdout, json_line({"block": INTERACTIVE_COMMIT_REASON}))

    def test_xargs_wrapped_commit_with_message_is_still_allowed(self) -> None:
        for option in self.SEPARATE_TOKEN_VALUE_OPTIONS:
            command = f"xargs {option} VALUE git commit -m done"
            with self.subTest(command=command):
                result = self.run_parser("noninteractive", command)

                self.assertEqual(result.stdout, json_line({"block": None}))

    def test_optional_value_option_consumes_no_separate_token(self) -> None:
        # `xargs -i VALUE git commit` runs VALUE, not git, so there is no
        # git subcommand for the gate to classify.
        result = self.run_parser("noninteractive", "xargs -i VALUE git commit")

        self.assertEqual(result.stdout, json_line({"block": None}))

    def test_xargs_wrapped_rm_rf_via_separate_token_value_option_is_still_blocked(self) -> None:
        result = self.run_parser("rm-rf", "xargs -a file.txt rm -rf directory/")

        self.assertEqual(result.stdout, json_line({"block": XARGS_RM_RF_REASON}))

    def test_xargs_wrapped_rm_rf_behind_optional_value_option_is_blocked(self) -> None:
        for option in self.OPTIONAL_ATTACHED_VALUE_OPTIONS:
            command = f"xargs {option} rm -rf directory/"
            with self.subTest(command=command):
                result = self.run_parser("rm-rf", command)

                self.assertEqual(result.stdout, json_line({"block": XARGS_RM_RF_REASON}))


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
            "ansi c shell command",
            "bash -c $'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "ansi c hex escaped shell command",
            r"bash -c $'rm\x20-rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "multiline ansi c shell command",
            "bash -c $'echo ok\nrm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "option bearing ansi c shell command",
            "bash -O extglob -c $'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "environment wrapped ansi c shell command",
            "env FOO=bar bash -c $'rm -rf directory/'",
            json_line({"block": RM_RF_REASON}),
        ),
        (
            "safe ansi c shell command",
            "bash -c $'echo safe'",
            json_line({"block": None}),
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

    def test_split_string_expansion_limit_fails_closed(self) -> None:
        excessive_split_string = "--split-string=" * (PARSER.MAX_ENV_SPLIT_STRING_EXPANSIONS + 1) + "printf"

        result = self.run_parser(f"env {excessive_split_string} safe")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.stdout, json_line({"block": RM_RF_REASON}))
