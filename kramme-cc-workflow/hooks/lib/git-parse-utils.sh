#!/bin/bash
# Shared git command parsing utilities used by noninteractive-git.sh
# and confirm-review-responses.sh hooks.

strip_wrapping_quotes() {
    local value="$1"
    case "$value" in
        \"*\")
            value="${value#\"}"
            value="${value%\"}"
            ;;
        \'*\')
            value="${value#\'}"
            value="${value%\'}"
            ;;
    esac
    printf '%s\n' "$value"
}

token_basename() {
    local value
    value="$(strip_wrapping_quotes "$1")"
    printf '%s\n' "${value##*/}"
}

trim_ascii_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

extract_body_substitutions() {
    # Scan a line for $(...) and `...` substitutions and append them to
    # HEREDOC_BODY_SUBSTITUTIONS. Used for unquoted heredoc bodies, where
    # the shell still performs command substitution.
    local line="$1"
    local length="${#line}"
    local idx=0
    local char

    while [ "$idx" -lt "$length" ]; do
        char="${line:$idx:1}"
        if [ "$char" = '$' ] && [ $((idx + 1)) -lt "$length" ] \
            && [ "${line:$((idx + 1)):1}" = '(' ]; then
            if [ $((idx + 2)) -lt "$length" ] && [ "${line:$((idx + 2)):1}" = "(" ]; then
                collect_arithmetic_substitutions "$line" "$idx" || return 1
                if [ "${#ARITHMETIC_SUBSTITUTIONS[@]}" -gt 0 ]; then
                    HEREDOC_BODY_SUBSTITUTIONS+=("${ARITHMETIC_SUBSTITUTIONS[@]}")
                fi
                idx="$SUBSTITUTION_END_INDEX"
                continue
            fi
            if read_dollar_substitution "$line" "$idx"; then
                HEREDOC_BODY_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
                idx="$SUBSTITUTION_END_INDEX"
                continue
            fi
            return 1
        fi
        if [ "$char" = '`' ]; then
            if read_backtick_substitution "$line" "$idx"; then
                HEREDOC_BODY_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
                idx="$SUBSTITUTION_END_INDEX"
                continue
            fi
            return 1
        fi
        idx=$((idx + 1))
    done
    return 0
}

match_heredoc_start() {
    local line="$1"
    local length="${#line}"
    local idx=0
    local candidate
    local char
    local h_single_pattern=$'^<<(-?)[[:space:]]*\'([^\']+)\''
    local h_double_pattern='^<<(-?)[[:space:]]*"([^"]+)"'
    local h_unquoted_pattern=$'^<<(-?)[[:space:]]*([^[:space:]\'";&()<>|]+)'
    local in_single=false
    local in_double=false
    local escaped=false

    HEREDOC_MATCH_DELIMITER=""
    HEREDOC_MATCH_IS_QUOTED=false
    HEREDOC_MATCH_IS_DASHED=false

    while [ "$idx" -lt "$length" ]; do
        char="${line:$idx:1}"

        if [ "$escaped" = "true" ]; then
            escaped=false
            idx=$((idx + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            escaped=true
            idx=$((idx + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            idx=$((idx + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            idx=$((idx + 1))
            continue
        fi

        if [ "$in_single" = "true" ] || [ "$in_double" = "true" ]; then
            idx=$((idx + 1))
            continue
        fi

        if [ "$char" = '$' ] && [ $((idx + 1)) -lt "$length" ] \
            && [ "${line:$((idx + 1)):1}" = "(" ]; then
            if [ $((idx + 2)) -lt "$length" ] && [ "${line:$((idx + 2)):1}" = "(" ]; then
                read_arithmetic_expansion_end "$line" "$idx" || return 1
            else
                read_dollar_substitution_end "$line" "$idx" || return 1
            fi
            idx="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$char" = '(' ] && [ $((idx + 1)) -lt "$length" ] \
            && [ "${line:$((idx + 1)):1}" = "(" ]; then
            read_arithmetic_command_end "$line" "$idx" || return 1
            idx="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$char" = '`' ]; then
            read_backtick_substitution_end "$line" "$idx" || return 1
            idx="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$idx" -ge $((length - 1)) ] || [ "${line:$idx:2}" != "<<" ]; then
            idx=$((idx + 1))
            continue
        fi

        candidate="${line:$idx}"
        if [[ "$candidate" =~ $h_single_pattern ]]; then
            HEREDOC_MATCH_DELIMITER="${BASH_REMATCH[2]}"
            HEREDOC_MATCH_IS_QUOTED=true
            [ -n "${BASH_REMATCH[1]}" ] && HEREDOC_MATCH_IS_DASHED=true || HEREDOC_MATCH_IS_DASHED=false
            return 0
        fi
        if [[ "$candidate" =~ $h_double_pattern ]]; then
            HEREDOC_MATCH_DELIMITER="${BASH_REMATCH[2]}"
            HEREDOC_MATCH_IS_QUOTED=true
            [ -n "${BASH_REMATCH[1]}" ] && HEREDOC_MATCH_IS_DASHED=true || HEREDOC_MATCH_IS_DASHED=false
            return 0
        fi
        if [[ "$candidate" =~ $h_unquoted_pattern ]]; then
            HEREDOC_MATCH_DELIMITER="${BASH_REMATCH[2]}"
            HEREDOC_MATCH_IS_QUOTED=false
            [ -n "${BASH_REMATCH[1]}" ] && HEREDOC_MATCH_IS_DASHED=true || HEREDOC_MATCH_IS_DASHED=false
            return 0
        fi

        idx=$((idx + 1))
    done

    return 1
}

strip_heredoc_bodies() {
    # Populates STRIPPED_COMMAND and HEREDOC_BODY_SUBSTITUTIONS.
    # Called in the current shell (no subshell) so globals propagate.
    local raw_command="$1"
    local line
    local delimiter=""
    local is_quoted=false
    local is_dashed=false
    local stripped
    local output_lines=()
    STRIPPED_COMMAND=""
    HEREDOC_BODY_SUBSTITUTIONS=()

    while IFS= read -r line || [ -n "$line" ]; do
        if [ -n "$delimiter" ]; then
            stripped="$line"
            if [ "$is_dashed" = "true" ]; then
                # <<- strips leading TABs only (POSIX). Do not strip spaces.
                while [ -n "$stripped" ] && [ "${stripped:0:1}" = $'\t' ]; do
                    stripped="${stripped:1}"
                done
            fi
            if [ "$stripped" = "$delimiter" ]; then
                output_lines+=("$line")
                delimiter=""
                is_quoted=false
                is_dashed=false
            else
                if [ "$is_quoted" != "true" ]; then
                    # Unquoted heredoc: shell still expands $(...) / `...` in body.
                    # Capture substitutions so the parser can inspect them.
                    extract_body_substitutions "$line" || return 1
                fi
                output_lines+=("")
            fi
            continue
        fi

        output_lines+=("$line")

        if match_heredoc_start "$line"; then
            delimiter="$HEREDOC_MATCH_DELIMITER"
            is_quoted="$HEREDOC_MATCH_IS_QUOTED"
            is_dashed="$HEREDOC_MATCH_IS_DASHED"
        fi
    done <<< "$raw_command"

    local joined
    printf -v joined '%s\n' "${output_lines[@]}"
    # Drop the trailing newline that printf adds to the last element.
    STRIPPED_COMMAND="${joined%$'\n'}"
    return 0
}

read_dollar_substitution_end() {
    local raw_command="$1"
    local index="$2"
    local length="${#raw_command}"
    local depth=1
    local char
    local in_single=false
    local in_double=false
    local escaped=false

    index=$((index + 2))

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
            && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
            if [ $((index + 2)) -lt "$length" ] && [ "${raw_command:$((index + 2)):1}" = "(" ]; then
                read_arithmetic_expansion_end "$raw_command" "$index" || return 1
                index="$SUBSTITUTION_END_INDEX"
                continue
            fi
            read_dollar_substitution_end "$raw_command" "$index" || return 1
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$in_double" != "true" ] && [ "$char" = ")" ]; then
            depth=$((depth - 1))
            index=$((index + 1))
            if [ "$depth" -eq 0 ]; then
                SUBSTITUTION_END_INDEX="$index"
                return 0
            fi
            continue
        fi

        index=$((index + 1))
    done

    return 1
}

read_double_paren_end() {
    local raw_command="$1"
    local index="$2"
    local prefix_length="$3"
    local length="${#raw_command}"
    local depth=1
    local char
    local escaped=false
    local in_single=false
    local in_double=false

    index=$((index + prefix_length))

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
            && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
            if [ $((index + 2)) -lt "$length" ] && [ "${raw_command:$((index + 2)):1}" = "(" ]; then
                read_arithmetic_expansion_end "$raw_command" "$index" || return 1
            else
                read_dollar_substitution_end "$raw_command" "$index" || return 1
            fi
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '`' ]; then
            read_backtick_substitution_end "$raw_command" "$index" || return 1
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$in_double" != "true" ]; then
            if [ "$char" = '(' ]; then
                depth=$((depth + 1))
                index=$((index + 1))
                continue
            fi

            if [ "$char" = ")" ]; then
                depth=$((depth - 1))
                if [ "$depth" -eq 0 ]; then
                    if [ "$index" -lt $((length - 1)) ] && [ "${raw_command:$((index + 1)):1}" = ")" ]; then
                        SUBSTITUTION_END_INDEX=$((index + 2))
                        return 0
                    fi
                    return 1
                fi
            fi
        fi

        index=$((index + 1))
    done

    return 1
}

read_arithmetic_expansion_end() {
    read_double_paren_end "$1" "$2" 3
}

read_arithmetic_command_end() {
    read_double_paren_end "$1" "$2" 2
}

collect_arithmetic_substitutions() {
    local raw_command="$1"
    local index="$2"
    local end="${3:-}"
    local limit char
    local escaped=false
    local in_single=false
    local in_double=false
    local collected=()
    local nested_end
    local nested_substitutions=()

    if [ -z "$end" ]; then
        read_arithmetic_expansion_end "$raw_command" "$index" || return 1
        end="$SUBSTITUTION_END_INDEX"
    fi

    limit=$((end - 2))
    index=$((index + 3))

    while [ "$index" -lt "$limit" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            index=$((index + 1))
            continue
        fi

        if [ "$in_single" = "true" ] || [ "$in_double" = "true" ]; then
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '$' ] && [ $((index + 1)) -lt "$limit" ] \
            && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
            if [ $((index + 2)) -lt "$limit" ] && [ "${raw_command:$((index + 2)):1}" = "(" ]; then
                collect_arithmetic_substitutions "$raw_command" "$index" || return 1
                nested_end="$SUBSTITUTION_END_INDEX"
                nested_substitutions=("${ARITHMETIC_SUBSTITUTIONS[@]}")
                if [ "${#nested_substitutions[@]}" -gt 0 ]; then
                    collected+=("${nested_substitutions[@]}")
                fi
                index="$nested_end"
                continue
            fi
            read_dollar_substitution "$raw_command" "$index" || return 1
            collected+=("$SUBSTITUTION_CONTENT")
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$char" = '`' ]; then
            read_backtick_substitution "$raw_command" "$index" || return 1
            collected+=("$SUBSTITUTION_CONTENT")
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        index=$((index + 1))
    done

    SUBSTITUTION_END_INDEX="$end"
    ARITHMETIC_SUBSTITUTIONS=("${collected[@]}")
    return 0
}

read_backtick_substitution_end() {
    local raw_command="$1"
    local index="$2"
    local length="${#raw_command}"
    local char
    local escaped=false

    index=$((index + 1))

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ]; then
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '`' ]; then
            SUBSTITUTION_END_INDEX=$((index + 1))
            return 0
        fi

        index=$((index + 1))
    done

    return 1
}

read_dollar_substitution() {
    local raw_command="$1"
    local index="$2"
    local length="${#raw_command}"
    local depth=1
    local char
    local inner=""
    local in_single=false
    local in_double=false
    local escaped=false

    index=$((index + 2))

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            inner+="$char"
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            inner+="$char"
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            inner+="$char"
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            inner+="$char"
            index=$((index + 1))
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
            && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
            if [ $((index + 2)) -lt "$length" ] && [ "${raw_command:$((index + 2)):1}" = "(" ]; then
                read_arithmetic_expansion_end "$raw_command" "$index" || return 1
                inner+="${raw_command:$index:$((SUBSTITUTION_END_INDEX - index))}"
                index="$SUBSTITUTION_END_INDEX"
                continue
            fi
            if ! read_dollar_substitution "$raw_command" "$index"; then
                return 1
            fi
            inner+="\$(${SUBSTITUTION_CONTENT})"
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$in_double" != "true" ] && [ "$char" = ")" ]; then
            depth=$((depth - 1))
            if [ "$depth" -eq 0 ]; then
                SUBSTITUTION_CONTENT="$inner"
                SUBSTITUTION_END_INDEX=$((index + 1))
                return 0
            fi
        fi

        inner+="$char"
        index=$((index + 1))
    done

    return 1
}

read_backtick_substitution() {
    local raw_command="$1"
    local index="$2"
    local length="${#raw_command}"
    local char
    local inner=""
    local escaped=false

    index=$((index + 1))

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            inner+="$char"
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ]; then
            inner+="$char"
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '`' ]; then
            SUBSTITUTION_CONTENT="$inner"
            SUBSTITUTION_END_INDEX=$((index + 1))
            return 0
        fi

        inner+="$char"
        index=$((index + 1))
    done

    return 1
}

replace_command_substitutions() {
    # strip_heredoc_bodies must run in the current shell so
    # HEREDOC_BODY_SUBSTITUTIONS and STRIPPED_COMMAND propagate.
    if ! strip_heredoc_bodies "$1"; then
        return 1
    fi
    local raw_command="$STRIPPED_COMMAND"
    local length="${#raw_command}"
    local index=0
    local char
    local result=""
    local in_single=false
    local in_double=false
    local escaped=false

    COMMAND_SUBSTITUTIONS=()

    # Substitutions captured from unquoted heredoc bodies still run
    # in the shell; callers must inspect them like any other cmd subst.
    if [ "${#HEREDOC_BODY_SUBSTITUTIONS[@]}" -gt 0 ]; then
        local heredoc_sub
        for heredoc_sub in "${HEREDOC_BODY_SUBSTITUTIONS[@]}"; do
            COMMAND_SUBSTITUTIONS+=("$heredoc_sub")
        done
    fi

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            result+="$char"
            escaped=false
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "\\" ] && [ "$in_single" != "true" ]; then
            result+="$char"
            escaped=true
            index=$((index + 1))
            continue
        fi

        if [ "$char" = "'" ] && [ "$in_double" != "true" ]; then
            if [ "$in_single" = "true" ]; then
                in_single=false
            else
                in_single=true
            fi
            result+="$char"
            index=$((index + 1))
            continue
        fi

        if [ "$char" = '"' ] && [ "$in_single" != "true" ]; then
            if [ "$in_double" = "true" ]; then
                in_double=false
            else
                in_double=true
            fi
            result+="$char"
            index=$((index + 1))
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] \
            && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
            if [ $((index + 2)) -lt "$length" ] && [ "${raw_command:$((index + 2)):1}" = "(" ]; then
                if ! collect_arithmetic_substitutions "$raw_command" "$index"; then
                    return 1
                fi
                if [ "${#ARITHMETIC_SUBSTITUTIONS[@]}" -gt 0 ]; then
                    COMMAND_SUBSTITUTIONS+=("${ARITHMETIC_SUBSTITUTIONS[@]}")
                fi
                result+="${raw_command:$index:$((SUBSTITUTION_END_INDEX - index))}"
                index="$SUBSTITUTION_END_INDEX"
                continue
            fi
            if ! read_dollar_substitution "$raw_command" "$index"; then
                return 1
            fi
            COMMAND_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
            result+="__CMD_SUBST_$(( ${#COMMAND_SUBSTITUTIONS[@]} - 1 ))__"
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        if [ "$in_single" != "true" ] && [ "$char" = '`' ]; then
            if ! read_backtick_substitution "$raw_command" "$index"; then
                return 1
            fi
            COMMAND_SUBSTITUTIONS+=("$SUBSTITUTION_CONTENT")
            result+="__CMD_SUBST_$(( ${#COMMAND_SUBSTITUTIONS[@]} - 1 ))__"
            index="$SUBSTITUTION_END_INDEX"
            continue
        fi

        result+="$char"
        index=$((index + 1))
    done

    SANITIZED_COMMAND="$result"
}

normalize_shell_newlines() {
    local raw_command="$1"
    local length="${#raw_command}"
    local index=0
    local char
    local mode="normal"
    local escaped=false
    local normalized=""

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            normalized+="$char"
            escaped=false
            index=$((index + 1))
            continue
        fi

        case "$mode" in
            single)
                normalized+="$char"
                [ "$char" = "'" ] && mode="normal"
                ;;
            double)
                normalized+="$char"
                if [ "$char" = "\\" ]; then
                    escaped=true
                elif [ "$char" = '"' ]; then
                    mode="normal"
                fi
                ;;
            *)
                case "$char" in
                    "'")
                        normalized+="$char"
                        mode="single"
                        ;;
                    '"')
                        normalized+="$char"
                        mode="double"
                        ;;
                    "\\")
                        normalized+="$char"
                        escaped=true
                        ;;
                    $'\n'|$'\r')
                        normalized+=";"
                        ;;
                    *)
                        normalized+="$char"
                        ;;
                esac
                ;;
        esac

        index=$((index + 1))
    done

    printf '%s\n' "$normalized"
}

shell_tokenize() {
    local raw_command="$1"
    local split_controls="${2:-false}"
    raw_command="$(normalize_shell_newlines "$raw_command")"
    local length="${#raw_command}"
    local index=0
    local current=""
    local char next
    local mode="normal"
    local escaped=false
    local token_started=false

    while [ "$index" -lt "$length" ]; do
        char="${raw_command:$index:1}"

        if [ "$escaped" = "true" ]; then
            case "$mode" in
                double)
                    if [ "$char" = "\\" ] || [ "$char" = '"' ] || [ "$char" = '$' ] || [ "$char" = '`' ]; then
                        current+="$char"
                    else
                        current+="\\$char"
                    fi
                    ;;
                *)
                    current+="$char"
                    ;;
            esac
            escaped=false
            token_started=true
            index=$((index + 1))
            continue
        fi

        if [ "$mode" != "single" ]; then
            if [ "$char" = '$' ] && [ $((index + 1)) -lt "$length" ] && [ "${raw_command:$((index + 1)):1}" = "(" ]; then
                if ! read_dollar_substitution_end "$raw_command" "$index"; then
                    return 1
                fi
                current+="__CMD_SUBST__"
                token_started=true
                index="$SUBSTITUTION_END_INDEX"
                continue
            fi

            if [ "$char" = '`' ]; then
                if ! read_backtick_substitution_end "$raw_command" "$index"; then
                    return 1
                fi
                current+="__CMD_SUBST__"
                token_started=true
                index="$SUBSTITUTION_END_INDEX"
                continue
            fi
        fi

        case "$mode" in
            single)
                case "$char" in
                    "'")
                        mode="normal"
                        token_started=true
                        ;;
                    *)
                        current+="$char"
                        token_started=true
                        ;;
                esac
                ;;
            double)
                if [ "$char" = "\\" ]; then
                    escaped=true
                elif [ "$char" = '"' ]; then
                    mode="normal"
                    token_started=true
                else
                    current+="$char"
                    token_started=true
                fi
                ;;
            *)
                case "$char" in
                    [[:space:]])
                        if [ "$token_started" = "true" ]; then
                            jq -cn --arg value "$current" '{type:"word", value:$value}'
                            current=""
                            token_started=false
                        fi
                        ;;
                    "'")
                        mode="single"
                        token_started=true
                        ;;
                    '"')
                        mode="double"
                        token_started=true
                        ;;
                    ';'|'|'|'&'|'('|')')
                        if [ "$split_controls" = "true" ]; then
                            if [ "$token_started" = "true" ]; then
                                jq -cn --arg value "$current" '{type:"word", value:$value}'
                                current=""
                                token_started=false
                            fi
                            next=""
                            if [ $((index + 1)) -lt "$length" ]; then
                                next="${raw_command:$((index + 1)):1}"
                            fi
                            case "$char$next" in
                                '&&'|'||'|'|&')
                                    jq -cn --arg value "$char$next" '{type:"control", value:$value}'
                                    index=$((index + 2))
                                    continue
                                    ;;
                            esac
                            jq -cn --arg value "$char" '{type:"control", value:$value}'
                        else
                            current+="$char"
                            token_started=true
                        fi
                        ;;
                    *)
                        if [ "$char" = "\\" ]; then
                            escaped=true
                            token_started=true
                        else
                            current+="$char"
                            token_started=true
                        fi
                        ;;
                esac
                ;;
        esac

        index=$((index + 1))
    done

    if [ "$escaped" = "true" ] || [ "$mode" != "normal" ]; then
        return 1
    fi

    if [ "$token_started" = "true" ]; then
        jq -cn --arg value "$current" '{type:"word", value:$value}'
    fi
}
