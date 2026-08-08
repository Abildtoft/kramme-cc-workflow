"""Cross-mode option vocabularies for the commands the gates must see through.

These tables are not shell grammar: they describe how `xargs` and `git`
consume their own options. Every mode resolves them through this module so a
given prefix can never mean different things to different gates.
"""

from __future__ import annotations

# Shared by the noninteractive and rm-rf modes. Both walk past xargs's own
# options to find the command xargs will invoke. Only options whose value is
# a *mandatory separate token* belong here, because membership means "skip
# the next token too". Both directions of error hide the real command from
# either gate: omitting `-a FILE` makes the walker read FILE as the invoked
# command, while listing an option that takes no separate token makes it
# skip past the command itself. The set spans both implementations, since
# either can be the xargs on PATH: `-J`, `-R`, and `-S` are BSD-only,
# `--arg-file` and `--process-slot-var` GNU-only.
#
# Options taking an optional, attached-only value must therefore stay out
# (GNU `-i[replace-str]`, `--replace[=str]`, `--eof[=str]`,
# `--max-lines[=n]`, `-e[eof-str]`, `-l[max-lines]`): in `xargs -i git
# commit` the next token is the command, so the generic leading-dash branch
# in _skip_xargs_options handles them correctly. Their mandatory-value
# counterparts `-I`, `-E`, and `-L` do belong here.
XARGS_OPTIONS_WITH_VALUE = {
    "-a",
    "-d",
    "-E",
    "-I",
    "-J",
    "-L",
    "-P",
    "-R",
    "-S",
    "-n",
    "-s",
    "--arg-file",
    "--delimiter",
    "--max-args",
    "--max-chars",
    "--max-procs",
    "--process-slot-var",
}


def _skip_xargs_options(args: list[str]) -> int:
    """Return the index of the command xargs will invoke, past its own options.

    Attached-value forms (`-n5`, `--max-args=5`, `-i{}`) need no entry of
    their own: they start with a dash and consume no separate token, so the
    generic leading-dash branch already advances past them correctly.
    """
    idx = 0
    while idx < len(args):
        token = args[idx]
        if token == "--":
            idx += 1
            break
        if token in XARGS_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if token.startswith("-"):
            idx += 1
            continue
        break
    return idx


# Git global options that consume the following token as their value. Both
# parser modes share this compatibility vocabulary: a mode that
# misses one of these mistakes the option's value for the subcommand, which
# hides the real subcommand from the safety gates.
#
# `--exec-path` without an attached value makes Git print its exec path and
# exit, so consuming the next token is a safe over-approximation — no
# subcommand runs either way, and both modes have always agreed on it.
# `--super-prefix` was value-bearing through Git 2.39. Keep consuming it for
# compatibility; newer Git rejects it before executing a subcommand.
GIT_GLOBAL_OPTIONS_WITH_VALUE = frozenset(
    {
        "-C",
        "-c",
        "--attr-source",
        "--config-env",
        "--exec-path",
        "--git-dir",
        "--namespace",
        "--shallow-file",
        "--super-prefix",
        "--work-tree",
    }
)
# Git global long options that never consume a following token. Any other
# unresolved long option before the subcommand is ambiguous: we cannot know
# whether the next token is its value or the subcommand, so both modes fail
# closed instead of guessing.
GIT_GLOBAL_VALUELESS_LONG_OPTIONS = frozenset(
    {
        "--bare",
        "--glob-pathspecs",
        "--help",
        "--html-path",
        "--icase-pathspecs",
        "--info-path",
        "--literal-pathspecs",
        "--man-path",
        "--no-advice",
        "--no-lazy-fetch",
        "--no-literal-pathspecs",
        "--no-optional-locks",
        "--no-pager",
        "--no-replace-objects",
        "--noglob-pathspecs",
        "--paginate",
        "--version",
    }
)

GIT_GLOBAL_END_OF_OPTIONS = "end"
GIT_GLOBAL_OPTION_WITH_VALUE = "value"
GIT_GLOBAL_OPTION_FLAG = "flag"
GIT_GLOBAL_OPTION_AMBIGUOUS = "ambiguous"
GIT_GLOBAL_SUBCOMMAND = "subcommand"


def classify_git_global_option(token: str) -> str:
    """Classify a token sitting between `git` and its subcommand.

    Both parser modes walk Git's global options through this classifier so a
    given prefix can never resolve to a different subcommand depending on which
    gate is asking.
    """
    if token == "--":
        return GIT_GLOBAL_END_OF_OPTIONS
    if token in GIT_GLOBAL_OPTIONS_WITH_VALUE:
        return GIT_GLOBAL_OPTION_WITH_VALUE
    if not token.startswith("-"):
        return GIT_GLOBAL_SUBCOMMAND
    if token.startswith("--"):
        # An attached value is self-contained, so no following token is at risk
        # even when the option itself is unknown to us.
        if "=" in token:
            return GIT_GLOBAL_OPTION_FLAG
        if token in GIT_GLOBAL_VALUELESS_LONG_OPTIONS:
            return GIT_GLOBAL_OPTION_FLAG
        return GIT_GLOBAL_OPTION_AMBIGUOUS
    # Short globals either stand alone (`-p`) or carry an attached value
    # (`-Crepo`, `-ccore.pager=cat`); the separated forms are matched above.
    return GIT_GLOBAL_OPTION_FLAG
