#!/usr/bin/env bats
# Direct tests for hooks/lib/git-parse-utils.sh.

load 'test_helper/common'

setup() {
	LIB="$BATS_TEST_DIRNAME/../hooks/lib/git-parse-utils.sh"
	source "$LIB"
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

@test "reports whether an array contains a value" {
	run array_contains "needle" "hay" "needle" "stack"
	[ "$status" -eq 0 ]

	run array_contains "missing" "hay" "needle" "stack"
	[ "$status" -eq 1 ]
}
