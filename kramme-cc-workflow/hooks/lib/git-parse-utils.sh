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
