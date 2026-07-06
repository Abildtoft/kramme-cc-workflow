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

@test "linear issue implement maps referenced Linear context into research and plan" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:linear:issue-implement"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/display-templates.md"
    test -f "$skill/assets/technical-plan.md"

    branch_line=$(grep -nF "[Branch Setup] -> IMMEDIATELY create/switch to Linear'\''s branchName" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    reference_line=$(grep -nF "[Reference Mapping] -> Fetch linked Linear issues/docs and record inaccessible assets" "$skill/SKILL.md" | head -n1 | cut -d: -f1)
    [ "$branch_line" -lt "$reference_line" ]
  '

	assert_required_contracts_registered \
		linear-issue-implement-reference-mapping \
		linear-issue-implement-display-template \
		linear-issue-implement-plan-template \
		linear-issue-implement-readme-note

	[ "$status" -eq 0 ]
}
