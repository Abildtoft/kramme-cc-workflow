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

PARSE_ERROR_REASON="Unable to safely parse command. Refusing potentially interactive git command."
COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES="mFCctSu"
COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE="mFCct"
COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE="--author --date --message --file --reuse-message --reedit-message --fixup --squash --cleanup --trailer --pathspec-from-file"
MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES="mFsSX"
MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE="mFsX"
MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE="--message --file --strategy --strategy-option --cleanup --into-name"

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-parse-utils.sh"

token_is_assignment() {
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]
}

is_shell_keyword_token() {
    case "$(strip_wrapping_quotes "$1")" in
        '!'|if|then|elif|else|fi|do|done|while|until|for|in|case|esac|'{'|'}'|'('|')')
            return 0
            ;;
    esac
    return 1
}

args_have_short_option() {
    local wanted="$1"
    shift
    local arg value

    for arg in "$@"; do
        value="$(strip_wrapping_quotes "$arg")"
        [ "$value" = "--" ] && break
        case "$value" in
            --*|-) continue ;;
            -*)
                case "${value#-}" in
                    *"$wanted"*) return 0 ;;
                esac
                ;;
        esac
    done
    return 1
}

args_have_short_option_value_aware() {
    local wanted="$1"
    local options_with_values="$2"
    shift 2
    local arg value short_options idx option

    for arg in "$@"; do
        value="$(strip_wrapping_quotes "$arg")"
        [ "$value" = "--" ] && break
        case "$value" in
            --*|-) continue ;;
            -*)
                short_options="${value#-}"
                for ((idx = 0; idx < ${#short_options}; idx += 1)); do
                    option="${short_options:$idx:1}"
                    if [ "$option" = "$wanted" ]; then
                        return 0
                    fi
                    case "$options_with_values" in
                        *"$option"*)
                            break
                            ;;
                    esac
                done
                ;;
        esac
    done
    return 1
}

short_option_consumes_next_value() {
    local arg="$1"
    local options_with_values="$2"
    local short_options idx option

    case "$arg" in
        --*|-) return 1 ;;
        -*)
            short_options="${arg#-}"
            for ((idx = 0; idx < ${#short_options}; idx += 1)); do
                option="${short_options:$idx:1}"
                case "$options_with_values" in
                    *"$option"*)
                        [ "$idx" -eq "$((${#short_options} - 1))" ]
                        return
                        ;;
                esac
            done
            ;;
    esac
    return 1
}

args_have_long_option_value_aware() {
    local wanted="$1"
    local short_options_with_values="$2"
    local long_options_with_values="$3"
    shift 3
    local arg value skip_next=false

    for arg in "$@"; do
        value="$(strip_wrapping_quotes "$arg")"
        if [ "$skip_next" = "true" ]; then
            skip_next=false
            continue
        fi
        [ "$value" = "--" ] && break
        [ "$value" = "$wanted" ] && return 0
        case "$value" in
            "$wanted"=*) return 0 ;;
        esac
        if short_option_consumes_next_value "$value" "$short_options_with_values"; then
            skip_next=true
            continue
        fi
        case " $long_options_with_values " in
            *" $value "*)
                skip_next=true
                ;;
        esac
    done
    return 1
}

args_have_long_option() {
    local wanted="$1"
    shift
    local arg value

    for arg in "$@"; do
        value="$(strip_wrapping_quotes "$arg")"
        [ "$value" = "--" ] && break
        [ "$value" = "$wanted" ] && return 0
        case "$value" in
            "$wanted"=*) return 0 ;;
        esac
    done
    return 1
}

fixup_value_is_interactive() {
    case "$1" in
        amend:*|reword:*)
            return 0
            ;;
    esac
    return 1
}

classify_commit_fixup() {
    local arg value skip_next=false expecting_fixup_value=false

    for arg in "$@"; do
        value="$(strip_wrapping_quotes "$arg")"
        if [ "$expecting_fixup_value" = "true" ]; then
            if fixup_value_is_interactive "$value"; then
                printf 'interactive\n'
            else
                printf 'safe\n'
            fi
            return
        fi
        if [ "$skip_next" = "true" ]; then
            skip_next=false
            continue
        fi
        [ "$value" = "--" ] && break
        case "$value" in
            --fixup)
                expecting_fixup_value=true
                continue
                ;;
            --fixup=*)
                if fixup_value_is_interactive "${value#*=}"; then
                    printf 'interactive\n'
                else
                    printf 'safe\n'
                fi
                return
                ;;
        esac
        if short_option_consumes_next_value "$value" "$COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE"; then
            skip_next=true
            continue
        fi
        case " $COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE " in
            *" $value "*)
                skip_next=true
                ;;
        esac
    done

    printf 'none\n'
}

merge_edit_is_safe() {
    args_have_long_option "--ff-only" "$@" && ! args_have_long_option "--no-ff" "$@"
}

commit_has_message_source() {
    local commit_fixup_mode="$1"
    shift
    commit_requests_editor "$@" && return 1
    args_have_short_option_value_aware "m" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
        || args_have_short_option_value_aware "F" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
        || args_have_short_option_value_aware "C" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
        || commit_has_safe_fixup "$@" \
        || args_have_long_option "--message" "$@" \
        || args_have_long_option "--file" "$@" \
        || [ "$commit_fixup_mode" = "safe" ] \
        || args_have_long_option "--reuse-message" "$@" \
        || args_have_long_option "--no-edit" "$@"
}

merge_has_message_source() {
    args_have_short_option_value_aware "m" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
        || args_have_short_option_value_aware "F" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" \
        || args_have_long_option "--message" "$@" \
        || args_have_long_option "--file" "$@"
}

commit_requests_editor() {
    local value short_options short_name consume_next

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        [ "$value" = "--" ] && break

        consume_next=0
        case "$value" in
            --edit|--reedit-message|--reedit-message=*)
                return 0
                ;;
            --message|--file|--reuse-message|--fixup)
                consume_next=1
                ;;
            --message=*|--file=*|--reuse-message=*|--fixup=*)
                ;;
            -[!-]*)
                short_options="${value#-}"
                while [ -n "$short_options" ]; do
                    short_name="${short_options%"${short_options#?}"}"
                    short_options="${short_options#?}"
                    case "$short_name" in
                        e|c)
                            return 0
                            ;;
                        m|F|C)
                            [ -z "$short_options" ] && consume_next=1
                            short_options=""
                            ;;
                    esac
                done
                ;;
        esac

        shift
        [ "$consume_next" -eq 1 ] && [ $# -gt 0 ] && shift
    done

    return 1
}

commit_has_safe_fixup() {
    local value target

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        [ "$value" = "--" ] && break
        case "$value" in
            --fixup)
                shift
                [ $# -gt 0 ] || return 1
                target="$(strip_wrapping_quotes "$1")"
                case "$target" in
                    amend:*|reword:*)
                        return 1
                        ;;
                    *)
                        return 0
                        ;;
                esac
                ;;
            --fixup=*)
                target="${value#*=}"
                case "$target" in
                    amend:*|reword:*)
                        return 1
                        ;;
                    *)
                        return 0
                        ;;
                esac
                ;;
        esac
        shift
    done
    return 1
}

extract_shell_inline_command() {
    local value

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
            --)
                return 1
                ;;
            -c|--command)
                shift
                [ $# -gt 0 ] || return 1
                printf '%s\n' "$(strip_wrapping_quotes "$1")"
                return 0
                ;;
            --command=*)
                printf '%s\n' "${value#*=}"
                return 0
                ;;
            --rcfile|--init-file|--startup-file|-o|-O|+O)
                shift
                [ $# -gt 0 ] && shift
                ;;
            --rcfile=*|--init-file=*|--startup-file=*)
                shift
                ;;
            --*)
                shift
                ;;
            -*)
                case "${value#-}" in
                    *c*)
                        shift
                        [ $# -gt 0 ] || return 1
                        printf '%s\n' "$(strip_wrapping_quotes "$1")"
                        return 0
                        ;;
                esac
                shift
                ;;
            +*)
                shift
                ;;
            *)
                return 1
                ;;
        esac
    done
    return 1
}

record_git_editor_env() {
    local assignment="$1"
    local key="${assignment%%=*}"

    case "$key" in
        GIT_EDITOR)
            has_git_editor=true
            ;;
        GIT_SEQUENCE_EDITOR)
            has_git_sequence_editor=true
            ;;
    esac
}

unset_git_editor_env() {
    case "$1" in
        GIT_EDITOR)
            has_git_editor=false
            ;;
        GIT_SEQUENCE_EDITOR)
            has_git_sequence_editor=false
            ;;
    esac
}

clear_git_editor_env() {
    has_git_editor=false
    has_git_sequence_editor=false
}

evaluate_find_exec_segments() {
    local value reason
    local exec_segment=()

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
            -exec|-execdir)
                shift
                exec_segment=()
                while [ $# -gt 0 ]; do
                    value="$(strip_wrapping_quotes "$1")"
                    case "$value" in
                        ';'|'+')
                            break
                            ;;
                    esac
                    exec_segment+=("$1")
                    shift
                done
                reason="$(evaluate_simple_git_segment "${exec_segment[@]}")"
                if [ "$reason" != "__ALLOW__" ]; then
                    printf '%s\n' "$reason"
                    return
                fi
                ;;
        esac
        shift
    done

    printf '__ALLOW__\n'
}

evaluate_simple_git_segment() {
    local token base value subcmd inline_command reason
    local has_git_editor=false
    local has_git_sequence_editor=false

    [ $# -eq 0 ] && {
        printf '__ALLOW__\n'
        return
    }

    while [ $# -gt 0 ] && is_shell_keyword_token "$1"; do
        shift
    done

    while [ $# -gt 0 ] && token_is_assignment "$(strip_wrapping_quotes "$1")"; do
        record_git_editor_env "$(strip_wrapping_quotes "$1")"
        shift
    done

    while [ $# -gt 0 ]; do
        token="$1"
        base="$(token_basename "$token")"
        case "$base" in
            env)
                shift
                while [ $# -gt 0 ]; do
                    value="$(strip_wrapping_quotes "$1")"
                    case "$value" in
                        --)
                            shift
                            break
                            ;;
                        [A-Za-z_][A-Za-z0-9_]*=*)
                            record_git_editor_env "$value"
                            shift
                            ;;
                        -i|--ignore-environment)
                            clear_git_editor_env
                            shift
                            ;;
                        -u|--unset)
                            shift
                            if [ $# -gt 0 ]; then
                                unset_git_editor_env "$(strip_wrapping_quotes "$1")"
                                shift
                            fi
                            ;;
                        --unset=*)
                            unset_git_editor_env "$(strip_wrapping_quotes "${value#*=}")"
                            shift
                            ;;
                        -u*)
                            unset_git_editor_env "$(strip_wrapping_quotes "${value#-u}")"
                            shift
                            ;;
                        -C|--chdir)
                            if [ $# -ge 2 ]; then
                                shift 2
                            else
                                shift
                            fi
                            ;;
                        --chdir=*|-C*)
                            shift
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            command)
                shift
                while [ $# -gt 0 ]; do
                    value="$(strip_wrapping_quotes "$1")"
                    case "$value" in
                        --)
                            shift
                            break
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            sudo)
                shift
                while [ $# -gt 0 ]; do
                    value="$(strip_wrapping_quotes "$1")"
                    case "$value" in
                        --)
                            shift
                            break
                            ;;
                        -u|-[ugpCRTtrh])
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --user|--group|--host|--prompt|--command-timeout|--close-from|--chdir|--role|--type|--other-user)
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --askpass|--background|--preserve-env|--remove-timestamp|--reset-timestamp|--validate|--version|--list|--non-interactive)
                            shift
                            ;;
                        --host=*|--user=*|--group=*|--prompt=*|--command-timeout=*|--close-from=*|--chdir=*|--role=*|--type=*|--other-user=*|--preserve-env=*)
                            shift
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            xargs)
                shift
                while [ $# -gt 0 ]; do
                    value="$(strip_wrapping_quotes "$1")"
                    case "$value" in
                        --)
                            shift
                            break
                            ;;
                        -d|-E|-I|-L|-P|-n|-s|--delimiter|--eof|--max-args|--max-chars|--max-procs|--replace)
                            shift
                            [ $# -gt 0 ] && shift
                            ;;
                        --delimiter=*|--eof=*|--max-args=*|--max-chars=*|--max-procs=*|--replace=*)
                            shift
                            ;;
                        -*)
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            find)
                reason="$(evaluate_find_exec_segments "$@")"
                printf '%s\n' "$reason"
                return
                ;;
            -exec|-execdir)
                shift
                ;;
            sh|bash|zsh|dash|ksh)
                shift
                if inline_command="$(extract_shell_inline_command "$@")"; then
                    if [ "$(fallback_noninteractive_reason "$inline_command")" != "__ALLOW__" ]; then
                        printf '%s\n' "$PARSE_ERROR_REASON"
                        return
                    fi
                fi
                printf '__ALLOW__\n'
                return
                ;;
            git)
                shift
                break
                ;;
            *)
                printf '__ALLOW__\n'
                return
                ;;
        esac
    done

    while [ $# -gt 0 ]; do
        value="$(strip_wrapping_quotes "$1")"
        case "$value" in
            --)
                shift
                break
                ;;
            -C|-c|--config-env|--exec-path|--git-dir|--namespace|--super-prefix|--work-tree)
                if [ $# -ge 2 ]; then
                    shift 2
                else
                    shift
                fi
                ;;
            --config-env=*|--exec-path=*|--git-dir=*|--namespace=*|--super-prefix=*|--work-tree=*|-C*|-c*)
                shift
                ;;
            -*)
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -eq 0 ]; then
        printf '__ALLOW__\n'
        return
    fi

    subcmd="$(strip_wrapping_quotes "$1")"
    shift

    case "$subcmd" in
        commit)
            local commit_fixup_mode has_no_edit=false

            if args_have_short_option_value_aware "e" "$COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" || args_have_long_option_value_aware "--edit" "$COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE" "$COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE" "$@"; then
                printf '%s\n' 'git commit --edit opens an editor. Remove --edit to keep the commit non-interactive.'
                return
            fi
            commit_fixup_mode="$(classify_commit_fixup "$@")"
            if args_have_long_option "--no-edit" "$@"; then
                has_no_edit=true
            fi
            if [ "$commit_fixup_mode" = "interactive" ] && [ "$has_no_edit" != "true" ]; then
                printf '%s\n' 'git commit --fixup=amend:<commit> and --fixup=reword:<commit> open an editor unless you also pass --no-edit.'
                return
            fi
            if ! commit_has_message_source "$commit_fixup_mode" "$@"; then
                printf '%s\n' 'git commit without a message source may open an editor. Use: git commit -m "your message" (or --no-edit for amend)'
                return
            fi
            ;;
        rebase)
            if (args_have_short_option "i" "$@" || args_have_long_option "--interactive" "$@") && [ "$has_git_sequence_editor" != "true" ]; then
                printf '%s\n' 'Interactive rebase will open an editor. Use: GIT_SEQUENCE_EDITOR=true git rebase -i ...'
                return
            fi
            if args_have_long_option "--continue" "$@" && [ "$has_git_editor" != "true" ]; then
                printf '%s\n' 'git rebase --continue may open an editor. Use: GIT_EDITOR=true git rebase --continue'
                return
            fi
            ;;
        add)
            if args_have_short_option "p" "$@" || args_have_short_option "i" "$@" || args_have_long_option "--patch" "$@" || args_have_long_option "--interactive" "$@"; then
                printf '%s\n' 'Interactive git add opens a prompt. Use explicit paths: git add <files>'
                return
            fi
            ;;
        merge)
            if (args_have_short_option_value_aware "e" "$MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES" "$@" || args_have_long_option_value_aware "--edit" "$MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE" "$MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE" "$@") && ! merge_edit_is_safe "$@"; then
                printf '%s\n' 'git merge --edit opens an editor. Remove --edit to keep the merge non-interactive.'
                return
            fi
            if ! (args_have_long_option "--abort" "$@" || args_have_long_option "--quit" "$@" || args_have_long_option "--no-edit" "$@" || args_have_long_option "--no-commit" "$@" || args_have_long_option "--squash" "$@" || args_have_long_option "--ff-only" "$@" || args_have_long_option "--ff" "$@" || merge_has_message_source "$@"); then
                printf '%s\n' 'git merge may open an editor for the merge commit message. Use: git merge --no-edit <branch>'
                return
            fi
            ;;
        cherry-pick)
            if ! (args_have_long_option "--continue" "$@" || args_have_long_option "--abort" "$@" || args_have_long_option "--quit" "$@" || args_have_long_option "--skip" "$@" || args_have_long_option "--no-edit" "$@" || args_have_long_option "--no-commit" "$@" || args_have_short_option "n" "$@"); then
                printf '%s\n' 'git cherry-pick may open an editor. Use: git cherry-pick --no-edit <commit>'
                return
            fi
            ;;
    esac

    printf '__ALLOW__\n'
}

fallback_noninteractive_reason() {
    local raw_command="$1"
    local token_json token_type token_value reason substitution
    local segment=()
    local sanitized_command
    local substitutions=()

    if ! replace_command_substitutions "$raw_command"; then
        printf '%s\n' "$PARSE_ERROR_REASON"
        return
    fi

    sanitized_command="$SANITIZED_COMMAND"
    substitutions=("${COMMAND_SUBSTITUTIONS[@]}")

    for substitution in "${substitutions[@]}"; do
        reason="$(fallback_noninteractive_reason "$substitution")"
        if [ "$reason" != "__ALLOW__" ]; then
            printf '%s\n' "$reason"
            return
        fi
    done

    local tokenized
    if ! tokenized="$(shell_tokenize "$sanitized_command" true)"; then
        printf '%s\n' "$PARSE_ERROR_REASON"
        return
    fi

    while IFS= read -r token_json; do
        [ -z "$token_json" ] && continue
        token_type="$(printf '%s\n' "$token_json" | jq -r '.type')"
        token_value="$(printf '%s\n' "$token_json" | jq -r '.value')"
        if [ "$token_type" = "control" ]; then
            reason="$(evaluate_simple_git_segment "${segment[@]}")"
            if [ "$reason" != "__ALLOW__" ]; then
                printf '%s\n' "$reason"
                return
            fi
            segment=()
            continue
        fi
        segment+=("$token_value")
    done <<EOF
$tokenized
EOF

    evaluate_simple_git_segment "${segment[@]}"
}

# If python3 is unavailable, fall back to a conservative shell parser.
if ! command -v python3 >/dev/null 2>&1; then
    reason="$(fallback_noninteractive_reason "$command")"
    if [ "$reason" = "__ALLOW__" ]; then
        exit 0
    fi
    block "$reason"
fi

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
    "(",
    ")",
}
SHELL_EXECUTABLES = {"sh", "bash", "zsh", "dash", "ksh"}
SHELL_OPTIONS_WITH_VALUE = {"--command", "--rcfile", "--init-file", "--startup-file", "-o", "-O", "+O"}

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
GIT_OPTIONS_WITH_VALUE = {
    "-C",
    "-c",
    "--config-env",
    "--exec-path",
    "--git-dir",
    "--namespace",
    "--super-prefix",
    "--work-tree",
}


def _extract_body_substitutions(line):
    # Collect $(...) / `...` contents from an unquoted heredoc body line.
    # Mirrors the bash extract_body_substitutions helper.
    subs = []
    idx = 0
    length = len(line)
    while idx < length:
        ch = line[idx]
        if ch == "$" and idx + 1 < length and line[idx + 1] == "(":
            inner, idx = read_dollar_substitution(line, idx)
            subs.append(inner)
            continue
        if ch == chr(96):
            inner, idx = read_backtick_substitution(line, idx)
            subs.append(inner)
            continue
        idx += 1
    return subs


def strip_heredoc_bodies(command):
    lines = command.splitlines(keepends=True)
    stripped_lines = []
    delimiter = None
    is_quoted = False
    is_dashed = False
    extracted = []

    for line in lines:
        if delimiter is not None:
            compare = line[:-1] if line.endswith("\n") else line
            if is_dashed:
                # POSIX: <<- strips leading TABs only (never spaces).
                compare = compare.lstrip("\t")
            if compare == delimiter:
                stripped_lines.append(line)
                delimiter = None
                is_quoted = False
                is_dashed = False
                continue
            if not is_quoted:
                # Unquoted heredoc bodies still expand $(...) and `...`.
                body_line = line[:-1] if line.endswith("\n") else line
                extracted.extend(_extract_body_substitutions(body_line))
            if line.endswith("\n"):
                stripped_lines.append("\n")
            else:
                stripped_lines.append("")
            continue

        match = HEREDOC_START.search(line)
        if match is not None:
            delimiter = match.group(2)
            is_quoted = match.group(1) != ""
            is_dashed = match.group(0).startswith("<<-")
        stripped_lines.append(line)

    return "".join(stripped_lines), extracted


def normalize_newlines(command):
    command, _ = strip_heredoc_bodies(command)
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
    lexer = shlex.shlex(normalize_newlines(command), posix=True, punctuation_chars="()|&;")
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


def read_dollar_substitution(command, start):
    inner = []
    depth = 1
    idx = start + 2
    in_single = False
    in_double = False
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            inner.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\" and not in_single:
            inner.append(char)
            escaped = True
            idx += 1
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            inner.append(char)
            idx += 1
            continue

        if char == '"' and not in_single:
            in_double = not in_double
            inner.append(char)
            idx += 1
            continue

        if not in_single and not in_double and command.startswith("$" + "(", idx):
            nested_inner, idx = read_dollar_substitution(command, idx)
            inner.append("$" + "(" + nested_inner + ")")
            continue

        if not in_single and not in_double and char == ")":
            depth -= 1
            if depth == 0:
                return "".join(inner), idx + 1

        inner.append(char)
        idx += 1

    raise ValueError("Unterminated command substitution.")


def read_backtick_substitution(command, start):
    inner = []
    idx = start + 1
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            inner.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\":
            inner.append(char)
            escaped = True
            idx += 1
            continue

        if char == chr(96):
            return "".join(inner), idx + 1

        inner.append(char)
        idx += 1

    raise ValueError("Unterminated backtick command substitution.")


def replace_command_substitutions(command):
    command, heredoc_body_substitutions = strip_heredoc_bodies(command)
    # Start with any substitutions extracted from unquoted heredoc
    # bodies — they're still executed by the shell and need inspection.
    substitutions = list(heredoc_body_substitutions)
    result = []
    idx = 0
    in_single = False
    in_double = False
    escaped = False

    while idx < len(command):
        char = command[idx]

        if escaped:
            result.append(char)
            escaped = False
            idx += 1
            continue

        if char == "\\" and not in_single:
            result.append(char)
            escaped = True
            idx += 1
            continue

        if char == "'" and not in_double:
            in_single = not in_single
            result.append(char)
            idx += 1
            continue

        if char == '"' and not in_single:
            in_double = not in_double
            result.append(char)
            idx += 1
            continue

        if not in_single and command.startswith("$" + "(", idx):
            inner, idx = read_dollar_substitution(command, idx)
            substitutions.append(inner)
            result.append(f"__CMD_SUBST_{len(substitutions) - 1}__")
            continue

        if not in_single and char == chr(96):
            inner, idx = read_backtick_substitution(command, idx)
            substitutions.append(inner)
            result.append(f"__CMD_SUBST_{len(substitutions) - 1}__")
            continue

        result.append(char)
        idx += 1

    return "".join(result), substitutions


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
        if arg in SHELL_OPTIONS_WITH_VALUE:
            idx += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in ("--rcfile", "--init-file", "--startup-file")):
            idx += 1
            continue
        if arg == "--":
            return None
        if arg.startswith("-") and not arg.startswith("--"):
            if "c" in arg[1:]:
                if idx + 1 < len(args):
                    return args[idx + 1]
                return None
            idx += 1
            continue
        if arg.startswith("+"):
            idx += 1
            continue
        return None
    return None


def clear_editor_env(env):
    env.pop("GIT_EDITOR", None)
    env.pop("GIT_SEQUENCE_EDITOR", None)


def unset_editor_env(env, key):
    if key in {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR"}:
        env.pop(key, None)


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
                    clear_editor_env(env)
                    idx += 1
                    continue
                if env_token in ("-u", "--unset"):
                    if idx + 1 < len(tokens):
                        unset_editor_env(env, tokens[idx + 1])
                    idx += 2
                    continue
                if env_token.startswith("-u") and env_token != "-u":
                    unset_editor_env(env, env_token[2:])
                    idx += 1
                    continue
                if env_token.startswith("--unset="):
                    unset_editor_env(env, env_token.split("=", 1)[1])
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
                if sudo_token in {
                    "--user",
                    "--group",
                    "--host",
                    "--prompt",
                    "--command-timeout",
                    "--close-from",
                    "--chdir",
                    "--role",
                    "--type",
                    "--other-user",
                }:
                    idx += 2
                    continue
                if sudo_token.startswith("--user=") or sudo_token.startswith("--group="):
                    idx += 1
                    continue
                if any(
                    sudo_token.startswith(prefix + "=")
                    for prefix in (
                        "--host",
                        "--prompt",
                        "--command-timeout",
                        "--close-from",
                        "--chdir",
                        "--role",
                        "--type",
                        "--other-user",
                    )
                ):
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

        if tokens[idx] in ("-exec", "-execdir"):
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

    git_idx = 0
    while git_idx < len(git_argv):
        token = git_argv[git_idx]
        if token == "--":
            git_idx += 1
            break
        if token in GIT_OPTIONS_WITH_VALUE:
            git_idx += 2
            continue
        if any(
            token.startswith(prefix + "=")
            for prefix in (
                "--config-env",
                "--exec-path",
                "--git-dir",
                "--namespace",
                "--super-prefix",
                "--work-tree",
            )
        ):
            git_idx += 1
            continue
        if token.startswith("-C") and token != "-C":
            git_idx += 1
            continue
        if token.startswith("-c") and token != "-c":
            git_idx += 1
            continue
        if token.startswith("-"):
            git_idx += 1
            continue
        break

    if git_idx >= len(git_argv):
        return None

    return {
        "env": env,
        "subcmd": git_argv[git_idx],
        "args": git_argv[git_idx + 1 :],
    }


def parse_git_commands(command, inherited_env=None):
    sanitized_command, substitutions = replace_command_substitutions(command)
    tokens = tokenize(sanitized_command)
    parsed_commands = []
    for segment in split_segments(tokens):
        parsed = parse_env_wrapped_segment(segment, inherited_env=inherited_env)
        if parsed is not None:
            parsed_commands.append(parsed)
    return parsed_commands, substitutions


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


def fixup_value_is_interactive(value):
    return value.startswith("amend:") or value.startswith("reword:")


def classify_commit_fixup(args):
    skip_next = False
    expecting_fixup_value = False
    for arg in args:
        if expecting_fixup_value:
            return "interactive" if fixup_value_is_interactive(arg) else "safe"
        if skip_next:
            skip_next = False
            continue
        if arg == "--":
            break
        if arg == "--fixup":
            expecting_fixup_value = True
            continue
        if arg.startswith("--fixup="):
            return "interactive" if fixup_value_is_interactive(arg.split("=", 1)[1]) else "safe"
        if short_option_consumes_next_value(arg, COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE):
            skip_next = True
            continue
        if arg in COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE:
            skip_next = True
    return "none"


def merge_edit_is_safe(args):
    return has_long_option(args, "--ff-only") and not has_long_option(args, "--no-ff")


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


COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES = set("mFCctSu")
COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE = set("mFCct")
COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE = {
    "--author",
    "--date",
    "--message",
    "--file",
    "--reuse-message",
    "--reedit-message",
    "--fixup",
    "--squash",
    "--cleanup",
    "--trailer",
    "--pathspec-from-file",
}
MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES = set("mFsSX")
MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE = set("mFsX")
MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE = {
    "--message",
    "--file",
    "--strategy",
    "--strategy-option",
    "--cleanup",
    "--into-name",
}


def has_short_option_value_aware(args, wanted, options_with_values):
    for arg in args:
        if arg == "--":
            break
        if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
            continue
        for letter in arg[1:]:
            if letter == wanted:
                return True
            if letter in options_with_values:
                break
    return False


def short_option_consumes_next_value(arg, options_with_values):
    if not arg.startswith("-") or arg == "-" or arg.startswith("--"):
        return False
    letters = arg[1:]
    for idx, letter in enumerate(letters):
        if letter in options_with_values:
            return idx == len(letters) - 1
    return False


def has_long_option_value_aware(
    args, wanted, short_options_with_values, long_options_with_values
):
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
            continue
        if arg == "--":
            break
        if arg == wanted or arg.startswith(wanted + "="):
            return True
        if short_option_consumes_next_value(arg, short_options_with_values):
            skip_next = True
            continue
        if arg in long_options_with_values:
            skip_next = True
    return False


def has_safe_fixup(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg == "--":
            break
        if arg == "--fixup":
            if idx + 1 >= len(args):
                return False
            return not args[idx + 1].startswith(("amend:", "reword:"))
        if arg.startswith("--fixup="):
            return not arg.split("=", 1)[1].startswith(("amend:", "reword:"))
        idx += 1
    return False


def commit_requests_editor(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg == "--":
            break
        if arg in ("--edit", "--reedit-message") or arg.startswith("--reedit-message="):
            return True
        if arg in ("--message", "--file", "--reuse-message", "--fixup"):
            idx += 2
            continue
        if arg.startswith(("--message=", "--file=", "--reuse-message=", "--fixup=")):
            idx += 1
            continue
        if arg.startswith("-") and arg != "-" and not arg.startswith("--"):
            cluster = arg[1:]
            consume_next = False
            for pos, letter in enumerate(cluster):
                if letter in ("e", "c"):
                    return True
                if letter in ("m", "F", "C"):
                    consume_next = pos == len(cluster) - 1
                    break
            idx += 2 if consume_next else 1
            continue
        idx += 1
    return False


def evaluate(parsed_commands, substitutions, depth=0):
    if depth > 4:
        return PARSE_ERROR_REASON

    for substitution in substitutions:
        try:
            nested_commands, nested_substitutions = parse_git_commands(substitution)
        except ValueError:
            return PARSE_ERROR_REASON
        reason = evaluate(nested_commands, nested_substitutions, depth=depth + 1)
        if reason is not None:
            return reason

    for parsed in parsed_commands:
        subcmd = parsed["subcmd"]
        args = parsed["args"]
        env = parsed["env"]

        if subcmd == "__shell_c__":
            try:
                nested_commands, nested_substitutions = parse_git_commands(args[0], inherited_env=env)
            except ValueError:
                return PARSE_ERROR_REASON
            reason = evaluate(nested_commands, nested_substitutions, depth=depth + 1)
            if reason is not None:
                return reason
            continue

        if subcmd == "commit":
            if has_short_option_value_aware(args, "e", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES) or has_long_option_value_aware(
                args,
                "--edit",
                COMMIT_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                COMMIT_LONG_OPTIONS_CONSUME_NEXT_VALUE,
            ):
                return "git commit --edit opens an editor. Remove --edit to keep the commit non-interactive."
            commit_fixup_mode = classify_commit_fixup(args)
            has_no_edit = has_long_option(args, "--no-edit")
            if commit_fixup_mode == "interactive" and not has_no_edit:
                return "git commit --fixup=amend:<commit> and --fixup=reword:<commit> open an editor unless you also pass --no-edit."
            has_message_source = (
                not commit_requests_editor(args)
                and (
                    has_short_option_value_aware(args, "m", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    or has_short_option_value_aware(args, "F", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    or has_short_option_value_aware(args, "C", COMMIT_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    or has_safe_fixup(args)
                    or has_long_option(args, "--message", "--file", "--reuse-message")
                    or commit_fixup_mode == "safe"
                    or has_long_option(args, "--no-edit")
                )
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
            if (
                has_short_option_value_aware(args, "e", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                or has_long_option_value_aware(
                    args,
                    "--edit",
                    MERGE_SHORT_OPTIONS_CONSUME_NEXT_VALUE,
                    MERGE_LONG_OPTIONS_CONSUME_NEXT_VALUE,
                )
            ) and not merge_edit_is_safe(args):
                return "git merge --edit opens an editor. Remove --edit to keep the merge non-interactive."
            is_explicitly_safe = has_long_option(
                args,
                "--abort",
                "--quit",
                "--no-edit",
                "--no-commit",
                "--squash",
                "--ff-only",
                "--ff",
                "--message",
                "--file",
            )
            if not is_explicitly_safe:
                is_explicitly_safe = (
                    has_short_option_value_aware(args, "m", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
                    or has_short_option_value_aware(args, "F", MERGE_SHORT_OPTIONS_WITH_ATTACHED_VALUES)
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
    parsed_commands, substitutions = parse_git_commands(sys.argv[1])
except ValueError:
    print(json.dumps({"block": PARSE_ERROR_REASON}))
    sys.exit(0)

reason = evaluate(parsed_commands, substitutions)
print(json.dumps({"block": reason}))
PY
); then
    block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if ! reason=$(echo "$decision" | jq -r '.block // "__ALLOW__"'); then
    block "Unable to safely parse command metadata. Refusing potentially interactive git command."
fi

if [ "$reason" != "__ALLOW__" ]; then
    block "$reason"
fi

exit 0
