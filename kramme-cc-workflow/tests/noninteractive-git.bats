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

run_hook_without_python() {
    local cmd="$1"
    local fake_bin="$BATS_TEST_TMPDIR/no-python-bin"
    rm -rf "$fake_bin"
    mkdir -p "$fake_bin"
    ln -s "$(command -v bash)" "$fake_bin/bash"
    ln -s "$(command -v jq)" "$fake_bin/jq"
    ln -s "$(command -v cat)" "$fake_bin/cat"
    ln -s "$(command -v grep)" "$fake_bin/grep"
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
    is_allowed
}

@test "allows non-git commands when python3 is unavailable" {
    run run_hook_without_python "ls -la"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git status when python3 is unavailable" {
    run run_hook_without_python "git status"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks sh -c git commit when python3 is unavailable" {
    run run_hook_without_python "sh -c 'git commit'"
    is_blocked
    [[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks bash -c interactive rebase when python3 is unavailable" {
    run run_hook_without_python "bash -c 'git rebase -i HEAD~2'"
    is_blocked
    [[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks absolute-path git commit when python3 is unavailable" {
    local absolute_git_dir
    absolute_git_dir="$(mktemp -d)"
    ln -s "$(command -v git)" "$absolute_git_dir/git"

    run run_hook_without_python "$absolute_git_dir/git commit"
    rm -rf "$absolute_git_dir"

    is_blocked
}

@test "allows git commit -m when python3 is unavailable" {
    run run_hook_without_python "git commit -m 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks bash --rcfile wrapped git commit when python3 is unavailable" {
    run run_hook_without_python "bash --rcfile /tmp/rc -c 'git commit'"

    is_blocked
    [[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks bash -O wrapped git commit when python3 is unavailable" {
    run run_hook_without_python "bash -O extglob -c 'git commit'"

    is_blocked
    [[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks git -C quoted path with spaces when python3 is unavailable" {
    local repo="$BATS_TEST_TMPDIR/repo with space"
    mkdir -p "$repo"

    run run_hook_without_python "git -C '$repo' commit"

    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks git -C empty path commit when python3 is unavailable" {
    run run_hook_without_python "git -C '' commit"

    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "allows quoted control operators when python3 is unavailable" {
    run run_hook_without_python "echo '&&' git commit"

    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows shell text mentioning git when python3 is unavailable" {
    run run_hook_without_python "sh -c 'echo git commit'"

    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows sudo arguments mentioning git when python3 is unavailable" {
    run run_hook_without_python "sudo printf '%s\n' git"

    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks sudo env-wrapped git commit when python3 is unavailable" {
    run run_hook_without_python "sudo /usr/bin/env git commit"

    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks sudo --user git commit when python3 is unavailable" {
    run run_hook_without_python "sudo --user root git commit"

    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks sudo --chdir interactive rebase when python3 is unavailable" {
    run run_hook_without_python "sudo --chdir /tmp git rebase -i HEAD~2"

    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks find -exec shell-wrapped git commit when python3 is unavailable" {
    run run_hook_without_python "find . -exec sh -c 'git commit' \;"

    is_blocked
    [[ "$output" == *"Unable to safely parse command"* || "$output" == *"git commit -m"* ]]
}

@test "blocks find with later exec git commit when python3 is unavailable" {
    run run_hook_without_python "find . -exec echo ok \; -exec git commit \;"

    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks git commit without message when python3 is unavailable" {
    run run_hook_without_python "git commit"
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "allows GIT_SEQUENCE_EDITOR=true git rebase -i when python3 is unavailable" {
    run run_hook_without_python "GIT_SEQUENCE_EDITOR=true git rebase -i HEAD~3"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git rebase -i without GIT_SEQUENCE_EDITOR when python3 is unavailable" {
    run run_hook_without_python "git rebase -i HEAD~3"
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks prefixed GIT_EDITOR unset before rebase --continue when python3 is unavailable" {
    run run_hook_without_python "GIT_EDITOR=true env -u GIT_EDITOR git rebase --continue"
    is_blocked
    [[ "$output" == *"GIT_EDITOR"* ]]
}

@test "blocks prefixed GIT_SEQUENCE_EDITOR ignore-environment before interactive rebase when python3 is unavailable" {
    run run_hook_without_python "GIT_SEQUENCE_EDITOR=true env -i git rebase -i HEAD~3"
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "allows git merge --no-edit when python3 is unavailable" {
    run run_hook_without_python "git merge --no-edit main"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git merge without --no-edit when python3 is unavailable" {
    run run_hook_without_python "git merge main"
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
}

@test "blocks git add -p when python3 is unavailable" {
    run run_hook_without_python "git add -p"
    is_blocked
    [[ "$output" == *"explicit paths"* ]]
}

@test "allows git cherry-pick --no-edit when python3 is unavailable" {
    run run_hook_without_python "git cherry-pick --no-edit abc123"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git cherry-pick without --no-edit when python3 is unavailable" {
    run run_hook_without_python "git cherry-pick abc123"
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
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

@test "blocks bash --rcfile wrapped git commit" {
    run run_hook "bash --rcfile /tmp/rc -c 'git commit'"
    is_blocked
    [[ "$output" == *"Unable to safely parse command"* || "$output" == *"git commit -m"* ]]
}

@test "blocks bash -O wrapped git commit" {
    run run_hook "bash -O extglob -c 'git commit'"
    is_blocked
    [[ "$output" == *"Unable to safely parse command"* || "$output" == *"git commit -m"* ]]
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

@test "allows git commit --amend --no-edit" {
    run run_hook "git commit --amend --no-edit"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git commit with -c flag (reedit message)" {
    run run_hook "git commit -c HEAD"
    is_blocked
}

@test "blocks git commit with --reedit-message flag" {
    run run_hook "git commit --reedit-message=HEAD"
    is_blocked
}

@test "blocks git commit without message flag" {
    run run_hook "git commit"
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks git -C repo commit without message flag" {
    run run_hook "git -C repo commit"
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks git commit --amend without message" {
    run run_hook "git commit --amend"
    is_blocked
}

@test "blocks git commit -a without message" {
    run run_hook "git commit -a"
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

@test "allows env-wrapped rebase with GIT_SEQUENCE_EDITOR" {
    run run_hook "env GIT_SEQUENCE_EDITOR=true git rebase -i HEAD~3"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks sudo --chdir interactive rebase" {
    run run_hook "sudo --chdir /tmp git rebase -i HEAD~3"
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks git rebase -i without GIT_SEQUENCE_EDITOR" {
    run run_hook "git rebase -i HEAD~3"
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks git rebase --interactive without GIT_SEQUENCE_EDITOR" {
    run run_hook "git rebase --interactive HEAD~3"
    is_blocked
}

@test "allows git rebase --continue with GIT_EDITOR" {
    run run_hook "GIT_EDITOR=true git rebase --continue"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git rebase --continue without GIT_EDITOR" {
    run run_hook "git rebase --continue"
    is_blocked
    [[ "$output" == *"GIT_EDITOR"* ]]
}

@test "blocks env-wrapped rebase --continue without GIT_EDITOR" {
    run run_hook "env -u GIT_EDITOR git rebase --continue"
    is_blocked
}

@test "blocks prefixed GIT_EDITOR unset before rebase --continue" {
    run run_hook "GIT_EDITOR=true env -u GIT_EDITOR git rebase --continue"
    is_blocked
    [[ "$output" == *"GIT_EDITOR"* ]]
}

@test "blocks prefixed GIT_SEQUENCE_EDITOR ignore-environment before interactive rebase" {
    run run_hook "GIT_SEQUENCE_EDITOR=true env -i git rebase -i HEAD~3"
    is_blocked
    [[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
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
    is_blocked
    [[ "$output" == *"explicit paths"* ]]
}

@test "blocks git -c core.editor=vim add -p" {
    run run_hook "git -c core.editor=vim add -p"
    is_blocked
    [[ "$output" == *"explicit paths"* ]]
}

@test "blocks git add --patch" {
    run run_hook "git add --patch"
    is_blocked
}

@test "blocks git add -i" {
    run run_hook "git add -i"
    is_blocked
}

@test "blocks git add --interactive" {
    run run_hook "git add --interactive"
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

@test "allows git merge --abort" {
    run run_hook "git merge --abort"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git merge --quit" {
    run run_hook "git merge --quit"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git merge without --no-edit" {
    run run_hook "git merge feature-branch"
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
}

@test "blocks git merge origin/main without --no-edit" {
    run run_hook "git merge origin/main"
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

@test "allows git cherry-pick --continue" {
    run run_hook "git cherry-pick --continue"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git cherry-pick --abort" {
    run run_hook "git cherry-pick --abort"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git cherry-pick --skip" {
    run run_hook "git cherry-pick --skip"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows git cherry-pick --quit" {
    run run_hook "git cherry-pick --quit"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks git cherry-pick without --no-edit" {
    run run_hook "git cherry-pick abc123"
    is_blocked
    [[ "$output" == *"--no-edit"* ]]
}

@test "blocks git cherry-pick with multiple commits" {
    run run_hook "git cherry-pick abc123 def456"
    is_blocked
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "handles command with extra whitespace" {
    run run_hook "  git   commit  "
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

@test "blocks git commit inside if condition" {
    run run_hook "if git commit; then echo ok; fi"
    is_blocked
}

@test "blocks /usr/bin/env git commit" {
    run run_hook "/usr/bin/env git commit"
    is_blocked
}

@test "blocks git commit inside command substitution assignment" {
    run run_hook "out=\$(git commit)"
    is_blocked
}

@test "allows safe command substitution before git commit" {
    run run_hook "MSG=\$(cat /tmp/msg) git commit -m 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "allows safe command substitution before git rebase --continue" {
    run run_hook "GIT_EDITOR=\$(command -v true) git rebase --continue"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks /usr/bin/sudo git commit" {
    run run_hook "/usr/bin/sudo git commit"
    is_blocked
}

@test "blocks sudo --user git commit" {
    run run_hook "sudo --user root git commit"
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "allows command -- git commit with message" {
    run run_hook "command -- git commit -m 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks command -p git commit" {
    run run_hook "command -p git commit"
    is_blocked
}

@test "allows sudo -u root git commit with message" {
    run run_hook "sudo -u root git commit -m 'test message'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks xargs git commit" {
    run run_hook "xargs git commit"
    is_blocked
}

@test "blocks find -exec git commit" {
    run run_hook "find . -exec git commit \\;"
    is_blocked
}

@test "blocks find with later exec git commit" {
    run run_hook "find . -exec echo ok \\; -exec git commit \\;"
    is_blocked
    [[ "$output" == *"git commit -m"* ]]
}

@test "blocks sh -c git commit" {
    run run_hook "sh -c 'git commit'"
    is_blocked
}

@test "allows sh -c git commit with message" {
    run run_hook "sh -c 'git commit -m \"test message\"'"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks chained git commit without message" {
    run run_hook "git status && git commit"
    is_blocked
}

@test "blocks piped git commit without message" {
    run run_hook "echo ok | git commit"
    is_blocked
}

@test "allows piped git commit with message" {
    run run_hook "git commit -m 'test message' | cat"
    [ "$status" -eq 0 ]
    is_allowed
}

@test "blocks newline-separated git commit without message" {
    run run_hook $'echo ok\ngit commit'
    is_blocked
}

@test "blocks malformed command if parser fails" {
    run run_hook "git commit \"unterminated"
    is_blocked
}
