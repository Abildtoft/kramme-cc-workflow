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

run_hook_without_jq() {
	local cmd="$1"
	local fake_bin="$BATS_TEST_TMPDIR/no-jq-bin"
	local json_input
	rm -rf "$fake_bin"
	mkdir -p "$fake_bin"
	ln -s "$(command -v bash)" "$fake_bin/bash"
	ln -s "$(command -v cat)" "$fake_bin/cat"
	json_input="$(make_bash_input "$cmd")"
	env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT" "$fake_bin/bash" "$HOOK" <<<"$json_input"
}

run_hook_without_jq_disabled() {
	local cmd="$1"
	local fake_bin="$BATS_TEST_TMPDIR/no-jq-disabled-bin"
	local plugin_root="$BATS_TEST_TMPDIR/no-jq-disabled-plugin"
	local json_input
	rm -rf "$fake_bin" "$plugin_root"
	mkdir -p "$fake_bin" "$plugin_root/hooks/lib"
	ln -s "$(command -v bash)" "$fake_bin/bash"
	ln -s "$(command -v cat)" "$fake_bin/cat"
	cp "$BATS_TEST_DIRNAME/../hooks/lib/check-enabled.sh" "$plugin_root/hooks/lib/check-enabled.sh"
	printf '%s\n' '{"disabled":["block-rm-rf"]}' >"$plugin_root/hooks/hook-state.json"
	json_input="$(make_bash_input "$cmd")"
	env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$plugin_root" "$fake_bin/bash" "$HOOK" <<<"$json_input"
}

# ============================================================================
# BASIC ALLOW CASES
# ============================================================================

@test "allows empty input" {
	run bash "$HOOK" <<<'{}'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows missing tool_input" {
	run bash "$HOOK" <<<'{"other":"data"}'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks command when jq is unavailable" {
	run run_hook_without_jq "rm -rf directory/"
	is_blocked
	[[ "$output" == *"jq not found"* ]]
	[[ "$output" == *"refusing to run safety hook without JSON parsing"* ]]
	[[ "$output" == *"Install jq or disable this hook explicitly"* ]]
}

@test "allows disabled hook when jq is unavailable" {
	run run_hook_without_jq_disabled "rm -rf directory/"
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

@test "blocks git rm followed by rm -rf with semicolon" {
	run run_hook "git rm tracked.md; rm -rf tmpdir"
	is_blocked
}

@test "blocks git rm followed by rm -rf with &&" {
	run run_hook "git rm tracked.md && rm -rf tmpdir"
	is_blocked
}

@test "blocks git rm followed by rm -rf with ||" {
	run run_hook "git rm tracked.md || rm -rf tmpdir"
	is_blocked
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
	is_blocked
	[[ "$output" == *"trash"* ]]
}

@test "blocks rm -fr (flag order reversed)" {
	run run_hook "rm -fr directory/"
	is_blocked
}

@test "blocks rm -r -f (separate flags)" {
	run run_hook "rm -r -f directory/"
	is_blocked
}

@test "blocks rm -f -r (separate flags reversed)" {
	run run_hook "rm -f -r directory/"
	is_blocked
}

@test "blocks rm --recursive --force" {
	run run_hook "rm --recursive --force directory/"
	is_blocked
}

@test "blocks rm --force --recursive" {
	run run_hook "rm --force --recursive directory/"
	is_blocked
}

@test "blocks rm with command substitution target before flags" {
	run run_hook 'rm $(echo directory/) -rf'
	is_blocked
}

@test "blocks rm with command substitution target containing semicolon before flags" {
	run run_hook 'rm $(echo directory/; echo other/) -rf'
	is_blocked
}

@test "blocks rm with command substitution target containing pipe before flags" {
	run run_hook 'rm $(find . -type d | head -1) -rf'
	is_blocked
}

@test "blocks rm with backtick target before flags" {
	run run_hook 'rm `echo directory/` -rf'
	is_blocked
}

@test "blocks command substitution rm with nested command substitution target before flags" {
	run run_hook 'echo $(rm $(echo directory/) -rf)'
	is_blocked
}

@test "blocks rm with nested command substitution target before flags" {
	run run_hook 'rm $(dirname $(pwd)) -rf'
	is_blocked
}

@test "blocks command substitution rm with deeply nested command substitution target before flags" {
	run run_hook 'echo $(rm $(dirname $(pwd)) -rf)'
	is_blocked
}

@test "allows command substitution rm without rf followed by outer rf text" {
	run run_hook 'echo $(rm file.txt) -rf'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks rm -R -f (uppercase R)" {
	run run_hook "rm -R -f directory/"
	is_blocked
}

@test "blocks rm -Rf" {
	run run_hook "rm -Rf directory/"
	is_blocked
}

@test "blocks rm -fR" {
	run run_hook "rm -fR directory/"
	is_blocked
}

@test "blocks rm -rfi (with interactive, still has rf)" {
	run run_hook "rm -rfi directory/"
	is_blocked
}

@test "blocks rm -rfv (with verbose)" {
	run run_hook "rm -rfv directory/"
	is_blocked
}

# ============================================================================
# PATH VARIANTS
# ============================================================================

@test "blocks /bin/rm -rf" {
	run run_hook "/bin/rm -rf directory/"
	is_blocked
}

@test "blocks /usr/bin/rm -rf" {
	run run_hook "/usr/bin/rm -rf directory/"
	is_blocked
}

@test "blocks ./rm -rf (relative path)" {
	run run_hook "./rm -rf directory/"
	is_blocked
}

# ============================================================================
# BYPASS ATTEMPTS
# ============================================================================

@test "blocks sudo rm -rf" {
	run run_hook "sudo rm -rf directory/"
	is_blocked
}

@test "blocks command rm -rf" {
	run run_hook "command rm -rf directory/"
	is_blocked
}

@test "blocks env rm -rf" {
	run run_hook "env rm -rf directory/"
	is_blocked
}

@test "blocks backslash rm -rf" {
	run run_hook '\rm -rf directory/'
	is_blocked
}

@test "blocks sudo /bin/rm -rf" {
	run run_hook "sudo /bin/rm -rf directory/"
	is_blocked
}

@test "blocks sudo command rm -rf" {
	run run_hook "sudo command rm -rf directory/"
	is_blocked
}

# ============================================================================
# XARGS
# ============================================================================

@test "blocks find | xargs rm -rf" {
	run run_hook "find . -name '*.tmp' | xargs rm -rf"
	is_blocked
}

@test "blocks ls | xargs rm -rf" {
	run run_hook "ls | xargs rm -rf"
	is_blocked
}

@test "blocks xargs rm -rf without pipe" {
	run run_hook "xargs rm -rf < files.txt"
	is_blocked
}

@test "allows xargs rm (without -rf)" {
	run run_hook "find . -name '*.tmp' | xargs rm"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks xargs bash -c 'rm -rf'" {
	run run_hook "xargs bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks xargs option-prefixed bash -c 'rm -rf'" {
	run run_hook "xargs -I{} bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks xargs macOS replacement option before bash -c 'rm -rf'" {
	run run_hook "xargs -J % bash -c 'rm -rf directory/'"
	is_blocked
}

# ============================================================================
# SUBSHELL EXECUTION
# ============================================================================

@test "blocks sh -c 'rm -rf'" {
	run run_hook "sh -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash -c 'rm -rf'" {
	run run_hook 'bash -c "rm -rf directory/"'
	is_blocked
}

@test "blocks zsh -c 'rm -rf'" {
	run run_hook 'zsh -c "rm -rf directory/"'
	is_blocked
}

@test "blocks bash -lc 'rm -rf'" {
	run run_hook "bash -lc 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash -ec 'rm -rf'" {
	run run_hook "bash -ec 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash -c -- 'rm -rf'" {
	run run_hook "bash -c -- 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash option operand before -c 'rm -rf'" {
	run run_hook "bash -O extglob -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash -c with ANSI-C quoted payload" {
	run run_hook "bash -c \$'rm -rf directory/'"
	is_blocked
}

@test "blocks zsh -fc 'rm -rf'" {
	run run_hook "zsh -fc 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash --command 'rm -rf'" {
	run run_hook "bash --command 'rm -rf directory/'"
	is_blocked
}

@test "blocks env bash -c 'rm -rf'" {
	run run_hook "env bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks env option-prefixed bash -c 'rm -rf'" {
	run run_hook "env -u FOO bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks env split-string bash -c 'rm -rf'" {
	run run_hook "env -S \"bash -c 'rm -rf directory/'\""
	is_blocked
}

@test "blocks env split-string equals bash -c 'rm -rf'" {
	run run_hook "env --split-string=\"bash -c 'rm -rf directory/'\""
	is_blocked
}

@test "blocks sudo bash -c 'rm -rf'" {
	run run_hook "sudo bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks sudo option-prefixed bash -c 'rm -rf'" {
	run run_hook "sudo -E bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks sudo option operand before bash -c 'rm -rf'" {
	run run_hook "sudo -u root bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks sudo combined option operand before bash -c 'rm -rf'" {
	run run_hook "sudo -Eu root bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks assignment-prefixed bash -c 'rm -rf'" {
	run run_hook "FOO=bar bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks command-substitution assignment before bash -c 'rm -rf'" {
	run run_hook "FOO=\$(id) bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks time bash -c 'rm -rf'" {
	run run_hook "time bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks time option-prefixed bash -c 'rm -rf'" {
	run run_hook "time -p bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks nice bash -c 'rm -rf'" {
	run run_hook "nice bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks nice option-prefixed bash -c 'rm -rf'" {
	run run_hook "nice -n 10 bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks timeout bash -c 'rm -rf'" {
	run run_hook "timeout 1 bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks timeout option-prefixed bash -c 'rm -rf'" {
	run run_hook "timeout -s KILL 1 bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks command bash -c 'rm -rf'" {
	run run_hook "command bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks bash -c 'rm -rf' after shell control word" {
	run run_hook "if bash -c 'rm -rf directory/'; then :; fi"
	is_blocked
}

@test "blocks rm -rf after shell control word in bash -c payload" {
	run run_hook "bash -c 'if true; then rm -rf directory/; fi'"
	is_blocked
}

@test "blocks rm -rf in case arm in bash -c payload" {
	run run_hook "bash -c 'case x in x) rm -rf directory/;; esac'"
	is_blocked
}

@test "blocks command-substituted bash -c payload with rm -rf text" {
	run run_hook 'bash -c "$(echo rm -rf directory/)"'
	is_blocked
}

@test "blocks eval rm -rf in bash -c payload" {
	run run_hook 'bash -c "eval rm -rf directory/"'
	is_blocked
}

@test "blocks eval quoted rm -rf in bash -c payload" {
	run run_hook "bash -c 'eval \"rm -rf directory/\"'"
	is_blocked
}

@test "allows eval echo with rm -rf text" {
	run run_hook "bash -c 'eval echo rm -rf is dangerous'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks local bash path -c 'rm -rf'" {
	run run_hook "/opt/homebrew/bin/bash -c 'rm -rf directory/'"
	is_blocked
}

@test "blocks local zsh path -c 'rm -rf'" {
	run run_hook "/usr/local/bin/zsh -c 'rm -rf directory/'"
	is_blocked
}

@test "allows sh -c with safe command" {
	run run_hook 'sh -c "echo hello"'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows bash -lc with safe command" {
	run run_hook 'bash -lc "echo hello"'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows env bash -c with safe command" {
	run run_hook 'env bash -c "echo hello"'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows bash -lc with quoted rm -rf text" {
	run run_hook 'bash -lc "echo \"rm -rf is dangerous\""'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows quoted shell wrapper text" {
	run run_hook "echo \"bash -lc 'rm -rf directory/'\""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows shell control words as plain command arguments" {
	run run_hook "echo then rm -rf is dangerous"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows unquoted shell wrapper text as plain command arguments" {
	run run_hook "echo bash -c 'rm -rf directory/'"
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
	is_blocked
}

@test "blocks find with -delete at end" {
	run run_hook "find /tmp -type f -mtime +7 -delete"
	is_blocked
}

@test "blocks find -exec rm -rf" {
	run run_hook "find . -type d -exec rm -rf {} \\;"
	is_blocked
}

@test "blocks find -exec rm -rf with +" {
	run run_hook "find . -type d -exec rm -rf {} +"
	is_blocked
}

@test "blocks find -exec bash -c 'rm -rf'" {
	run run_hook "find . -type d -exec bash -c 'rm -rf directory/' \\;"
	is_blocked
}

@test "blocks find -execdir bash -c 'rm -rf'" {
	run run_hook "find . -type d -execdir bash -c 'rm -rf directory/' \\;"
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
	is_blocked
}

@test "blocks shred with options" {
	run run_hook "shred -u -z file.txt"
	is_blocked
}

@test "blocks /usr/bin/shred" {
	run run_hook "/usr/bin/shred file.txt"
	is_blocked
}

@test "blocks sudo shred" {
	run run_hook "sudo shred -u file.txt"
	is_blocked
}

# ============================================================================
# UNLINK (file deletion)
# ============================================================================

@test "blocks unlink" {
	run run_hook "unlink file.txt"
	is_blocked
}

@test "blocks /bin/unlink" {
	run run_hook "/bin/unlink file.txt"
	is_blocked
}

@test "blocks sudo unlink" {
	run run_hook "sudo unlink file.txt"
	is_blocked
}

# ============================================================================
# COMMAND CHAINING
# ============================================================================

@test "blocks rm -rf in command chain with &&" {
	run run_hook "cd /tmp && rm -rf directory/"
	is_blocked
}

@test "blocks rm -rf in command chain with ;" {
	run run_hook "ls; rm -rf directory/"
	is_blocked
}

@test "blocks rm -rf in command chain with ||" {
	run run_hook "test -d dir || rm -rf backup/"
	is_blocked
}

@test "allows multiline rm -r before unrelated tar force flag" {
	run run_hook $'rm -r build\ntar -cf archive.tar src'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows multiline rm -r before unrelated curl force flag" {
	run run_hook $'rm -r build\ncurl -fsSL https://example.com | head'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks backslash-continued rm -r with force flag on next line" {
	run run_hook $'rm -r build \\\n-f'
	is_blocked
}

@test "blocks rm -r with force flag after multiline double-quoted argument" {
	run run_hook $'rm -r "dir\nname" -f'
	is_blocked
}

@test "blocks rm -rf in middle of multiline command" {
	run run_hook $'echo start\nrm -rf build\necho done'
	is_blocked
}

@test "blocks rm -rf in command substitution" {
	run run_hook 'echo $(rm -rf directory/)'
	is_blocked
}

@test "blocks rm -rf in double-quoted command substitution" {
	run run_hook 'echo "$(rm -rf directory/)"'
	is_blocked
}

@test "allows double-quoted safe command substitution with rm -rf text" {
	run run_hook 'echo "$(echo rm -rf is dangerous)"'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks rm -rf in backticks" {
	run run_hook 'echo `rm -rf directory/`'
	is_blocked
}

@test "blocks rm -rf in double-quoted backticks" {
	run run_hook 'echo "`rm -rf directory/`"'
	is_blocked
}

@test "allows double-quoted safe backticks with rm -rf text" {
	run run_hook 'echo "`echo rm -rf is dangerous`"'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks rm -rf in process substitution" {
	run run_hook 'bash -c "cat <(rm -rf directory/)"'
	is_blocked
}

@test "blocks rm -rf in output process substitution" {
	run run_hook 'bash -c "cat >(rm -rf directory/)"'
	is_blocked
}

@test "allows quoted process substitution text" {
	run run_hook 'bash -c "echo \"<(rm -rf directory/)\""'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "allows non-shell heredoc containing rm -rf text" {
	run run_hook $'cat > script.sh <<\'EOF\'\nrm -rf "$tmp"\nEOF'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks shell heredoc containing rm -rf" {
	run run_hook $'bash <<\'EOF\'\nrm -rf directory/\nEOF'
	is_blocked
}

@test "blocks rm -rf after quoted heredoc marker text" {
	run run_hook $'echo "<<EOF"\nrm -rf directory/\nEOF'
	is_blocked
}

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
	is_blocked
}

@test "blocks rm -rf with multiple targets" {
	run run_hook "rm -rf dir1/ dir2/ dir3/"
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
