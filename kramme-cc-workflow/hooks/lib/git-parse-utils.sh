#!/bin/bash
# Shared git command parsing utilities used by noninteractive-git.sh
# and confirm-review-responses.sh hooks.

strip_wrapping_quotes() {
    local value="$1"
    value="${value#\'}"
    value="${value%\'}"
    value="${value#\"}"
    value="${value%\"}"
    printf '%s\n' "$value"
}

token_basename() {
    local value
    value="$(strip_wrapping_quotes "$1")"
    printf '%s\n' "${value##*/}"
}
