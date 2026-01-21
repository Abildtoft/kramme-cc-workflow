#!/usr/bin/env bats
# Tests for confirm-review-responses.sh hook

load 'test_helper/common'

setup() {
    HOOK="$BATS_TEST_DIRNAME/../hooks/confirm-review-responses.sh"
    # Create temp directory for git mocking
    export MOCK_DIR=$(mktemp -d)
    export PATH="$MOCK_DIR:$PATH"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

# Helper: Create a mock git command that returns specific staged files
mock_git_staged() {
    local staged_files="$1"
    cat > "$MOCK_DIR/git" << EOF
#!/bin/bash
if [[ "\$1" == "diff" && "\$2" == "--cached" && "\$3" == "--name-only" ]]; then
    echo "$staged_files"
    exit 0
fi
# Pass through other git commands
/usr/bin/git "\$@"
EOF
    chmod +x "$MOCK_DIR/git"
}

# Helper to run hook with given command
run_hook() {
    make_bash_input "$1" | bash "$HOOK"
}

# ============================================================================
# BASIC ALLOW CASES
# ============================================================================

@test "allows empty input" {
    run bash "$HOOK" <<< '{}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows missing tool_input" {
    run bash "$HOOK" <<< '{"other":"data"}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows non-git commands" {
    run run_hook "ls -la"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git status" {
    run run_hook "git status"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git add" {
    run run_hook "git add file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git push" {
    run run_hook "git push origin main"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git diff" {
    run run_hook "git diff"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# GIT COMMIT WITHOUT REVIEW_RESPONSES.MD
# ============================================================================

@test "allows git commit when REVIEW_RESPONSES.md is not staged" {
    mock_git_staged "file1.txt
file2.js
src/component.tsx"
    run run_hook "git commit -m 'test commit'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git commit when no files are staged" {
    mock_git_staged ""
    run run_hook "git commit -m 'empty commit'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git commit with similar but different filename" {
    mock_git_staged "REVIEW_RESPONSES.md.bak
MY_REVIEW_RESPONSES.md
REVIEW_RESPONSES.markdown"
    run run_hook "git commit -m 'test'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# BLOCK CASES: REVIEW_RESPONSES.MD STAGED
# ============================================================================

@test "blocks git commit when REVIEW_RESPONSES.md is staged" {
    mock_git_staged "REVIEW_RESPONSES.md"
    run run_hook "git commit -m 'test commit'"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"REVIEW_RESPONSES.md"* ]]
    [[ "$output" == *"confirm"* ]]
}

@test "blocks git commit when REVIEW_RESPONSES.md is staged with other files" {
    mock_git_staged "file1.txt
REVIEW_RESPONSES.md
file2.js"
    run run_hook "git commit -m 'multiple files'"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit when REVIEW_RESPONSES.md is in subdirectory" {
    mock_git_staged "src/REVIEW_RESPONSES.md"
    run run_hook "git commit -m 'subdir file'"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit when REVIEW_RESPONSES.md is in deep path" {
    mock_git_staged "path/to/deep/REVIEW_RESPONSES.md"
    run run_hook "git commit -m 'deep path'"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# COMMIT COMMAND VARIANTS
# ============================================================================

@test "blocks git commit without message flag" {
    mock_git_staged "REVIEW_RESPONSES.md"
    run run_hook "git commit"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit with --amend" {
    mock_git_staged "REVIEW_RESPONSES.md"
    run run_hook "git commit --amend"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit with -a flag" {
    mock_git_staged "REVIEW_RESPONSES.md"
    run run_hook "git commit -a -m 'auto stage'"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit with multiple flags" {
    mock_git_staged "REVIEW_RESPONSES.md"
    run run_hook "git commit -v --no-verify -m 'test'"
    [ "$status" -eq 0 ]
    is_blocked
}
