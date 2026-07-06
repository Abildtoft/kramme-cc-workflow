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
