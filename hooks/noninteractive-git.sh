#!/bin/bash
# Hook: Block git commands that open interactive editors
# Forces non-interactive alternatives for rebase, commit, merge, cherry-pick, and add
#
# Check if hook is enabled
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "noninteractive-git"

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
[ -z "$command" ] && exit 0

# Helper to output block decision
block() {
    local reason="$1"
    echo "$reason" >&2
    exit 2
}

if ! decision=$(python3 - "$command" <<'PY'
import json
import os
import re
import shlex
import sys

PARSE_ERROR_REASON = (
    "Unable to safely parse command. Refusing potentially interactive git command."
)

CONTROL_TOKENS = {";", "&&", "||", "|", "|&", "&"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
HEREDOC_START = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
SHELL_KEYWORDS = {
    "!",
    "if",
    "then",
    "elif",
    "else",
    "fi",
    "do",
    "done",
    "while",
    "until",
    "for",
    "in",
    "case",
    "esac",
    "{",
    "}",
}
SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}

XARGS_OPTIONS_WITH_VALUE = {
    "-d",
    "-E",
    "-I",
    "-L",
    "-P",
    "-n",
    "-s",
    "--delimiter",
    "--eof",
    "--max-args",
    "--max-chars",
    "--max-procs",
    "--replace",
}
SUDO_OPTIONS_WITH_VALUE = {"-u", "-g", "-h", "-p", "-C", "-T", "-r", "-t"}


def strip_heredoc_bodies(command):
    lines = command.splitlines(keepends=True)
    stripped_lines = []
    delimiter = None

    for line in lines:
        if delimiter is not None:
            if line.strip() == delimiter:
                stripped_lines.append(line)
                delimiter = None
            elif line.endswith("\n"):
                stripped_lines.append("\n")
            else:
                stripped_lines.append("")
            continue

        match = HEREDOC_START.search(line)
        if match is not None:
            delimiter = match.group(2)
        stripped_lines.append(line)

    return "".join(stripped_lines)


def normalize_newlines(command):
    command = strip_heredoc_bodies(command)
    normalized = []
    in_single = False
    in_double = False
    escaped = False

    for char in command:
        if char in ("\n", "\r") and not in_single and not in_double:
            normalized.append(";")
            escaped = False
            continue

        normalized.append(char)

        if escaped:
            escaped = False
            continue

        if char == "\\" and not in_single:
            escaped = True
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            continue

        if char == '"' and not in_single:
            in_double = not in_double

    return "".join(normalized)


def tokenize(command):
    lexer = shlex.shlex(normalize_newlines(command), posix=True, punctuation_chars="|&;")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def split_segments(tokens):
    current = []
    for token in tokens:
        if token in CONTROL_TOKENS:
            if current:
                yield current
                current = []
            continue
        current.append(token)
    if current:
        yield current


def is_assignment(token):
    return ASSIGNMENT.match(token) is not None


def basename(token):
    return os.path.basename(token)


def is_git_exec(token):
    return basename(token) == "git"


def extract_shell_c_command(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in ("-c", "--command"):
            if idx + 1 < len(args):
                return args[idx + 1]
            return None
        if arg.startswith("--command="):
            return arg.split("=", 1)[1]
        if arg == "--":
            return None
        if arg.startswith("-") and not arg.startswith("--"):
            if "c" in arg[1:]:
                if idx + 1 < len(args):
                    return args[idx + 1]
                return None
            idx += 1
            continue
        return None
    return None


def parse_env_wrapped_segment(tokens, inherited_env=None):
    env = dict(inherited_env or {})
    idx = 0

    # Support git commands nested in simple shell structures, e.g.:
    # if git commit; then ...
    while idx < len(tokens) and tokens[idx] in SHELL_KEYWORDS:
        idx += 1

    while idx < len(tokens) and is_assignment(tokens[idx]):
        key, value = tokens[idx].split("=", 1)
        env[key] = value
        idx += 1

    while idx < len(tokens):
        token = basename(tokens[idx])
        if token == "env":
            idx += 1
            while idx < len(tokens):
                env_token = tokens[idx]
                if env_token == "--":
                    idx += 1
                    break
                if is_assignment(env_token):
                    key, value = env_token.split("=", 1)
                    env[key] = value
                    idx += 1
                    continue
                if env_token in ("-i", "--ignore-environment"):
                    idx += 1
                    continue
                if env_token in ("-u", "--unset"):
                    idx += 2
                    continue
                if env_token.startswith("-u") and env_token != "-u":
                    idx += 1
                    continue
                if env_token.startswith("--unset="):
                    idx += 1
                    continue
                if env_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "command":
            idx += 1
            while idx < len(tokens):
                command_token = tokens[idx]
                if command_token == "--":
                    idx += 1
                    break
                if command_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "sudo":
            idx += 1
            while idx < len(tokens):
                sudo_token = tokens[idx]
                if sudo_token == "--":
                    idx += 1
                    break
                if sudo_token in SUDO_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if sudo_token.startswith("--user=") or sudo_token.startswith("--group="):
                    idx += 1
                    continue
                if sudo_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "xargs":
            idx += 1
            while idx < len(tokens):
                xargs_token = tokens[idx]
                if xargs_token == "--":
                    idx += 1
                    break
                if xargs_token in XARGS_OPTIONS_WITH_VALUE:
                    idx += 2
                    continue
                if any(
                    xargs_token.startswith(prefix)
                    for prefix in (
                        "--delimiter=",
                        "--eof=",
                        "--max-args=",
                        "--max-chars=",
                        "--max-procs=",
                        "--replace=",
                    )
                ):
                    idx += 1
                    continue
                if xargs_token.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if token == "find":
            idx += 1
            while idx < len(tokens):
                if tokens[idx] in ("-exec", "-execdir"):
                    idx += 1
                    break
                idx += 1
            continue

        break

    while idx < len(tokens) and tokens[idx] in SHELL_KEYWORDS:
        idx += 1

    if idx >= len(tokens):
        return None

    exec_token = tokens[idx]
    if basename(exec_token) in SHELL_EXECUTABLES:
        nested_command = extract_shell_c_command(tokens[idx + 1 :])
        if nested_command is None:
            return None
        return {
            "env": env,
            "subcmd": "__shell_c__",
            "args": [nested_command],
        }

    if not is_git_exec(exec_token):
        return None

    git_argv = tokens[idx + 1:]
    if not git_argv:
        return None

    return {
        "env": env,
        "subcmd": git_argv[0],
        "args": git_argv[1:],
    }


def parse_git_commands(command, inherited_env=None):
    tokens = tokenize(command)
    parsed_commands = []
    for segment in split_segments(tokens):
        parsed = parse_env_wrapped_segment(segment, inherited_env=inherited_env)
        if parsed is not None:
            parsed_commands.append(parsed)
    return parsed_commands


def has_long_option(args, *names):
    names_set = set(names)
    for arg in args:
        if arg == "--":
            break
        if arg in names_set:
            return True
        if arg.startswith("--"):
            for name in names_set:
                if arg.startswith(name + "="):
                    return True
    return False


def has_short_option(args, *letters):
    wanted = set(letters)
    for arg in args:
        if arg == "--":
            break
        if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
            continue
        for letter in arg[1:]:
            if letter in wanted:
                return True
    return False


def evaluate(parsed_commands, depth=0):
    if depth > 4:
        return PARSE_ERROR_REASON

    for parsed in parsed_commands:
        subcmd = parsed["subcmd"]
        args = parsed["args"]
        env = parsed["env"]

        if subcmd == "__shell_c__":
            try:
                nested_commands = parse_git_commands(args[0], inherited_env=env)
            except ValueError:
                return PARSE_ERROR_REASON
            reason = evaluate(nested_commands, depth=depth + 1)
            if reason is not None:
                return reason
            continue

        if subcmd == "commit":
            has_message_source = (
                has_short_option(args, "m", "F", "C")
                or has_long_option(
                    args,
                    "--message",
                    "--file",
                    "--reuse-message",
                )
                or has_long_option(args, "--no-edit")
            )
            if not has_message_source:
                return "git commit without a message source may open an editor. Use: git commit -m \"your message\" (or --no-edit for amend)"

        elif subcmd == "rebase":
            if has_short_option(args, "i") or has_long_option(args, "--interactive"):
                if "GIT_SEQUENCE_EDITOR" not in env:
                    return "Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ..."
            if has_long_option(args, "--continue"):
                if "GIT_EDITOR" not in env:
                    return "git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue"

        elif subcmd == "add":
            if has_short_option(args, "p", "i") or has_long_option(args, "--patch", "--interactive"):
                return "Interactive git add opens a prompt. Use explicit paths: git add <files>"

        elif subcmd == "merge":
            is_explicitly_safe = has_long_option(
                args,
                "--abort",
                "--quit",
                "--no-edit",
                "--no-commit",
                "--squash",
                "--ff-only",
                "--ff",
            )
            if not is_explicitly_safe:
                return "git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>"

        elif subcmd == "cherry-pick":
            is_explicitly_safe = (
                has_long_option(
                    args,
                    "--continue",
                    "--abort",
                    "--quit",
                    "--skip",
                    "--no-edit",
                    "--no-commit",
                )
                or has_short_option(args, "n")
            )
            if not is_explicitly_safe:
                return "git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>"

    return None


try:
    parsed_commands = parse_git_commands(sys.argv[1])
except ValueError:
    print(json.dumps({"block": PARSE_ERROR_REASON}))
    sys.exit(0)

reason = evaluate(parsed_commands)
print(json.dumps({"block": reason}))
PY
); then
    block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if ! reason=$(echo "$decision" | jq -r '.block // "__ALLOW__"' 2>/dev/null); then
    block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if [ "$reason" != "__ALLOW__" ]; then
    block "$reason"
fi

exit 0
