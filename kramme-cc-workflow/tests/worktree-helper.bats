#!/usr/bin/env bats
# Tests for kramme:git:worktree helper

setup() {
	SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/kramme:git:worktree/scripts/worktree-helper.sh"
	TMP_DIR="$(mktemp -d)"
	ROOT="$TMP_DIR/conductor/workspaces/root"
	CHILD="$TMP_DIR/conductor/workspaces/child"

	mkdir -p "$ROOT"
	cd "$ROOT"
	git init -q
	git config user.email "test@example.com"
	git config user.name "Test User"
	printf 'base\n' >README.md
	git add README.md
	git commit -q -m "initial"
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
