#!/usr/bin/env bats
# Tests for confirm-review-responses.sh hook

load 'test_helper/common'

setup() {
	HOOK="$BATS_TEST_DIRNAME/../hooks/confirm-review-responses.sh"
	# Resolve jq before MOCK_DIR joins PATH. Looking it up later would consult
	# bash's hash table, which `rm -f` does not invalidate, so a helper could
	# resolve a mock it had just deleted.
	REAL_JQ="$(command -v jq)"
	# Create temp directory for git mocking
	export MOCK_DIR=$(mktemp -d)
	export PATH="$MOCK_DIR:$PATH"
	REAL_COMMIT_REPO=""
}

teardown() {
	unset CONFIRM_REVIEW_ARTIFACT_LIST_FILE
	if [ -n "$REAL_COMMIT_REPO" ]; then
		rm -rf "$REAL_COMMIT_REPO"
	fi
	rm -rf "$MOCK_DIR"
}

# Helper: Create a mock git command that returns specific staged files
mock_git_staged() {
	local staged_files="$1"
	cat >"$MOCK_DIR/git" <<EOF
#!/bin/bash
has_arg() {
    local wanted="\$1"
    shift
    local arg
    for arg in "\$@"; do
        if [[ "\$arg" == "\$wanted" ]]; then
            return 0
        fi
    done
    return 1
}
if has_arg diff "\$@" && has_arg --cached "\$@" && has_arg --name-only "\$@"; then
    printf '%s\0' "$staged_files" | tr '\n' '\0'
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
	cat >"$MOCK_DIR/git" <<EOF
#!/bin/bash
has_arg() {
    local wanted="\$1"
    shift
    local arg
    for arg in "\$@"; do
        if [[ "\$arg" == "\$wanted" ]]; then
            return 0
        fi
    done
    return 1
}
selects_repo_via_prefix() {
    local prev=""
    local arg
    for arg in "\$@"; do
        if [[ "\$prev" == "-C" && "\$arg" == "$repo" ]]; then
            return 0
        fi
        if [[ "\$arg" == "-C$repo" ]]; then
            return 0
        fi
        prev="\$arg"
    done
    return 1
}
if has_arg diff "\$@" && has_arg --cached "\$@" && has_arg --name-only "\$@" && [[ "\$GIT_DIR" == "$repo/.git" && "\$GIT_WORK_TREE" == "$repo" ]]; then
    printf '%s\0' "$staged_files" | tr '\n' '\0'
    exit 0
fi
if has_arg diff "\$@" && has_arg --cached "\$@" && has_arg --name-only "\$@" && selects_repo_via_prefix "\$@"; then
    printf '%s\0' "$staged_files" | tr '\n' '\0'
    exit 0
fi
if has_arg diff "\$@" && has_arg --cached "\$@" && has_arg --name-only "\$@"; then
    printf '%s\0' "$default_files" | tr '\n' '\0'
    exit 0
fi
/usr/bin/git "\$@"
EOF
	chmod +x "$MOCK_DIR/git"
}

# Helper: Replace jq with a wrapper that records one line per decoder call.
# Only decoder invocations are counted, so the tally does not drift when the
# shared parser wrapper or the bats harness changes how often it calls jq.
mock_jq_counting_calls() {
	local counter_file="$1"

	: >"$counter_file"
	cat >"$MOCK_DIR/jq" <<EOF
#!/bin/bash
case "\$*" in
	*"def context_tokens"*) printf 'call\n' >>"$counter_file" ;;
esac
exec "$REAL_JQ" "\$@"
EOF
	chmod +x "$MOCK_DIR/jq"
}

# Helper: Replace jq with a wrapper that drops trailing NUL-delimited tokens
# from the commit-context decoder's output, simulating a truncated stream.
# The decoder is recognized by a definition it cannot work without, so tidying
# a comment can never silently turn the truncation tests into no-ops.
mock_jq_truncating_decoder() {
	local dropped_tokens="$1"

	cat >"$MOCK_DIR/jq" <<EOF
#!/bin/bash
set -o pipefail
for arg in "\$@"; do
	case "\$arg" in
		*"def context_tokens"*)
			"$REAL_JQ" "\$@" | python3 -c '
import sys

tokens = sys.stdin.buffer.read().split(b"\x00")[:-1]
kept = tokens[: max(0, len(tokens) - $dropped_tokens)]
sys.stdout.buffer.write(b"".join(token + b"\x00" for token in kept))
'
			exit \$?
			;;
	esac
done
exec "$REAL_JQ" "\$@"
EOF
	chmod +x "$MOCK_DIR/jq"
}

# Helper to run hook with given command
run_hook() {
	run_safety_hook "$HOOK" "$1"
}

run_hook_with_system_bash() {
	local command="$1"
	local working_dir="${2:-$PWD}"
	make_bash_input "$command" | (cd "$working_dir" && /bin/bash "$HOOK")
}

run_hook_missing_python_parser() {
	run_safety_hook_without_python_parser "$HOOK" "$1"
}

run_hook_with_repo_env() {
	local repo="$1"
	local cmd="$2"
	make_bash_input "$cmd" | env GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" bash "$HOOK"
}

setup_real_commit_repo() {
	REAL_COMMIT_REPO="$(mktemp -d)"
	git -C "$REAL_COMMIT_REPO" init -q
	git -C "$REAL_COMMIT_REPO" config user.email test@example.com
	git -C "$REAL_COMMIT_REPO" config user.name "Hook Test"
	printf 'base\n' >"$REAL_COMMIT_REPO/notes.txt"
	printf 'base\n' >"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add notes.txt REVIEW_OVERVIEW.md
	git -C "$REAL_COMMIT_REPO" commit -qm "base"
}

PARSER_FIXTURES="$BATS_TEST_DIRNAME/fixtures/git-command-parser-cases.json"

setup_review_parser_fixture_mock() {
	local case_json="$1"
	local review_mock
	review_mock="$(printf '%s\n' "$case_json" | jq -r '.reviewMock')"

	case "$review_mock" in
		stagedArtifact)
			mock_git_staged "REVIEW_OVERVIEW.md"
			;;
		repoArtifact)
			mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
			;;
		repoArtifactWithDefaultNotes)
			mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
			;;
		*)
			printf 'Unknown review fixture mock "%s"\n' "$review_mock" >&2
			return 1
			;;
	esac
}

assert_review_parser_fixture_decision() {
	local case_name="$1"
	local mode="$2"
	local expected="$3"

	case "$expected" in
		allow)
			if [ "$status" -ne 0 ] || [ -n "$output" ]; then
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

@test "blocks malformed hook input" {
	run bash "$HOOK" <<<'{"tool_input":'
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks malformed parser output" {
	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" '{}'
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks malformed commit context fields" {
	run run_safety_hook_with_parser_output \
		"$HOOK" \
		"git commit -m 'test'" \
		'[{"git_args":{},"git_env":[]}]'
	is_blocked
	[[ "$output" == *"Unable to safely decode git commit context"* ]]
	[[ "$output" == *"commit-context field contract"* ]]
}

@test "names the failing contract for every malformed commit context field type" {
	local parser_output

	while IFS= read -r parser_output; do
		run run_safety_hook_with_parser_output \
			"$HOOK" \
			"git commit -m 'test'" \
			"$parser_output"
		if ! is_blocked; then
			printf 'Expected malformed context to be blocked: %s\n' "$parser_output" >&2
			return 1
		fi
		if [[ "$output" != *"commit-context field contract"* ]]; then
			printf 'Expected contract reason for %s, got: %s\n' "$parser_output" "$output" >&2
			return 1
		fi
	done < <(printf '%s\n' \
		'["not-an-object"]' \
		'[{"git_args":{}}]' \
		'[{"git_env":[1]}]' \
		'[{"pathspecs":"REVIEW_OVERVIEW.md"}]' \
		'[{"selection_mode":[]}]' \
		'[{"pathspec_from_file":null}]' \
		'[{"pathspec_file_nul":"true"}]' \
		'[{"parse_error":5}]')
}

@test "blocks commit contexts carrying a NUL byte instead of truncating them" {
	local parser_output
	parser_output="$(jq -nc '[{git_args: ["-C", ("re" + ([0] | implode) + "po")], git_env: []}]')"

	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$parser_output"

	is_blocked
	[[ "$output" == *"Unable to safely decode git commit context"* ]]
	[[ "$output" == *"NUL byte"* ]]
}

@test "preserves special characters when decoding commit context arrays" {
	local artifact_list="$MOCK_DIR/artifacts.txt"
	local newline_path=$'first line\nsecond line.txt'
	local spaced_artifact='odd name.md'
	local parser_output

	setup_real_commit_repo
	printf 'base\n' >"$REAL_COMMIT_REPO/$spaced_artifact"
	printf 'base\n' >"$REAL_COMMIT_REPO/$newline_path"
	git -C "$REAL_COMMIT_REPO" add "$spaced_artifact" "$newline_path"
	git -C "$REAL_COMMIT_REPO" commit -qm "add special-character paths"
	printf 'change\n' >>"$REAL_COMMIT_REPO/$spaced_artifact"
	printf 'change\n' >>"$REAL_COMMIT_REPO/$newline_path"
	printf '%s\n' "$spaced_artifact" >"$artifact_list"
	export CONFIRM_REVIEW_ARTIFACT_LIST_FILE="$artifact_list"

	parser_output="$(
		jq -nc \
			--arg repo "$REAL_COMMIT_REPO" \
			--arg newline_path "$newline_path" \
			--arg spaced_artifact "$spaced_artifact" \
			'[{
				git_args: ["-C", $repo],
				git_env: [],
				selection_mode: "only",
				pathspecs: [$newline_path, $spaced_artifact]
			}]'
	)"

	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$parser_output"

	is_blocked
	[[ "$output" == *"$spaced_artifact"* ]]
}

@test "blocks when the decoded context stream ends before its context count" {
	mock_git_staged "notes.txt"
	mock_jq_truncating_decoder 4

	run run_safety_hook_with_parser_output \
		"$HOOK" \
		"git commit -m 'test'" \
		'[{"git_args":[],"git_env":[]},{"git_args":[],"git_env":[]}]'
	is_blocked
	# Assert the specific reason: the shared prefix is also what an empty or
	# unreadable records file produces, so matching it alone proves nothing.
	[[ "$output" == *"ended before the parser's context count"* ]]
}

@test "blocks when the decoded context stream loses its end marker" {
	mock_git_staged "notes.txt"
	mock_jq_truncating_decoder 1

	run run_safety_hook_with_parser_output \
		"$HOOK" \
		"git commit -m 'test'" \
		'[{"git_args":[],"git_env":[]},{"git_args":[],"git_env":[]}]'
	is_blocked
	# A satisfied context count with a missing frame is the opposite condition
	# from the test above, and must not report the same reason.
	[[ "$output" == *"missing their end marker"* ]]
}

@test "blocks when parser output carries more than one JSON document" {
	local parser_output

	setup_real_commit_repo
	printf 'change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add REVIEW_OVERVIEW.md

	# jq applies a filter once per input document. A leading empty array must
	# not let a later document's commit context go uninspected.
	parser_output="$(
		printf '[]\n%s' "$(
			jq -nc --arg repo "$REAL_COMMIT_REPO" '[{git_args: ["-C", $repo], git_env: []}]'
		)"
	)"

	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$parser_output"

	is_blocked
	[[ "$output" == *"commit-context field contract"* ]]
}

@test "blocks when the private inspection workspace cannot be created" {
	run env TMPDIR="$BATS_TEST_TMPDIR/absent-tmpdir" bash "$HOOK" \
		<<<"$(make_bash_input "git commit -m 'test'")"

	is_blocked
	[[ "$output" == *"private workspace for commit inspection"* ]]
}

@test "names the failing step when staged commit content cannot be read" {
	run run_safety_hook_with_parser_output \
		"$HOOK" \
		"git commit -m 'test'" \
		'[{"git_args":["-C","/nonexistent-hook-repo"],"git_env":[]}]'

	is_blocked
	[[ "$output" == *"Unable to read the already staged commit content"* ]]
}

@test "names the failing step when the repository index is not a regular file" {
	local parser_output

	setup_real_commit_repo
	rm -f "$REAL_COMMIT_REPO/.git/index"
	mkdir "$REAL_COMMIT_REPO/.git/index"
	parser_output="$(
		jq -nc --arg repo "$REAL_COMMIT_REPO" \
			'[{git_args: ["-C", $repo], git_env: [], selection_mode: "all", pathspecs: []}]'
	)"

	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$parser_output"

	is_blocked
	[[ "$output" == *"Repository index is not a regular file"* ]]
}

@test "decodes commit contexts with a bounded number of jq processes" {
	local counter="$BATS_TEST_TMPDIR/jq-calls"
	local small large small_calls large_calls

	mock_git_staged "notes.txt"
	small="$(jq -nc '[{git_args: [], git_env: [], pathspecs: [], selection_mode: "index"}]')"
	large="$(jq -nc '[{
		git_args: [range(200) | "--ignored-\(.)"],
		git_env: [range(200) | "IGNORED_\(.)=value"],
		pathspecs: [range(200) | "path-\(.)"],
		selection_mode: "index"
	}]')"

	mock_jq_counting_calls "$counter"
	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$small"
	[ "$status" -eq 0 ]
	small_calls="$(grep -c . "$counter")"

	mock_jq_counting_calls "$counter"
	run run_safety_hook_with_parser_output "$HOOK" "git commit -m 'test'" "$large"
	[ "$status" -eq 0 ]
	large_calls="$(grep -c . "$counter")"

	# Decoding must not scale with array length: no jq process per element.
	[ "$small_calls" -eq "$large_calls" ]
	[ "$large_calls" -eq 1 ]
}

@test "commit context decoding does not depend on dev fd process substitution" {
	run grep -F '< <(' "$HOOK"
	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "blocks command when jq is unavailable" {
	run run_safety_hook_without_jq "$HOOK" "git commit -m 'test commit'"
	is_blocked
	[[ "$output" == *"jq not found"* ]]
	[[ "$output" == *"refusing to run safety hook without JSON parsing"* ]]
	[[ "$output" == *"Install jq or disable this hook explicitly"* ]]
	[[ "$output" != *"allowing command unchanged"* ]]
}

@test "allows disabled hook when jq is unavailable" {
	run run_disabled_safety_hook_without_jq "$HOOK" "confirm-review-responses" "git commit -m 'test commit'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks when python parser file is unavailable" {
	run run_hook_missing_python_parser "git commit -m 'test commit'"
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks commands when python3 is unavailable" {
	run run_safety_hook_without_python "$HOOK" "ls -la" "$MOCK_DIR/git"
	is_blocked
	[[ "$output" == *"python3 not found"* ]]
	[[ "$output" == *"refusing to run safety hook without the shared git command parser"* ]]
	[[ "$output" == *"Install python3 or disable this hook explicitly"* ]]
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

@test "shared parser fixtures match review-response artifact decisions" {
	local case_json case_name command expected mode

	# Common shell/git parser cases belong in the shared fixture file so parser
	# consolidation can compare both hook consumers against the same baseline.
	while IFS= read -r case_json; do
		case_name="$(printf '%s\n' "$case_json" | jq -r '.name')"
		command="$(printf '%s\n' "$case_json" | jq -r '.command')"
		expected="$(printf '%s\n' "$case_json" | jq -r '.reviewResponseExpected')"
		while IFS= read -r mode; do
			setup_review_parser_fixture_mock "$case_json"
			case "$mode" in
				python)
					run run_hook "$command"
					;;
				*)
					printf 'Unknown fixture python mode "%s" for "%s"\n' "$mode" "$case_name" >&2
					return 1
					;;
			esac
			assert_review_parser_fixture_decision "$case_name" "$mode" "$expected"
		done < <(printf '%s\n' "$case_json" | jq -r '.pythonModes[]')
	done < <(jq -c '.cases[] | select(.reviewResponseExpected != null)' "$PARSER_FIXTURES")
}

@test "normalizes supported command prefixes before review-artifact policy" {
	local command
	mock_git_staged "REVIEW_OVERVIEW.md"

	while IFS= read -r command; do
		run run_hook "$command"
		if ! is_blocked; then
			printf 'Expected prefixed command to be blocked: %s\n' "$command" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
	done < <(safety_command_prefix_matrix "git commit -m test")
}

@test "preserves unguarded commit behavior across supported command prefixes" {
	local command
	mock_git_staged "notes.txt"

	while IFS= read -r command; do
		run run_hook "$command"
		if [ "$status" -ne 0 ] || [ -n "$output" ]; then
			printf 'Expected prefixed command to be allowed: %s\n' "$command" >&2
			return 1
		fi
	done < <(safety_command_prefix_matrix "git commit -m test")
}

@test "blocks review-artifact commit behind separated --attr-source" {
	mock_git_staged "REVIEW_OVERVIEW.md"

	run run_hook "git --attr-source HEAD commit -m test"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "blocks review-artifact commit behind --attr-source=<tree-ish>" {
	mock_git_staged "REVIEW_OVERVIEW.md"

	run run_hook "git --attr-source=HEAD commit -m test"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "preserves unguarded commit behavior behind --attr-source" {
	mock_git_staged "notes.txt"

	run run_hook "git --attr-source HEAD commit -m test"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails closed when --attr-source changes worktree pathspec selection" {
	local attr_source
	setup_real_commit_repo
	printf 'REVIEW_OVERVIEW.md review\n' >"$REAL_COMMIT_REPO/.gitattributes"
	git -C "$REAL_COMMIT_REPO" add .gitattributes
	git -C "$REAL_COMMIT_REPO" commit -qm "add attributes"
	printf 'REVIEW_OVERVIEW.md -review\nnotes.txt review\n' >"$REAL_COMMIT_REPO/.gitattributes"
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	printf 'ordinary change\n' >>"$REAL_COMMIT_REPO/notes.txt"

	for attr_source in "--attr-source HEAD" "--attr-source=HEAD"; do
		run run_hook "git -C $REAL_COMMIT_REPO $attr_source commit --only -m test ':(attr:review)'"
		if ! is_blocked || [[ "$output" != *"alter config or attributes"* ]]; then
			printf 'Expected attr-source prefix to fail closed: %s\n' "$attr_source" >&2
			return 1
		fi
		# The specific reason replaces the generic one instead of joining it.
		if [ "${#lines[@]}" -ne 1 ]; then
			printf 'Expected one reason for %s, got: %s\n' "$attr_source" "$output" >&2
			return 1
		fi
	done
}

@test "preserves shallow and no-literal-pathspec globals for commit inspection" {
	local artifact_list="$MOCK_DIR/artifacts.txt"
	setup_real_commit_repo
	printf 'literal base\n' >"$REAL_COMMIT_REPO/guard*.txt"
	printf 'guarded base\n' >"$REAL_COMMIT_REPO/guarded.txt"
	git -C "$REAL_COMMIT_REPO" add 'guard*.txt' guarded.txt
	git -C "$REAL_COMMIT_REPO" commit -qm "add pathspec fixtures"
	printf 'literal change\n' >>"$REAL_COMMIT_REPO/guard*.txt"
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/guarded.txt"
	printf 'guarded.txt\n' >"$artifact_list"
	export CONFIRM_REVIEW_ARTIFACT_LIST_FILE="$artifact_list"

	run run_hook "GIT_LITERAL_PATHSPECS=1 git -C $REAL_COMMIT_REPO --shallow-file $REAL_COMMIT_REPO/.git/shallow --no-literal-pathspecs commit --only -m test 'guard*.txt'"

	is_blocked
	[[ "$output" == *"guarded.txt"* ]]
}

@test "fails closed for commits behind an unknown git global option" {
	mock_git_staged "notes.txt"

	run run_hook "git --future-global value commit -m test"
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
}

@test "allows supported non-commit command behind legacy --super-prefix" {
	mock_git_staged "notes.txt"

	run run_hook "git --super-prefix sub/ submodule--helper status"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails closed for malformed supported command prefixes" {
	local command

	while IFS= read -r command; do
		run run_hook "$command"
		if ! is_blocked; then
			printf 'Expected malformed prefixed command to be blocked: %s\n' "$command" >&2
			return 1
		fi
		[[ "$output" == *"Unable to safely parse command"* ]]
	done < <(safety_malformed_prefix_matrix "git commit -m test")
}

@test "does not persist shell builtins through external command prefixes" {
	local prefix
	mock_git_staged_for_repo "other" "notes.txt" "REVIEW_OVERVIEW.md"

	while IFS= read -r prefix; do
		run run_hook "$prefix export GIT_DIR=other/.git GIT_WORK_TREE=other; git commit -m test"
		if ! is_blocked; then
			printf 'Expected external-wrapper export to leave the current repo selected: %s\n' "$prefix" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
	done < <(printf '%s\n' "timeout 1" "nice" "nohup" "env" "sudo" "exec" "command time")
}

@test "does not persist prefixed repo selection through a payload-less wrapper" {
	mock_git_staged_for_repo "other" "notes.txt" "REVIEW_OVERVIEW.md"

	run run_hook "GIT_DIR=other/.git GIT_WORK_TREE=other env -i; export GIT_DIR GIT_WORK_TREE; git commit -m test"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "preserves shell builtin state through the time keyword" {
	mock_git_staged_for_repo "other" "REVIEW_OVERVIEW.md" "notes.txt"

	run run_hook "time export GIT_DIR=other/.git GIT_WORK_TREE=other; git commit -m test"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "preserves shell builtin state through builtin lookup prefixes" {
	local prefix
	mock_git_staged_for_repo "other" "REVIEW_OVERVIEW.md" "notes.txt"

	while IFS= read -r prefix; do
		run run_hook "$prefix export GIT_DIR=other/.git GIT_WORK_TREE=other; git commit -m test"
		if ! is_blocked; then
			printf 'Expected builtin-lookup export to select the redirected repo: %s\n' "$prefix" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
	done < <(printf '%s\n' "command" "builtin")
}

@test "treats quoted and escaped time as an external command" {
	local prefix
	mock_git_staged_for_repo "other" "notes.txt" "REVIEW_OVERVIEW.md"

	while IFS= read -r prefix; do
		run run_hook "$prefix export GIT_DIR=other/.git GIT_WORK_TREE=other; git commit -m test"
		if ! is_blocked; then
			printf 'Expected non-keyword time to leave the current repo selected: %s\n' "$prefix" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
	done < <(printf '%s\n' '\time' '"time"' "'time'")
}

@test "exec -c clears prefixed repo selection" {
	mock_git_staged_for_repo "other" "notes.txt" "REVIEW_OVERVIEW.md"

	run run_hook "GIT_DIR=other/.git GIT_WORK_TREE=other exec -c git commit -m test"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
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

@test "allows git commit -a under the system bash with no git prefixes" {
	setup_real_commit_repo
	printf 'ordinary change\n' >>"$REAL_COMMIT_REPO/notes.txt"

	run run_hook_with_system_bash "git commit -a -m 'test commit'" "$REAL_COMMIT_REPO"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "ignores config-bearing git prefixes when checking staged files" {
	local repo marker
	repo="$(mktemp -d)"
	marker="$BATS_TEST_TMPDIR/fsmonitor-prefix-marker"
	rm -f "$marker"

	git -C "$repo" init -q
	touch "$repo/file.txt"
	git -C "$repo" add file.txt

	run run_hook "git -C $repo -c \"core.fsmonitor=touch $marker; false\" commit -m 'test'"
	rm -rf "$repo"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ ! -f "$marker" ]
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

@test "blocks git commit when COPY_REVIEW_OVERVIEW.md is staged" {
	mock_git_staged "COPY_REVIEW_OVERVIEW.md"
	run run_hook "git commit -m 'copy review staged'"
	is_blocked
	[[ "$output" == *"COPY_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when CONVENTION_REVIEW_OVERVIEW.md is staged" {
	mock_git_staged "CONVENTION_REVIEW_OVERVIEW.md"
	run run_hook "git commit -m 'convention review staged'"
	is_blocked
	[[ "$output" == *"CONVENTION_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when OVERENGINEERING_REVIEW_OVERVIEW.md is staged" {
	mock_git_staged "OVERENGINEERING_REVIEW_OVERVIEW.md"
	run run_hook "git commit -m 'overengineering review staged'"
	is_blocked
	[[ "$output" == *"OVERENGINEERING_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when CODEBASE_WEAKNESS_REPORT.md is staged" {
	mock_git_staged "CODEBASE_WEAKNESS_REPORT.md"
	run run_hook "git commit -m 'weakness report staged'"
	is_blocked
	[[ "$output" == *"CODEBASE_WEAKNESS_REPORT.md"* ]]
}

@test "blocks git commit when GITHUB_PR_REVIEW_OVERVIEW.md is staged" {
	mock_git_staged "GITHUB_PR_REVIEW_OVERVIEW.md"
	run run_hook "git commit -m 'github pr review staged'"
	is_blocked
	[[ "$output" == *"GITHUB_PR_REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when PR plan artifact matching glob is staged" {
	mock_git_staged "PR_PLAN_ADD_API_ERROR_HANDLING.md"
	run run_hook "git commit -m 'plan staged'"
	is_blocked
	[[ "$output" == *"PR_PLAN_ADD_API_ERROR_HANDLING.md"* ]]
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

@test "names an artifact once when several commit contexts stage it" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "git commit -m 'first' && git commit -m 'second'"
	is_blocked
	# Two contexts resolve to the same file, so the reason must not repeat it.
	[[ "$output" == *"commit: REVIEW_OVERVIEW.md."* ]]
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
	setup_real_commit_repo
	printf 'guarded staged change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add REVIEW_OVERVIEW.md

	run run_hook "git -C $REAL_COMMIT_REPO commit -a -m 'auto stage'"

	is_blocked
}

@test "blocks -a when a protected tracked file is only modified in the worktree" {
	setup_real_commit_repo
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"

	run run_hook "git -C $REAL_COMMIT_REPO commit -a -m 'auto stage'"

	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "selection inspection leaves the real index and object store unchanged" {
	local index_before index_after objects_before objects_after
	setup_real_commit_repo
	printf 'ordinary staged change\n' >>"$REAL_COMMIT_REPO/notes.txt"
	git -C "$REAL_COMMIT_REPO" add notes.txt
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	index_before="$(git hash-object "$REAL_COMMIT_REPO/.git/index")"
	objects_before="$(git -C "$REAL_COMMIT_REPO" count-objects -v | sed -n 's/^count: //p')"

	run run_hook "git -C $REAL_COMMIT_REPO commit -a -m 'auto stage'"

	is_blocked
	index_after="$(git hash-object "$REAL_COMMIT_REPO/.git/index")"
	objects_after="$(git -C "$REAL_COMMIT_REPO" count-objects -v | sed -n 's/^count: //p')"
	[ "$index_after" = "$index_before" ]
	[ "$objects_after" = "$objects_before" ]
}

@test "allows worktree selection when configured filters are inactive on selected paths" {
	local clean_marker="$MOCK_DIR/clean-filter-ran"
	local process_marker="$MOCK_DIR/process-filter-ran"
	setup_real_commit_repo
	git -C "$REAL_COMMIT_REPO" config filter.review.clean "touch $clean_marker; cat"
	git -C "$REAL_COMMIT_REPO" config filter.review.process "touch $process_marker; exit 1"
	printf 'REVIEW_OVERVIEW.md filter=review\n' >"$REAL_COMMIT_REPO/.gitattributes"
	printf 'ordinary selected change\n' >>"$REAL_COMMIT_REPO/notes.txt"

	run run_hook "git -C $REAL_COMMIT_REPO commit --only -m 'only notes' notes.txt"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$clean_marker" ]
	[ ! -e "$process_marker" ]
}

@test "fails closed without executing configured clean filters" {
	local marker="$MOCK_DIR/clean-filter-ran"
	setup_real_commit_repo
	git -C "$REAL_COMMIT_REPO" config filter.review.clean "touch $marker; cat"
	printf '*.md filter=review\n' >"$REAL_COMMIT_REPO/.gitattributes"
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"

	run run_hook "git -C $REAL_COMMIT_REPO commit -a -m 'auto stage'"

	is_blocked
	[[ "$output" == *"configured clean filters"* ]]
	# The specific reason replaces the generic one instead of joining it.
	[ "${#lines[@]}" -eq 1 ]
	[ ! -e "$marker" ]
}

@test "fails closed without executing configured process filters" {
	local marker="$MOCK_DIR/process-filter-ran"
	setup_real_commit_repo
	git -C "$REAL_COMMIT_REPO" config filter.review.process "touch $marker; exit 1"
	printf '*.md filter=review\n' >"$REAL_COMMIT_REPO/.gitattributes"
	printf 'guarded change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"

	run run_hook "git -C $REAL_COMMIT_REPO commit -a -m 'auto stage'"

	is_blocked
	[[ "$output" == *"configured clean filters"* ]]
	[ "${#lines[@]}" -eq 1 ]
	[ ! -e "$marker" ]
}

@test "blocks --include when it adds an unstaged protected file to staged content" {
	setup_real_commit_repo
	printf 'ordinary staged change\n' >>"$REAL_COMMIT_REPO/notes.txt"
	printf 'guarded included change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add notes.txt

	run run_hook "git -C $REAL_COMMIT_REPO commit --include -m 'include' REVIEW_OVERVIEW.md"

	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "allows --include to resolve the selected path in an unmerged index" {
	local base_branch
	setup_real_commit_repo
	base_branch="$(git -C "$REAL_COMMIT_REPO" branch --show-current)"
	git -C "$REAL_COMMIT_REPO" checkout -qb conflict-side
	printf 'side\n' >"$REAL_COMMIT_REPO/notes.txt"
	git -C "$REAL_COMMIT_REPO" commit -qam "side"
	git -C "$REAL_COMMIT_REPO" checkout -q "$base_branch"
	printf 'main\n' >"$REAL_COMMIT_REPO/notes.txt"
	git -C "$REAL_COMMIT_REPO" commit -qam "main"
	git -C "$REAL_COMMIT_REPO" merge conflict-side >/dev/null 2>&1 || true
	printf 'resolved\n' >"$REAL_COMMIT_REPO/notes.txt"

	run run_hook "git -C $REAL_COMMIT_REPO commit --include -m 'resolve' notes.txt"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks --only and -o when an unstaged protected file is selected" {
	local only_flag

	for only_flag in --only -o; do
		setup_real_commit_repo
		printf 'ordinary staged change\n' >>"$REAL_COMMIT_REPO/notes.txt"
		printf 'guarded selected change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
		git -C "$REAL_COMMIT_REPO" add notes.txt

		run run_hook "git -C $REAL_COMMIT_REPO commit $only_flag -m 'only' REVIEW_OVERVIEW.md"

		if ! is_blocked; then
			printf 'Expected %s selection to block, got status %s and output: %s\n' "$only_flag" "$status" "$output" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
		rm -rf "$REAL_COMMIT_REPO"
		REAL_COMMIT_REPO=""
	done
}

@test "allows --only when a staged protected file is outside the selected commit set" {
	setup_real_commit_repo
	printf 'ordinary selected change\n' >>"$REAL_COMMIT_REPO/notes.txt"
	printf 'guarded staged change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add REVIEW_OVERVIEW.md

	run run_hook "git -C $REAL_COMMIT_REPO commit --only -m 'only notes' -- notes.txt"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "honors pathspecs after the commit option separator" {
	setup_real_commit_repo
	printf 'ordinary staged change\n' >>"$REAL_COMMIT_REPO/notes.txt"
	printf 'guarded selected change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
	git -C "$REAL_COMMIT_REPO" add notes.txt

	run run_hook "git -C $REAL_COMMIT_REPO commit -m 'selected' -- REVIEW_OVERVIEW.md"

	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "honors line and nul delimited pathspec files" {
	local pathspec_args

	for pathspec_args in \
		"--pathspec-from-file=$MOCK_DIR/pathspecs.txt" \
		"--pathspec-from-file=$MOCK_DIR/pathspecs.bin --pathspec-file-nul"
	do
		setup_real_commit_repo
		printf 'ordinary staged change\n' >>"$REAL_COMMIT_REPO/notes.txt"
		printf 'guarded selected change\n' >>"$REAL_COMMIT_REPO/REVIEW_OVERVIEW.md"
		git -C "$REAL_COMMIT_REPO" add notes.txt
		printf 'REVIEW_OVERVIEW.md\n' >"$MOCK_DIR/pathspecs.txt"
		printf 'REVIEW_OVERVIEW.md\0' >"$MOCK_DIR/pathspecs.bin"

		run run_hook "git -C $REAL_COMMIT_REPO commit -m 'pathspec file' $pathspec_args"

		if ! is_blocked; then
			printf 'Expected pathspec selection to block: %s\n' "$pathspec_args" >&2
			return 1
		fi
		[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
		rm -rf "$REAL_COMMIT_REPO"
		REAL_COMMIT_REPO=""
	done
}

@test "blocks unsupported interactive commit selection explicitly" {
	run run_hook "git commit --patch -m 'partial'"

	is_blocked
	[[ "$output" == *"Unable to safely inspect git commit content selection"* ]]
}

@test "blocks dynamic commit pathspec selection" {
	run run_hook "git commit --only -m 'dynamic' \$(printf REVIEW_OVERVIEW.md)"

	is_blocked
	[[ "$output" == *"Unable to safely inspect git commit content selection"* ]]
}

@test "blocks abbreviated long commit options that could consume pathspecs" {
	run run_hook "git commit --mes notes.txt"

	is_blocked
	[[ "$output" == *"unrecognized commit option --mes"* ]]
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

@test "allows env -u clearing repo selection before git commit" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
	run run_hook "GIT_DIR=repo/.git GIT_WORK_TREE=repo env -u GIT_DIR -u GIT_WORK_TREE git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows env -i clearing repo selection before git commit" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
	run run_hook "GIT_DIR=repo/.git GIT_WORK_TREE=repo env -i git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows env -u clearing exported repo selection before git commit" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
	run run_hook_with_repo_env "repo" "env -u GIT_DIR -u GIT_WORK_TREE git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "allows env -i clearing exported repo selection before git commit" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
	run run_hook_with_repo_env "repo" "env -i git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "checks staged artifacts in repo selected via exported GIT_DIR and GIT_WORK_TREE" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook_with_repo_env "repo" "git commit -m 'test'"
	is_blocked
}

@test "blocks git commit when repo selection is exported in an earlier shell segment" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo && git commit -m 'test'"
	is_blocked
}

@test "blocks git commit when repo selection is exported from earlier shell assignments" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "GIT_DIR=repo/.git; GIT_WORK_TREE=repo; export GIT_DIR GIT_WORK_TREE && git commit -m 'test'"
	is_blocked
}

@test "blocks git commit after exported repo selection is nameref-unset" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo && unset -n GIT_DIR GIT_WORK_TREE && git commit -m 'test'"
	is_blocked
}

@test "allows git commit after exported repo selection is unset" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo && unset GIT_DIR GIT_WORK_TREE && git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks git commit after exported repo selection is function-unset" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo && unset -f GIT_DIR GIT_WORK_TREE && git commit -m 'test'"
	is_blocked
}

@test "allows git commit when function-unset does not retain prefixed repo selection" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "GIT_DIR=repo/.git GIT_WORK_TREE=repo unset -f nope && export GIT_DIR GIT_WORK_TREE && git commit -m 'test'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks git commit when piped export does not actually retarget the repo" {
	mock_git_staged_for_repo "repo" "" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo | git commit -m 'test'"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit when subshell export does not actually retarget the repo" {
	mock_git_staged_for_repo "repo" "" "REVIEW_OVERVIEW.md"
	run run_hook "(export GIT_DIR=repo/.git GIT_WORK_TREE=repo) && git commit -m 'test'"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "blocks chained git commit when artifact is staged" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "git status && git commit -m 'test'"
	is_blocked
}

@test "blocks git commit inside if condition when artifact is staged" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "if git commit -m 'test'; then echo ok; fi"
	is_blocked
}

@test "blocks git commit inside subshell grouping when artifact is staged" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "(git commit -m 'test')"
	is_blocked
}

@test "blocks shell-wrapped git commit when artifact is staged" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "sh -c 'git commit -m \"test\"'"
	is_blocked
}

@test "normalizes ANSI-C shell payloads before checking commit contexts" {
	local command
	mock_git_staged "REVIEW_OVERVIEW.md"
	for command in \
		"bash -c \$'git commit -m test'" \
		"bash -c \$'git\\x20commit -m test'" \
		$'bash -c $\'echo ok\ngit commit -m test\'' \
		"bash -O extglob -c \$'git commit -m test'" \
		"env FOO=bar bash -c \$'git commit -m test'"
	do
		run run_hook "$command"
		is_blocked
	done

	run run_hook "bash -c \$'echo safe'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "fails closed for malformed ANSI-C shell commit payload" {
	run run_hook "bash -c \$'git commit -m test"
	is_blocked
}

@test "blocks shell alias git commit when parser cannot prove target" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook $'shopt -s expand_aliases\nalias g=git\ng commit -m test'
	is_blocked
	[[ "$output" == *"Unable to safely parse command"* ]]
}

@test "blocks nested shell commit contexts when later context stages artifact" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md" "notes.txt"
	run run_hook "sh -c 'git commit -m \"default\"; git -C repo commit -m \"selected\"'"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit inside command substitution when exported repo selection is inherited" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "export GIT_DIR=repo/.git GIT_WORK_TREE=repo && out=\$(git commit -m 'test')"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "allows git commit text inside heredoc command substitution" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "cat <<'EOF'
\$(git commit -m 'test')
EOF"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "blocks git commit inside unquoted heredoc command substitution" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "cat <<EOF
\$(git commit -m 'test')
EOF"
	is_blocked
	[[ "$output" == *"REVIEW_OVERVIEW.md"* ]]
}

@test "blocks git commit with prefixed command substitution when artifact is staged" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "MSG=\$(cat /tmp/msg) git -C repo commit -m 'test'"
	is_blocked
}

@test "blocks git commit inside command substitution when artifact is staged" {
	mock_git_staged "REVIEW_OVERVIEW.md"
	run run_hook "out=\$(git commit -m 'test')"
	is_blocked
}

@test "blocks git commit inside command substitution when repo selection is inherited through sh -c" {
	local repo
	repo="$(mktemp -d)"
	git -C "$repo" init -q
	touch "$repo/REVIEW_OVERVIEW.md"
	git -C "$repo" add REVIEW_OVERVIEW.md

	run run_hook "env GIT_DIR=$repo/.git GIT_WORK_TREE=$repo sh -c 'echo \$(git commit -m \"test\")'"
	rm -rf "$repo"

	is_blocked
}

@test "blocks git -C commit when artifact is staged" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "git -C repo commit -m 'test'"
	is_blocked
}

@test "blocks git -C command substitution when repo selection is dynamic" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "git -C \$(printf repo) commit -m 'test'"
	is_blocked
	[[ "$output" == *"Unable to safely determine the git commit target"* ]]
}

@test "blocks GIT_DIR command substitution when repo selection is dynamic" {
	mock_git_staged_for_repo "repo" "REVIEW_OVERVIEW.md"
	run run_hook "GIT_DIR=\$(printf repo/.git) GIT_WORK_TREE=repo git commit -m 'test'"
	is_blocked
	[[ "$output" == *"Unable to safely determine the git commit target"* ]]
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

@test "checks staged artifacts in repo selected via GIT_DIR and GIT_WORK_TREE without executing fsmonitor config" {
	local repo marker
	repo="$(mktemp -d)"
	marker="$BATS_TEST_TMPDIR/fsmonitor-config-marker"
	rm -f "$marker"

	git -C "$repo" init -q
	touch "$repo/REVIEW_OVERVIEW.md"
	git -C "$repo" add REVIEW_OVERVIEW.md
	git -C "$repo" config core.fsmonitor "touch $marker; false"

	run run_hook "GIT_DIR=$repo/.git GIT_WORK_TREE=$repo git commit -m 'test'"
	rm -rf "$repo"

	is_blocked
	[ ! -f "$marker" ]
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

@test "blocks env -u GIT_INDEX_FILE after explicit assignment" {
	local repo
	repo="$(mktemp -d)"
	git -C "$repo" init -q
	touch "$repo/REVIEW_OVERVIEW.md"
	git -C "$repo" add REVIEW_OVERVIEW.md
	: >"$repo/alt.index"

	run run_hook "GIT_INDEX_FILE=$repo/alt.index env -u GIT_INDEX_FILE git -C $repo commit -m 'test'"
	rm -rf "$repo"

	is_blocked
}

# ============================================================================
# CONFIGURABLE ARTIFACT LIST
# ============================================================================

@test "uses custom artifact list from CONFIRM_REVIEW_ARTIFACT_LIST_FILE" {
	custom_list="$MOCK_DIR/custom-artifacts.txt"
	cat >"$custom_list" <<'EOF'
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
