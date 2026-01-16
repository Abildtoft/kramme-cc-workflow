#!/usr/bin/env bats
# Tests for block-rm-rf.sh hook

load 'test_helper/common'

setup() {
    HOOK="$BATS_TEST_DIRNAME/../hooks/block-rm-rf.sh"
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

@test "allows simple ls command" {
    run run_hook "ls -la"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows cat command" {
    run run_hook "cat file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows mkdir command" {
    run run_hook "mkdir -p directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows rm without -rf flags" {
    run run_hook "rm file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows rm -r without -f" {
    run run_hook "rm -r directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows rm -f without -r" {
    run run_hook "rm -f file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows rm -i (interactive)" {
    run run_hook "rm -i file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows rmdir (different command)" {
    run run_hook "rmdir empty_directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# GIT RM (allowed - tracked by git, recoverable)
# ============================================================================

@test "allows git rm" {
    run run_hook "git rm file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git rm -rf" {
    run run_hook "git rm -rf directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git rm --force" {
    run run_hook "git rm --force file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git rm -r --cached" {
    run run_hook "git rm -r --cached node_modules/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows git rm in command chain" {
    run run_hook "cd repo && git rm -rf directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# QUOTED STRINGS (allowed - false positive prevention)
# ============================================================================

@test "allows echo with rm -rf in double quotes" {
    run run_hook 'echo "rm -rf is dangerous"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows echo with rm -rf in single quotes" {
    run run_hook "echo 'rm -rf /'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows printf with rm -rf" {
    run run_hook 'printf "Never run rm -rf /"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows grep pattern containing rm -rf" {
    run run_hook 'grep "rm -rf" script.sh'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows sed with rm -rf pattern" {
    run run_hook "sed 's/rm -rf/safe/' file.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows log message containing rm -rf" {
    run run_hook 'echo "Blocked: rm -rf attempt detected"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# BASIC BLOCK CASES: rm -rf variants
# ============================================================================

@test "blocks rm -rf" {
    run run_hook "rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
    [[ "$output" == *"trash"* ]]
}

@test "blocks rm -fr (flag order reversed)" {
    run run_hook "rm -fr directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -r -f (separate flags)" {
    run run_hook "rm -r -f directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -f -r (separate flags reversed)" {
    run run_hook "rm -f -r directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm --recursive --force" {
    run run_hook "rm --recursive --force directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm --force --recursive" {
    run run_hook "rm --force --recursive directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -R -f (uppercase R)" {
    run run_hook "rm -R -f directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -Rf" {
    run run_hook "rm -Rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -fR" {
    run run_hook "rm -fR directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rfi (with interactive, still has rf)" {
    run run_hook "rm -rfi directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rfv (with verbose)" {
    run run_hook "rm -rfv directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# PATH VARIANTS
# ============================================================================

@test "blocks /bin/rm -rf" {
    run run_hook "/bin/rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks /usr/bin/rm -rf" {
    run run_hook "/usr/bin/rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks ./rm -rf (relative path)" {
    run run_hook "./rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# BYPASS ATTEMPTS
# ============================================================================

@test "blocks sudo rm -rf" {
    run run_hook "sudo rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks command rm -rf" {
    run run_hook "command rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks env rm -rf" {
    run run_hook "env rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks backslash rm -rf" {
    run run_hook '\rm -rf directory/'
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks sudo /bin/rm -rf" {
    run run_hook "sudo /bin/rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks sudo command rm -rf" {
    run run_hook "sudo command rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# XARGS
# ============================================================================

@test "blocks find | xargs rm -rf" {
    run run_hook "find . -name '*.tmp' | xargs rm -rf"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks ls | xargs rm -rf" {
    run run_hook "ls | xargs rm -rf"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks xargs rm -rf without pipe" {
    run run_hook "xargs rm -rf < files.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows xargs rm (without -rf)" {
    run run_hook "find . -name '*.tmp' | xargs rm"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# SUBSHELL EXECUTION
# ============================================================================

@test "blocks sh -c 'rm -rf'" {
    run run_hook "sh -c 'rm -rf directory/'"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks bash -c 'rm -rf'" {
    run run_hook 'bash -c "rm -rf directory/"'
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks zsh -c 'rm -rf'" {
    run run_hook 'zsh -c "rm -rf directory/"'
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows sh -c with safe command" {
    run run_hook 'sh -c "echo hello"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows bash -c with rm (no -rf)" {
    run run_hook 'bash -c "rm file.txt"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows bash -c with ls" {
    run run_hook 'bash -c "ls -la"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# FIND COMMANDS
# ============================================================================

@test "blocks find -delete" {
    run run_hook "find . -name '*.tmp' -delete"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks find with -delete at end" {
    run run_hook "find /tmp -type f -mtime +7 -delete"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks find -exec rm -rf" {
    run run_hook "find . -type d -exec rm -rf {} \\;"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks find -exec rm -rf with +" {
    run run_hook "find . -type d -exec rm -rf {} +"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows find -exec rm (without -rf)" {
    run run_hook "find . -name '*.tmp' -exec rm {} \\;"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows find without -delete or -exec rm" {
    run run_hook "find . -name '*.txt' -print"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows find -type" {
    run run_hook "find . -type f -name '*.log'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================================
# SHRED (secure deletion, no recovery)
# ============================================================================

@test "blocks shred" {
    run run_hook "shred file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks shred with options" {
    run run_hook "shred -u -z file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks /usr/bin/shred" {
    run run_hook "/usr/bin/shred file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks sudo shred" {
    run run_hook "sudo shred -u file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# UNLINK (file deletion)
# ============================================================================

@test "blocks unlink" {
    run run_hook "unlink file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks /bin/unlink" {
    run run_hook "/bin/unlink file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks sudo unlink" {
    run run_hook "sudo unlink file.txt"
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# COMMAND CHAINING
# ============================================================================

@test "blocks rm -rf in command chain with &&" {
    run run_hook "cd /tmp && rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rf in command chain with ;" {
    run run_hook "ls; rm -rf directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rf in command chain with ||" {
    run run_hook "test -d dir || rm -rf backup/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rf in command substitution" {
    run run_hook 'echo $(rm -rf directory/)'
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rf in backticks" {
    run run_hook 'echo `rm -rf directory/`'
    [ "$status" -eq 0 ]
    is_blocked
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "allows command with 'rm' in path but not rm command" {
    run run_hook "ls /var/run/rm-safe/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows trash command (the recommended alternative)" {
    run run_hook "trash directory/"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "blocks rm -rf even with extra whitespace" {
    run run_hook "rm   -rf    directory/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "blocks rm -rf with multiple targets" {
    run run_hook "rm -rf dir1/ dir2/ dir3/"
    [ "$status" -eq 0 ]
    is_blocked
}

@test "allows npm commands" {
    run run_hook "npm install"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows yarn commands" {
    run run_hook "yarn add package"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
