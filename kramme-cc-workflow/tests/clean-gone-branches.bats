#!/usr/bin/env bats
# Tests for kramme:git:clean-gone-branches script

load 'test_helper/common'

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../skills/kramme:git:clean-gone-branches/scripts/clean-gone-branches.sh"
	TMP_DIR="$(mktemp -d)"
	ORIGIN="$TMP_DIR/origin.git"
	WORK="$TMP_DIR/work"

	init_test_git_repo "$WORK" --origin "$ORIGIN" --file README.md
	cd "$WORK"
}

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

make_gone_branch() {
	local branch="$1"
	git switch -c "$branch" main >/dev/null 2>&1
	git push -u origin "$branch" >/dev/null 2>&1
	git switch main >/dev/null 2>&1
	git push origin --delete "$branch" >/dev/null 2>&1
	git fetch --prune >/dev/null 2>&1
}

@test "lists local branches with gone upstreams without deleting" {
	make_gone_branch "stale/topic"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"stale/topic"* ]]
	[[ "$output" == *"origin/stale/topic"* ]]
	[[ "$output" == *"Discovery only"* ]]
	git show-ref --verify --quiet refs/heads/stale/topic
}

@test "refuses deletion without explicit yes flag" {
	make_gone_branch "stale/refuse"

	run "$SCRIPT" --delete

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to delete without --yes"* ]]
	git show-ref --verify --quiet refs/heads/stale/refuse
}

@test "deletes safe merged gone branches after confirmation" {
	make_gone_branch "stale/delete"

	run "$SCRIPT" --delete --yes "stale/delete"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Summary: deleted=1 skipped=0 failed=0"* ]]
	run git show-ref --verify --quiet refs/heads/stale/delete
	[ "$status" -eq 1 ]
}

@test "refuses deletion without confirmed branch names" {
	make_gone_branch "stale/no-confirmed-set"

	run "$SCRIPT" --delete --yes

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to delete without confirmed branch names"* ]]
	git show-ref --verify --quiet refs/heads/stale/no-confirmed-set
}

@test "deletes only confirmed branch names" {
	make_gone_branch "stale/confirmed"
	make_gone_branch "stale/unconfirmed"

	run "$SCRIPT" --delete --yes "stale/confirmed"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Summary: deleted=1 skipped=0 failed=0"* ]]
	[[ "$output" != *"stale/unconfirmed"* ]]
	run git show-ref --verify --quiet refs/heads/stale/confirmed
	[ "$status" -eq 1 ]
	git show-ref --verify --quiet refs/heads/stale/unconfirmed
}

@test "skips gone branches checked out in a worktree" {
	make_gone_branch "stale/worktree"
	git worktree add "$TMP_DIR/linked-worktree" stale/worktree >/dev/null 2>&1

	run "$SCRIPT" --delete --yes "stale/worktree"

	[ "$status" -eq 0 ]
	[[ "$output" == *"checked-out"* ]]
	[[ "$output" == *"SKIP checked-out branch: stale/worktree"* ]]
	git show-ref --verify --quiet refs/heads/stale/worktree
}

@test "labels Conductor workspace paths" {
	make_gone_branch "stale/conductor"
	git worktree add "$TMP_DIR/conductor/workspaces/example" stale/conductor >/dev/null 2>&1

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"stale/conductor"* ]]
	[[ "$output" == *"conductor-workspace"* ]]
}

@test "does not label a branch without a worktree as a Conductor workspace" {
	make_gone_branch "stale/no-worktree"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	line=$(printf '%s\n' "$output" | grep -F "stale/no-worktree")
	[[ "$line" != *"conductor-workspace"* ]]
}

@test "does not label a non-Conductor worktree path" {
	make_gone_branch "stale/normal-worktree"
	git worktree add "$TMP_DIR/elsewhere/normal-worktree" stale/normal-worktree >/dev/null 2>&1

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	line=$(printf '%s\n' "$output" | grep -F "stale/normal-worktree")
	[[ "$line" == *"checked-out"* ]]
	[[ "$line" != *"conductor-workspace"* ]]
}

@test "labels Conductor workspace paths containing spaces" {
	make_gone_branch "stale/space-conductor"
	git worktree add "$TMP_DIR/conductor/workspaces/space example" stale/space-conductor >/dev/null 2>&1

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"stale/space-conductor"* ]]
	[[ "$output" == *"conductor-workspace"* ]]
}
