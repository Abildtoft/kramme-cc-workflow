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
	printf '%s\n' '{"disabled":["noninteractive-git"]}' >"$plugin_root/hooks/hook-state.json"
	json_input="$(make_bash_input "$cmd")"
	env PATH="$fake_bin" CLAUDE_PLUGIN_ROOT="$plugin_root" "$fake_bin/bash" "$HOOK" <<<"$json_input"
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

PARSER_FIXTURES="$BATS_TEST_DIRNAME/fixtures/git-command-parser-cases.json"

assert_parser_fixture_decision() {
	local case_name="$1"
	local mode="$2"
	local expected="$3"

	case "$expected" in
		allow)
			if [ "$status" -ne 0 ] || ! is_allowed; then
				printf 'Expected fixture "%s" (%s) to be allowed, got status %s and output: %s\n' "$case_name" "$mode" "$status" "$output" >&2
				return 1
			fi
			;;
		block)
			if ! is_blocked; then
				printf 'Expected fixture "%s" (%s) to be blocked, got status %s and output: %s\n' "$case_name" "$mode" "$status" "$output" >&2
				return 1
			fi
			;;
		*)
			printf 'Unknown fixture expectation "%s" for "%s"\n' "$expected" "$case_name" >&2
			return 1
			;;
	esac
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
	run run_hook_without_jq "git commit"
	is_blocked
	[[ "$output" == *"jq not found"* ]]
	[[ "$output" == *"refusing to run safety hook without JSON parsing"* ]]
	[[ "$output" == *"Install jq or disable this hook explicitly"* ]]
	[[ "$output" != *"allowing command unchanged"* ]]
}

@test "allows disabled hook when jq is unavailable" {
	run run_hook_without_jq_disabled "git commit"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows non-git commands" {
	run run_hook "ls -la"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks commands when python3 is unavailable" {
	run run_hook_without_python "ls -la"
	is_blocked
	[[ "$output" == *"python3 not found"* ]]
	[[ "$output" == *"refusing to run safety hook without the shared git command parser"* ]]
	[[ "$output" == *"Install python3 or disable this hook explicitly"* ]]
}

@test "shared parser fixtures match noninteractive hook decisions" {
	local case_json case_name command expected mode

	# Common shell/git parser cases belong in the shared fixture file so parser
	# consolidation can compare both hook consumers against the same baseline.
	while IFS= read -r case_json; do
		case_name="$(printf '%s\n' "$case_json" | jq -r '.name')"
		command="$(printf '%s\n' "$case_json" | jq -r '.command')"
		expected="$(printf '%s\n' "$case_json" | jq -r '.noninteractiveExpected')"
		while IFS= read -r mode; do
			case "$mode" in
				python)
					run run_hook "$command"
					;;
				*)
					printf 'Unknown fixture python mode "%s" for "%s"\n' "$mode" "$case_name" >&2
					return 1
					;;
			esac
			assert_parser_fixture_decision "$case_name" "$mode" "$expected"
		done < <(printf '%s\n' "$case_json" | jq -r '.pythonModes[]')
	done < <(jq -c '.cases[] | select(.noninteractiveExpected != null)' "$PARSER_FIXTURES")
}

@test "blocks shell alias git command" {
	run run_hook $'shopt -s expand_aliases\nalias g=git\ng commit'
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
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

@test "allows git commit with attached -m value" {
	run run_hook "git commit -mtest-message"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows git commit -m with literal --edit message" {
	run run_hook "git commit -m --edit"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows git commit --message with literal --edit value" {
	run run_hook "git commit --message --edit"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows git commit --fixup with separate target" {
	run run_hook "git commit --fixup HEAD"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows git commit --fixup with inline target" {
	run run_hook "git commit --fixup=HEAD"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git commit --fixup amend target" {
	run run_hook "git commit --fixup amend:HEAD"
	is_blocked
	[[ "$output" == *"--fixup=amend:"* ]]
}

@test "allows git commit --fixup amend target with --no-edit" {
	run run_hook "git commit --fixup=amend:HEAD --no-edit"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git commit --fixup reword target" {
	run run_hook "git commit --fixup=reword:HEAD"
	is_blocked
	[[ "$output" == *"--fixup=reword:"* ]]
}

@test "allows git commit --fixup reword target with --no-edit" {
	run run_hook "git commit --fixup=reword:HEAD --no-edit"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git commit with -m and --edit" {
	run run_hook "git commit -m 'test message' --edit"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit -S with --edit" {
	run run_hook "git commit -S --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit --gpg-sign with --edit" {
	run run_hook "git commit --gpg-sign --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit -S<keyid> with --edit" {
	run run_hook "git commit -Sdeadbeef --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit --gpg-sign=<keyid> with --edit" {
	run run_hook "git commit --gpg-sign=deadbeef --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit -u with --edit" {
	run run_hook "git commit -u --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git commit --untracked-files=<mode> with --edit" {
	run run_hook "git commit --untracked-files=all --edit -m 'test message'"
	is_blocked
	[[ "$output" == *"--edit"* ]]
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

@test "allows git commit with safe --fixup flag" {
	run run_hook "git commit --fixup=HEAD"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git commit with editor-opening --fixup=amend flag" {
	run run_hook "git commit --fixup=amend:HEAD"
	is_blocked
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

@test "allows exported GIT_SEQUENCE_EDITOR before interactive rebase" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true && git rebase -i HEAD~3"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows bare-exported GIT_SEQUENCE_EDITOR before interactive rebase" {
	run run_hook "GIT_SEQUENCE_EDITOR=true; export GIT_SEQUENCE_EDITOR && git rebase -i HEAD~3"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks piped exported GIT_SEQUENCE_EDITOR before interactive rebase" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true | git rebase -i HEAD~3"
	is_blocked
	[[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks subshell-exported GIT_SEQUENCE_EDITOR before interactive rebase" {
	run run_hook "(export GIT_SEQUENCE_EDITOR=true) && git rebase -i HEAD~3"
	is_blocked
	[[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "allows interactive rebase after exported GIT_SEQUENCE_EDITOR is nameref-unset" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true && unset -n GIT_SEQUENCE_EDITOR && git rebase -i HEAD~3"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks interactive rebase after exported GIT_SEQUENCE_EDITOR is unset" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true && unset GIT_SEQUENCE_EDITOR && git rebase -i HEAD~3"
	is_blocked
	[[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "allows interactive rebase after exported GIT_SEQUENCE_EDITOR is function-unset" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true && unset -f GIT_SEQUENCE_EDITOR && git rebase -i HEAD~3"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks interactive rebase when function-unset does not retain prefixed GIT_SEQUENCE_EDITOR" {
	run run_hook "GIT_SEQUENCE_EDITOR=true unset -f nope && export GIT_SEQUENCE_EDITOR && git rebase -i HEAD~3"
	is_blocked
	[[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
}

@test "blocks env -u GIT_SEQUENCE_EDITOR after explicit assignment" {
	run run_hook "GIT_SEQUENCE_EDITOR=true env -u GIT_SEQUENCE_EDITOR git rebase -i HEAD~3"
	is_blocked
	[[ "$output" == *"GIT_SEQUENCE_EDITOR"* ]]
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

@test "allows exported GIT_EDITOR before rebase --continue" {
	run run_hook "export GIT_EDITOR=true && git rebase --continue"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows bare-exported GIT_EDITOR before rebase --continue" {
	run run_hook "GIT_EDITOR=true; export GIT_EDITOR && git rebase --continue"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows rebase --continue after exported GIT_EDITOR is nameref-unset" {
	run run_hook "export GIT_EDITOR=true && unset -n GIT_EDITOR && git rebase --continue"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks rebase --continue after exported GIT_EDITOR is unset" {
	run run_hook "export GIT_EDITOR=true && unset GIT_EDITOR && git rebase --continue"
	is_blocked
	[[ "$output" == *"GIT_EDITOR"* ]]
}

@test "allows rebase --continue after exported GIT_EDITOR is function-unset" {
	run run_hook "export GIT_EDITOR=true && unset -f GIT_EDITOR && git rebase --continue"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks rebase --continue when function-unset does not retain prefixed GIT_EDITOR" {
	run run_hook "GIT_EDITOR=true unset -f nope && export GIT_EDITOR && git rebase --continue"
	is_blocked
	[[ "$output" == *"GIT_EDITOR"* ]]
}

@test "allows command substitution to inherit exported GIT_SEQUENCE_EDITOR" {
	run run_hook "export GIT_SEQUENCE_EDITOR=true && out=\$(git rebase -i HEAD~3)"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks env -u GIT_EDITOR after explicit assignment" {
	run run_hook "GIT_EDITOR=true env -u GIT_EDITOR git rebase --continue"
	is_blocked
	[[ "$output" == *"GIT_EDITOR"* ]]
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

@test "allows git merge --ff with -m" {
	run run_hook "git merge --ff -m 'merge message' feature-branch"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "allows git merge --ff-only with --edit" {
	run run_hook "git merge --ff-only --edit feature-branch"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git merge --ff-only --no-ff with --edit" {
	run run_hook "git merge --ff-only --no-ff --edit feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "allows git merge -m with literal --edit message" {
	run run_hook "git merge -m --edit feature-branch"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git merge --edit with -m" {
	run run_hook "git merge --edit -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git merge -e with -m" {
	run run_hook "git merge -e -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git merge -S with --edit" {
	run run_hook "git merge -S --edit -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git merge --gpg-sign with --edit" {
	run run_hook "git merge --gpg-sign --edit -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git merge -S<keyid> with --edit" {
	run run_hook "git merge -Sdeadbeef --edit -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
}

@test "blocks git merge --gpg-sign=<keyid> with --edit" {
	run run_hook "git merge --gpg-sign=deadbeef --edit -m 'merge message' feature-branch"
	is_blocked
	[[ "$output" == *"--edit"* ]]
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

@test "allows git commit text inside heredoc command substitution" {
	run run_hook "cat <<'EOF'
\$(git commit -m 'test message')
EOF"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "blocks git commit inside unquoted heredoc command substitution" {
	run run_hook "cat <<EOF
\$(git commit)
EOF"
	is_blocked
	[[ "$output" == *"git commit -m"* ]]
}

@test "blocks git commit inside if condition" {
	run run_hook "if git commit; then echo ok; fi"
	is_blocked
}

@test "blocks git commit inside subshell grouping" {
	run run_hook "(git commit)"
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

@test "normalizes ANSI-C shell payloads before checking git commands" {
	local command
	for command in \
		"bash -c \$'git commit'" \
		"bash -c \$'git\\x20commit'" \
		"bash -c \$'git\\tcommit'" \
		$'bash -c $\'echo ok\ngit commit\'' \
		"bash -O extglob -c \$'git commit'" \
		"env FOO=bar bash -c \$'git commit'"
	do
		run run_hook "$command"
		is_blocked
	done

	run run_hook "bash -c \$'git commit -m test'"
	[ "$status" -eq 0 ]
	is_allowed
}

@test "fails closed for malformed ANSI-C shell payload" {
	run run_hook "bash -c \$'git commit"
	is_blocked
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
