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

    ! grep -qF "pr-title.XXXXXX.txt" "$confirmation"
    ! grep -qF "pr-body.XXXXXX.md" "$confirmation"
    ! grep -q -- "--body \"\$(cat <<" "$confirmation"
  '

	assert_required_contracts_registered \
		pr-create-gh-prevalidation \
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
  '

	assert_required_contracts_registered pr-create-state-restoration-contract

	[ "$status" -eq 0 ]
}
