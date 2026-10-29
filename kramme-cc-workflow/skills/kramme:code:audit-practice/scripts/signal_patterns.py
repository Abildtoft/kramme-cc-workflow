"""Event classifiers for session-signals.py.

Kept apart from transcript parsing so the vocabularies can grow without crowding it. Every
classifier works on one prompt, command line, or tool name and returns a label or a flag,
never transcript text.
"""

from __future__ import annotations

import os
import re
from typing import List, Tuple

EDIT_TOOLS = frozenset({"Edit", "MultiEdit", "NotebookEdit", "Write", "apply_patch"})
EXPLORE_TOOLS = frozenset({"Glob", "Grep", "LS", "Read"})
EXPLORE_PROGRAMS = frozenset("cat fd find grep head ls rg sed tail tree wc".split())
SHELL_TOOLS = frozenset({"Bash", "exec_command", "local_shell", "shell"})
SUBAGENT_TOOLS = frozenset({"Agent", "Task", "spawn_agent"})
REVIEW_NAME = re.compile(r"(?<!resolve-)review(?!-reply)", re.IGNORECASE)
ALIGNMENT_SKILL = re.compile(r"interview|grill|spec|issue-define|discovery|wayfinder|plan", re.IGNORECASE)
VERIFY_SKILL = re.compile(r"verify[:-]run|verification-before-completion|(?:^|[:-])verify$", re.IGNORECASE)

CONDUCTOR_INSTRUCTION_CLOSE = "</system_instruction>"
SYSTEM_REMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.DOTALL)
COMMAND_NAME = re.compile(r"<command-name>\s*/?([^<\s]+)\s*</command-name>")
NON_PROMPT_PREFIXES = ("<local-command-stdout>", "<local-command-stderr>", "<local-command-caveat>", "Caveat:")
INTERRUPT_PREFIX = "[Request interrupted by user"
CODEX_INJECTED_PREFIXES = ("# AGENTS.md instructions for", "<environment_context>", "<user_instructions>")

NUDGE_WORDS = frozenset(
    "ahead approve approved carry continue do for go going good great it k keep lgtm looks next nice ok okay on "
    "perfect please proceed ship sounds sure thanks thank y yeah yep yes you".split()
)
CORRECTION = re.compile(
    r"^(?:no|nope|wrong|incorrect|undo|revert|that'?s (?:not|wrong|incorrect)|that is (?:not|wrong)|"
    r"this is (?:not|wrong)|not what i|i (?:said|meant|asked)|you (?:missed|forgot|broke|ignored|didn'?t)|"
    r"why did you)\b"
)

SEGMENT_SEPARATORS = re.compile(r"&&|\|\||[;|&\n()]")
ENV_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
PREFIX_COMMANDS = frozenset("bunx command env exec nice npx rtk time timeout".split())
RUN_SUBCOMMANDS = {"bundle": "exec", "pipenv": "run", "poetry": "run", "uv": "run"}
NAVIGATION_PROGRAMS = frozenset(". : cd export popd pushd set source true".split())
CHECK_PROGRAMS = frozenset(
    "ava bats biome ctest eslint flake8 golangci-lint jest mocha mypy nox phpunit pylint pyright pytest rspec ruff "
    "shellcheck tox tsc vitest vue-tsc".split()
)
CHECK_SUBCOMMANDS = {
    "cargo": frozenset({"check", "clippy", "nextest", "test"}),
    "deno": frozenset({"check", "lint", "test"}),
    "dotnet": frozenset({"build", "test"}),
    "go": frozenset({"test", "vet"}),
    "playwright": frozenset({"test"}),
    "swift": frozenset({"build", "test"}),
}
TASK_RUNNERS = frozenset("bun gradle gradlew just make mvn mvnw npm nx pnpm rake task turbo yarn".split())
INSTALL_CI_RUNNERS = frozenset({"bun", "npm", "pnpm"})
VALUE_OPTIONS = frozenset("-C -F -f --cwd --dir --directory --file --filter --makefile --prefix --workspace".split())
CHECK_TARGET = re.compile(r"(?:^|[-:_./])(?:build|check|ci|lint|test|tests|typecheck|type-check|verify)(?:$|[-:_.])")


def shell_segments(command: str) -> List[List[str]]:
    """Split a command line into argument lists, dropping env assignments and wrapper commands."""
    segments: List[List[str]] = []
    for segment in SEGMENT_SEPARATORS.split(command):
        words = segment.split()
        while words and ENV_ASSIGNMENT.match(words[0]):
            words.pop(0)
        while words:
            head = os.path.basename(words[0])
            if head in PREFIX_COMMANDS:
                words.pop(0)
                while words and (words[0].startswith("-") or (head == "timeout" and words[0][:1].isdigit())):
                    words.pop(0)
            elif RUN_SUBCOMMANDS.get(head) and len(words) > 1 and words[1] == RUN_SUBCOMMANDS[head]:
                words = words[2:]
            elif head in ("python", "python3") and len(words) > 2 and words[1] == "-m":
                words = words[2:]
            else:
                break
        if words:
            segments.append([os.path.basename(words[0]), *words[1:]])
    return segments


def positional_args(args: List[str]) -> List[str]:
    """Arguments that are neither options nor the values of options that take one."""
    positional: List[str] = []
    skip = False
    for arg in args:
        if skip:
            skip = False
        elif arg.startswith("-"):
            skip = arg in VALUE_OPTIONS
        else:
            positional.append(arg)
    return positional


def is_check(argv: List[str]) -> bool:
    program = argv[0]
    targets = positional_args(argv[1:])
    if program in CHECK_PROGRAMS:
        return True
    if program in CHECK_SUBCOMMANDS:
        return bool(targets) and targets[0] in CHECK_SUBCOMMANDS[program]
    if program in INSTALL_CI_RUNNERS and targets[:1] == ["ci"]:
        return False
    if program in TASK_RUNNERS:
        return any(CHECK_TARGET.search(target) for target in targets[:3])
    return False


def classify_command(command: str) -> Tuple[bool, str]:
    """Return whether a command runs a check and which program produced its output."""
    segments = shell_segments(command)
    producer = next((argv[0] for argv in segments if argv[0] not in NAVIGATION_PROGRAMS), "")
    return any(is_check(argv) for argv in segments), producer


def prompt_body(text: str) -> str:
    """Drop host-injected instruction blocks and collapse whitespace."""
    end = text.rfind(CONDUCTOR_INSTRUCTION_CLOSE)
    if end != -1:
        text = text[end + len(CONDUCTOR_INSTRUCTION_CLOSE) :]
    return " ".join(SYSTEM_REMINDER.sub(" ", text).split())


def is_nudge(body: str) -> bool:
    words = re.findall(r"[a-z']+", body.lower())
    if not words:
        return 0 < len(body) <= 4
    return len(words) <= 5 and all(word.strip("'") in NUDGE_WORDS for word in words)


def is_correction(body: str) -> bool:
    return CORRECTION.match(body.lower()) is not None


def tool_group(name: str) -> str:
    """Group MCP tools by server so one server's output reads as one source."""
    parts = name.split("__")
    return f"mcp__{parts[1]}" if name.startswith("mcp__") and len(parts) > 2 else name
