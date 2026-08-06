#!/usr/bin/env bats
# Tests for kramme:git:worktree helper

load 'test_helper/common'

setup() {
	SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/kramme:git:worktree/scripts/worktree-helper.sh"
	TMP_DIR="$(mktemp -d)"
	ROOT="$TMP_DIR/conductor/workspaces/root"
	CHILD="$TMP_DIR/conductor/workspaces/child"

	init_test_git_repo "$ROOT" --file README.md
	cd "$ROOT"
	git branch child
	git worktree add -q "$CHILD" child
}

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "refuses relative Conductor workspace removal without allow flag" {
	run "$SCRIPT" remove --path ../child --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$CHILD" ]
}

@test "allows confirmed Conductor workspace removal with allow flag" {
	run "$SCRIPT" remove --path ../child --yes --allow-conductor

	[ "$status" -eq 0 ]
	[ ! -d "$CHILD" ]
}

@test "list does not flag a non-Conductor worktree path" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	mkdir -p "$(dirname "$OTHER")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child

	run "$SCRIPT" list

	[ "$status" -eq 0 ]
	line=$(printf '%s\n' "$output" | grep -F "$OTHER")
	[[ "$line" != *"conductor-workspace"* ]]
}

@test "allows removing a non-Conductor worktree without allow-conductor flag" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	mkdir -p "$(dirname "$OTHER")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child

	run "$SCRIPT" remove --path "$OTHER" --yes

	[ "$status" -eq 0 ]
	[ ! -d "$OTHER" ]
}

@test "refuses Conductor workspace removal when the path contains spaces" {
	SPACED="$TMP_DIR/conductor/workspaces/space child"
	git branch space-branch
	git worktree add -q "$SPACED" space-branch

	run "$SCRIPT" remove --path "$SPACED" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$SPACED" ]
}

@test "list classifies a Conductor workspace path containing spaces" {
	SPACED="$TMP_DIR/conductor/workspaces/space child"
	git branch space-branch
	git worktree add -q "$SPACED" space-branch

	run "$SCRIPT" list

	[ "$status" -eq 0 ]
	line=$(printf '%s\n' "$output" | grep -F "$SPACED")
	[[ "$line" == *"conductor-workspace"* ]]
}
