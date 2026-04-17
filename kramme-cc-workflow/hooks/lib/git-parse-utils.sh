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

strip_heredoc_bodies() {
    local raw_command="$1"
    local line
    local delimiter=""
    local output_lines=()
    local heredoc_pattern='<<-?[[:space:]]*(['"'"'"]?)([A-Za-z_][A-Za-z0-9_]*)\1'

    while IFS= read -r line || [ -n "$line" ]; do
        if [ -n "$delimiter" ]; then
            if [ "$(trim_ascii_whitespace "$line")" = "$delimiter" ]; then
                output_lines+=("$line")
                delimiter=""
            else
                output_lines+=("")
            fi
            continue
        fi

        output_lines+=("$line")

        if [[ "$line" =~ $heredoc_pattern ]]; then
            delimiter="${BASH_REMATCH[2]}"
        fi
    done <<< "$raw_command"

    printf '%s\n' "${output_lines[@]}"
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
            depth=$((depth + 1))
            index=$((index + 2))
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
    local raw_command
    raw_command="$(strip_heredoc_bodies "$1")"
    local length="${#raw_command}"
    local index=0
    local char
    local result=""
    local in_single=false
    local in_double=false
    local escaped=false

    COMMAND_SUBSTITUTIONS=()

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

shell_tokenize() {
    local raw_command="$1"
    local split_controls="${2:-false}"
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
                    ';'|'|'|'&')
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
