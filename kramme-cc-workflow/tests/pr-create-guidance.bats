#!/usr/bin/env bats

assert_required_contracts_registered() {
	cd "$BATS_TEST_DIRNAME/.."
	python3 - "$@" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path("scripts/synced-contracts.yaml").read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
missing = sorted(set(sys.argv[1:]) - registered)
if missing:
    raise SystemExit(f"missing required_file_contracts: {', '.join(missing)}")
PY
}

extract_commit_and_include_block() {
	python3 - "$1" "$2" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
section = source.split('#### If "Commit and include"', 1)[1]
block = section.split("```bash", 1)[1].split("```", 1)[0].strip()
pathlib.Path(sys.argv[2]).write_text(f"{block}\n")
PY
}

file_mode() {
	if [ "$(uname -s)" = "Darwin" ]; then
		stat -f '%Lp' "$1"
	else
		stat -c '%a' "$1"
	fi
}

@test "pr-create owns one absence-leased remote publication" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"
    recreate="skills/kramme:git:recreate-commits/SKILL.md"

    grep -qF "[--authorize-history-rewrite]" "$create"
    grep -qF "AUTHORIZE_HISTORY_REWRITE=true" "$create"
    grep -qF -- "--auto --no-push --authorize-history-rewrite" "$create"
    grep -qF "Always pass \`--no-push\`" "$create"
    grep -qF "Neither \`AUTO_MODE\` nor branch handling may publish the pre-rewrite history early" "$branch"
    ! grep -qF "git push -u origin \$(git branch --show-current)" "$branch"
    grep -qF "Step 5 proved that \`{rollback-origin-ref}\` was absent" "$confirmation"
    grep -qF "If any actor creates the remote branch after Step 5, the lease fails" "$confirmation"
    grep -qF "no Pull Request could have existed for that branch at the moment this workflow created it" "$confirmation"
    grep -qF "Immediately before any push, repeat the fail-closed open-Pull-Request check" "$confirmation"
    grep -qF "If an open Pull Request appeared after Step 3.5" "$confirmation"
    grep -qF "does not prove that this invocation owns the Pull Request" "$confirmation"
    grep -qF -- "--force-with-lease=\"{rollback-origin-ref}:\"" "$confirmation"
    ! grep -qF -- "--force-with-lease=\"{rollback-origin-ref}:{rollback-origin-oid}\"" "$confirmation"
    grep -qF "Do not use plain \`--force\`, an OID lease for a pre-existing remote ref" "$confirmation"
    grep -qF "workflow'\''s sole remote update before Pull Request creation" "$confirmation"
    grep -qF "[--no-push] [--authorize-history-rewrite]" "$recreate"
    grep -qF "If \`--no-push\` was passed, do not run any push command" "$recreate"
    grep -qF "\`--auto\` alone is not authorization" "$recreate"
  '

	assert_required_contracts_registered \
		pr-create-history-rewrite-authorization \
		pr-create-deferred-upstream-contract \
		pr-create-absence-lease-contract \
		pr-create-remote-absence-contract \
		recreate-commits-deferred-push-contract

	[ "$status" -eq 0 ]
}

@test "absence lease rejects a concurrently created remote branch" {
	run bash -c '
    set -e
    root="$1"
    remote="$root/remote.git"
    publisher="$root/publisher"
    contender="$root/contender"

    git init --bare "$remote" >/dev/null
    git init "$publisher" >/dev/null
    git -C "$publisher" config user.name "Test User"
    git -C "$publisher" config user.email "test@example.com"
    printf "base\n" >"$publisher/file.txt"
    git -C "$publisher" add file.txt
    git -C "$publisher" commit -m "base" >/dev/null
    git -C "$publisher" branch -M main
    git -C "$publisher" remote add origin "$remote"
    git -C "$publisher" push -u origin main >/dev/null
    git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

    git clone "$remote" "$contender" >/dev/null
    git -C "$publisher" checkout -b feature >/dev/null
    printf "publisher\n" >>"$publisher/file.txt"
    git -C "$publisher" commit -am "publisher work" >/dev/null

    test -z "$(git -C "$publisher" ls-remote --heads origin refs/heads/feature)"
    git -C "$contender" checkout -b feature origin/main >/dev/null
    git -C "$contender" push origin HEAD:refs/heads/feature >/dev/null
    expected=$(git -C "$contender" rev-parse HEAD)

    if git -C "$publisher" push \
      --force-with-lease=refs/heads/feature: \
      origin HEAD:refs/heads/feature >/dev/null 2>&1; then
      exit 1
    fi

    actual=$(git -C "$publisher" ls-remote --heads origin refs/heads/feature | awk "{print \$1}")
    test "$actual" = "$expected"
  ' _ "$BATS_TEST_TMPDIR"

	[ "$status" -eq 0 ]
}

@test "existing remote branch stops before history rewriting" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    grep -qF "The feature branch already exists on \`origin\`" "$create"
    grep -qF "continue only when it returns no matching ref" "$state"
    grep -qF "stop before \`kramme:git:recreate-commits\`" "$state"
    grep -qF "never rewrites an existing remote ref" "$state"
    grep -qF "cannot atomically prevent another actor from opening a Pull Request" "$state"
    grep -qF "Do not use plain \`--force\`, an OID lease for a pre-existing remote ref" "$confirmation"
    ! grep -qF "git fetch --no-tags origin \"{rollback-origin-ref}\"" "$state"
    ! grep -qF "git merge-base --is-ancestor \"{rollback-origin-oid}\" \"{original-commit}\"" "$state"
  '

	[ "$status" -eq 0 ]
}

@test "pr-create guidance contracts are registered and files are wired" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    preflight="skills/kramme:pr:create/references/pre-validation-checks.md"
    branch="skills/kramme:pr:create/references/branch-and-platform-handling.md"
    confirmation="skills/kramme:pr:create/references/confirmation-and-creation.md"

    test -f "$create"
    test -f "$preflight"
    test -f "$branch"
    test -f "$confirmation"

    grep -qF "references/pre-validation-checks.md" "$create"
    grep -qF "references/branch-and-platform-handling.md" "$create"
    grep -qF "references/state-and-rollback.md" "$create"
    grep -qF "references/confirmation-and-creation.md" "$create"
    grep -qF "## Step 3.5: Reject an Existing Pull Request" "$create"
    grep -qF "Inspect the agent-tracked value directly" "$create"
    grep -qF "Require the whole string to match \`[A-Za-z0-9][A-Za-z0-9._/-]*\`" "$create"
    grep -qF "git check-ref-format --branch \"{feature-branch}\"" "$create"
    grep -qF "gh pr list --head \"{feature-branch}\" --state open" "$create"
    grep -qF "errors are blockers, not evidence that no Pull Request exists" "$create"

    branch_validation_line=$(grep -nF "Inspect the agent-tracked value directly" "$create" | cut -d: -f1)
    git_validation_line=$(grep -nF "git check-ref-format --branch \"{feature-branch}\"" "$create" | cut -d: -f1)
    existing_pr_query_line=$(grep -nF "gh pr list --head \"{feature-branch}\" --state open" "$create" | cut -d: -f1)
    [ "$branch_validation_line" -lt "$git_validation_line" ]
    [ "$git_validation_line" -lt "$existing_pr_query_line" ]

    ! grep -qF "pr-title.XXXXXX.txt" "$confirmation"
    ! grep -qF "pr-body.XXXXXX.md" "$confirmation"
    ! grep -q -- "--body \"\$(cat <<" "$confirmation"
  '

	assert_required_contracts_registered \
		pr-create-gh-prevalidation \
		pr-create-existing-pr-preflight \
		pr-create-description-generation-contract \
		pr-create-linear-id-normalization \
		pr-create-branch-linear-state \
		pr-create-body-file-contract \
		pr-create-edit-loop-linear-normalization

	[ "$status" -eq 0 ]
}

@test "pr-create restores the original index when the include commit fails" {
	state="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/state-and-rollback.md"
	block="$BATS_TEST_TMPDIR/commit-and-include.sh"
	repo="$BATS_TEST_TMPDIR/repo"
	extract_commit_and_include_block "$state" "$block"

	git init --shared=group "$repo"
	cd "$repo"
	git config user.name "Test User"
	git config user.email "test@example.com"
	printf 'initial\n' > tracked.txt
	git add tracked.txt
	git commit -m "Initial commit"
	printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

	printf 'staged\n' > staged.txt
	git add staged.txt
	printf 'unstaged\n' >> tracked.txt
	printf 'untracked\n' > untracked.txt
	index_path=$(git rev-parse --git-path index)
	chmod 0664 "$index_path"

	before_head=$(git rev-parse HEAD)
	before_index=$(git hash-object "$index_path")
	before_mode=$(file_mode "$index_path")
	before_cached=$(git diff --cached --binary)
	before_unstaged=$(git diff --binary)
	before_status=$(git status --porcelain)

	run bash "$block"
	[ "$status" -ne 0 ]
	[[ "$output" == *"restored the original Git index"* ]]
	[ "$(git rev-parse HEAD)" = "$before_head" ]
	[ "$(git hash-object "$index_path")" = "$before_index" ]
	[ "$(file_mode "$index_path")" = "$before_mode" ]
	[ "$(git diff --cached --binary)" = "$before_cached" ]
	[ "$(git diff --binary)" = "$before_unstaged" ]
	[ "$(git status --porcelain)" = "$before_status" ]
}

@test "pr-create preserves the index backup when restoration fails" {
	state="$BATS_TEST_DIRNAME/../skills/kramme:pr:create/references/state-and-rollback.md"
	block="$BATS_TEST_TMPDIR/commit-and-include.sh"
	repo="$BATS_TEST_TMPDIR/repo"
	fake_bin="$BATS_TEST_TMPDIR/fake-bin"
	extract_commit_and_include_block "$state" "$block"

	git init "$repo"
	cd "$repo"
	git config user.name "Test User"
	git config user.email "test@example.com"
	printf 'initial\n' > tracked.txt
	git add tracked.txt
	git commit -m "Initial commit"
	printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

	printf 'staged\n' > staged.txt
	git add staged.txt
	printf 'unstaged\n' >> tracked.txt
	index_path=$(git rev-parse --git-path index)
	before_head=$(git rev-parse HEAD)
	before_index=$(git hash-object "$index_path")

	mkdir -p "$fake_bin"
	printf '#!/bin/sh\nexit 73\n' > "$fake_bin/mv"
	chmod +x "$fake_bin/mv"

	run env PATH="$fake_bin:$PATH" bash "$block"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to restore the original Git index. Backup remains at "* ]]
	[[ "$output" != *"restored the original Git index"* ]]
	backup_path=${output##*Backup remains at }
	backup_path=${backup_path%.}
	[ -f "$backup_path" ]
	[ "$(git hash-object "$backup_path")" = "$before_index" ]
	[ "$(git rev-parse HEAD)" = "$before_head" ]
}

@test "pr-create state and rollback guidance keeps required sections" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    state="skills/kramme:pr:create/references/state-and-rollback.md"

    test -f "$state"
    grep -q "^## Step 5: State Preservation" "$state"
    grep -q "^## Step 9.0: Restore Excluded Uncommitted Changes" "$state"
    grep -q "^## Step 10: Abort and Rollback" "$state"
    grep -qF "{rollback-origin-ref}" "$state"
    grep -qF "{rollback-origin-oid}" "$state"
    grep -qF "git ls-remote --heads origin \"{rollback-origin-ref}\"" "$state"
    grep -qF "continue only when it returns no matching ref" "$state"
    grep -qF "Neither \`--auto\` nor \`--authorize-history-rewrite\` may bypass the remote-absence requirement" "$state"
    grep -qF "never force-push, delete, or recreate the remote ref during automatic rollback" "$state"
    grep -qF "Remote state: {unchanged at captured OID/absence | diverged" "$state"
    grep -qF "Remote restoration is claimed only when the read-only comparison reports \`unchanged\`" "$state"
    ! grep -qF "Your work has been restored to the pre-skill branch state." "$state"
  '

	assert_required_contracts_registered \
		pr-create-remote-absence-contract \
		pr-create-state-restoration-contract

	[ "$status" -eq 0 ]
}

@test "pr-create auto mode includes uncommitted work without prompting" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    create="skills/kramme:pr:create/SKILL.md"
    state="skills/kramme:pr:create/references/state-and-rollback.md"

    grep -qF "include all uncommitted changes by selecting **Commit and include**" "$create"
    grep -qF "Step 5 uncommitted-work decision when \`AUTO_MODE=false\`" "$create"
    grep -qF "If uncommitted changes are present and \`AUTO_MODE=true\`, do not prompt." "$state"
    grep -qF "Select **Commit and include** and execute that path below." "$state"
    grep -qF "If uncommitted changes are present and \`AUTO_MODE=false\`" "$state"
  '

	[ "$status" -eq 0 ]
}
