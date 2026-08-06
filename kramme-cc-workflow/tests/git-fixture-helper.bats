#!/usr/bin/env bats
# Tests for the shared init_test_git_repo fixture helper

load 'test_helper/common'

setup() {
	TMP_DIR="$(mktemp -d)"
	WORK="$TMP_DIR/work"
	ORIGIN="$TMP_DIR/origin.git"
	GLOBAL_CONFIG="$TMP_DIR/gitconfig"

	# Every assertion below runs against a global configuration that breaks unprepared
	# fixtures, which is what contributors hit locally. The real global config is never
	# read or written because GIT_CONFIG_GLOBAL redirects it into TMP_DIR.
	cat >"$GLOBAL_CONFIG" <<'CONFIG'
[user]
	name = Global Contributor
	email = global@example.invalid
[commit]
	gpgsign = true
[tag]
	gpgsign = true
[init]
	defaultBranch = trunk
CONFIG
	export GIT_CONFIG_GLOBAL="$GLOBAL_CONFIG"
	export GIT_CONFIG_NOSYSTEM=1
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "commits as the fixture identity on main with signing disabled" {
	init_test_git_repo "$WORK"

	[ "$(git -C "$WORK" rev-parse --abbrev-ref HEAD)" = "main" ]
	[ "$(git -C "$WORK" log --format=%an%n%ae%n%cn%n%ce%n%s -1)" = \
		$'Test User\ntest@example.com\nTest User\ntest@example.com\ninitial' ]
	[ "$(git -C "$WORK" rev-list --count HEAD)" -eq 1 ]
	! git -C "$WORK" cat-file commit HEAD | grep -q '^gpgsig'
}

@test "creates annotated tags while global tag signing is enabled" {
	init_test_git_repo "$WORK"

	git -C "$WORK" tag -a fixture-tag -m "fixture tag"

	[ "$(git -C "$WORK" rev-parse fixture-tag^{})" = "$(git -C "$WORK" rev-parse HEAD)" ]
}

@test "commits tracked.txt by default and the requested file otherwise" {
	init_test_git_repo "$WORK"
	init_test_git_repo "$TMP_DIR/readme-work" --file README.md

	[ "$(git -C "$WORK" show --name-only --format= HEAD)" = "tracked.txt" ]
	[ "$(cat "$WORK/tracked.txt")" = "base" ]
	[ "$(git -C "$TMP_DIR/readme-work" show --name-only --format= HEAD)" = "README.md" ]
}

@test "initializes a standalone repository without a remote by default" {
	init_test_git_repo "$WORK"

	[ -z "$(git -C "$WORK" remote)" ]
}

@test "clones an optional bare origin and tracks main upstream" {
	init_test_git_repo "$WORK" --origin "$ORIGIN"

	[ "$(git -C "$ORIGIN" rev-parse --is-bare-repository)" = "true" ]
	[ "$(git -C "$WORK" rev-parse --abbrev-ref main@{upstream})" = "origin/main" ]
	[ "$(git -C "$ORIGIN" rev-parse refs/heads/main)" = "$(git -C "$WORK" rev-parse HEAD)" ]
}

@test "leaves the caller's working directory and global config untouched" {
	local before_pwd="$PWD"
	local before_config
	before_config="$(cat "$GLOBAL_CONFIG")"

	init_test_git_repo "$WORK" --origin "$ORIGIN"

	[ "$PWD" = "$before_pwd" ]
	[ "$(cat "$GLOBAL_CONFIG")" = "$before_config" ]
}

@test "rejects an unknown option instead of creating a repository" {
	run init_test_git_repo "$WORK" --branch trunk

	[ "$status" -eq 1 ]
	[[ "$output" == *"init_test_git_repo: unknown option: --branch"* ]]
	[ ! -e "$WORK" ]
}

@test "rejects options without values instead of hanging" {
	local option

	for option in --origin --file; do
		run init_test_git_repo "$WORK" "$option"

		[ "$status" -eq 1 ]
		[[ "$output" == *"init_test_git_repo: option requires a value: $option"* ]]
		[ ! -e "$WORK" ]
	done
}

@test "returns failure when the initial file cannot be written" {
	mkdir -p "$WORK/tracked.txt"

	run init_test_git_repo "$WORK"

	[ "$status" -ne 0 ]
	! git -C "$WORK" rev-parse --verify HEAD >/dev/null 2>&1
}
