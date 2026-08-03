#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	SCRIPT="$REPO_ROOT/skills/kramme:git:recreate-commits/scripts/resolve-push-target.sh"
	TMP_DIR="$(mktemp -d)"
	REMOTE="$TMP_DIR/remote.git"
	WORK="$TMP_DIR/work"

	git init --bare "$REMOTE" >/dev/null
	git clone "$REMOTE" "$WORK" >/dev/null 2>&1
	cd "$WORK"
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config commit.gpgsign false
	printf 'base\n' >tracked.txt
	git add tracked.txt
	git commit -m "initial" >/dev/null
	git branch -M main
	git push -u origin main >/dev/null 2>&1
	git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main
	git switch -c feature >/dev/null 2>&1
	printf 'feature\n' >feature.txt
	git add feature.txt
	git commit -m "feature" >/dev/null
	git push -u origin feature >/dev/null 2>&1
}

teardown() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

load_assignments() {
	local assignments
	assignments=$(printf '%s\n' "$output" | grep -E '^(PUSH_SOURCE_BRANCH|PUSH_REMOTE_URL|PUSH_REMOTE_REF|PUSH_LEASE_OID)=' || true)
	eval "$assignments"
}

add_fork_remote() {
	FORK="$TMP_DIR/fork.git"
	git init --bare "$FORK" >/dev/null
	git remote add fork "$FORK"
	git push fork feature >/dev/null 2>&1
	git fetch fork feature:refs/remotes/fork/feature >/dev/null 2>&1
}

@test "resolves the tracked branch to an exact remote ref and lease" {
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 0 ]
	load_assignments
	[ "$PUSH_SOURCE_BRANCH" = "feature" ]
	[ "$PUSH_REMOTE_URL" = "$REMOTE" ]
	[ "$PUSH_REMOTE_REF" = "refs/heads/feature" ]
	[ "$PUSH_LEASE_OID" = "$(git rev-parse refs/remotes/origin/feature)" ]
}

@test "honors branch pushRemote and freezes that destination" {
	add_fork_remote
	git config push.default current
	git config branch.feature.pushRemote fork
	local original_tip origin_tip
	original_tip="$(git rev-parse HEAD)"
	origin_tip="$(git --git-dir="$REMOTE" rev-parse refs/heads/feature)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 0 ]
	load_assignments
	[ "$PUSH_REMOTE_URL" = "$FORK" ]
	[ "$PUSH_REMOTE_REF" = "refs/heads/feature" ]
	[ "$PUSH_LEASE_OID" = "$(git rev-parse refs/remotes/fork/feature)" ]

	git commit --amend -m "recreated feature" >/dev/null
	git push \
		--no-follow-tags \
		--force-with-lease="${PUSH_REMOTE_REF}:${PUSH_LEASE_OID}" \
		-- "$PUSH_REMOTE_URL" "HEAD:${PUSH_REMOTE_REF}" >/dev/null 2>&1
	[ "$(git --git-dir="$FORK" rev-parse refs/heads/feature)" = "$(git rev-parse HEAD)" ]
	[ "$(git --git-dir="$REMOTE" rev-parse refs/heads/feature)" = "$origin_tip" ]
}

@test "honors remote pushDefault when branch pushRemote is absent" {
	add_fork_remote
	git config push.default current
	git config remote.pushDefault fork
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 0 ]
	load_assignments
	[ "$PUSH_REMOTE_URL" = "$FORK" ]
	[ "$PUSH_LEASE_OID" = "$(git rev-parse refs/remotes/fork/feature)" ]
}

@test "rejects a push refspec that renames the destination branch" {
	git push origin feature:refs/heads/review/feature >/dev/null 2>&1
	git fetch origin refs/heads/review/feature:refs/remotes/origin/review/feature >/dev/null 2>&1
	git config remote.origin.push refs/heads/feature:refs/heads/review/feature
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"remaps it to 'refs/remotes/origin/review/feature'"* ]]
}

@test "rejects fetched upstream commits missing from the local original tip" {
	local original_tip
	local collaborator="$TMP_DIR/collaborator"
	original_tip="$(git rev-parse HEAD)"

	git clone "$REMOTE" "$collaborator" >/dev/null 2>&1
	git -C "$collaborator" config user.email "collaborator@example.com"
	git -C "$collaborator" config user.name "Collaborator"
	git -C "$collaborator" switch feature >/dev/null 2>&1
	printf 'collaborator\n' >>"$collaborator/feature.txt"
	git -C "$collaborator" commit -am "collaborator" >/dev/null
	git -C "$collaborator" push >/dev/null 2>&1
	git fetch origin feature >/dev/null 2>&1

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"contains commits absent from the local original tip"* ]]
}

@test "explicit push target ignores wildcard configured push refspecs" {
	git switch main >/dev/null 2>&1
	git switch -c victim >/dev/null 2>&1
	printf 'victim\n' >victim.txt
	git add victim.txt
	git commit -m "victim" >/dev/null
	git push -u origin victim >/dev/null 2>&1
	local victim_remote_before
	victim_remote_before="$(git --git-dir="$REMOTE" rev-parse refs/heads/victim)"

	git switch feature >/dev/null 2>&1
	local original_tip
	original_tip="$(git rev-parse HEAD)"
	run "$SCRIPT" --original-tip "$original_tip" --base-branch main
	[ "$status" -eq 0 ]
	load_assignments

	git branch -f victim main
	git commit --amend -m "recreated feature" >/dev/null
	git tag -a release-candidate -m "release candidate"
	git config remote.origin.push 'refs/heads/*:refs/heads/*'
	git config push.followTags true
	git push \
		--no-follow-tags \
		--force-with-lease="${PUSH_REMOTE_REF}:${PUSH_LEASE_OID}" \
		-- "$PUSH_REMOTE_URL" "HEAD:${PUSH_REMOTE_REF}" >/dev/null 2>&1

	[ "$(git --git-dir="$REMOTE" rev-parse refs/heads/victim)" = "$victim_remote_before" ]
	[ "$(git --git-dir="$REMOTE" rev-parse refs/heads/feature)" = "$(git rev-parse HEAD)" ]
	! git --git-dir="$REMOTE" show-ref --verify --quiet refs/tags/release-candidate
}

@test "returns an empty target for a branch without a remote upstream" {
	git branch --unset-upstream
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 0 ]
	load_assignments
	[ "$PUSH_SOURCE_BRANCH" = "" ]
	[ "$PUSH_REMOTE_URL" = "" ]
	[ "$PUSH_REMOTE_REF" = "" ]
	[ "$PUSH_LEASE_OID" = "" ]
}

@test "rejects an empty upstream config value instead of treating it as absent" {
	git config branch.feature.remote ""
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"branch.feature.remote' is present but empty"* ]]
}

@test "fails closed when upstream config cannot be read" {
	local bin_dir="$TMP_DIR/bin"
	local real_git
	real_git="$(command -v git)"
	mkdir -p "$bin_dir"
	cat >"$bin_dir/git" <<'GIT'
#!/bin/sh
if [ "$1" = "config" ] && [ "$2" = "--get" ] && [ "$3" = "branch.feature.remote" ]; then
  exit 2
fi
exec "$REAL_GIT" "$@"
GIT
	chmod +x "$bin_dir/git"
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run env PATH="$bin_dir:$PATH" REAL_GIT="$real_git" "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"Could not read Git configuration 'branch.feature.remote'"* ]]
}

@test "rejects an upstream that targets the base branch" {
	git branch --set-upstream-to=origin/main feature >/dev/null
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"targets the base branch 'main'"* ]]
}

@test "rejects incomplete upstream configuration instead of treating it as local-only" {
	git config --unset branch.feature.merge
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"upstream configuration for 'feature' is incomplete"* ]]
}

@test "rejects remotes with multiple push destinations" {
	local mirror="$TMP_DIR/mirror.git"
	git clone --bare "$REMOTE" "$mirror" >/dev/null 2>&1
	git remote set-url --push origin "$REMOTE"
	git remote set-url --add --push origin "$mirror"
	local original_tip
	original_tip="$(git rev-parse HEAD)"

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"must resolve to exactly one push URL"* ]]
}

@test "rejects a branch tip that changed after backup creation" {
	local original_tip
	original_tip="$(git rev-parse HEAD)"
	printf 'late\n' >>feature.txt
	git commit -am "late commit" >/dev/null

	run "$SCRIPT" --original-tip "$original_tip" --base-branch main

	[ "$status" -eq 1 ]
	[[ "$output" == *"current tip changed after backup creation"* ]]
}
