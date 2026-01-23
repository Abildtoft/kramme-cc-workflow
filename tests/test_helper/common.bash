#!/bin/bash
# Common test utilities for BATS tests

# Make hooks path available
export HOOKS_DIR="${BATS_TEST_DIRNAME}/../hooks"
export CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."

# Helper: Create JSON input for block-rm-rf hook
make_bash_input() {
    local cmd="$1"
    # Escape double quotes and backslashes for JSON
    cmd=$(echo "$cmd" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    printf '{"tool_input":{"command":"%s"}}' "$cmd"
}

# Helper: Run block-rm-rf hook with a command
run_block_hook() {
    local cmd="$1"
    make_bash_input "$cmd" | bash "$HOOKS_DIR/block-rm-rf.sh"
}

# Helper: Check if output indicates a block decision
is_blocked() {
    [[ "$output" == *'"decision":"block"'* ]]
}

# Helper: Check if output is empty (allowed)
is_allowed() {
    [ -z "$output" ] || [ "$output" = "{}" ]
}

# Helper: Create JSON input for auto-format hook
make_format_input() {
    local path="$1"
    # Escape double quotes and backslashes for JSON
    path=$(echo "$path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    printf '{"tool_input":{"file_path":"%s"}}' "$path"
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
