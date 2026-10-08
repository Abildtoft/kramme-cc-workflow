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

assert_worktree_registered() {
	local path="$1"
	local physical_parent
	physical_parent=$(cd "$(dirname "$path")" && pwd -P)
	git worktree list --porcelain | grep -Fqx "worktree $physical_parent/$(basename "$path")"
}

assert_worktree_not_registered() {
	! assert_worktree_registered "$1"
}

@test "refuses relative Conductor workspace removal without allow flag" {
	run "$SCRIPT" remove --path ../child --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$CHILD" ]
	grep -Fqx base "$CHILD/README.md"
}

@test "new worktree starts from this repository's configured development workbench" {
	ORIGIN="$TMP_DIR/origin.git"
	git init -q --bare "$ORIGIN"
	git remote add origin "$ORIGIN"
	git push -q origin main
	git switch -q -c development main
	printf 'development\n' > development.txt
	git add development.txt
	git commit -qm 'Add development change'
	git push -q origin development
	git switch -q main
	git config --local kramme.baseBranch development
	BIN_DIR="$TMP_DIR/bin"
	mkdir -p "$BIN_DIR"
	printf '#!/bin/sh\nprintf "main\\n"\n' > "$BIN_DIR/gh"
	chmod +x "$BIN_DIR/gh"
	NEW_WORKTREE="$TMP_DIR/elsewhere/new-work"
	mkdir -p "$(dirname "$NEW_WORKTREE")"

	run env PATH="$BIN_DIR:$PATH" CONDUCTOR_DEFAULT_BRANCH=main "$SCRIPT" create --path "$NEW_WORKTREE" --branch new-work

	[ "$status" -eq 0 ]
	[ -f "$NEW_WORKTREE/development.txt" ]
	[ "$(git -C "$NEW_WORKTREE" rev-parse HEAD)" = "$(git rev-parse development)" ]
}

@test "new worktree falls back to HEAD in a repository without origin or configured workbench" {
	NEW_WORKTREE="$TMP_DIR/elsewhere/local-work"

	run env -u CONDUCTOR_DEFAULT_BRANCH "$SCRIPT" create --path "$NEW_WORKTREE" --branch local-work

	[ "$status" -eq 0 ]
	[ "$(git -C "$NEW_WORKTREE" rev-parse HEAD)" = "$(git rev-parse HEAD)" ]
	[ -f "$NEW_WORKTREE/README.md" ]
}

@test "new worktree does not fall back to HEAD when a configured workbench is unavailable" {
	git config --local kramme.baseBranch development
	NEW_WORKTREE="$TMP_DIR/elsewhere/invalid-work"

	run "$SCRIPT" create --path "$NEW_WORKTREE" --branch invalid-work

	[ "$status" -eq 1 ]
	[ ! -e "$NEW_WORKTREE" ]
}

@test "new worktree can use a cached workbench when fetch fails" {
	ORIGIN="$TMP_DIR/origin.git"
	git init -q --bare "$ORIGIN"
	git remote add origin "$ORIGIN"
	git push -q origin main
	git switch -q -c development main
	printf 'development\n' > development.txt
	git add development.txt
	git commit -qm 'Add development change'
	git push -q origin development
	git fetch -q origin development:refs/remotes/origin/development
	git switch -q main
	git config --local kramme.baseBranch development
	git remote set-url origin "$TMP_DIR/missing-origin.git"
	NEW_WORKTREE="$TMP_DIR/elsewhere/offline-work"

	run "$SCRIPT" create --path "$NEW_WORKTREE" --branch offline-work

	[ "$status" -eq 0 ]
	[[ "$output" == *"using existing refs/remotes/origin/development"* ]]
	[ -f "$NEW_WORKTREE/development.txt" ]
}

@test "new worktree can start from a workbench unrelated to current HEAD" {
	ORIGIN="$TMP_DIR/origin.git"
	git init -q --bare "$ORIGIN"
	git remote add origin "$ORIGIN"
	git push -q origin main
	git switch -q --orphan pages
	printf 'pages\n' > pages.txt
	git add pages.txt
	git commit -qm 'Start pages history'
	NEW_WORKTREE="$TMP_DIR/elsewhere/independent-work"

	run "$SCRIPT" create --path "$NEW_WORKTREE" --branch independent-work

	[ "$status" -eq 0 ]
	[ -f "$NEW_WORKTREE/README.md" ]
	[ ! -f "$NEW_WORKTREE/pages.txt" ]
}

@test "allows confirmed Conductor workspace removal with allow flag" {
	run "$SCRIPT" remove --path ../child --yes --allow-conductor

	[ "$status" -eq 0 ]
	[ ! -d "$CHILD" ]
	assert_worktree_not_registered "$CHILD"
}

@test "refuses a final symlink to a Conductor workspace without allow flag" {
	ALIAS_DIR="$TMP_DIR/elsewhere"
	ALIAS="$ALIAS_DIR/child-alias"
	mkdir -p "$ALIAS_DIR"
	ln -s "$CHILD" "$ALIAS"

	run "$SCRIPT" remove --path "$ALIAS" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$CHILD" ]
	grep -Fqx base "$CHILD/README.md"
	assert_worktree_registered "$CHILD"
}

@test "refuses a chained symlink to a Conductor workspace without allow flag" {
	ALIAS_DIR="$TMP_DIR/elsewhere"
	FIRST_ALIAS="$ALIAS_DIR/first alias"
	SECOND_ALIAS="$ALIAS_DIR/second alias"
	mkdir -p "$ALIAS_DIR"
	ln -s "$CHILD" "$FIRST_ALIAS"
	ln -s "$FIRST_ALIAS" "$SECOND_ALIAS"

	run "$SCRIPT" remove --path "$SECOND_ALIAS" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$CHILD" ]
	grep -Fqx base "$CHILD/README.md"
	assert_worktree_registered "$CHILD"
}

@test "allows confirmed Conductor workspace removal through an alias" {
	ALIAS_DIR="$TMP_DIR/elsewhere"
	ALIAS="$ALIAS_DIR/child-alias"
	mkdir -p "$ALIAS_DIR"
	ln -s "$CHILD" "$ALIAS"

	run "$SCRIPT" remove --path "$ALIAS" --yes --allow-conductor

	[ "$status" -eq 0 ]
	[ ! -d "$CHILD" ]
	assert_worktree_not_registered "$CHILD"
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
	assert_worktree_not_registered "$OTHER"
}

@test "allows removing a non-Conductor worktree through an alias" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS_DIR="$TMP_DIR/aliases"
	ALIAS="$ALIAS_DIR/normal-child"
	mkdir -p "$(dirname "$OTHER")" "$ALIAS_DIR"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$ALIAS"

	run "$SCRIPT" remove --path "$ALIAS" --yes

	[ "$status" -eq 0 ]
	[ ! -d "$OTHER" ]
	assert_worktree_not_registered "$OTHER"
}

@test "allows a bare relative worktree path when CDPATH is set" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS="$ROOT/normal-child"
	mkdir -p "$(dirname "$OTHER")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$ALIAS"

	run env CDPATH=. "$SCRIPT" remove --path normal-child --yes

	[ "$status" -eq 0 ]
	[ ! -d "$OTHER" ]
	assert_worktree_not_registered "$OTHER"
}

@test "allows an option-like relative worktree path" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS="$ROOT/-P"
	mkdir -p "$(dirname "$OTHER")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$ALIAS"

	run "$SCRIPT" remove --path -P --yes

	[ "$status" -eq 0 ]
	[ ! -d "$OTHER" ]
	assert_worktree_not_registered "$OTHER"
}

@test "allows a spaced non-Conductor worktree through a relative path" {
	OTHER="$TMP_DIR/elsewhere/normal child"
	mkdir -p "$(dirname "$OTHER")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child

	run "$SCRIPT" remove --path "../../../elsewhere/normal child" --yes

	[ "$status" -eq 0 ]
	[ ! -d "$OTHER" ]
	assert_worktree_not_registered "$OTHER"
}

@test "refuses configured current workspace through its physical alias" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS_DIR="$TMP_DIR/aliases"
	ALIAS="$ALIAS_DIR/current-workspace"
	mkdir -p "$(dirname "$OTHER")" "$ALIAS_DIR"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$ALIAS"

	run env CONDUCTOR_WORKSPACE_PATH="$ALIAS" "$SCRIPT" remove --path "$OTHER" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$OTHER" ]
	grep -Fqx base "$OTHER/README.md"
	assert_worktree_registered "$OTHER"
}

@test "refuses an aliased request for the physical configured current workspace" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS_DIR="$TMP_DIR/aliases"
	ALIAS="$ALIAS_DIR/current-workspace"
	mkdir -p "$(dirname "$OTHER")" "$ALIAS_DIR"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$ALIAS"

	run env CONDUCTOR_WORKSPACE_PATH="$OTHER" "$SCRIPT" remove --path "$ALIAS" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$OTHER" ]
	grep -Fqx base "$OTHER/README.md"
	assert_worktree_registered "$OTHER"
}

@test "refuses a physical request for a chained configured current-workspace alias" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	ALIAS_DIR="$TMP_DIR/aliases"
	FIRST_ALIAS="$ALIAS_DIR/first-current-workspace"
	SECOND_ALIAS="$ALIAS_DIR/second-current-workspace"
	mkdir -p "$(dirname "$OTHER")" "$ALIAS_DIR"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$OTHER" "$FIRST_ALIAS"
	ln -s "$FIRST_ALIAS" "$SECOND_ALIAS"

	run env CONDUCTOR_WORKSPACE_PATH="$SECOND_ALIAS" "$SCRIPT" remove --path "$OTHER" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$OTHER" ]
	grep -Fqx base "$OTHER/README.md"
	assert_worktree_registered "$OTHER"
}

@test "refuses removal when the requested path cannot be resolved" {
	BROKEN_ALIAS="$TMP_DIR/elsewhere/broken-child"
	mkdir -p "$(dirname "$BROKEN_ALIAS")"
	ln -s "$TMP_DIR/missing-child" "$BROKEN_ALIAS"

	run "$SCRIPT" remove --path "$BROKEN_ALIAS" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove worktree with unresolved path"* ]]
	[ -d "$CHILD" ]
	grep -Fqx base "$CHILD/README.md"
	assert_worktree_registered "$CHILD"
}

@test "refuses removal when the configured current-workspace path cannot be resolved" {
	OTHER="$TMP_DIR/elsewhere/normal-child"
	BROKEN_ALIAS="$TMP_DIR/aliases/broken-current-workspace"
	mkdir -p "$(dirname "$OTHER")" "$(dirname "$BROKEN_ALIAS")"
	git branch normal-child
	git worktree add -q "$OTHER" normal-child
	ln -s "$TMP_DIR/missing-current-workspace" "$BROKEN_ALIAS"

	run env CONDUCTOR_WORKSPACE_PATH="$BROKEN_ALIAS" "$SCRIPT" remove --path "$OTHER" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"configured Conductor workspace path is unresolved"* ]]
	[ -d "$OTHER" ]
	grep -Fqx base "$OTHER/README.md"
	assert_worktree_registered "$OTHER"
}

@test "refuses Conductor workspace removal when the path contains spaces" {
	SPACED="$TMP_DIR/conductor/workspaces/space child"
	git branch space-branch
	git worktree add -q "$SPACED" space-branch

	run "$SCRIPT" remove --path "$SPACED" --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to remove likely Conductor workspace without --allow-conductor"* ]]
	[ -d "$SPACED" ]
	grep -Fqx base "$SPACED/README.md"
	assert_worktree_registered "$SPACED"
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
