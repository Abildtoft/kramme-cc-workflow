#!/bin/bash
# Common test utilities for BATS tests

# Make hooks path available
export HOOKS_DIR="${BATS_TEST_DIRNAME}/../hooks"
export CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."

# Helper: Create JSON input for block-rm-rf hook
make_bash_input() {
    local cmd="$1"
    jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}'
}

# Helper: Run block-rm-rf hook with a command
run_block_hook() {
    local cmd="$1"
    make_bash_input "$cmd" | bash "$HOOKS_DIR/block-rm-rf.sh"
}

# Helper: Check if output indicates a block decision (exit 2 + stderr message)
is_blocked() {
    [ "$status" -eq 2 ] && [ -n "$output" ]
}

# Helper: Check if output is empty (allowed)
is_allowed() {
    [ -z "$output" ] || [ "$output" = "{}" ]
}

# Helper: Create JSON input for auto-format hook
make_format_input() {
    local path="$1"
    jq -n --arg path "$path" '{tool_input:{file_path:$path}}'
}

# Helper: Check if output contains systemMessage
has_system_message() {
    [[ "$output" == *'"systemMessage"'* ]]
}

# Helper: Check if output indicates formatting happened
is_formatted() {
    [[ "$output" == *'Formatted'* ]]
}

# Helper: Check if output indicates no formatter
has_no_formatter() {
    [[ "$output" == *'No formatter'* ]]
}
