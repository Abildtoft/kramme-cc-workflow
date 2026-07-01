#!/usr/bin/env bats

setup() {
	SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts"
	TMP_DIR="$(mktemp -d)"
	ORIGIN="$TMP_DIR/origin.git"
	WORK="$TMP_DIR/work"
	BIN_DIR="$TMP_DIR/bin"
	mkdir -p "$BIN_DIR"
	write_failing_gh
	export PATH="$BIN_DIR:$PATH"

	git init --bare "$ORIGIN" >/dev/null
	git clone "$ORIGIN" "$WORK" >/dev/null 2>&1
	cd "$WORK"
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config commit.gpgsign false
	printf 'base\n' >tracked.txt
	git add tracked.txt
	git commit -m "initial" >/dev/null
	git branch -M main
	git push -u origin main >/dev/null 2>&1
	git remote set-head origin main >/dev/null 2>&1
	git switch -c feature >/dev/null 2>&1
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

write_failing_gh() {
	cat >"$BIN_DIR/gh" <<'GH'
#!/bin/sh
exit 1
GH
	chmod +x "$BIN_DIR/gh"
}

write_gh_base() {
	local branch="$1"
	cat >"$BIN_DIR/gh" <<GH
#!/bin/sh
if [ "\$*" = "pr view --json baseRefName --jq .baseRefName" ]; then
  if [ "\${GH_PROMPT_DISABLED:-}" != "1" ]; then
    exit 3
  fi
  printf '%s\n' "$branch"
  exit 0
fi
exit 1
GH
	chmod +x "$BIN_DIR/gh"
}

write_git_fetch_env_assertion() {
	local real_git
	real_git="${CONDUCTOR_REAL_GIT_PATH:-$(command -v git)}"
	cat >"$BIN_DIR/git" <<GIT
#!/bin/sh
if [ "\$1" = "fetch" ]; then
  if [ "\${GIT_TERMINAL_PROMPT:-}" != "0" ]; then
    echo "missing GIT_TERMINAL_PROMPT=0" >&2
    exit 86
  fi
  if [ "\${GCM_INTERACTIVE:-}" != "Never" ]; then
    echo "missing GCM_INTERACTIVE=Never" >&2
    exit 86
  fi
fi
exec "$real_git" "\$@"
GIT
	chmod +x "$BIN_DIR/git"
}

write_slow_git_fetch() {
	local real_git
	real_git="${CONDUCTOR_REAL_GIT_PATH:-$(command -v git)}"
	cat >"$BIN_DIR/git" <<GIT
#!/bin/sh
if [ "\$1" = "fetch" ]; then
  if [ -n "\${MOCK_GIT_FETCH_CHILD_MARKER:-}" ]; then
    sh -c 'sleep "\$1"; printf alive > "\$2"' sh "\${MOCK_GIT_FETCH_CHILD_SLEEP_SECONDS:-0.2}" "\$MOCK_GIT_FETCH_CHILD_MARKER" &
    wait
    exit 87
  fi
  sleep "\${MOCK_GIT_FETCH_SLEEP_SECONDS:-1}"
  exit 87
fi
exec "$real_git" "\$@"
GIT
	chmod +x "$BIN_DIR/git"
}

load_assignments() {
	local assignments
	assignments=$(printf '%s\n' "$output" | grep -E '^(BASE_REF|BASE_BRANCH|MERGE_BASE|AFTER_COMMIT|RESET_POINT|ORIGINAL_TIP|BACKUP_REF)=' || true)
	eval "$assignments"
}

json_value() {
	local key="$1"
	JSON_OUTPUT="$output" python3 - "$key" <<'PY'
import json
import os
import sys

print(json.loads(os.environ["JSON_OUTPUT"])[sys.argv[1]])
PY
}

json_keys() {
	JSON_OUTPUT="$output" python3 - <<'PY'
import json
import os

print("\n".join(json.loads(os.environ["JSON_OUTPUT"]).keys()))
PY
}

commit_file() {
	local file="$1"
	local content="$2"
	local message="$3"
	printf '%s\n' "$content" >"$file"
	git add "$file"
	git commit -m "$message" >/dev/null
}

create_remote_branch() {
	local branch="$1"
	git branch "$branch" main
	git push origin "$branch" >/dev/null 2>&1
	git fetch origin "$branch:refs/remotes/origin/$branch" >/dev/null 2>&1
}

delete_origin_head() {
	git symbolic-ref --delete refs/remotes/origin/HEAD
}

@test "resolves origin HEAD and prints the stdout assignment contract" {
	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | sed 's/=.*//')" = $'BASE_REF\nBASE_BRANCH\nMERGE_BASE\nAFTER_COMMIT\nRESET_POINT\nORIGINAL_TIP\nBACKUP_REF' ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/main" ]
	[ "$BASE_BRANCH" = "main" ]
	[ -n "$MERGE_BASE" ]
	[ "$AFTER_COMMIT" = "" ]
	[ "$RESET_POINT" = "" ]
	[ "$ORIGINAL_TIP" = "" ]
	[ "$BACKUP_REF" = "" ]
}

@test "json format exports structured fields matching shell compatibility output" {
	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	local expected_base_ref="$BASE_REF"
	local expected_base_branch="$BASE_BRANCH"
	local expected_merge_base="$MERGE_BASE"
	local expected_after_commit="$AFTER_COMMIT"
	local expected_reset_point="$RESET_POINT"
	local expected_original_tip="$ORIGINAL_TIP"
	local expected_backup_ref="$BACKUP_REF"

	run "$SCRIPT_DIR/resolve-base.sh" --format json

	[ "$status" -eq 0 ]
	[ "$(json_keys)" = $'base_ref\nbase_branch\nmerge_base\nafter_commit\nreset_point\noriginal_tip\nbackup_ref' ]
	[ "$(json_value base_ref)" = "$expected_base_ref" ]
	[ "$(json_value base_branch)" = "$expected_base_branch" ]
	[ "$(json_value merge_base)" = "$expected_merge_base" ]
	[ "$(json_value after_commit)" = "$expected_after_commit" ]
	[ "$(json_value reset_point)" = "$expected_reset_point" ]
	[ "$(json_value original_tip)" = "$expected_original_tip" ]
	[ "$(json_value backup_ref)" = "$expected_backup_ref" ]
}

@test "json format treats shell metacharacters as data" {
	local branch='topic-$(touch${IFS}$PWNED_FILE)'
	export PWNED_FILE="$TMP_DIR/json-pwned"
	create_remote_branch "$branch"

	run "$SCRIPT_DIR/resolve-base.sh" --format json --base "$branch"

	[ "$status" -eq 0 ]
	[ "$(json_value base_branch)" = "$branch" ]
	[ ! -e "$PWNED_FILE" ]
}

@test "uses GitHub PR base metadata before origin HEAD" {
	create_remote_branch "develop"
	write_gh_base "develop"

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/develop" ]
	[ "$BASE_BRANCH" = "develop" ]
}

@test "fetch disables interactive credential prompts" {
	write_git_fetch_env_assertion

	run "$SCRIPT_DIR/resolve-base.sh" --base main

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/main" ]
	[ "$BASE_BRANCH" = "main" ]
}

@test "falls back to origin main when origin HEAD is missing" {
	delete_origin_head

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/main" ]
	[ "$BASE_BRANCH" = "main" ]
}

@test "falls back to origin master when no origin HEAD or origin main tracking ref exists" {
	create_remote_branch "master"
	delete_origin_head
	git update-ref -d refs/remotes/origin/main

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/master" ]
	[ "$BASE_BRANCH" = "master" ]
}

@test "fails when no automatic base source is available" {
	delete_origin_head
	git update-ref -d refs/remotes/origin/main

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Could not determine base branch; expected PR metadata, origin/HEAD, origin/main, or origin/master"* ]]
}

@test "explicit base branch wins over GitHub metadata and origin HEAD" {
	create_remote_branch "develop"
	write_gh_base "main"

	run "$SCRIPT_DIR/resolve-base.sh" --base develop

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/develop" ]
	[ "$BASE_BRANCH" = "develop" ]
}

@test "explicit local base ref is normalized to origin remote branch" {
	create_remote_branch "develop"

	run "$SCRIPT_DIR/resolve-base.sh" --base refs/heads/develop

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/develop" ]
	[ "$BASE_BRANCH" = "develop" ]
}

@test "explicit remote base ref preserves its remote" {
	local upstream="$TMP_DIR/upstream.git"
	git init --bare "$upstream" >/dev/null
	git remote add upstream "$upstream"
	git push upstream main:release >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --base refs/remotes/upstream/release

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/upstream/release" ]
	[ "$BASE_BRANCH" = "release" ]
}

@test "explicit branch name with slash is treated as an origin branch when prefix is not a remote" {
	create_remote_branch "release/next"

	run "$SCRIPT_DIR/resolve-base.sh" --base release/next

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/release/next" ]
	[ "$BASE_BRANCH" = "release/next" ]
}

@test "explicit remote-qualified base uses the named remote when it exists" {
	local upstream="$TMP_DIR/upstream.git"
	git init --bare "$upstream" >/dev/null
	git remote add upstream "$upstream"
	git push upstream main:release >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --base upstream/release

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/upstream/release" ]
	[ "$BASE_BRANCH" = "release" ]
}

@test "explicit base fails when origin remote is missing" {
	git remote remove origin

	run "$SCRIPT_DIR/resolve-base.sh" --base main

	[ "$status" -eq 1 ]
	[[ "$output" == *"Explicit base ref 'main' names unknown remote 'origin'"* ]]
}

@test "invalid explicit base branch fails before fetch" {
	run "$SCRIPT_DIR/resolve-base.sh" --base "bad..name"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Explicit base branch 'bad..name' is not a valid branch name"* ]]
}

@test "strict mode fails when fetching the resolved base fails" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --strict

	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch origin/main"* ]]
}

@test "default fetch mode is strict" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch origin/main"* ]]
}

@test "strict mode fails when fetching the resolved base times out" {
	write_slow_git_fetch
	export RESOLVE_BASE_FETCH_TIMEOUT_SECONDS="0.05"
	export MOCK_GIT_FETCH_SLEEP_SECONDS="1"
	export MOCK_GIT_FETCH_CHILD_MARKER="$TMP_DIR/leaked-fetch-child"
	export MOCK_GIT_FETCH_CHILD_SLEEP_SECONDS="0.2"

	run "$SCRIPT_DIR/resolve-base.sh" --strict

	[ "$status" -eq 1 ]
	[[ "$output" == *"Timed out fetching origin/main after 0.05s"* ]]
	sleep 0.3
	[ ! -e "$MOCK_GIT_FETCH_CHILD_MARKER" ]
}

@test "tolerates fetch failure when a cached remote ref exists" {
	git fetch origin main >/dev/null 2>&1
	git remote set-url origin "$TMP_DIR/missing-origin.git"

	run "$SCRIPT_DIR/resolve-base.sh" --tolerate-fetch-failure

	[ "$status" -eq 0 ]
	[[ "$output" == *"Warning: failed to fetch origin/main; using existing refs/remotes/origin/main"* ]]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/main" ]
	[ "$BASE_BRANCH" = "main" ]
}

@test "tolerates fetch timeout when a cached remote ref exists" {
	write_slow_git_fetch
	export RESOLVE_BASE_FETCH_TIMEOUT_SECONDS="0.05"
	export MOCK_GIT_FETCH_SLEEP_SECONDS="1"

	run "$SCRIPT_DIR/resolve-base.sh" --tolerate-fetch-failure

	[ "$status" -eq 0 ]
	[[ "$output" == *"Warning: timed out fetching origin/main; using existing refs/remotes/origin/main"* ]]
	load_assignments
	[ "$BASE_REF" = "refs/remotes/origin/main" ]
	[ "$BASE_BRANCH" = "main" ]
}

@test "normal mode allows detached HEAD" {
	git checkout --detach HEAD >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_BRANCH" = "main" ]
}

@test "backup mode rejects detached HEAD" {
	git checkout --detach HEAD >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"HEAD is detached; switch to the feature branch first"* ]]
}

@test "normal mode allows running on the base branch itself" {
	git switch main >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$BASE_BRANCH" = "main" ]
}

@test "backup mode rejects running on the base branch itself" {
	git switch main >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"Current branch is the base branch 'main'; switch to a feature branch first"* ]]
}

@test "fails when histories are unrelated" {
	git switch --orphan unrelated >/dev/null 2>&1
	git rm -r --cached . >/dev/null 2>&1 || true
	rm -f tracked.txt
	commit_file "unrelated.txt" "unrelated" "unrelated root"

	run "$SCRIPT_DIR/resolve-base.sh" --base main

	[ "$status" -eq 1 ]
	[[ "$output" == *"No merge base between 'refs/remotes/origin/main' and HEAD; histories are unrelated"* ]]
}

@test "after commit is resolved and exported when it is an ancestor of HEAD" {
	commit_file "one.txt" "one" "feature one"
	local after_commit
	after_commit="$(git rev-parse HEAD)"
	commit_file "two.txt" "two" "feature two"

	run "$SCRIPT_DIR/resolve-base.sh" --after "$after_commit"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$AFTER_COMMIT" = "$after_commit" ]
	[ "$RESET_POINT" = "" ]
}

@test "after commit fails when it does not resolve" {
	run "$SCRIPT_DIR/resolve-base.sh" --after missing-commit

	[ "$status" -eq 1 ]
	[[ "$output" == *"--after commit 'missing-commit' does not resolve"* ]]
}

@test "after commit fails when it is not an ancestor of HEAD" {
	git switch -c sibling main >/dev/null 2>&1
	commit_file "sibling.txt" "sibling" "sibling"
	local sibling_commit
	sibling_commit="$(git rev-parse HEAD)"
	git switch feature >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --after "$sibling_commit"

	[ "$status" -eq 1 ]
	[[ "$output" == *"--after commit '$sibling_commit' is not an ancestor of HEAD"* ]]
}

@test "backup mode exports reset point original tip and creates recovery branch" {
	commit_file "feature.txt" "feature" "feature commit"
	local feature_tip
	feature_tip="$(git rev-parse HEAD)"

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 0 ]
	load_assignments
	[ "$RESET_POINT" = "$MERGE_BASE" ]
	[ "$ORIGINAL_TIP" = "$feature_tip" ]
	[ "$BACKUP_REF" = "feature-recreate-backup" ]
	[ "$(git rev-parse feature-recreate-backup)" = "$feature_tip" ]
}

@test "backup mode uses after commit as reset point" {
	commit_file "one.txt" "one" "feature one"
	local after_commit
	after_commit="$(git rev-parse HEAD)"
	commit_file "two.txt" "two" "feature two"
	local feature_tip
	feature_tip="$(git rev-parse HEAD)"

	run "$SCRIPT_DIR/resolve-base.sh" --backup --after "$after_commit"

	[ "$status" -eq 0 ]
	load_assignments
	[ "$AFTER_COMMIT" = "$after_commit" ]
	[ "$RESET_POINT" = "$after_commit" ]
	[ "$ORIGINAL_TIP" = "$feature_tip" ]
}

@test "backup mode rejects dirty working tree" {
	printf 'dirty\n' >>tracked.txt

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"Working tree has uncommitted changes; commit or stash them first"* ]]
}

@test "backup mode fast-forwards matching local base branch to origin" {
	git switch main >/dev/null 2>&1
	local old_main
	old_main="$(git rev-parse HEAD)"
	commit_file "remote.txt" "remote" "remote main"
	git push origin main >/dev/null 2>&1
	git reset --hard "$old_main" >/dev/null
	git switch feature >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 0 ]
	[ "$(git rev-parse main)" = "$(git rev-parse refs/remotes/origin/main)" ]
}

@test "backup mode rejects diverged local base branch" {
	git switch main >/dev/null 2>&1
	commit_file "local.txt" "local" "local main"
	git switch feature >/dev/null 2>&1

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"Local base branch 'main' has diverged from origin/main; resolve manually before retrying"* ]]
}

@test "backup mode refuses to replace existing backup branch without force" {
	commit_file "one.txt" "one" "feature one"
	local old_tip
	old_tip="$(git rev-parse HEAD)"
	git branch feature-recreate-backup "$old_tip"
	commit_file "two.txt" "two" "feature two"

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"Backup branch 'feature-recreate-backup' already exists at $old_tip; refusing to move it."* ]]
}

@test "force backup moves existing backup branch to current tip" {
	commit_file "one.txt" "one" "feature one"
	git branch feature-recreate-backup HEAD
	commit_file "two.txt" "two" "feature two"
	local new_tip
	new_tip="$(git rev-parse HEAD)"

	run "$SCRIPT_DIR/resolve-base.sh" --backup --force-backup

	[ "$status" -eq 0 ]
	[ "$(git rev-parse feature-recreate-backup)" = "$new_tip" ]
}

@test "force backup without backup mode is rejected" {
	run "$SCRIPT_DIR/resolve-base.sh" --force-backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"--force-backup requires --backup"* ]]
}

@test "backup mode refuses to run from the plugin repository itself" {
	cd "$SCRIPT_DIR/.."

	run "$SCRIPT_DIR/resolve-base.sh" --backup

	[ "$status" -eq 1 ]
	[[ "$output" == *"Refusing to run backup mode against the repository that contains this plugin script."* ]]
}

@test "fails outside a git repository" {
	cd "$TMP_DIR"

	run "$SCRIPT_DIR/resolve-base.sh"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Not inside a git repository"* ]]
}

@test "argument parser rejects missing values and unknown arguments" {
	run "$SCRIPT_DIR/resolve-base.sh" --base
	[ "$status" -eq 1 ]
	[[ "$output" == *"--base requires a value"* ]]

	run "$SCRIPT_DIR/resolve-base.sh" --after --strict
	[ "$status" -eq 1 ]
	[[ "$output" == *"--after requires a value"* ]]

	run "$SCRIPT_DIR/resolve-base.sh" --format
	[ "$status" -eq 1 ]
	[[ "$output" == *"--format requires a value"* ]]

	run "$SCRIPT_DIR/resolve-base.sh" --format yaml
	[ "$status" -eq 1 ]
	[[ "$output" == *"--format must be 'shell' or 'json'"* ]]

	run "$SCRIPT_DIR/resolve-base.sh" --bogus
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown argument: --bogus"* ]]
}
