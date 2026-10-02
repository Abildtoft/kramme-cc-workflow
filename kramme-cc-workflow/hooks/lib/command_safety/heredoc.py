"""Heredoc operator scanning shared by every parser mode.

Finds the `<<` operators that open a heredoc body while carrying quote and
substitution context from one command line to the next. Imports nothing else
in the package, so the tokenizer can depend on it without a cycle.
"""

from __future__ import annotations

from typing import Optional, TypedDict


class HeredocSpec(TypedDict):
    delimiter: str
    quoted: bool
    strip_tabs: bool
    start: int
    # Where the owning command's text begins on the operator's line: 0, just inside a `$(` or backtick
    # opened on this line, or just after a multi-line word that closed on this line.
    command_start: int
    # True when the owning command began on an earlier line, so its executable is not on this line.
    owner_started_earlier: bool
    # True inside `$(...)`, where bash also ends the body at a `<delimiter>)` line.
    in_substitution: bool


class PendingHeredoc(HeredocSpec):
    keep_body: bool


# A `#` starts a comment only at the start of a word in command context.
COMMENT_PRECEDING_CHARS = frozenset(" \t;&|()<>")
COMMAND_FRAME_KINDS = frozenset({"command", "substitution", "backtick"})


class _ShellFrame:
    """One open shell context: command, substitution, backtick, a quote kind, or arithmetic."""

    __slots__ = ("carried", "kind", "parens", "start", "started_earlier")

    def __init__(self, kind: str, start: int) -> None:
        self.kind = kind
        self.start = start
        self.parens = 0
        self.carried = False
        self.started_earlier = False


class HeredocScanner:
    """Find heredoc operators line by line, carrying shell context across lines.

    An operator counts only in command context: at top level, or inside `$(...)`
    or backticks, including a substitution nested in double quotes. `<<` inside
    quotes, `$'...'`, `$((...))`, `((...))`, or a comment is not an operator. Feed command
    lines only; heredoc body lines do not change shell context.

    A heredoc whose substitution closes on its own line is dropped: bash 3.2
    runs the following lines as commands while bash 5 reads them as the body,
    so analyzing them as commands is the conservative reading.
    """

    def __init__(self) -> None:
        self._frames = [_ShellFrame("command", 0)]
        self._continued_frame: Optional[_ShellFrame] = None

    def scan(self, line: str) -> list[HeredocSpec]:
        for frame in self._frames:
            frame.start = 0
            frame.carried = True
            # A backslash-newline continues the same command onto this line.
            frame.started_earlier = frame is self._continued_frame
        self._continued_frame = None
        heredocs: list[tuple[HeredocSpec, _ShellFrame]] = []
        idx = 0
        length = len(line)

        while idx < length:
            frame = self._frames[-1]
            char = line[idx]

            if frame.kind == "single":
                if char == "'":
                    self._close_frame(idx + 1)
                idx += 1
                continue

            if char == "\\":
                if frame.kind in COMMAND_FRAME_KINDS and line[idx + 1 : idx + 2] in ("\n", "\r"):
                    self._continued_frame = frame
                idx += 2
                continue

            if frame.kind == "ansi":
                if char == "'":
                    self._close_frame(idx + 1)
                idx += 1
                continue

            if frame.kind == "arithmetic":
                if char == "(":
                    frame.parens += 1
                elif char == ")" and frame.parens:
                    frame.parens -= 1
                elif char == ")":
                    idx += 2 if line.startswith("))", idx) else 1
                    self._close_frame(idx)
                    continue
                idx += 1
                continue

            if frame.kind == "double":
                if char == '"':
                    self._close_frame(idx + 1)
                    idx += 1
                    continue
                idx = self._open_expansion(line, idx)
                continue

            # Command context: top level, `$(...)`, or backticks.
            if char == "#" and (idx == 0 or line[idx - 1] in COMMENT_PRECEDING_CHARS):
                break
            if char in {"'", '"'}:
                self._frames.append(_ShellFrame("single" if char == "'" else "double", idx + 1))
                idx += 1
                continue
            if line.startswith("$'", idx):
                self._frames.append(_ShellFrame("ansi", idx + 2))
                idx += 2
                continue
            if char == "`" and frame.kind == "backtick":
                self._close_frame(idx + 1)
                idx += 1
                continue
            if line.startswith("((", idx):
                self._frames.append(_ShellFrame("arithmetic", idx + 2))
                idx += 2
                continue
            if char == "(":
                frame.parens += 1
                frame.started_earlier = False
                idx += 1
                continue
            if char == ")":
                if frame.parens:
                    frame.parens -= 1
                elif frame.kind == "substitution":
                    self._close_frame(idx + 1)
                idx += 1
                continue
            if line.startswith("<<", idx):
                heredoc, idx = _read_heredoc_operator(line, idx, frame)
                if heredoc is not None:
                    heredocs.append((heredoc, frame))
                continue
            if _separates_commands(line, idx):
                frame.started_earlier = False
            idx = self._open_expansion(line, idx)

        return [heredoc for heredoc, owner in heredocs if any(owner is frame for frame in self._frames)]

    def _close_frame(self, end: int) -> None:
        closed = self._frames.pop()
        if closed.carried:
            # The closed word began on an earlier line, so the enclosing command's text on this line resumes
            # after it, and that command itself began earlier.
            self._frames[-1].start = end
            self._frames[-1].started_earlier = True

    def _open_expansion(self, line: str, idx: int) -> int:
        if line.startswith("$((", idx):
            self._frames.append(_ShellFrame("arithmetic", idx + 3))
            return idx + 3
        if line.startswith("$(", idx):
            self._frames.append(_ShellFrame("substitution", idx + 2))
            return idx + 2
        if line[idx] == "`":
            self._frames.append(_ShellFrame("backtick", idx + 1))
        return idx + 1


def _separates_commands(line: str, idx: int) -> bool:
    """Whether `line[idx]` is a `;`, `|`, or `&` operator rather than part of `>|`, `2>&1`, or `&>`."""
    char = line[idx]
    previous = line[idx - 1 : idx]
    if char == ";":
        return True
    if char == "|":
        return previous != ">"
    return char == "&" and previous not in ("<", ">") and not line.startswith("&>", idx)


def _read_heredoc_operator(line: str, start: int, owner: _ShellFrame) -> tuple[Optional[HeredocSpec], int]:
    """Read the `<<` operator at `start`; return its spec, if any, and the index after it."""
    if line.startswith("<<<", start):
        return None, start + 3

    idx = start + 2
    strip_tabs = line.startswith("-", idx)
    if strip_tabs:
        idx += 1
    while idx < len(line) and line[idx] in {" ", "\t"}:
        idx += 1

    token: list[str] = []
    quoted = False
    if idx < len(line) and line[idx] in {"'", '"'}:
        end = line.find(line[idx], idx + 1)
        if end == -1:
            # An unterminated quote is not a delimiter; let the scan open it.
            return None, idx
        quoted = True
        token.append(line[idx + 1 : end])
        idx = end + 1
    else:
        while idx < len(line):
            char = line[idx]
            if char in {" ", "\t", "\n", "\r", ";", "|", "&", "<", ">", "(", ")", "`"}:
                break
            if char == "\\" and idx + 1 < len(line):
                idx += 1
                char = line[idx]
            token.append(char)
            idx += 1

    delimiter = "".join(token)
    if not delimiter:
        return None, idx
    return {
        "delimiter": delimiter,
        "quoted": quoted,
        "strip_tabs": strip_tabs,
        "start": start,
        "command_start": owner.start,
        "owner_started_earlier": owner.started_earlier,
        "in_substitution": owner.kind == "substitution",
    }, idx
