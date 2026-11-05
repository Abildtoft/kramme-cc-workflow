#!/usr/bin/env bats
# Tests for the shared assert_required_contracts_registered helper

load 'test_helper/common'

setup() {
	REGISTERED_CONTRACT="workflow-artifact-cleanup-names"
}

@test "accepts a contract that the registry declares" {
	assert_required_contracts_registered "$REGISTERED_CONTRACT"
}

@test "reports every unregistered contract in one sorted diagnostic" {
	run assert_required_contracts_registered \
		zz-second-absent-contract \
		"$REGISTERED_CONTRACT" \
		zz-first-absent-contract

	[ "$status" -ne 0 ]
	[[ "$output" == *"missing required_file_contracts: zz-first-absent-contract, zz-second-absent-contract"* ]]
	[[ "$output" != *"$REGISTERED_CONTRACT"* ]]
}

# Guidance suites call the helper between a `run` and its `[ "$status" -eq 0 ]` assertion,
# so it must not run through `run` itself or change the directory the suite works from.
@test "leaves the caller's status and working directory untouched" {
	local before_pwd="$PWD"

	run false
	assert_required_contracts_registered "$REGISTERED_CONTRACT"

	[ "$status" -eq 1 ]
	[ "$PWD" = "$before_pwd" ]
}
