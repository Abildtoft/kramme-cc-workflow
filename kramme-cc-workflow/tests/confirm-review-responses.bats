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
    unset CONFIRM_REVIEW_ARTIFACT_LIST_FILE
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
# GIT COMMIT WITHOUT GUARDED ARTIFACTS
# ============================================================================

@test "allows git commit when configured artifacts are not staged" {
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
    mock_git_staged "REVIEW_OVERVIEW.md.bak
MY_REVIEW_OVERVIEW.md
REVIEW_OVERVIEW.markdown
AUDIT_IMPLEMENTATION_REPORT.md.bak
AUDIT_SPEC_REPORT.md.bak"
    run run_hook "git commit -m 'test'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# ALLOW CASES: LEGACY REVIEW FILES STAGED
# ============================================================================

@test "allows git commit when other review markdown files are staged" {
    mock_git_staged "REVIEW_NOTES.md
REVIEW_SUMMARY.md"
    run run_hook "git commit -m 'test commit'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# BLOCK CASES: CONFIGURED ARTIFACTS STAGED
# ============================================================================

@test "blocks git commit when REVIEW_OVERVIEW.md is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git commit -m 'test commit'"
    is_blocked
    [[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
    [[ "$output" == *"confirm"* ]]
}

@test "blocks git commit when AUDIT_IMPLEMENTATION_REPORT.md is staged" {
    mock_git_staged "AUDIT_IMPLEMENTATION_REPORT.md"
    run run_hook "git commit -m 'audit report staged'"
    is_blocked
    [[ "$output" == *"AUDIT_IMPLEMENTATION_REPORT.md"* ]]
}

@test "blocks git commit when AUDIT_IMPLEMENTATION_REPORT.md is staged in subdirectory" {
    mock_git_staged "siw/AUDIT_IMPLEMENTATION_REPORT.md"
    run run_hook "git commit -m 'audit report in siw'"
    is_blocked
    [[ "$output" == *"siw/AUDIT_IMPLEMENTATION_REPORT.md"* ]]
}

@test "blocks git commit when AUDIT_SPEC_REPORT.md is staged" {
    mock_git_staged "AUDIT_SPEC_REPORT.md"
    run run_hook "git commit -m 'spec audit report staged'"
    is_blocked
    [[ "$output" == *"AUDIT_SPEC_REPORT.md"* ]]
}

@test "blocks git commit when AUDIT_SPEC_REPORT.md is staged in subdirectory" {
    mock_git_staged "siw/AUDIT_SPEC_REPORT.md"
    run run_hook "git commit -m 'spec audit report in siw'"
    is_blocked
    [[ "$output" == *"siw/AUDIT_SPEC_REPORT.md"* ]]
}

@test "allows git commit when siw/LOG.md is staged" {
    mock_git_staged "siw/LOG.md"
    run run_hook "git commit -m 'log staged'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git commit when siw/OPEN_ISSUES_OVERVIEW.md is staged" {
    mock_git_staged "siw/OPEN_ISSUES_OVERVIEW.md"
    run run_hook "git commit -m 'overview staged'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git commit when siw/PROJECT_PLAN.md is staged" {
    mock_git_staged "siw/PROJECT_PLAN.md"
    run run_hook "git commit -m 'plan staged'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "blocks git commit when UX_REVIEW_OVERVIEW.md is staged" {
    mock_git_staged "UX_REVIEW_OVERVIEW.md"
    run run_hook "git commit -m 'ux review staged'"
    is_blocked
    [[ "$output" == *"UX_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when configured artifact is staged with other files" {
    mock_git_staged "file1.txt
REVIEW_OVERVIEW.md
file2.js"
    run run_hook "git commit -m 'multiple files'"
    is_blocked
}

@test "blocks git commit when REVIEW_OVERVIEW.md is in subdirectory" {
    mock_git_staged "src/REVIEW_OVERVIEW.md"
    run run_hook "git commit -m 'subdir file'"
    is_blocked
}

@test "blocks git commit when REVIEW_OVERVIEW.md is in deep path" {
    mock_git_staged "path/to/deep/REVIEW_OVERVIEW.md"
    run run_hook "git commit -m 'deep path'"
    is_blocked
}

@test "blocks git commit when artifact and other markdown files are all staged" {
    mock_git_staged "REVIEW_OVERVIEW.md
REVIEW_NOTES.md
REVIEW_SUMMARY.md"
    run run_hook "git commit -m 'both files'"
    is_blocked
}

# ============================================================================
# COMMIT COMMAND VARIANTS
# ============================================================================

@test "blocks git commit without message flag" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git commit"
    is_blocked
}

@test "blocks git commit with --amend" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git commit --amend"
    is_blocked
}

@test "blocks git commit with -a flag" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git commit -a -m 'auto stage'"
    is_blocked
}

@test "blocks git commit with multiple flags" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git commit -v --no-verify -m 'test'"
    is_blocked
}

# ============================================================================
# CONFIGURABLE ARTIFACT LIST
# ============================================================================

@test "uses custom artifact list from CONFIRM_REVIEW_ARTIFACT_LIST_FILE" {
    custom_list="$MOCK_DIR/custom-artifacts.txt"
    cat > "$custom_list" << 'EOF'
# Custom artifact list for this test
CUSTOM_REVIEW.md
siw/CUSTOM_LOG.md
EOF
    export CONFIRM_REVIEW_ARTIFACT_LIST_FILE="$custom_list"
    mock_git_staged "siw/CUSTOM_LOG.md"

    run run_hook "git commit -m 'custom artifact'"
    is_blocked
    [[ "$output" == *"siw/CUSTOM_LOG.md"* ]]
}

@test "falls back to REVIEW_OVERVIEW.md when configured list file is missing" {
    export CONFIRM_REVIEW_ARTIFACT_LIST_FILE="$MOCK_DIR/does-not-exist.txt"
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook "git commit -m 'fallback list'"
    is_blocked
    [[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}
