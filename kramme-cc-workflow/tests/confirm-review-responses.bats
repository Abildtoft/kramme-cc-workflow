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

mock_git_staged_for_repo() {
    local repo="$1"
    local staged_files="$2"
    local default_files="${3:-}"
    cat > "$MOCK_DIR/git" << EOF
#!/bin/bash
if [[ "\$1" == "-C" && "\$2" == "$repo" && "\$3" == "diff" && "\$4" == "--cached" && "\$5" == "--name-only" ]]; then
    echo "$staged_files"
    exit 0
fi
if [[ "\$1" == "diff" && "\$2" == "--cached" && "\$3" == "--name-only" ]]; then
    echo "$default_files"
    exit 0
fi
/usr/bin/git "\$@"
EOF
    chmod +x "$MOCK_DIR/git"
}

# Helper to run hook with given command
run_hook() {
    make_bash_input "$1" | bash "$HOOK"
}

run_hook_without_python() {
    local cmd="$1"
    local fake_bin="$BATS_TEST_TMPDIR/no-python-bin"
    rm -rf "$fake_bin"
    mkdir -p "$fake_bin"
    ln -s /bin/bash "$fake_bin/bash"
    ln -s "$(command -v jq)" "$fake_bin/jq"
    ln -s /bin/cat "$fake_bin/cat"
    ln -s "$(command -v grep)" "$fake_bin/grep"
    ln -s "$(command -v sed)" "$fake_bin/sed"
    ln -s "$MOCK_DIR/git" "$fake_bin/git"
    make_bash_input "$cmd" | env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT" "$fake_bin/bash" "$HOOK"
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

@test "blocks git commit when PRODUCT_REVIEW_OVERVIEW.md is staged" {
    mock_git_staged "PRODUCT_REVIEW_OVERVIEW.md"
    run run_hook "git commit -m 'product review staged'"
    is_blocked
    [[ "$output" == *"PRODUCT_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when PRODUCT_AUDIT_OVERVIEW.md is staged" {
    mock_git_staged "PRODUCT_AUDIT_OVERVIEW.md"
    run run_hook "git commit -m 'product audit overview staged'"
    is_blocked
    [[ "$output" == *"PRODUCT_AUDIT_OVERVIEW.md"* ]]
}

@test "blocks git commit when PRODUCT_AUDIT.md is staged in subdirectory" {
    mock_git_staged "siw/PRODUCT_AUDIT.md"
    run run_hook "git commit -m 'siw product audit staged'"
    is_blocked
    [[ "$output" == *"siw/PRODUCT_AUDIT.md"* ]]
}

@test "blocks git commit when QA_REPORT.md is staged" {
    mock_git_staged "QA_REPORT.md"
    run run_hook "git commit -m 'qa report staged'"
    is_blocked
    [[ "$output" == *"QA_REPORT.md"* ]]
}

@test "blocks git commit when QA_BASELINE.json is staged" {
    mock_git_staged "QA_BASELINE.json"
    run run_hook "git commit -m 'qa baseline staged'"
    is_blocked
    [[ "$output" == *"QA_BASELINE.json"* ]]
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

@test "blocks env-wrapped git commit when artifact is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "/usr/bin/env git commit -m 'test'"
    is_blocked
}

@test "blocks env -C wrapped git commit when artifact is staged" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
    run run_hook "env -C repo git commit -m 'test'"
    is_blocked
}

@test "blocks env --chdir wrapped git commit when artifact is staged" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
    run run_hook "env --chdir=repo git commit -m 'test'"
    is_blocked
}

@test "blocks chained git commit when artifact is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "git status && git commit -m 'test'"
    is_blocked
}

@test "blocks shell-wrapped git commit when artifact is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook "sh -c 'git commit -m \"test\"'"
    is_blocked
}

@test "blocks git -C commit when artifact is staged" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
    run run_hook "git -C repo commit -m 'test'"
    is_blocked
}

@test "blocks git -C commit when artifact is staged without python3" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
    run run_hook_without_python "git -C repo commit -m 'test'"
    is_blocked
}

@test "blocks env --chdir wrapped git commit when artifact is staged without python3" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
    run run_hook_without_python "env --chdir=repo git commit -m 'test'"
    is_blocked
}

@test "blocks chained git commit when artifact is staged without python3" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook_without_python "git status && git commit -m 'test'"
    is_blocked
}

@test "blocks shell-wrapped git commit when artifact is staged without python3" {
    mock_git_staged "REVIEW_OVERVIEW.md"
    run run_hook_without_python "sh -c 'git commit -m \"test\"'"
    is_blocked
}

@test "blocks git -C quoted path with spaces when artifact is staged without python3" {
    local repo="$BATS_TEST_TMPDIR/repo with space"
    mkdir -p "$repo"
    mock_git_staged_for_repo "$repo" "REVIEW_OVERVIEW.md"

    run run_hook_without_python "git -C '$repo' commit -m 'test'"

    is_blocked
}

@test "blocks git -C empty path commit when artifact is staged without python3" {
    mock_git_staged_for_repo "" "REVIEW_OVERVIEW.md" "nothing.txt"

    run run_hook_without_python "git -C '' commit -m 'test'"

    is_blocked
}

@test "blocks git -C escaped path with spaces when artifact is staged without python3" {
    local repo="$BATS_TEST_TMPDIR/repo with space"
    mkdir -p "$repo"
    mock_git_staged_for_repo "$repo" "REVIEW_OVERVIEW.md"

    run run_hook_without_python "git -C ${repo// /\\ } commit -m 'test'"

    is_blocked
}

@test "blocks git -C mixed quoted path with spaces when artifact is staged without python3" {
    local repo_base="$BATS_TEST_TMPDIR/base"
    local repo="$repo_base/repo with space"
    mkdir -p "$repo_base" "$repo"
    mock_git_staged_for_repo "$repo" "REVIEW_OVERVIEW.md"

    run run_hook_without_python "git -C $repo_base/'repo with space' commit -m 'test'"

    is_blocked
}

@test "blocks sudo git commit when artifact is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook "sudo git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --user git commit when artifact is staged" {
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook "sudo --user root git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --chdir git commit when artifact is staged" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"

    run run_hook "sudo --chdir repo git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --chdir= git commit when artifact is staged" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"

    run run_hook "sudo --chdir=repo git commit -m 'test'"

    is_blocked
}

@test "blocks sudo git commit when artifact is staged without python3" {
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook_without_python "sudo git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --user git commit when artifact is staged without python3" {
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook_without_python "sudo --user root git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --chdir git commit when artifact is staged without python3" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"

    run run_hook_without_python "sudo --chdir repo git commit -m 'test'"

    is_blocked
}

@test "blocks sudo --chdir= git commit when artifact is staged without python3" {
    mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"

    run run_hook_without_python "sudo --chdir=repo git commit -m 'test'"

    is_blocked
}

@test "blocks absolute-path git commit when artifact is staged without python3" {
    local absolute_git_dir
    absolute_git_dir="$(mktemp -d)"
    ln -s "$MOCK_DIR/git" "$absolute_git_dir/git"
    mock_git_staged "REVIEW_OVERVIEW.md"

    run run_hook_without_python "$absolute_git_dir/git commit -m 'test'"
    rm -rf "$absolute_git_dir"

    is_blocked
}

@test "checks staged artifacts in repo selected via GIT_DIR and GIT_WORK_TREE" {
    local repo
    repo="$(mktemp -d)"
    git -C "$repo" init -q
    touch "$repo/REVIEW_OVERVIEW.md"
    git -C "$repo" add REVIEW_OVERVIEW.md

    run run_hook "GIT_DIR=$repo/.git GIT_WORK_TREE=$repo git commit -m 'test'"
    rm -rf "$repo"

    is_blocked
}

@test "checks staged artifacts via GIT_DIR and GIT_WORK_TREE without python3" {
    local repo
    repo="$(mktemp -d)"
    git -C "$repo" init -q
    touch "$repo/REVIEW_OVERVIEW.md"
    git -C "$repo" add REVIEW_OVERVIEW.md

    # Needs real git (not mock) to query staged files from the real repo.
    local fake_bin="$BATS_TEST_TMPDIR/no-python-bin-real-git"
    rm -rf "$fake_bin"
    mkdir -p "$fake_bin"
    ln -s /bin/bash "$fake_bin/bash"
    ln -s "$(command -v jq)" "$fake_bin/jq"
    ln -s /bin/cat "$fake_bin/cat"
    ln -s "$(command -v grep)" "$fake_bin/grep"
    ln -s "$(command -v sed)" "$fake_bin/sed"
    ln -s "$(command -v git)" "$fake_bin/git"
    ln -s "$(command -v env)" "$fake_bin/env"

    run make_bash_input "GIT_DIR=$repo/.git GIT_WORK_TREE=$repo git commit -m 'test'"
    local json_input="$output"

    run env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT" "$fake_bin/bash" "$HOOK" <<< "$json_input"
    rm -rf "$repo" "$fake_bin"

    is_blocked
}

@test "checks staged artifacts via env GIT_DIR wrapper" {
    local repo
    repo="$(mktemp -d)"
    git -C "$repo" init -q
    touch "$repo/REVIEW_OVERVIEW.md"
    git -C "$repo" add REVIEW_OVERVIEW.md

    run run_hook "env GIT_DIR=$repo/.git GIT_WORK_TREE=$repo git commit -m 'test'"
    rm -rf "$repo"

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
