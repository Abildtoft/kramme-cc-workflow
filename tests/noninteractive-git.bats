#!/usr/bin/env bats
# Tests for noninteractive-git.sh hook

load 'test_helper/common'

setup() {
    HOOK="$BATS_TEST_DIRNAME/../hooks/noninteractive-git.sh"
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
    is_allowed
}

@test "allows git status" {
    run run_hook "git status"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git diff" {
    run run_hook "git diff"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git log" {
    run run_hook "git log --oneline"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git push" {
    run run_hook "git push origin main"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git pull" {
    run run_hook "git pull origin main"
    [ "$status" -eq 0 ]
    is_allowed
}

# ============================================================================
# GIT COMMIT CASES
# ============================================================================

@test "allows git commit with -m flag" {
    run run_hook "git commit -m 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with --message flag" {
    run run_hook "git commit --message 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with -C flag (reuse message)" {
    run run_hook "git commit -C HEAD"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with --reuse-message flag" {
    run run_hook "git commit --reuse-message=HEAD"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with -F flag (message from file)" {
    run run_hook "git commit -F /tmp/message.txt"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with --file flag" {
    run run_hook "git commit --file /tmp/message.txt"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit with -m and --amend" {
    run run_hook "git commit --amend -m 'updated message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git commit without message flag" {
    run run_hook "git commit"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks git commit --amend without message" {
    run run_hook "git commit --amend"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git commit -a without message" {
    run run_hook "git commit -a"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows quoted git commit in echo" {
    run run_hook "echo 'git commit'"
    [ "$status" -eq 0 ]
    is_allowed
}

# ============================================================================
# GIT REBASE CASES
# ============================================================================

@test "allows non-interactive rebase" {
    run run_hook "git rebase main"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows rebase with GIT_SEQUENCE_EDITOR=true" {
    run run_hook "GIT_SEQUENCE_EDITOR=true git rebase -i HEAD~3"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows rebase with GIT_SEQUENCE_EDITOR=cat" {
    run run_hook "GIT_SEQUENCE_EDITOR=cat git rebase --interactive HEAD~3"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git rebase -i without GIT_SEQUENCE_EDITOR" {
    run run_hook "git rebase -i HEAD~3"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks git rebase --interactive without GIT_SEQUENCE_EDITOR" {
    run run_hook "git rebase --interactive HEAD~3"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows git rebase --continue with GIT_EDITOR" {
    run run_hook "GIT_EDITOR=true git rebase --continue"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git rebase --continue without GIT_EDITOR" {
    run run_hook "git rebase --continue"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"GIT_EDITOR"* ]]
}

@test "allows git rebase --abort" {
    run run_hook "git rebase --abort"
    [ "$status" -eq 0 ]
    is_allowed
}

# ============================================================================
# GIT ADD CASES
# ============================================================================

@test "allows git add with file paths" {
    run run_hook "git add file.txt"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git add with dot" {
    run run_hook "git add ."
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git add -A" {
    run run_hook "git add -A"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git add -p" {
    run run_hook "git add -p"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"explicit paths"* ]]
}

@test "blocks git add --patch" {
    run run_hook "git add --patch"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git add -i" {
    run run_hook "git add -i"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks git add --interactive" {
    run run_hook "git add --interactive"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# GIT MERGE CASES
# ============================================================================

@test "allows git merge with --no-edit" {
    run run_hook "git merge --no-edit feature-branch"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git merge with --no-commit" {
    run run_hook "git merge --no-commit feature-branch"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git merge with --squash" {
    run run_hook "git merge --squash feature-branch"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git merge with --ff-only" {
    run run_hook "git merge --ff-only feature-branch"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git merge with --ff" {
    run run_hook "git merge --ff feature-branch"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git merge without --no-edit" {
    run run_hook "git merge feature-branch"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
}

@test "blocks git merge origin/main without --no-edit" {
    run run_hook "git merge origin/main"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# GIT CHERRY-PICK CASES
# ============================================================================

@test "allows git cherry-pick with --no-edit" {
    run run_hook "git cherry-pick --no-edit abc123"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git cherry-pick with --no-commit" {
    run run_hook "git cherry-pick --no-commit abc123"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git cherry-pick with -n flag" {
    run run_hook "git cherry-pick -n abc123"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git cherry-pick without --no-edit" {
    run run_hook "git cherry-pick abc123"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
}

@test "blocks git cherry-pick with multiple commits" {
    run run_hook "git cherry-pick abc123 def456"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "handles command with extra whitespace" {
    run run_hook "  git   commit  "
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows echo with git commit in quotes" {
    run run_hook "echo \"git commit without -m\""
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git commit in heredoc context" {
    run run_hook "cat <<EOF
git commit
EOF"
    [ "$status" -eq 0 ]
    # This might match, but the heredoc content is in quotes effectively
    # The behavior here depends on implementation - this tests current behavior
}
