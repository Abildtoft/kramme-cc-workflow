"""Mode dispatch for the command-safety parser CLI.

Each mode module is imported inside its own branch. One invocation asks for
one mode, and a single Bash tool call fans out to all three gates in three
separate processes (see the `Bash` matchers in `hooks/hooks.json`), so eager
imports would charge every process for the two modes it will not run.
"""

from __future__ import annotations

import sys


def main(argv: list[str]) -> int:
    """Dispatch the command-safety parser modes.

    See README.md#git-command-parser-mode-contracts.
    """
    if len(argv) < 2:
        print(
            "usage: git_command_parser.py <noninteractive|commit-contexts|rm-rf> <command> [parse-error-reason]",
            file=sys.stderr,
        )
        return 2

    mode = argv[0]
    command = argv[1]

    if mode == "noninteractive":
        from .noninteractive import run_noninteractive

        return run_noninteractive(command)

    if mode == "commit-contexts":
        from .commit import run_commit_contexts

        parse_error_reason = argv[2] if len(argv) > 2 else "Unable to safely parse command."
        return run_commit_contexts(command, parse_error_reason)

    if mode == "rm-rf":
        from .rm_rf import run_rm_rf

        return run_rm_rf(command)

    print(f"unknown parser mode: {mode}", file=sys.stderr)
    return 2
