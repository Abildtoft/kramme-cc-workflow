#!/usr/bin/env bats
# Direct tests for hooks/lib/git-parse-utils.sh.

load 'test_helper/common'

setup() {
	LIB="$BATS_TEST_DIRNAME/../hooks/lib/git-parse-utils.sh"
	source "$LIB"
}

run_replace_command_substitutions() {
	replace_command_substitutions "$1"
	printf 'cmd:%s\n' "$SANITIZED_COMMAND"
	local substitution
	for substitution in "${COMMAND_SUBSTITUTIONS[@]}"; do
		printf 'sub:%s\n' "$substitution"
	done
}

run_strip_heredoc_bodies() {
	strip_heredoc_bodies "$1"
	printf '%s\n' "$STRIPPED_COMMAND"
	printf 'subs:%s\n' "${#HEREDOC_BODY_SUBSTITUTIONS[@]}"
	local substitution
	for substitution in "${HEREDOC_BODY_SUBSTITUTIONS[@]}"; do
		printf 'sub:%s\n' "$substitution"
	done
}

@test "strips wrapping quotes from tokens" {
	run strip_wrapping_quotes '"git commit"'
	[ "$status" -eq 0 ]
	[ "$output" = "git commit" ]

	run strip_wrapping_quotes "'git status'"
	[ "$status" -eq 0 ]
	[ "$output" = "git status" ]
}

@test "returns basename after removing wrapping quotes" {
	run token_basename '"/usr/local/bin/git"'

	[ "$status" -eq 0 ]
	[ "$output" = "git" ]
}

@test "trims leading and trailing ascii whitespace" {
	run trim_ascii_whitespace $' \t git commit -m test \r '

	[ "$status" -eq 0 ]
	[ "$output" = "git commit -m test" ]
}

@test "tokenizes quoted shell words and control operators" {
	run shell_tokenize "git -C 'repo path' commit -m \"hello world\" && echo done" true

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = '{"type":"word","value":"git"}' ]
	[ "${lines[1]}" = '{"type":"word","value":"-C"}' ]
	[ "${lines[2]}" = '{"type":"word","value":"repo path"}' ]
	[ "${lines[3]}" = '{"type":"word","value":"commit"}' ]
	[ "${lines[4]}" = '{"type":"word","value":"-m"}' ]
	[ "${lines[5]}" = '{"type":"word","value":"hello world"}' ]
	[ "${lines[6]}" = '{"type":"control","value":"&&"}' ]
	[ "${lines[7]}" = '{"type":"word","value":"echo"}' ]
	[ "${lines[8]}" = '{"type":"word","value":"done"}' ]
}

@test "keeps control operators inside words when split_controls is false" {
	run shell_tokenize "echo one&&two" false

	[ "$status" -eq 0 ]
	[ "$output" = '{"type":"word","value":"echo"}'$'\n''{"type":"word","value":"one&&two"}' ]
}

@test "returns failure for unterminated quoted input" {
	run shell_tokenize 'git commit "unterminated' true

	[ "$status" -eq 1 ]
}

@test "captures command substitutions and replaces them with placeholders" {
	run run_replace_command_substitutions 'MSG=$(cat /tmp/msg) git commit -m "ok" && echo `git status`'

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = 'cmd:MSG=__CMD_SUBST_0__ git commit -m "ok" && echo __CMD_SUBST_1__' ]
	[ "${lines[1]}" = 'sub:cat /tmp/msg' ]
	[ "${lines[2]}" = 'sub:git status' ]
}

@test "ignores command substitutions inside single quotes" {
	run run_replace_command_substitutions 'echo '\''$(git commit)'\'' "$(git status)"'

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "cmd:echo '\$(git commit)' \"__CMD_SUBST_0__\"" ]
	[ "${lines[1]}" = 'sub:git status' ]
}

@test "captures substitutions inside unquoted heredoc bodies" {
	local input
	input=$(printf 'cat <<EOF\n$(git commit)\nEOF')

	run run_strip_heredoc_bodies "$input"

	[ "$status" -eq 0 ]
	[[ "$output" == *$'cat <<EOF\n\nEOF'* ]]
	[[ "$output" == *'subs:1'* ]]
	[[ "$output" == *'sub:git commit'* ]]
}

@test "ignores substitutions inside quoted heredoc bodies" {
	local input
	local expected
	input=$(printf "cat <<'EOF'\n\$(git commit)\nEOF")
	expected=$(printf "cat <<'EOF'\n\nEOF")

	run run_strip_heredoc_bodies "$input"

	[ "$status" -eq 0 ]
	[[ "$output" == *"$expected"* ]]
	[[ "$output" == *'subs:0'* ]]
}
