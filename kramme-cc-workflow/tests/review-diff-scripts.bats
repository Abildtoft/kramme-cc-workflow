#!/usr/bin/env bats

setup() {
	SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts"
	TMP_DIR="$(mktemp -d)"
	ORIGIN="$TMP_DIR/origin.git"
	WORK="$TMP_DIR/work"

	git init --bare "$ORIGIN" >/dev/null
	git clone "$ORIGIN" "$WORK" >/dev/null 2>&1
	cd "$WORK"
	git config user.email "test@example.com"
	git config user.name "Test User"
	printf 'base\n' >tracked.txt
	git add tracked.txt
	git commit -m "initial" >/dev/null
	git branch -M main
	git push -u origin main >/dev/null 2>&1
	git remote set-head origin main >/dev/null 2>&1
	git switch -c feature >/dev/null 2>&1
}

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "resolve-base resolves origin HEAD and merge base" {
	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"BASE_BRANCH=main"* ]]
	[[ "$output" == *"BASE_REF=refs/remotes/origin/main"* ]]
	[[ "$output" == *"MERGE_BASE="* ]]
}

@test "resolve-base strict mode fails when fetch fails" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --strict

	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch origin/main"* ]]
}

@test "resolve-base can tolerate fetch failure when cached ref exists" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --tolerate-fetch-failure

	[ "$status" -eq 0 ]
	[[ "$output" == *"BASE_BRANCH=main"* ]]
	[[ "$output" == *"Warning: failed to fetch origin/main"* ]]
}

@test "collect-review-diff includes committed staged unstaged and untracked files" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null

	printf 'staged\n' >staged.txt
	git add staged.txt

	printf 'base\nunstaged\n' >tracked.txt
	printf 'untracked\n' >untracked.txt

	run bash -c '
    set -e
    eval "$("'"$SCRIPT_DIR"'/collect-review-diff.sh")"
    printf "%s\n" "$CHANGED_FILES"
  '

	[ "$status" -eq 0 ]
	[ "$output" = $'committed.txt\nstaged.txt\ntracked.txt\nuntracked.txt' ]
}

@test "resolve-base backup mode creates recovery branch" {
	printf 'committed\n' >committed.txt
	git add committed.txt
	git commit -m "feature commit" >/dev/null
	feature_tip=$(git rev-parse HEAD)

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 0 ]
	[[ "$output" == *"BACKUP_REF=feature-recreate-backup"* ]]
	[ "$(git rev-parse feature-recreate-backup)" = "$feature_tip" ]
}

@test "shared scripts parse as bash" {
	run bash -n "$SCRIPT_DIR/resolve-base.sh"
	[ "$status" -eq 0 ]

	run bash -n "$SCRIPT_DIR/collect-review-diff.sh"
	[ "$status" -eq 0 ]
}
